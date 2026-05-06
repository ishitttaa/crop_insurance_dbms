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
        SELECT cl.Claim_ID AS claim_id,
               f.Name AS farmer_name,
               f.District AS district,
               cl.Claim_Status AS claim_status,
               cl.Claim_Date AS claim_date,
               ip.Sum_Insured AS sum_insured,
               we.Rainfall AS rainfall,
               p.Amount AS payout_amount,
               CASE 
                   WHEN ip.Premium = 1000.0 AND ip.Sum_Insured = 50000.0 THEN 'Relief Policy'
                   ELSE 'Standard Policy'
               END AS policy_source
        FROM CLAIM cl
        JOIN INSURANCE_POLICY ip ON cl.Policy_ID = ip.Policy_ID
        JOIN FARMER f ON ip.Farmer_ID = f.Farmer_ID
        JOIN WEATHER_EVENT we ON cl.Weather_ID = we.Weather_ID
        LEFT JOIN PAYOUT p ON cl.Claim_ID = p.Claim_ID
        ORDER BY cl.Claim_ID DESC
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
        rainfall_val = float(data['rainfall'])
        msg = "Weather data recorded."
        
        # 1. Check for Drought (Rainfall < 50mm) - Register Policies BEFORE weather event
        if rainfall_val < 50:
            msg += " DROUGHT DETECTED!"
            today = datetime.now().date()
            next_year = today.replace(year=today.year + 1)
            
            # Auto-Register relief policies for farmers in this district
            cursor.execute("""
                INSERT INTO INSURANCE_POLICY (Sum_Insured, Premium, Start_Date, End_Date, Farmer_ID)
                SELECT 50000.0, 1000.0, %s, %s, f.Farmer_ID
                FROM FARMER f
                LEFT JOIN INSURANCE_POLICY ip ON f.Farmer_ID = ip.Farmer_ID
                WHERE f.District = %s AND ip.Policy_ID IS NULL
            """, (today, next_year, data['district']))
            
            affected_count = cursor.rowcount
            if affected_count > 0:
                msg += f" {affected_count} farmers auto-enrolled in Relief Policy."
        
        # 2. Insert the weather event (This fires the SQL Trigger trg_Auto_Claim_On_Low_Rainfall)
        cursor.execute("""
            INSERT INTO WEATHER_EVENT (Date, District, Rainfall, Temperature)
            VALUES (%s, %s, %s, %s)
        """, (data['date'], data['district'], data['rainfall'], data['temperature']))
        
        conn.commit()
        return jsonify({"message": msg})

    except Exception as e:
        conn.rollback()
        print(f"ADD_WEATHER ERROR: {e}")
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
        # 1. Sync Weather for all districts (Farmer districts + Defaults)
        cursor.execute("SELECT DISTINCT District FROM FARMER")
        districts = [row[0] for row in cursor.fetchall()]
        
        # Pan-India Default Districts (Major Agricultural Hubs)
        defaults = [
            # Central
            "Vidisha", "Indore", "Bhopal", "Sagar", "Hoshangabad",
            # West
            "Nashik", "Nagpur", "Pune", "Rajkot", "Ahmedabad",
            # North
            "Ludhiana", "Karnal", "Amritsar", "Bathinda", "Bareilly",
            # South
            "Coimbatore", "Guntur", "Warangal", "Belgaum", "Mysore",
            # East
            "Patna", "Bardhaman", "Cuttack", "Guwahati"
        ]
        districts = list(set(districts + defaults))
        
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

@app.route('/api/farmers/analysis', methods=['GET'])
def get_farmer_analysis():
    conn = get_connection()
    cursor = conn.cursor()
    
    # Get all farmers and their land area
    cursor.execute("SELECT Farmer_ID, Name, District, Land_Area FROM FARMER")
    farmers = cursor.fetchall()
    
    # Get price distress records for mapping
    cursor.execute("""
        SELECT District, Crop_Name, Price_Status 
        FROM Price_Volatility_View 
        WHERE Price_Status IN ('DISTRESS', 'SEVERE DISTRESS')
    """)
    distress_prices = cursor.fetchall()
    
    # Get active claims
    cursor.execute("""
        SELECT f.Farmer_ID, cl.Claim_Status 
        FROM CLAIM cl
        JOIN INSURANCE_POLICY ip ON cl.Policy_ID = ip.Policy_ID
        JOIN FARMER f ON ip.Farmer_ID = f.Farmer_ID
        WHERE cl.Claim_Status IN ('Pending', 'Approved')
    """)
    claims = cursor.fetchall()
    
    # Map distress
    distress_map = {}
    for district, crop, status in distress_prices:
        if district not in distress_map:
            distress_map[district] = []
        distress_map[district].append(status)
        
    farmer_claims = {}
    for f_id, status in claims:
        if f_id not in farmer_claims:
            farmer_claims[f_id] = []
        farmer_claims[f_id].append(status)

    analysis = []
    for f_id, name, district, land in farmers:
        # Eligibility logic
        eligible_schemes = ["PMFBY", "Kisan Credit Card", "RKVY"]
        if land < 2.0:
            eligible_schemes.append("PM-KISAN")
            
        # Distress logic
        is_under_distress = False
        distress_reason = []
        
        if district in distress_map:
            is_under_distress = True
            distress_reason.append(f"Price Distress in {district}")
            
        if f_id in farmer_claims:
            is_under_distress = True
            distress_reason.append("Active Insurance Claim")
            
        # Policy check
        cursor.execute("SELECT COUNT(*) FROM INSURANCE_POLICY WHERE Farmer_ID = %s", (f_id,))
        has_policy = cursor.fetchone()[0] > 0
            
        analysis.append({
            "farmer_id": f_id,
            "name": name,
            "district": district,
            "land_area": land,
            "eligible_schemes": eligible_schemes,
            "is_under_distress": is_under_distress,
            "distress_reasons": distress_reason,
            "has_policy": has_policy
        })
        
    cursor.close()
    conn.close()
    return jsonify(analysis)

@app.route('/api/farmers', methods=['POST'])
def register_farmer():
    data = request.json
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # 1. Insert Farmer
        cursor.execute("""
            INSERT INTO FARMER (Name, District, Land_Area)
            VALUES (%s, %s, %s)
        """, (data['name'], data['district'], data['land_area']))
        farmer_id = cursor.lastrowid
        
        # 2. Link Crop if provided
        if data.get('crop_id'):
            cursor.execute("""
                INSERT INTO FARMER_CROP (Farmer_ID, Crop_ID)
                VALUES (%s, %s)
            """, (farmer_id, data['crop_id']))
            
        conn.commit()
        return jsonify({"message": "Farmer registered successfully with crops!"})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/schemes/all', methods=['GET'])
def get_all_schemes():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT Scheme_ID, Scheme_Name, Eligibility_Criteria FROM GOVERNMENT_SCHEME")
    data = rows_to_json(cursor)
    cursor.close()
    conn.close()
    return jsonify(data)

@app.route('/api/crops', methods=['GET'])
def get_crops():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT Crop_ID, Crop_Name, Season FROM CROP")
    data = rows_to_json(cursor)
    cursor.close()
    conn.close()
    return jsonify(data)

@app.route('/api/policies', methods=['POST'])
def apply_policy():
    data = request.json
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # Check if farmer exists
        cursor.execute("SELECT Farmer_ID FROM FARMER WHERE Farmer_ID = %s", (data['farmer_id'],))
        if not cursor.fetchone():
            return jsonify({"error": "Farmer not found"}), 404

        today = datetime.now().date()
        next_year = today.replace(year=today.year + 1)

        cursor.execute("""
            INSERT INTO INSURANCE_POLICY (Sum_Insured, Premium, Start_Date, End_Date, Farmer_ID)
            VALUES (%s, %s, %s, %s, %s)
        """, (data['sum_insured'], data['premium'], today, next_year, data['farmer_id']))
        conn.commit()
        return jsonify({"message": "Policy applied successfully!"})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/claims/manual', methods=['POST'])
def apply_claim_manual():
    data = request.json
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # We need a weather event to link the claim to.
        # Find the latest one for the district of the farmer who owns this policy
        cursor.execute("""
            SELECT we.Weather_ID FROM WEATHER_EVENT we
            JOIN INSURANCE_POLICY ip ON ip.Policy_ID = %s
            JOIN FARMER f ON ip.Farmer_ID = f.Farmer_ID
            WHERE we.District = f.District
            ORDER BY we.Date DESC LIMIT 1
        """, (data['policy_id'],))
        row = cursor.fetchone()
        if not row:
            return jsonify({"error": "No weather event found for this district to link claim."}), 400
        weather_id = row[0]

        cursor.execute("""
            INSERT INTO CLAIM (Claim_Status, Claim_Date, Policy_ID, Weather_ID)
            VALUES ('Pending', %s, %s, %s)
        """, (datetime.now().date(), data['policy_id'], weather_id))
        conn.commit()
        return jsonify({"message": "Claim filed successfully and is now PENDING!"})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/farmers/quick-claim', methods=['POST'])
def quick_claim():
    data = request.json
    conn = get_connection()
    cursor = conn.cursor()
    try:
        farmer_id = data['farmer_id']
        
        # 1. Check if farmer has an active policy
        cursor.execute("SELECT Policy_ID FROM INSURANCE_POLICY WHERE Farmer_ID = %s", (farmer_id,))
        row = cursor.fetchone()
        
        if not row:
            # Create a relief policy
            today = datetime.now().date()
            next_year = today.replace(year=today.year + 1)
            cursor.execute("""
                INSERT INTO INSURANCE_POLICY (Sum_Insured, Premium, Start_Date, End_Date, Farmer_ID)
                VALUES (50000.0, 1000.0, %s, %s, %s)
            """, (today, next_year, farmer_id))
            policy_id = cursor.lastrowid
        else:
            policy_id = row[0]
            
        # 2. Find latest weather event for this farmer's district
        cursor.execute("""
            SELECT we.Weather_ID FROM WEATHER_EVENT we
            JOIN FARMER f ON f.Farmer_ID = %s
            WHERE we.District = f.District
            ORDER BY we.Date DESC LIMIT 1
        """, (farmer_id,))
        w_row = cursor.fetchone()
        
        if not w_row:
            return jsonify({"error": "No weather records found for this farmer's district. Add weather data first."}), 400
        
        weather_id = w_row[0]
        
        # 3. Create Pending Claim
        cursor.execute("""
            INSERT INTO CLAIM (Claim_Status, Claim_Date, Policy_ID, Weather_ID)
            VALUES ('Pending', %s, %s, %s)
        """, (datetime.now().date(), policy_id, weather_id))
        
        conn.commit()
        return jsonify({"message": "Relief granted! Policy and Pending Claim created successfully."})
        
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/farmers/<int:farmer_id>', methods=['GET'])
def get_farmer_details(farmer_id):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM Farmer_Portfolio_View WHERE Farmer_ID = %s", (farmer_id,))
        row = rows_to_json(cursor)
        if not row:
            return jsonify({"error": "Farmer not found"}), 404
        
        # Also get their active policies
        cursor.execute("SELECT * FROM INSURANCE_POLICY WHERE Farmer_ID = %s", (farmer_id,))
        policies = rows_to_json(cursor)
        
        return jsonify({
            "portfolio": row[0],
            "policies": policies
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    app.run(debug=True, port=5000)