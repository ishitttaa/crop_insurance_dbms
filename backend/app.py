from flask import Flask, jsonify, request
from flask_cors import CORS
from db_config import get_connection

app = Flask(__name__)
CORS(app)  # Allow frontend to call backend

# ── FARMERS ──────────────────────────────────────────────────
@app.route('/api/farmers', methods=['GET'])
def get_farmers():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT f.FARMER_ID, f.NAME, f.DISTRICT, f.LAND_AREA,
               COUNT(DISTINCT ip.POLICY_ID) AS TOTAL_POLICIES,
               COUNT(DISTINCT cl.CLAIM_ID)  AS TOTAL_CLAIMS
        FROM FARMER f
        LEFT JOIN INSURANCE_POLICY ip ON f.FARMER_ID = ip.FARMER_ID
        LEFT JOIN CLAIM cl ON ip.POLICY_ID = cl.POLICY_ID
        GROUP BY f.FARMER_ID, f.NAME, f.DISTRICT, f.LAND_AREA
        ORDER BY f.FARMER_ID
    """)
    cols = [c[0] for c in cursor.description]
    rows = [dict(zip(cols, row)) for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return jsonify(rows)

# ── PRICES ───────────────────────────────────────────────────
@app.route('/api/prices', methods=['GET'])
def get_prices():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT CROP_NAME, DISTRICT, PRICE_DATE, MIN_PRICE,
               MAX_PRICE, MODAL_Price, MSP,
               PRICE_PCT_OF_MSP, PRICE_STATUS
        FROM PRICE_VOLATILITY_VIEW
        ORDER BY PRICE_DATE DESC
        FETCH FIRST 50 ROWS ONLY
    """)
    cols = [c[0] for c in cursor.description]
    rows = [dict(zip(cols, str(v) if hasattr(v, 'read') else v
                    for v in row)) for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return jsonify(rows)

@app.route('/api/prices/distress', methods=['GET'])
def get_distress():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT CROP_NAME, DISTRICT, PRICE_DATE,
               MODAL_PRICE, MSP, PRICE_STATUS, PRICE_PCT_OF_MSP
        FROM PRICE_VOLATILITY_VIEW
        WHERE PRICE_STATUS IN ('DISTRESS','SEVERE DISTRESS')
        ORDER BY PRICE_PCT_OF_MSP ASC
    """)
    cols = [c[0] for c in cursor.description]
    rows = [dict(zip(cols, row)) for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return jsonify(rows)

# ── CLAIMS ───────────────────────────────────────────────────
@app.route('/api/claims', methods=['GET'])
def get_claims():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT CLAIM_ID, FARMER_NAME, DISTRICT,
               CLAIM_STATUS, CLAIM_DATE,
               SUM_INSURED, RAINFALL, PAYOUT_AMOUNT
        FROM CLAIM_DETAIL_VIEW
        ORDER BY CLAIM_ID DESC
    """)
    cols = [c[0] for c in cursor.description]
    rows = [dict(zip(cols, row)) for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return jsonify(rows)

@app.route('/api/claims/approve/<int:claim_id>', methods=['PUT'])
def approve_claim(claim_id):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE CLAIM SET CLAIM_STATUS='Approved' WHERE CLAIM_ID=:1
    """, [claim_id])
    conn.commit()
    cursor.close()
    conn.close()
    return jsonify({"message": f"Claim {claim_id} approved"})

# ── WEATHER (triggers auto-claim) ────────────────────────────
@app.route('/api/weather', methods=['POST'])
def add_weather():
    data = request.json
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO WEATHER_EVENT
            (WEATHER_ID, EVENT_DATE, DISTRICT, RAINFALL, TEMPERATURE)
            VALUES (SEQ_WEATHER.NEXTVAL,
                    TO_DATE(:1,'YYYY-MM-DD'), :2, :3, :4)
        """, [data['date'], data['district'],
              data['rainfall'], data['temperature']])
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

# ── STATS FOR DASHBOARD ──────────────────────────────────────
@app.route('/api/stats', methods=['GET'])
def get_stats():
    conn = get_connection()
    cursor = conn.cursor()

    stats = {}

    cursor.execute("SELECT COUNT(*) FROM FARMER")
    stats['total_farmers'] = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM CLAIM")
    stats['total_claims'] = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM CLAIM WHERE CLAIM_STATUS='Pending'")
    stats['pending_claims'] = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM CLAIM WHERE CLAIM_STATUS='Approved'")
    stats['approved_claims'] = cursor.fetchone()[0]

    cursor.execute("SELECT NVL(SUM(AMOUNT),0) FROM PAYOUT")
    stats['total_payout'] = float(cursor.fetchone()[0])

    cursor.execute("""
        SELECT COUNT(*) FROM PRICE_VOLATILITY_VIEW
        WHERE PRICE_STATUS IN ('DISTRESS','SEVERE DISTRESS')
    """)
    stats['distress_records'] = cursor.fetchone()[0]

    cursor.close()
    conn.close()
    return jsonify(stats)

# ── SCHEMES ──────────────────────────────────────────────────
@app.route('/api/schemes', methods=['GET'])
def get_schemes():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT gs.SCHEME_NAME,
               COUNT(fs.FARMER_ID) AS FARMERS_ENROLLED
        FROM GOVERNMENT_SCHEME gs
        LEFT JOIN FARMER_SCHEME fs ON gs.SCHEME_ID = fs.SCHEME_ID
        GROUP BY gs.SCHEME_NAME
        ORDER BY COUNT(fs.FARMER_ID) DESC
    """)
    cols = [c[0] for c in cursor.description]
    rows = [dict(zip(cols, row)) for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return jsonify(rows)

if __name__ == '__main__':
    app.run(debug=True, port=5000)
