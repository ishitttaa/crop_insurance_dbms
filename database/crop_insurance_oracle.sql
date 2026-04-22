-- ============================================================
--  INTEGRATED CROP PRICE VOLATILITY & INSURANCE CLAIM ANALYSIS
--  DATABASE MANAGEMENT SYSTEM  |  UCS310  |  THAPAR INSTITUTE
--  Students : Ishita Rajput (1024031185) | Tripti (1024030183)
--  Platform : Oracle Database 21c XE  (SQL Developer)
-- ============================================================
--
--  HOW TO RUN IN SQL DEVELOPER:
--  1. Open SQL Developer → connect to your XE schema (e.g. user: SYSTEM)
--  2. Open this file: File → Open
--  3. Run section by section using F5 (Run Script) in each worksheet
--  4. DO NOT run the entire file at once — Oracle needs each block
--     (procedures, triggers) run separately as shown below.
--
--  NOTE: In Oracle you do NOT create a separate database.
--        Everything lives inside your USER/SCHEMA.
--        Just connect and run the DDL directly.
-- ============================================================


-- ============================================================
-- SECTION 0 : CLEANUP  (drop everything if re-running)
-- ============================================================
-- Run this block first to start fresh. Ignore "does not exist" errors.

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE CLAIM_AUDIT CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE POLICY_CROP CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE FARMER_SCHEME CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE FARMER_CROP CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE PAYOUT CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE CLAIM CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE INSURANCE_POLICY CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE MANDI_PRICE CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE WEATHER_EVENT CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE CROP CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE FARMER CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE GOVERNMENT_SCHEME CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Drop sequences
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_scheme';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_farmer';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_crop';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_weather';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_mandi';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_policy';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_claim';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_payout';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_audit';    EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Drop procedures, functions, triggers
BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE Get_Price_Trend_Report';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE Approve_Claims_By_District'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE Register_Farmer_With_Crop'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP FUNCTION Calculate_Volatility';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP FUNCTION Is_Claim_Eligible';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP FUNCTION Calculate_Payout';            EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_Auto_Claim_On_Low_Rainfall'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_No_Duplicate_Policy';      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_Claim_Status_Audit';       EXCEPTION WHEN OTHERS THEN NULL; END;
/


-- ============================================================
-- SECTION 1 : DDL  –  SEQUENCES (replace AUTO_INCREMENT)
-- ============================================================
-- Oracle does not have AUTO_INCREMENT.
-- We use SEQUENCES + triggers (or GENERATED AS IDENTITY in Oracle 12c+).
-- Using GENERATED AS IDENTITY here (cleaner, Oracle 12c+ supported in 21c XE).

CREATE SEQUENCE seq_scheme  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_farmer  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_crop    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_weather START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_mandi   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_policy  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_claim   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_payout  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_audit   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;


-- ============================================================
-- SECTION 2 : DDL  –  CREATE TABLES
-- ============================================================
-- Oracle differences applied:
--   INT          → NUMBER
--   FLOAT        → NUMBER(10,2)
--   VARCHAR(n)   → VARCHAR2(n)
--   TEXT         → VARCHAR2(500)
--   AUTO_INCREMENT removed (sequences used)
--   ON UPDATE CASCADE not supported in Oracle (removed)
--   DEFAULT CURRENT_TIMESTAMP → DEFAULT SYSTIMESTAMP

-- 1. GOVERNMENT_SCHEME
CREATE TABLE GOVERNMENT_SCHEME (
    Scheme_ID            NUMBER        PRIMARY KEY,
    Scheme_Name          VARCHAR2(100) NOT NULL,
    Eligibility_Criteria VARCHAR2(500) NOT NULL
);

-- 2. FARMER
CREATE TABLE FARMER (
    Farmer_ID  NUMBER        PRIMARY KEY,
    Name       VARCHAR2(100) NOT NULL,
    District   VARCHAR2(60)  NOT NULL,
    Land_Area  NUMBER(10,2)  NOT NULL,
    CONSTRAINT chk_land CHECK (Land_Area > 0)
);

-- 3. CROP
CREATE TABLE CROP (
    Crop_ID    NUMBER        PRIMARY KEY,
    Crop_Name  VARCHAR2(60)  NOT NULL,
    Season     VARCHAR2(30)  NOT NULL,
    MSP        NUMBER(10,2)  NOT NULL,
    CONSTRAINT chk_msp CHECK (MSP > 0)
);

-- 4. WEATHER_EVENT
CREATE TABLE WEATHER_EVENT (
    Weather_ID   NUMBER        PRIMARY KEY,
    Event_Date   DATE          NOT NULL,   -- "Date" is reserved in Oracle; renamed Event_Date
    District     VARCHAR2(60)  NOT NULL,
    Rainfall     NUMBER(10,2)  NOT NULL,
    Temperature  NUMBER(10,2)  NOT NULL,
    CONSTRAINT chk_rainfall CHECK (Rainfall >= 0)
);

-- 5. MANDI_PRICE  (FK → CROP)
CREATE TABLE MANDI_PRICE (
    Price_ID     NUMBER        PRIMARY KEY,
    Price_Date   DATE          NOT NULL,   -- "Date" reserved; renamed Price_Date
    District     VARCHAR2(60)  NOT NULL,
    Min_Price    NUMBER(10,2)  NOT NULL,
    Max_Price    NUMBER(10,2)  NOT NULL,
    Modal_Price  NUMBER(10,2)  NOT NULL,
    Crop_ID      NUMBER        NOT NULL,
    CONSTRAINT chk_minprice  CHECK (Min_Price >= 0),
    CONSTRAINT chk_maxprice  CHECK (Max_Price >= Min_Price),
    CONSTRAINT chk_modalprice CHECK (Modal_Price >= 0),
    CONSTRAINT fk_mandi_crop FOREIGN KEY (Crop_ID) REFERENCES CROP(Crop_ID)
);

-- 6. INSURANCE_POLICY  (FK → FARMER)
CREATE TABLE INSURANCE_POLICY (
    Policy_ID    NUMBER        PRIMARY KEY,
    Sum_Insured  NUMBER(10,2)  NOT NULL,
    Premium      NUMBER(10,2)  NOT NULL,
    Start_Date   DATE          NOT NULL,
    End_Date     DATE          NOT NULL,
    Farmer_ID    NUMBER        NOT NULL,
    CONSTRAINT chk_sum_insured CHECK (Sum_Insured > 0),
    CONSTRAINT chk_premium     CHECK (Premium > 0),
    CONSTRAINT chk_pol_dates   CHECK (End_Date > Start_Date),
    CONSTRAINT fk_policy_farmer FOREIGN KEY (Farmer_ID) REFERENCES FARMER(Farmer_ID)
);

-- 7. CLAIM  (FK → INSURANCE_POLICY, WEATHER_EVENT)
CREATE TABLE CLAIM (
    Claim_ID      NUMBER        PRIMARY KEY,
    Claim_Status  VARCHAR2(20)  DEFAULT 'Pending' NOT NULL,
    Claim_Date    DATE          NOT NULL,
    Policy_ID     NUMBER        NOT NULL,
    Weather_ID    NUMBER        NOT NULL,
    CONSTRAINT chk_status     CHECK (Claim_Status IN ('Pending','Approved','Rejected')),
    CONSTRAINT fk_claim_policy  FOREIGN KEY (Policy_ID)  REFERENCES INSURANCE_POLICY(Policy_ID),
    CONSTRAINT fk_claim_weather FOREIGN KEY (Weather_ID) REFERENCES WEATHER_EVENT(Weather_ID)
);

-- 8. PAYOUT  (FK → CLAIM, 1:1)
CREATE TABLE PAYOUT (
    Payout_ID     NUMBER        PRIMARY KEY,
    Amount        NUMBER(10,2)  NOT NULL,
    Payment_Date  DATE          NOT NULL,
    Claim_ID      NUMBER        NOT NULL UNIQUE,
    CONSTRAINT chk_amount CHECK (Amount > 0),
    CONSTRAINT fk_payout_claim FOREIGN KEY (Claim_ID) REFERENCES CLAIM(Claim_ID)
);

-- 9. FARMER_CROP  (M:N)
CREATE TABLE FARMER_CROP (
    Farmer_ID  NUMBER NOT NULL,
    Crop_ID    NUMBER NOT NULL,
    CONSTRAINT pk_farmer_crop PRIMARY KEY (Farmer_ID, Crop_ID),
    CONSTRAINT fk_fc_farmer FOREIGN KEY (Farmer_ID) REFERENCES FARMER(Farmer_ID) ON DELETE CASCADE,
    CONSTRAINT fk_fc_crop   FOREIGN KEY (Crop_ID)   REFERENCES CROP(Crop_ID)     ON DELETE CASCADE
);

-- 10. FARMER_SCHEME  (M:N)
CREATE TABLE FARMER_SCHEME (
    Farmer_ID  NUMBER NOT NULL,
    Scheme_ID  NUMBER NOT NULL,
    CONSTRAINT pk_farmer_scheme PRIMARY KEY (Farmer_ID, Scheme_ID),
    CONSTRAINT fk_fs_farmer FOREIGN KEY (Farmer_ID) REFERENCES FARMER(Farmer_ID)            ON DELETE CASCADE,
    CONSTRAINT fk_fs_scheme FOREIGN KEY (Scheme_ID) REFERENCES GOVERNMENT_SCHEME(Scheme_ID) ON DELETE CASCADE
);

-- 11. POLICY_CROP  (M:N)
CREATE TABLE POLICY_CROP (
    Policy_ID  NUMBER NOT NULL,
    Crop_ID    NUMBER NOT NULL,
    CONSTRAINT pk_policy_crop PRIMARY KEY (Policy_ID, Crop_ID),
    CONSTRAINT fk_pc_policy FOREIGN KEY (Policy_ID) REFERENCES INSURANCE_POLICY(Policy_ID) ON DELETE CASCADE,
    CONSTRAINT fk_pc_crop   FOREIGN KEY (Crop_ID)   REFERENCES CROP(Crop_ID)               ON DELETE CASCADE
);

-- 12. CLAIM_AUDIT (for trigger 3)
CREATE TABLE CLAIM_AUDIT (
    Audit_ID    NUMBER PRIMARY KEY,
    Claim_ID    NUMBER,
    Old_Status  VARCHAR2(20),
    New_Status  VARCHAR2(20),
    Changed_At  TIMESTAMP DEFAULT SYSTIMESTAMP
);


-- ============================================================
-- SECTION 3 : DML  –  INSERT SAMPLE DATA
-- ============================================================
-- Oracle uses seq_name.NEXTVAL for primary keys.
-- Multi-row INSERT ... VALUES not supported; use separate INSERTs.
-- Dates use TO_DATE('YYYY-MM-DD','YYYY-MM-DD').

-- Government Schemes
INSERT INTO GOVERNMENT_SCHEME VALUES (seq_scheme.NEXTVAL, 'PMFBY',             'All farmers with land holding and crop insurance requirement');
INSERT INTO GOVERNMENT_SCHEME VALUES (seq_scheme.NEXTVAL, 'PM-KISAN',          'Small and marginal farmers with land records');
INSERT INTO GOVERNMENT_SCHEME VALUES (seq_scheme.NEXTVAL, 'Kisan Credit Card', 'Farmers needing short-term credit for crop cultivation');
INSERT INTO GOVERNMENT_SCHEME VALUES (seq_scheme.NEXTVAL, 'RKVY',              'Farmers involved in agriculture and allied activities');

-- Farmers
INSERT INTO FARMER VALUES (seq_farmer.NEXTVAL, 'Ramesh Kumar', 'Vidisha',     3.5);
INSERT INTO FARMER VALUES (seq_farmer.NEXTVAL, 'Suresh Patel', 'Hoshangabad', 2.0);
INSERT INTO FARMER VALUES (seq_farmer.NEXTVAL, 'Meena Devi',   'Nashik',      4.0);
INSERT INTO FARMER VALUES (seq_farmer.NEXTVAL, 'Ajay Singh',   'Vidisha',     1.5);
INSERT INTO FARMER VALUES (seq_farmer.NEXTVAL, 'Priya Sharma', 'Hoshangabad', 5.0);
INSERT INTO FARMER VALUES (seq_farmer.NEXTVAL, 'Vijay Yadav',  'Nashik',      2.8);
INSERT INTO FARMER VALUES (seq_farmer.NEXTVAL, 'Anita Kumari', 'Bhopal',      3.2);
INSERT INTO FARMER VALUES (seq_farmer.NEXTVAL, 'Mohan Lal',    'Indore',      6.0);

-- Crops
INSERT INTO CROP VALUES (seq_crop.NEXTVAL, 'Wheat',   'Rabi',   2015.00);
INSERT INTO CROP VALUES (seq_crop.NEXTVAL, 'Rice',    'Kharif', 2183.00);
INSERT INTO CROP VALUES (seq_crop.NEXTVAL, 'Onion',   'Rabi',    800.00);
INSERT INTO CROP VALUES (seq_crop.NEXTVAL, 'Soybean', 'Kharif', 3950.00);
INSERT INTO CROP VALUES (seq_crop.NEXTVAL, 'Cotton',  'Kharif', 6620.00);
INSERT INTO CROP VALUES (seq_crop.NEXTVAL, 'Maize',   'Kharif', 1870.00);

-- Weather Events  (note: column is Event_Date)
INSERT INTO WEATHER_EVENT VALUES (seq_weather.NEXTVAL, TO_DATE('2024-07-15','YYYY-MM-DD'), 'Vidisha',     35.0, 32.5);
INSERT INTO WEATHER_EVENT VALUES (seq_weather.NEXTVAL, TO_DATE('2024-07-20','YYYY-MM-DD'), 'Hoshangabad', 80.0, 30.0);
INSERT INTO WEATHER_EVENT VALUES (seq_weather.NEXTVAL, TO_DATE('2024-08-05','YYYY-MM-DD'), 'Nashik',      20.0, 28.0);
INSERT INTO WEATHER_EVENT VALUES (seq_weather.NEXTVAL, TO_DATE('2024-08-10','YYYY-MM-DD'), 'Vidisha',     10.0, 34.0);
INSERT INTO WEATHER_EVENT VALUES (seq_weather.NEXTVAL, TO_DATE('2024-09-01','YYYY-MM-DD'), 'Bhopal',      60.0, 27.5);
INSERT INTO WEATHER_EVENT VALUES (seq_weather.NEXTVAL, TO_DATE('2024-09-15','YYYY-MM-DD'), 'Indore',      45.0, 29.0);
INSERT INTO WEATHER_EVENT VALUES (seq_weather.NEXTVAL, TO_DATE('2024-10-01','YYYY-MM-DD'), 'Nashik',      15.0, 25.0);

-- Mandi Prices (Onion crash, Wheat, Soybean, Cotton, Rice)
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-09-01','YYYY-MM-DD'), 'Nashik',        100,  300,  180, 3);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-09-08','YYYY-MM-DD'), 'Nashik',         80,  200,  120, 3);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-09-15','YYYY-MM-DD'), 'Nashik',         50,  150,   90, 3);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-09-22','YYYY-MM-DD'), 'Nashik',         60,  180,  110, 3);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-03-10','YYYY-MM-DD'), 'Vidisha',      1800, 2200, 2050, 1);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-03-17','YYYY-MM-DD'), 'Vidisha',      1950, 2300, 2100, 1);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-03-24','YYYY-MM-DD'), 'Hoshangabad',  1500, 1900, 1600, 1);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-10-05','YYYY-MM-DD'), 'Indore',       3200, 4000, 3600, 4);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-10-12','YYYY-MM-DD'), 'Indore',       3000, 3800, 3100, 4);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-11-01','YYYY-MM-DD'), 'Vidisha',      5500, 6800, 6200, 5);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-11-08','YYYY-MM-DD'), 'Vidisha',      5200, 6500, 5800, 5);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-08-20','YYYY-MM-DD'), 'Hoshangabad',  2000, 2400, 2200, 2);
INSERT INTO MANDI_PRICE VALUES (seq_mandi.NEXTVAL, TO_DATE('2024-08-27','YYYY-MM-DD'), 'Hoshangabad',  1700, 2100, 1800, 2);

-- Insurance Policies
INSERT INTO INSURANCE_POLICY VALUES (seq_policy.NEXTVAL, 50000, 1000, TO_DATE('2024-06-01','YYYY-MM-DD'), TO_DATE('2024-12-31','YYYY-MM-DD'), 1);
INSERT INTO INSURANCE_POLICY VALUES (seq_policy.NEXTVAL, 40000,  800, TO_DATE('2024-06-01','YYYY-MM-DD'), TO_DATE('2024-12-31','YYYY-MM-DD'), 2);
INSERT INTO INSURANCE_POLICY VALUES (seq_policy.NEXTVAL, 60000, 1200, TO_DATE('2024-06-01','YYYY-MM-DD'), TO_DATE('2024-12-31','YYYY-MM-DD'), 3);
INSERT INTO INSURANCE_POLICY VALUES (seq_policy.NEXTVAL, 35000,  700, TO_DATE('2024-06-01','YYYY-MM-DD'), TO_DATE('2024-12-31','YYYY-MM-DD'), 4);
INSERT INTO INSURANCE_POLICY VALUES (seq_policy.NEXTVAL, 75000, 1500, TO_DATE('2024-06-01','YYYY-MM-DD'), TO_DATE('2024-12-31','YYYY-MM-DD'), 5);
INSERT INTO INSURANCE_POLICY VALUES (seq_policy.NEXTVAL, 45000,  900, TO_DATE('2024-07-01','YYYY-MM-DD'), TO_DATE('2025-01-31','YYYY-MM-DD'), 6);
INSERT INTO INSURANCE_POLICY VALUES (seq_policy.NEXTVAL, 55000, 1100, TO_DATE('2024-07-01','YYYY-MM-DD'), TO_DATE('2025-01-31','YYYY-MM-DD'), 7);
INSERT INTO INSURANCE_POLICY VALUES (seq_policy.NEXTVAL, 80000, 1600, TO_DATE('2024-07-01','YYYY-MM-DD'), TO_DATE('2025-01-31','YYYY-MM-DD'), 8);

-- Farmer-Crop links
INSERT INTO FARMER_CROP VALUES (1,1); INSERT INTO FARMER_CROP VALUES (1,3);
INSERT INTO FARMER_CROP VALUES (2,1); INSERT INTO FARMER_CROP VALUES (2,2);
INSERT INTO FARMER_CROP VALUES (3,3); INSERT INTO FARMER_CROP VALUES (3,5);
INSERT INTO FARMER_CROP VALUES (4,1); INSERT INTO FARMER_CROP VALUES (5,2);
INSERT INTO FARMER_CROP VALUES (5,4); INSERT INTO FARMER_CROP VALUES (6,3);
INSERT INTO FARMER_CROP VALUES (7,6); INSERT INTO FARMER_CROP VALUES (8,4);
INSERT INTO FARMER_CROP VALUES (8,5);

-- Policy-Crop links
INSERT INTO POLICY_CROP VALUES (1,1); INSERT INTO POLICY_CROP VALUES (1,3);
INSERT INTO POLICY_CROP VALUES (2,1); INSERT INTO POLICY_CROP VALUES (2,2);
INSERT INTO POLICY_CROP VALUES (3,3); INSERT INTO POLICY_CROP VALUES (3,5);
INSERT INTO POLICY_CROP VALUES (4,1); INSERT INTO POLICY_CROP VALUES (5,2);
INSERT INTO POLICY_CROP VALUES (5,4); INSERT INTO POLICY_CROP VALUES (6,3);
INSERT INTO POLICY_CROP VALUES (7,6); INSERT INTO POLICY_CROP VALUES (8,4);
INSERT INTO POLICY_CROP VALUES (8,5);

-- Farmer-Scheme links
INSERT INTO FARMER_SCHEME VALUES (1,1); INSERT INTO FARMER_SCHEME VALUES (1,2);
INSERT INTO FARMER_SCHEME VALUES (2,1); INSERT INTO FARMER_SCHEME VALUES (3,1);
INSERT INTO FARMER_SCHEME VALUES (3,3); INSERT INTO FARMER_SCHEME VALUES (4,2);
INSERT INTO FARMER_SCHEME VALUES (5,1); INSERT INTO FARMER_SCHEME VALUES (5,2);
INSERT INTO FARMER_SCHEME VALUES (6,1); INSERT INTO FARMER_SCHEME VALUES (7,4);
INSERT INTO FARMER_SCHEME VALUES (8,3); INSERT INTO FARMER_SCHEME VALUES (8,4);

-- Manual Claims
INSERT INTO CLAIM VALUES (seq_claim.NEXTVAL, 'Approved', TO_DATE('2024-07-16','YYYY-MM-DD'), 1, 1);
INSERT INTO CLAIM VALUES (seq_claim.NEXTVAL, 'Approved', TO_DATE('2024-08-06','YYYY-MM-DD'), 3, 3);
INSERT INTO CLAIM VALUES (seq_claim.NEXTVAL, 'Pending',  TO_DATE('2024-09-16','YYYY-MM-DD'), 6, 7);

-- Payouts
INSERT INTO PAYOUT VALUES (seq_payout.NEXTVAL, 25000, TO_DATE('2024-08-01','YYYY-MM-DD'), 1);
INSERT INTO PAYOUT VALUES (seq_payout.NEXTVAL, 30000, TO_DATE('2024-09-01','YYYY-MM-DD'), 2);

COMMIT;


-- ============================================================
-- SECTION 4 : VIEWS
-- ============================================================
-- Oracle uses CREATE OR REPLACE VIEW (same as MySQL here).
-- GROUP_CONCAT → LISTAGG in Oracle.
-- Column renamed: Date → Event_Date / Price_Date.

-- View 1: Price Volatility Analysis
CREATE OR REPLACE VIEW Price_Volatility_View AS
SELECT
    m.Price_ID,
    m.Crop_ID,
    c.Crop_Name,
    c.MSP,
    m.District,
    m.Price_Date                                                          AS Price_Date,
    m.Min_Price,
    m.Max_Price,
    m.Modal_Price,
    ROUND((m.Modal_Price / c.MSP) * 100, 2)                              AS Price_Pct_of_MSP,
    ROUND(((m.Max_Price - m.Min_Price) / m.Min_Price) * 100, 2)         AS Daily_Volatility_Pct,
    CASE
        WHEN m.Modal_Price < 0.6 * c.MSP THEN 'SEVERE DISTRESS'
        WHEN m.Modal_Price < 0.8 * c.MSP THEN 'DISTRESS'
        ELSE 'NORMAL'
    END AS Price_Status
FROM MANDI_PRICE m
JOIN CROP c ON m.Crop_ID = c.Crop_ID;
/

-- View 2: Full Claim Details
CREATE OR REPLACE VIEW Claim_Detail_View AS
SELECT
    cl.Claim_ID,
    f.Farmer_ID,
    f.Name          AS Farmer_Name,
    f.District,
    ip.Policy_ID,
    ip.Sum_Insured,
    ip.Premium,
    cl.Claim_Status,
    cl.Claim_Date,
    we.Rainfall,
    we.Temperature,
    we.Event_Date   AS Weather_Date,
    p.Amount        AS Payout_Amount,
    p.Payment_Date
FROM CLAIM cl
JOIN INSURANCE_POLICY ip ON cl.Policy_ID  = ip.Policy_ID
JOIN FARMER f             ON ip.Farmer_ID  = f.Farmer_ID
JOIN WEATHER_EVENT we     ON cl.Weather_ID = we.Weather_ID
LEFT JOIN PAYOUT p        ON cl.Claim_ID   = p.Claim_ID;
/

-- View 3: Farmer Portfolio Summary
-- LISTAGG replaces GROUP_CONCAT
CREATE OR REPLACE VIEW Farmer_Portfolio_View AS
SELECT
    f.Farmer_ID,
    f.Name,
    f.District,
    f.Land_Area,
    LISTAGG(DISTINCT c.Crop_Name,  ', ') WITHIN GROUP (ORDER BY c.Crop_Name)  AS Crops_Grown,
    LISTAGG(DISTINCT gs.Scheme_Name,', ') WITHIN GROUP (ORDER BY gs.Scheme_Name) AS Schemes_Enrolled,
    COUNT(DISTINCT ip.Policy_ID)  AS Total_Policies,
    COUNT(DISTINCT cl.Claim_ID)   AS Total_Claims
FROM FARMER f
LEFT JOIN FARMER_CROP fc         ON f.Farmer_ID  = fc.Farmer_ID
LEFT JOIN CROP c                  ON fc.Crop_ID   = c.Crop_ID
LEFT JOIN FARMER_SCHEME fsc       ON f.Farmer_ID  = fsc.Farmer_ID
LEFT JOIN GOVERNMENT_SCHEME gs    ON fsc.Scheme_ID = gs.Scheme_ID
LEFT JOIN INSURANCE_POLICY ip     ON f.Farmer_ID  = ip.Farmer_ID
LEFT JOIN CLAIM cl                ON ip.Policy_ID = cl.Policy_ID
GROUP BY f.Farmer_ID, f.Name, f.District, f.Land_Area;
/


-- ============================================================
-- SECTION 5 : STORED PROCEDURES
-- ============================================================
-- Oracle uses CREATE OR REPLACE PROCEDURE ... IS ... BEGIN ... END;
-- No DELIMITER needed in Oracle.
-- Each block ends with / on its own line.

-- Procedure 1: Price trend report for a crop
-- Oracle procedures use a REF CURSOR to return result sets.
CREATE OR REPLACE PROCEDURE Get_Price_Trend_Report (
    p_crop_id  IN  NUMBER,
    p_cursor   OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT Price_Date, District, Min_Price, Max_Price,
               Modal_Price, Price_Status, Price_Pct_of_MSP
        FROM Price_Volatility_View
        WHERE Crop_ID = p_crop_id
        ORDER BY Price_Date DESC;
END Get_Price_Trend_Report;
/

-- Procedure 2: Bulk approve pending claims for a district
CREATE OR REPLACE PROCEDURE Approve_Claims_By_District (
    p_district IN VARCHAR2
)
IS
    v_count NUMBER;
BEGIN
    UPDATE CLAIM cl
    SET cl.Claim_Status = 'Approved'
    WHERE cl.Claim_Status = 'Pending'
      AND cl.Policy_ID IN (
          SELECT ip.Policy_ID
          FROM INSURANCE_POLICY ip
          JOIN FARMER f ON ip.Farmer_ID = f.Farmer_ID
          WHERE f.District = p_district
      );

    v_count := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Claims approved: ' || v_count);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END Approve_Claims_By_District;
/

-- Procedure 3: Register new farmer with a crop (transaction demo)
CREATE OR REPLACE PROCEDURE Register_Farmer_With_Crop (
    p_name      IN VARCHAR2,
    p_district  IN VARCHAR2,
    p_land      IN NUMBER,
    p_crop_id   IN NUMBER
)
IS
    v_farmer_id NUMBER;
BEGIN
    v_farmer_id := seq_farmer.NEXTVAL;

    INSERT INTO FARMER (Farmer_ID, Name, District, Land_Area)
    VALUES (v_farmer_id, p_name, p_district, p_land);

    INSERT INTO FARMER_CROP (Farmer_ID, Crop_ID)
    VALUES (v_farmer_id, p_crop_id);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Farmer registered. ID = ' || v_farmer_id);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Registration failed: ' || SQLERRM);
        RAISE;
END Register_Farmer_With_Crop;
/


-- ============================================================
-- SECTION 6 : FUNCTIONS
-- ============================================================
-- Oracle: RETURN keyword (not RETURNS), IS instead of BEGIN directly,
-- ELSIF instead of ELSEIF, no SET keyword for assignments.

-- Function 1: Calculate price volatility %
CREATE OR REPLACE FUNCTION Calculate_Volatility (
    p_crop_id  IN NUMBER,
    p_district IN VARCHAR2
)
RETURN NUMBER
IS
    v_max  NUMBER;
    v_min  NUMBER;
BEGIN
    SELECT MAX(Modal_Price), MIN(Modal_Price)
    INTO   v_max, v_min
    FROM   MANDI_PRICE
    WHERE  Crop_ID = p_crop_id AND District = p_district;

    IF v_min IS NULL OR v_min = 0 THEN
        RETURN 0;
    END IF;

    RETURN ROUND(((v_max - v_min) / v_min) * 100, 2);
END Calculate_Volatility;
/

-- Function 2: Check weather-based eligibility
CREATE OR REPLACE FUNCTION Is_Claim_Eligible (
    p_weather_id IN NUMBER
)
RETURN VARCHAR2
IS
    v_rainfall NUMBER;
BEGIN
    SELECT Rainfall INTO v_rainfall
    FROM WEATHER_EVENT
    WHERE Weather_ID = p_weather_id;

    IF v_rainfall < 50 THEN
        RETURN 'YES';
    ELSE
        RETURN 'NO';
    END IF;
END Is_Claim_Eligible;
/

-- Function 3: Calculate payout amount
CREATE OR REPLACE FUNCTION Calculate_Payout (
    p_policy_id IN NUMBER,
    p_rainfall  IN NUMBER
)
RETURN NUMBER
IS
    v_sum_insured NUMBER;
    v_payout      NUMBER;
BEGIN
    SELECT Sum_Insured INTO v_sum_insured
    FROM INSURANCE_POLICY
    WHERE Policy_ID = p_policy_id;

    IF p_rainfall < 10 THEN
        v_payout := v_sum_insured * 0.80;
    ELSIF p_rainfall < 25 THEN
        v_payout := v_sum_insured * 0.60;
    ELSE
        v_payout := v_sum_insured * 0.40;
    END IF;

    RETURN ROUND(v_payout, 2);
END Calculate_Payout;
/


-- ============================================================
-- SECTION 7 : TRIGGERS
-- ============================================================
-- Oracle trigger syntax: no BEGIN...END wrapper for the INSERT loop —
-- use PRAGMA AUTONOMOUS_TRANSACTION for DML inside AFTER triggers.
-- :NEW replaces NEW., :OLD replaces OLD.

-- Trigger 1: Auto-generate claim on low rainfall
CREATE OR REPLACE TRIGGER trg_Auto_Claim_On_Low_Rainfall
AFTER INSERT ON WEATHER_EVENT
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    IF :NEW.Rainfall < 50 THEN
        INSERT INTO CLAIM (Claim_ID, Claim_Status, Claim_Date, Policy_ID, Weather_ID)
        SELECT
            seq_claim.NEXTVAL,
            'Pending',
            SYSDATE,
            ip.Policy_ID,
            :NEW.Weather_ID
        FROM INSURANCE_POLICY ip
        JOIN FARMER f ON ip.Farmer_ID = f.Farmer_ID
        WHERE f.District   = :NEW.District
          AND ip.End_Date  >= SYSDATE
          AND NOT EXISTS (
              SELECT 1 FROM CLAIM c2
              WHERE c2.Policy_ID  = ip.Policy_ID
                AND c2.Weather_ID = :NEW.Weather_ID
          );
        COMMIT;
    END IF;
END;
/

-- Trigger 2: Prevent duplicate policies
CREATE OR REPLACE TRIGGER trg_No_Duplicate_Policy
BEFORE INSERT ON INSURANCE_POLICY
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM INSURANCE_POLICY
    WHERE Farmer_ID  = :NEW.Farmer_ID
      AND Start_Date = :NEW.Start_Date
      AND End_Date   = :NEW.End_Date;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Duplicate policy: farmer already has a policy for this period.');
    END IF;
END;
/

-- Trigger 3: Audit claim status changes
CREATE OR REPLACE TRIGGER trg_Claim_Status_Audit
AFTER UPDATE ON CLAIM
FOR EACH ROW
BEGIN
    IF :OLD.Claim_Status <> :NEW.Claim_Status THEN
        INSERT INTO CLAIM_AUDIT (Audit_ID, Claim_ID, Old_Status, New_Status)
        VALUES (seq_audit.NEXTVAL, :NEW.Claim_ID, :OLD.Claim_Status, :NEW.Claim_Status);
    END IF;
END;
/


-- ============================================================
-- SECTION 8 : ADVANCED SELECT QUERIES (ANALYTICAL)
-- ============================================================
-- Oracle: column aliases with spaces must use double quotes.
-- HAVING clause uses full expression (not alias) in Oracle.
-- FROM DUAL used for single-value SELECT with no table.

-- Q1: All price-distress records
SELECT Crop_Name, District, Price_Date, Modal_Price, MSP, Price_Status
FROM Price_Volatility_View
WHERE Price_Status IN ('DISTRESS', 'SEVERE DISTRESS')
ORDER BY Price_Pct_of_MSP ASC;

-- Q2: District-wise distress event count
SELECT
    District,
    Crop_Name,
    COUNT(*)                    AS Distress_Days,
    ROUND(AVG(Modal_Price), 2)  AS Avg_Modal_Price,
    MIN(Modal_Price)             AS Lowest_Price
FROM Price_Volatility_View
WHERE Price_Status <> 'NORMAL'
GROUP BY District, Crop_Name
ORDER BY COUNT(*) DESC;

-- Q3: Total claims and payout per farmer
SELECT
    f.Farmer_ID,
    f.Name,
    f.District,
    COUNT(DISTINCT cl.Claim_ID)                                              AS Total_Claims,
    SUM(CASE WHEN cl.Claim_Status = 'Approved' THEN 1 ELSE 0 END)           AS Approved_Claims,
    NVL(SUM(p.Amount), 0)                                                    AS Total_Payout_Received
FROM FARMER f
LEFT JOIN INSURANCE_POLICY ip ON f.Farmer_ID = ip.Farmer_ID
LEFT JOIN CLAIM cl             ON ip.Policy_ID = cl.Policy_ID
LEFT JOIN PAYOUT p             ON cl.Claim_ID  = p.Claim_ID
GROUP BY f.Farmer_ID, f.Name, f.District
ORDER BY NVL(SUM(p.Amount), 0) DESC;

-- Q4: Crops with highest price volatility
SELECT
    c.Crop_ID,
    c.Crop_Name,
    mp.District,
    Calculate_Volatility(c.Crop_ID, mp.District) AS Volatility_Pct
FROM CROP c
JOIN MANDI_PRICE mp ON c.Crop_ID = mp.Crop_ID
GROUP BY c.Crop_ID, c.Crop_Name, mp.District
ORDER BY Calculate_Volatility(c.Crop_ID, mp.District) DESC;

-- Q5: Farmers eligible for claims
SELECT DISTINCT
    f.Name,
    f.District,
    we.Event_Date     AS Weather_Date,
    we.Rainfall,
    Is_Claim_Eligible(we.Weather_ID) AS Eligible
FROM FARMER f
JOIN WEATHER_EVENT we ON f.District = we.District
WHERE Is_Claim_Eligible(we.Weather_ID) = 'YES';

-- Q6: INNER JOIN – Policies with claim status
SELECT
    ip.Policy_ID,
    f.Name         AS Farmer_Name,
    ip.Sum_Insured,
    cl.Claim_Status,
    cl.Claim_Date
FROM INSURANCE_POLICY ip
INNER JOIN FARMER f ON ip.Farmer_ID = f.Farmer_ID
INNER JOIN CLAIM cl ON ip.Policy_ID = cl.Policy_ID
ORDER BY cl.Claim_Date DESC;

-- Q7: LEFT JOIN – All farmers even without claims
SELECT
    f.Name,
    f.District,
    NVL(cl.Claim_Status, 'No Claim') AS Claim_Status,   -- NVL replaces COALESCE
    NVL(p.Amount, 0)                  AS Payout
FROM FARMER f
LEFT JOIN INSURANCE_POLICY ip ON f.Farmer_ID = ip.Farmer_ID
LEFT JOIN CLAIM cl             ON ip.Policy_ID = cl.Policy_ID
LEFT JOIN PAYOUT p             ON cl.Claim_ID  = p.Claim_ID;

-- Q8: Subquery – Farmers whose crop price fell below MSP
SELECT DISTINCT f.Name, f.District
FROM FARMER f
JOIN FARMER_CROP fc ON f.Farmer_ID = fc.Farmer_ID
WHERE fc.Crop_ID IN (
    SELECT DISTINCT mp.Crop_ID
    FROM MANDI_PRICE mp
    JOIN CROP c ON mp.Crop_ID = c.Crop_ID
    WHERE mp.Modal_Price < c.MSP
);

-- Q9: Aggregate – Avg rainfall per district and claims caused
-- HAVING uses full expression in Oracle (not alias)
SELECT
    we.District,
    ROUND(AVG(we.Rainfall), 2)    AS Avg_Rainfall_mm,
    COUNT(DISTINCT cl.Claim_ID)   AS Claims_Generated
FROM WEATHER_EVENT we
LEFT JOIN CLAIM cl ON we.Weather_ID = cl.Weather_ID
GROUP BY we.District
HAVING ROUND(AVG(we.Rainfall), 2) < 60
ORDER BY AVG(we.Rainfall) ASC;

-- Q10: HAVING – Districts with more than 1 claim
SELECT
    f.District,
    COUNT(cl.Claim_ID) AS Claim_Count
FROM CLAIM cl
JOIN INSURANCE_POLICY ip ON cl.Policy_ID = ip.Policy_ID
JOIN FARMER f             ON ip.Farmer_ID = f.Farmer_ID
GROUP BY f.District
HAVING COUNT(cl.Claim_ID) > 1;

-- Q11: Correlated subquery – Above-average sum insured
SELECT Policy_ID, Farmer_ID, Sum_Insured
FROM INSURANCE_POLICY ip
WHERE Sum_Insured > (
    SELECT AVG(Sum_Insured) FROM INSURANCE_POLICY
);

-- Q12: Scheme enrollment count
SELECT
    gs.Scheme_Name,
    COUNT(fsc.Farmer_ID) AS Farmers_Enrolled
FROM GOVERNMENT_SCHEME gs
LEFT JOIN FARMER_SCHEME fsc ON gs.Scheme_ID = fsc.Scheme_ID
GROUP BY gs.Scheme_Name
ORDER BY COUNT(fsc.Farmer_ID) DESC;


-- ============================================================
-- SECTION 9 : DML  –  UPDATE AND DELETE
-- ============================================================

-- Update: Approve a specific claim
UPDATE CLAIM
SET Claim_Status = 'Approved'
WHERE Claim_ID = 3;
COMMIT;

-- Update: Increase premium by 10% for farmer 1
UPDATE INSURANCE_POLICY
SET Premium = Premium * 1.10
WHERE Farmer_ID = 1;
COMMIT;

-- Delete: Remove expired policies with no claims
DELETE FROM INSURANCE_POLICY
WHERE End_Date < SYSDATE
  AND Policy_ID NOT IN (SELECT DISTINCT Policy_ID FROM CLAIM);
COMMIT;


-- ============================================================
-- SECTION 10 : TRANSACTION MANAGEMENT DEMO
-- ============================================================
-- Oracle: no START TRANSACTION keyword — transactions begin automatically.
-- Use COMMIT / ROLLBACK / SAVEPOINT directly.

DECLARE
    v_new_policy_id NUMBER;
BEGIN
    v_new_policy_id := seq_policy.NEXTVAL;

    INSERT INTO INSURANCE_POLICY (Policy_ID, Sum_Insured, Premium, Start_Date, End_Date, Farmer_ID)
    VALUES (v_new_policy_id, 70000, 1400,
            TO_DATE('2025-01-01','YYYY-MM-DD'),
            TO_DATE('2025-12-31','YYYY-MM-DD'), 2);

    INSERT INTO POLICY_CROP (Policy_ID, Crop_ID)
    VALUES (v_new_policy_id, 1);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('New policy created: ' || v_new_policy_id);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Failed: ' || SQLERRM);
END;
/

-- Savepoint demo
BEGIN
    SAVEPOINT before_payout;

    INSERT INTO PAYOUT (Payout_ID, Amount, Payment_Date, Claim_ID)
    VALUES (seq_payout.NEXTVAL, 18000, SYSDATE, 3);

    -- Uncomment next line to test rollback to savepoint:
    -- ROLLBACK TO SAVEPOINT before_payout;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Payout inserted successfully.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Payout failed: ' || SQLERRM);
END;
/


-- ============================================================
-- SECTION 11 : CALL PROCEDURES AND USE FUNCTIONS
-- ============================================================

-- Enable output (run this first in SQL Developer)
SET SERVEROUTPUT ON;

-- Call Procedure 1: Price trend for Onion (Crop_ID=3)
-- In SQL Developer, use a PL/SQL block to open the ref cursor
DECLARE
    v_cur SYS_REFCURSOR;
    v_date        DATE;
    v_district    VARCHAR2(60);
    v_min         NUMBER;
    v_max         NUMBER;
    v_modal       NUMBER;
    v_status      VARCHAR2(20);
    v_pct         NUMBER;
BEGIN
    Get_Price_Trend_Report(3, v_cur);
    LOOP
        FETCH v_cur INTO v_date, v_district, v_min, v_max, v_modal, v_status, v_pct;
        EXIT WHEN v_cur%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_district || ' | ' || v_modal || ' | ' || v_status);
    END LOOP;
    CLOSE v_cur;
END;
/

-- Call Procedure 2: Approve all Vidisha claims
BEGIN
    Approve_Claims_By_District('Vidisha');
END;
/

-- Call Procedure 3: Register a new farmer
BEGIN
    Register_Farmer_With_Crop('Lakshmi Bai', 'Sagar', 2.5, 1);
END;
/

-- Use functions in SELECT (Oracle requires FROM DUAL for standalone selects)
SELECT Calculate_Volatility(3, 'Nashik') AS Onion_Nashik_Volatility FROM DUAL;
SELECT Is_Claim_Eligible(1) AS Weather1_Eligible                     FROM DUAL;
SELECT Is_Claim_Eligible(2) AS Weather2_Eligible                     FROM DUAL;
SELECT Calculate_Payout(1, 10) AS Estimated_Payout_Policy1           FROM DUAL;


-- ============================================================
-- SECTION 12 : VERIFY ALL VIEWS AND AUDIT
-- ============================================================

SELECT * FROM Price_Volatility_View  ORDER BY Price_Date DESC;
SELECT * FROM Claim_Detail_View      ORDER BY Claim_ID;
SELECT * FROM Farmer_Portfolio_View  ORDER BY Farmer_ID;
SELECT * FROM CLAIM_AUDIT            ORDER BY Audit_ID;

-- Quick table counts
SELECT 'FARMER'            AS Table_Name, COUNT(*) AS Row_Count FROM FARMER            UNION ALL
SELECT 'CROP',                            COUNT(*)               FROM CROP              UNION ALL
SELECT 'WEATHER_EVENT',                   COUNT(*)               FROM WEATHER_EVENT     UNION ALL
SELECT 'MANDI_PRICE',                     COUNT(*)               FROM MANDI_PRICE       UNION ALL
SELECT 'INSURANCE_POLICY',                COUNT(*)               FROM INSURANCE_POLICY  UNION ALL
SELECT 'CLAIM',                           COUNT(*)               FROM CLAIM             UNION ALL
SELECT 'PAYOUT',                          COUNT(*)               FROM PAYOUT            UNION ALL
SELECT 'GOVERNMENT_SCHEME',               COUNT(*)               FROM GOVERNMENT_SCHEME UNION ALL
SELECT 'FARMER_CROP',                     COUNT(*)               FROM FARMER_CROP       UNION ALL
SELECT 'FARMER_SCHEME',                   COUNT(*)               FROM FARMER_SCHEME     UNION ALL
SELECT 'POLICY_CROP',                     COUNT(*)               FROM POLICY_CROP       UNION ALL
SELECT 'CLAIM_AUDIT',                     COUNT(*)               FROM CLAIM_AUDIT;

-- ============================================================
-- END OF ORACLE SCRIPT
-- ============================================================
