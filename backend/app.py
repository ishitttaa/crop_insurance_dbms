from flask import Flask, jsonify, request
from flask_cors import CORS
from db_config import get_connection
from datetime import date, datetime
from decimal import Decimal
from external_data import fetch_weather, fetch_crop_prices

app = Flask(__name__)
CORS(app)

def clean_value(v):
    if isinstance(v, (date, datetime)):
        return v.isoformat()
    if isinstance(v, Decimal):
        return float(v)
    return v

def rows_to_json(cursor):
    cols = [c[0] for c in cursor.description]
    rows = cursor.fetchall()
    return [
        {cols[i]: clean_value(row[i]) for i in range(len(cols))}
        for row in rows
    ]

@app.route("/")
def home():
    return "Crop Insurance Backend Running"

@app.route("/api/test-db")
def test_db():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SHOW TABLES")
    data = rows_to_json(cursor)
    cursor.close()
    conn.close()
    return jsonify(data)

@app.route('/api/farmers', methods=['GET'])
def get_farmers():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT f.Farmer_ID AS farmer_id,
               f.Name AS name,
               f.District AS district,
               f.Land_Area AS land_area,
               COUNT(DISTINCT ip.Policy_ID) AS total_policies,
               COUNT(DISTINCT cl.Claim_ID) AS total_claims
        FROM FARMER f
        LEFT JOIN INSURANCE_POLICY ip ON f.Farmer_ID = ip.Farmer_ID
        LEFT JOIN CLAIM cl ON ip.Policy_ID = cl.Policy_ID
        GROUP BY f.Farmer_ID, f.Name, f.District, f.Land_Area
        ORDER BY f.Farmer_ID
    """)
    data = rows_to_json(cursor)
    cursor.close()
    conn.close()
    return jsonify(data)

@app.route('/api/prices', methods=['GET'])
def get_prices():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT Crop_Name, District, Price_Date, Min_Price,
               Max_Price, Modal_Price, MSP,
               Price_Pct_of_MSP, Price_Status
        FROM Price_Volatility_View
        ORDER BY Price_Date DESC
        LIMIT 50
    """)
    data = rows_to_json(cursor)
    cursor.close()
    conn.close()
    return jsonify(data)

@app.route('/api/prices/distress', methods=['GET'])
def get_distress():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT Crop_Name AS crop_name,
               District AS district,
               Price_Date AS price_date,
               Modal_Price AS modal_price,
               MSP AS msp,
               Price_Status AS price_status,
               Price_Pct_of_MSP AS price_pct_of_msp
        FROM Price_Volatility_View
        WHERE Price_Status IN ('DISTRESS','SEVERE DISTRESS','Below MSP')
        ORDER BY Price_Pct_of_MSP ASC
    """)
    data = rows_to_json(cursor)
    cursor.close()
    conn.close()
    return jsonify(data)

@app.route('/api/claims', methods=['GET'])
def get_claims():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT Claim_ID AS claim_id,
               Farmer_Name AS farmer_name,
               District AS district,
               Claim_Status AS claim_status,
               Claim_Date AS claim_date,
               Sum_Insured AS sum_insured,
               Rainfall AS rainfall,
               Payout_Amount AS payout_amount
        FROM Claim_Detail_View
        ORDER BY Claim_ID DESC
    """)
    data = rows_to_json(cursor)
    cursor.close()
    conn.close()
    return jsonify(data)

@app.route('/api/claims/approve/<int:claim_id>', methods=['PUT'])
def approve_claim(claim_id):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE CLAIM
        SET Claim_Status = 'Approved'
        WHERE Claim_ID = %s
    """, (claim_id,))
    conn.commit()
    cursor.close()
    conn.close()
    return jsonify({"message": f"Claim {claim_id} approved"})

@app.route('/api/weather', methods=['POST'])
def add_weather():
    data = request.json
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO WEATHER_EVENT
            (Date, District, Rainfall, Temperature)
            VALUES (%s, %s, %s, %s)
        """, (
            data['date'],
            data['district'],
            data['rainfall'],
            data['temperature']
        ))
        conn.commit()

        msg = "Weather added."
        if float(data['rainfall']) < 50:
            msg += " Low rainfall detected — claims auto-triggered!"

        return jsonify({"message": msg})

    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()

@app.route('/api/stats', methods=['GET'])
def get_stats():
    conn = get_connection()
    cursor = conn.cursor()

    stats = {}

    cursor.execute("SELECT COUNT(*) FROM FARMER")
    stats['total_farmers'] = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM CLAIM")
    stats['total_claims'] = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM CLAIM WHERE Claim_Status='Pending'")
    stats['pending_claims'] = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM CLAIM WHERE Claim_Status='Approved'")
    stats['approved_claims'] = cursor.fetchone()[0]

    cursor.execute("SELECT COALESCE(SUM(Amount), 0) FROM PAYOUT")
    stats['total_payout'] = float(cursor.fetchone()[0])

    cursor.execute("""
        SELECT COUNT(*) FROM Price_Volatility_View
        WHERE Price_Status IN ('DISTRESS','SEVERE DISTRESS', 'Below MSP')
    """)
    stats['distress_records'] = cursor.fetchone()[0]

    cursor.close()
    conn.close()
    return jsonify(stats)

@app.route('/api/schemes', methods=['GET'])
def get_schemes():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT gs.Scheme_Name,
               COUNT(fs.Farmer_ID) AS Farmers_Enrolled
        FROM GOVERNMENT_SCHEME gs
        LEFT JOIN FARMER_SCHEME fs ON gs.Scheme_ID = fs.Scheme_ID
        GROUP BY gs.Scheme_Name
        ORDER BY COUNT(fs.Farmer_ID) DESC
    """)
    data = rows_to_json(cursor)
    cursor.close()
    conn.close()
    return jsonify(data)

@app.route('/api/sync', methods=['POST'])

def sync_data():
    conn = get_connection()
    cursor = conn.cursor()
    
    sync_results = {
        "weather": 0,
        "prices": 0,
        "errors": []
    }

    try:
        # 1. Sync Weather for all districts in FARMER table
        cursor.execute("SELECT DISTINCT District FROM FARMER")
        districts = [row[0] for row in cursor.fetchall()]
        
        for district in districts:
            rainfall, temp = fetch_weather(district)
            if rainfall is not None:
                cursor.execute("""
                    INSERT INTO WEATHER_EVENT (Date, District, Rainfall, Temperature)
                    VALUES (%s, %s, %s, %s)
                """, (datetime.now().date(), district, rainfall, temp))
                sync_results["weather"] += 1
            else:
                sync_results["errors"].append(f"Failed to fetch weather for {district}")

        # 2. Sync Prices for all crops in CROP table across all districts
        cursor.execute("SELECT Crop_ID, Crop_Name FROM CROP")
        crops = cursor.fetchall()
        
        for crop_id, crop_name in crops:
            # For each crop, fetch price for each district where it's grown
            cursor.execute("""
                SELECT DISTINCT District FROM FARMER f
                JOIN FARMER_CROP fc ON f.Farmer_ID = fc.Farmer_ID
                WHERE fc.Crop_ID = %s
            """, (crop_id,))
            crop_districts = [row[0] for row in cursor.fetchall()]
            
            for district in crop_districts:
                min_p, max_p, modal_p = fetch_crop_prices(crop_name, district)
                if modal_p is not None:
                    cursor.execute("""
                        INSERT INTO MANDI_PRICE (Price_Date, District, Min_Price, Max_Price, Modal_Price, Crop_ID)
                        VALUES (%s, %s, %s, %s, %s, %s)
                    """, (datetime.now().date(), district, min_p, max_p, modal_p, crop_id))
                    sync_results["prices"] += 1
                else:
                    # Don't log every miss as error to keep it clean, some mandis might not have daily data
                    pass

        conn.commit()
        return jsonify({
            "message": "Synchronization complete",
            "stats": sync_results
        })

    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    app.run(debug=True, port=5000)