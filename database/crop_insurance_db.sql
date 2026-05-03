-- ============================================================
--  INTEGRATED CROP PRICE VOLATILITY & INSURANCE CLAIM ANALYSIS
--  DATABASE MANAGEMENT SYSTEM  |  UCS310  |  THAPAR INSTITUTE
--  Students : Ishita Rajput (1024031185) | Tripti (1024030183)
--  Platform : MySQL 8.x  (MySQL Workbench)
-- ============================================================

-- ============================================================
-- SECTION 0 : DATABASE SETUP
-- ============================================================

DROP DATABASE IF EXISTS crop_insurance_db;
CREATE DATABASE crop_insurance_db;
USE crop_insurance_db;

-- ============================================================
-- SECTION 1 : DDL  –  CREATE TABLES
-- ============================================================
-- Order: independent tables first, then tables with FKs.

-- 1. GOVERNMENT_SCHEME
CREATE TABLE GOVERNMENT_SCHEME (
    Scheme_ID            INT           PRIMARY KEY AUTO_INCREMENT,
    Scheme_Name          VARCHAR(100)  NOT NULL,
    Eligibility_Criteria TEXT          NOT NULL
);

-- 2. FARMER
CREATE TABLE FARMER (
    Farmer_ID   INT           PRIMARY KEY AUTO_INCREMENT,
    Name        VARCHAR(100)  NOT NULL,
    District    VARCHAR(60)   NOT NULL,
    Land_Area   FLOAT         NOT NULL CHECK (Land_Area > 0)
);

-- 3. CROP
CREATE TABLE CROP (
    Crop_ID    INT          PRIMARY KEY AUTO_INCREMENT,
    Crop_Name  VARCHAR(60)  NOT NULL,
    Season     VARCHAR(30)  NOT NULL,
    MSP        FLOAT        NOT NULL CHECK (MSP > 0)   -- Minimum Support Price (₹/quintal)
);

-- 4. WEATHER_EVENT
CREATE TABLE WEATHER_EVENT (
    Weather_ID   INT          PRIMARY KEY AUTO_INCREMENT,
    Date         DATE         NOT NULL,
    District     VARCHAR(60)  NOT NULL,
    Rainfall     FLOAT        NOT NULL CHECK (Rainfall >= 0),   -- mm
    Temperature  FLOAT        NOT NULL                           -- °C
);

-- 5. MANDI_PRICE  (FK → CROP)
CREATE TABLE MANDI_PRICE (
    Price_ID INT PRIMARY KEY AUTO_INCREMENT,
    Price_Date DATE NOT NULL,
    District VARCHAR(60) NOT NULL,
    Min_Price FLOAT NOT NULL,
    Max_Price FLOAT NOT NULL,
    Modal_Price FLOAT NOT NULL,
    Crop_ID INT NOT NULL,

    CONSTRAINT chk_min_price CHECK (Min_Price >= 0),
    CONSTRAINT chk_max_price CHECK (Max_Price >= Min_Price),
    CONSTRAINT chk_modal_price CHECK (Modal_Price >= 0),

    FOREIGN KEY (Crop_ID) REFERENCES CROP(Crop_ID)
    ON DELETE RESTRICT ON UPDATE CASCADE
);
-- 6. INSURANCE_POLICY  (FK → FARMER)
CREATE TABLE INSURANCE_POLICY (
    Policy_ID    INT    PRIMARY KEY AUTO_INCREMENT,
    Sum_Insured  FLOAT  NOT NULL CHECK (Sum_Insured > 0),
    Premium      FLOAT  NOT NULL CHECK (Premium > 0),
    Start_Date   DATE   NOT NULL,
    End_Date     DATE   NOT NULL,
    Farmer_ID    INT    NOT NULL,
    FOREIGN KEY (Farmer_ID) REFERENCES FARMER(Farmer_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_dates CHECK (End_Date > Start_Date)
);

-- 7. CLAIM  (FK → INSURANCE_POLICY, WEATHER_EVENT)
CREATE TABLE CLAIM (
    Claim_ID      INT          PRIMARY KEY AUTO_INCREMENT,
    Claim_Status  VARCHAR(20)  NOT NULL DEFAULT 'Pending',
    Claim_Date    DATE         NOT NULL,
    Policy_ID     INT          NOT NULL,
    Weather_ID    INT          NOT NULL,
    FOREIGN KEY (Policy_ID)   REFERENCES INSURANCE_POLICY(Policy_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (Weather_ID)  REFERENCES WEATHER_EVENT(Weather_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_status CHECK (Claim_Status IN ('Pending','Approved','Rejected'))
);

-- 8. PAYOUT  (FK → CLAIM, 1:1)
CREATE TABLE PAYOUT (
    Payout_ID     INT    PRIMARY KEY AUTO_INCREMENT,
    Amount        FLOAT  NOT NULL CHECK (Amount > 0),
    Payment_Date  DATE   NOT NULL,
    Claim_ID      INT    NOT NULL UNIQUE,
    FOREIGN KEY (Claim_ID) REFERENCES CLAIM(Claim_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ---- Associative / Junction Tables (M:N relationships) ------

-- 9. FARMER_CROP  (M:N between FARMER and CROP)
CREATE TABLE FARMER_CROP (
    Farmer_ID  INT  NOT NULL,
    Crop_ID    INT  NOT NULL,
    PRIMARY KEY (Farmer_ID, Crop_ID),
    FOREIGN KEY (Farmer_ID) REFERENCES FARMER(Farmer_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Crop_ID)   REFERENCES CROP(Crop_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 10. FARMER_SCHEME  (M:N between FARMER and GOVERNMENT_SCHEME)
CREATE TABLE FARMER_SCHEME (
    Farmer_ID  INT  NOT NULL,
    Scheme_ID  INT  NOT NULL,
    PRIMARY KEY (Farmer_ID, Scheme_ID),
    FOREIGN KEY (Farmer_ID) REFERENCES FARMER(Farmer_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Scheme_ID) REFERENCES GOVERNMENT_SCHEME(Scheme_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 11. POLICY_CROP  (M:N between INSURANCE_POLICY and CROP)
CREATE TABLE POLICY_CROP (
    Policy_ID  INT  NOT NULL,
    Crop_ID    INT  NOT NULL,
    PRIMARY KEY (Policy_ID, Crop_ID),
    FOREIGN KEY (Policy_ID) REFERENCES INSURANCE_POLICY(Policy_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Crop_ID)   REFERENCES CROP(Crop_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);


-- ============================================================
-- SECTION 2 : DML  –  INSERT SAMPLE DATA
-- ============================================================

-- Government Schemes
INSERT INTO GOVERNMENT_SCHEME (Scheme_Name, Eligibility_Criteria) VALUES
('PMFBY',             'All farmers with land holding and crop insurance requirement'),
('PM-KISAN',          'Small and marginal farmers with land records'),
('Kisan Credit Card', 'Farmers needing short-term credit for crop cultivation'),
('RKVY',              'Farmers involved in agriculture and allied activities');

-- Farmers
INSERT INTO FARMER (Name, District, Land_Area) VALUES
('Ramesh Kumar',    'Vidisha',       3.5),
('Suresh Patel',    'Hoshangabad',   2.0),
('Meena Devi',      'Nashik',        4.0),
('Ajay Singh',      'Vidisha',       1.5),
('Priya Sharma',    'Hoshangabad',   5.0),
('Vijay Yadav',     'Nashik',        2.8),
('Anita Kumari',    'Bhopal',        3.2),
('Mohan Lal',       'Indore',        6.0);

-- Crops
INSERT INTO CROP (Crop_Name, Season, MSP) VALUES
('Wheat',    'Rabi',   2015.00),
('Rice',     'Kharif', 2183.00),
('Onion',    'Rabi',   800.00),
('Soybean',  'Kharif', 3950.00),
('Cotton',   'Kharif', 6620.00),
('Maize',    'Kharif', 1870.00);

-- Weather Events
INSERT INTO WEATHER_EVENT (Date, District, Rainfall, Temperature) VALUES
('2024-07-15', 'Vidisha',     35.0, 32.5),   -- below 50mm → triggers claim
('2024-07-20', 'Hoshangabad', 80.0, 30.0),
('2024-08-05', 'Nashik',      20.0, 28.0),   -- below 50mm → triggers claim
('2024-08-10', 'Vidisha',     10.0, 34.0),   -- below 50mm → triggers claim
('2024-09-01', 'Bhopal',      60.0, 27.5),
('2024-09-15', 'Indore',      45.0, 29.0),   -- below 50mm → triggers claim
('2024-10-01', 'Nashik',      15.0, 25.0);   -- below 50mm → triggers claim

-- Mandi Prices
INSERT INTO MANDI_PRICE (Price_Date, District, Min_Price, Max_Price, Modal_Price, Crop_ID) VALUES
-- Onion (Crop_ID=3, MSP=800) — price crash scenario (Nashik 2024)
('2024-09-01', 'Nashik',       100.00,  300.00,  180.00, 3),
('2024-09-08', 'Nashik',        80.00,  200.00,  120.00, 3),
('2024-09-15', 'Nashik',        50.00,  150.00,   90.00, 3),   -- severe distress
('2024-09-22', 'Nashik',        60.00,  180.00,  110.00, 3),
-- Wheat (Crop_ID=1, MSP=2015)
('2024-03-10', 'Vidisha',     1800.00, 2200.00, 2050.00, 1),
('2024-03-17', 'Vidisha',     1950.00, 2300.00, 2100.00, 1),
('2024-03-24', 'Hoshangabad', 1500.00, 1900.00, 1600.00, 1),   -- distress
-- Soybean (Crop_ID=4, MSP=3950)
('2024-10-05', 'Indore',      3200.00, 4000.00, 3600.00, 4),
('2024-10-12', 'Indore',      3000.00, 3800.00, 3100.00, 4),   -- distress
-- Cotton (Crop_ID=5, MSP=6620)
('2024-11-01', 'Vidisha',     5500.00, 6800.00, 6200.00, 5),
('2024-11-08', 'Vidisha',     5200.00, 6500.00, 5800.00, 5),   -- distress
-- Rice (Crop_ID=2, MSP=2183)
('2024-08-20', 'Hoshangabad', 2000.00, 2400.00, 2200.00, 2),
('2024-08-27', 'Hoshangabad', 1700.00, 2100.00, 1800.00, 2);   -- distress

-- Insurance Policies
INSERT INTO INSURANCE_POLICY (Sum_Insured, Premium, Start_Date, End_Date, Farmer_ID) VALUES
(50000.00, 1000.00, '2024-06-01', '2024-12-31', 1),
(40000.00,  800.00, '2024-06-01', '2024-12-31', 2),
(60000.00, 1200.00, '2024-06-01', '2024-12-31', 3),
(35000.00,  700.00, '2024-06-01', '2024-12-31', 4),
(75000.00, 1500.00, '2024-06-01', '2024-12-31', 5),
(45000.00,  900.00, '2024-07-01', '2025-01-31', 6),
(55000.00, 1100.00, '2024-07-01', '2025-01-31', 7),
(80000.00, 1600.00, '2024-07-01', '2025-01-31', 8);

-- Farmer-Crop links
INSERT INTO FARMER_CROP (Farmer_ID, Crop_ID) VALUES
(1,1),(1,3),(2,1),(2,2),(3,3),(3,5),(4,1),(5,2),(5,4),(6,3),(7,6),(8,4),(8,5);

-- Policy-Crop links
INSERT INTO POLICY_CROP (Policy_ID, Crop_ID) VALUES
(1,1),(1,3),(2,1),(2,2),(3,3),(3,5),(4,1),(5,2),(5,4),(6,3),(7,6),(8,4),(8,5);

-- Farmer-Scheme links
INSERT INTO FARMER_SCHEME (Farmer_ID, Scheme_ID) VALUES
(1,1),(1,2),(2,1),(3,1),(3,3),(4,2),(5,1),(5,2),(6,1),(7,4),(8,3),(8,4);

-- Manual Claims (trigger will add more automatically)
INSERT INTO CLAIM (Claim_Status, Claim_Date, Policy_ID, Weather_ID) VALUES
('Approved', '2024-07-16', 1, 1),
('Approved', '2024-08-06', 3, 3),
('Pending',  '2024-09-16', 6, 7);

-- Payouts (only for Approved claims)
INSERT INTO PAYOUT (Amount, Payment_Date, Claim_ID) VALUES
(25000.00, '2024-08-01', 1),
(30000.00, '2024-09-01', 2);


-- ============================================================
-- SECTION 3 : VIEWS
-- ============================================================

-- View 1: Price volatility analysis (core analytical view)
CREATE OR REPLACE VIEW Price_Volatility_View AS
SELECT
    m.Price_ID,
    c.Crop_Name,
    c.MSP,
    m.District,
    m.Price_Date,
    m.Min_Price,
    m.Max_Price,
    m.Modal_Price,
    ROUND((m.Modal_Price / c.MSP) * 100, 2)        AS Price_Pct_of_MSP,
    ROUND(((m.Max_Price - m.Min_Price) / m.Min_Price) * 100, 2) AS Daily_Volatility_Pct,
    CASE
        WHEN m.Modal_Price < 0.6 * c.MSP THEN 'SEVERE DISTRESS'
        WHEN m.Modal_Price < 0.8 * c.MSP THEN 'DISTRESS'
        ELSE 'NORMAL'
    END AS Price_Status
FROM MANDI_PRICE m
JOIN CROP c ON m.Crop_ID = c.Crop_ID;

-- View 2: Full claim details with farmer info
CREATE OR REPLACE VIEW Claim_Detail_View AS
SELECT
    cl.Claim_ID,
    f.Farmer_ID,
    f.Name         AS Farmer_Name,
    f.District,
    ip.Policy_ID,
    ip.Sum_Insured,
    ip.Premium,
    cl.Claim_Status,
    cl.Claim_Date,
    we.Rainfall,
    we.Temperature,
    we.Date        AS Weather_Date,
    p.Amount       AS Payout_Amount,
    p.Payment_Date
FROM CLAIM cl
JOIN INSURANCE_POLICY ip ON cl.Policy_ID  = ip.Policy_ID
JOIN FARMER f             ON ip.Farmer_ID  = f.Farmer_ID
JOIN WEATHER_EVENT we     ON cl.Weather_ID = we.Weather_ID
LEFT JOIN PAYOUT p        ON cl.Claim_ID   = p.Claim_ID;

-- View 3: Farmer portfolio summary
CREATE OR REPLACE VIEW Farmer_Portfolio_View AS
SELECT
    f.Farmer_ID,
    f.Name,
    f.District,
    f.Land_Area,
    GROUP_CONCAT(DISTINCT c.Crop_Name  ORDER BY c.Crop_Name  SEPARATOR ', ') AS Crops_Grown,
    GROUP_CONCAT(DISTINCT gs.Scheme_Name ORDER BY gs.Scheme_Name SEPARATOR ', ') AS Schemes_Enrolled,
    COUNT(DISTINCT ip.Policy_ID)  AS Total_Policies,
    COUNT(DISTINCT cl.Claim_ID)   AS Total_Claims
FROM FARMER f
LEFT JOIN FARMER_CROP fc         ON f.Farmer_ID = fc.Farmer_ID
LEFT JOIN CROP c                  ON fc.Crop_ID  = c.Crop_ID
LEFT JOIN FARMER_SCHEME fsc       ON f.Farmer_ID = fsc.Farmer_ID
LEFT JOIN GOVERNMENT_SCHEME gs    ON fsc.Scheme_ID = gs.Scheme_ID
LEFT JOIN INSURANCE_POLICY ip     ON f.Farmer_ID = ip.Farmer_ID
LEFT JOIN CLAIM cl                ON ip.Policy_ID = cl.Policy_ID
GROUP BY f.Farmer_ID, f.Name, f.District, f.Land_Area;


-- ============================================================
-- SECTION 4 : PL/SQL  –  STORED PROCEDURE
-- ============================================================



DELIMITER //

CREATE PROCEDURE Get_Price_Trend_Report(IN p_crop_id INT)
BEGIN
    SELECT 
        mp.Price_Date,
        mp.District,
        mp.Min_Price,
        mp.Max_Price,
        mp.Modal_Price,
        CASE 
            WHEN mp.Modal_Price < c.MSP THEN 'Below MSP'
            ELSE 'Normal'
        END AS Price_Status,
        ROUND((mp.Modal_Price / c.MSP) * 100, 2) AS Price_Pct_of_MSP
    FROM MANDI_PRICE mp
    JOIN CROP c ON mp.Crop_ID = c.Crop_ID
    WHERE mp.Crop_ID = p_crop_id
    ORDER BY mp.Price_Date DESC;
END //

DELIMITER ;

-- Procedure 2: Bulk approve all pending claims for a district

DELIMITER //

CREATE PROCEDURE Approve_Claims_By_District(IN p_district VARCHAR(60))
BEGIN
    UPDATE CLAIM cl
    JOIN INSURANCE_POLICY ip ON cl.Policy_ID = ip.Policy_ID
    JOIN FARMER f ON ip.Farmer_ID = f.Farmer_ID
    SET cl.Claim_Status = 'Approved'
    WHERE f.District = p_district
      AND cl.Claim_Status = 'Pending';
END //

DELIMITER ;

-- Procedure 3: Register a new farmer with a crop (transaction demo)
CREATE PROCEDURE Register_Farmer_With_Crop(
    IN p_name      VARCHAR(100),
    IN p_district  VARCHAR(60),
    IN p_land      FLOAT,
    IN p_crop_id   INT
)
BEGIN
    DECLARE v_farmer_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Registration failed. Transaction rolled back.';
    END;

    START TRANSACTION;
        INSERT INTO FARMER (Name, District, Land_Area) VALUES (p_name, p_district, p_land);
        SET v_farmer_id = LAST_INSERT_ID();
        INSERT INTO FARMER_CROP (Farmer_ID, Crop_ID) VALUES (v_farmer_id, p_crop_id);
    COMMIT;

    SELECT v_farmer_id AS New_Farmer_ID, p_name AS Name, 'Registered Successfully' AS Status;
END //

DELIMITER ;


-- ============================================================
-- SECTION 5 : PL/SQL  –  FUNCTIONS
-- ============================================================

DELIMITER //

-- Function 1: Calculate price volatility % for a crop in a district
CREATE FUNCTION Calculate_Volatility(
    p_crop_id  INT,
    p_district VARCHAR(60)
)
RETURNS FLOAT
DETERMINISTIC
BEGIN
    DECLARE v_max  FLOAT;
    DECLARE v_min  FLOAT;
    DECLARE v_vol  FLOAT;

    SELECT MAX(Modal_Price), MIN(Modal_Price)
    INTO   v_max, v_min
    FROM   MANDI_PRICE
    WHERE  Crop_ID = p_crop_id AND District = p_district;

    IF v_min IS NULL OR v_min = 0 THEN
        RETURN 0.0;
    END IF;

    SET v_vol = ROUND(((v_max - v_min) / v_min) * 100, 2);
    RETURN v_vol;
END //

-- Function 2: Check weather-based eligibility for a claim
CREATE FUNCTION Is_Claim_Eligible(p_weather_id INT)
RETURNS VARCHAR(5)
DETERMINISTIC
BEGIN
    DECLARE v_rainfall FLOAT;

    SELECT Rainfall INTO v_rainfall
    FROM WEATHER_EVENT
    WHERE Weather_ID = p_weather_id;

    IF v_rainfall < 50 THEN
        RETURN 'YES';
    ELSE
        RETURN 'NO';
    END IF;
END //

-- Function 3: Calculate payout amount based on sum insured and loss severity
CREATE FUNCTION Calculate_Payout(
    p_policy_id  INT,
    p_rainfall   FLOAT
)
RETURNS FLOAT
DETERMINISTIC
BEGIN
    DECLARE v_sum_insured FLOAT;
    DECLARE v_payout      FLOAT;

    SELECT Sum_Insured INTO v_sum_insured
    FROM INSURANCE_POLICY
    WHERE Policy_ID = p_policy_id;

    -- Payout scale: < 10mm → 80%, 10-25mm → 60%, 25-50mm → 40%
    IF p_rainfall < 10 THEN
        SET v_payout = v_sum_insured * 0.80;
    ELSEIF p_rainfall < 25 THEN
        SET v_payout = v_sum_insured * 0.60;
    ELSE
        SET v_payout = v_sum_insured * 0.40;
    END IF;

    RETURN ROUND(v_payout, 2);
END //

DELIMITER ;


-- ============================================================
-- SECTION 6 : TRIGGERS
-- ============================================================

DELIMITER //

-- Trigger 1: AUTO-GENERATE CLAIM when rainfall < 50mm
--            Fires AFTER INSERT on WEATHER_EVENT
CREATE TRIGGER trg_Auto_Claim_On_Low_Rainfall
AFTER INSERT ON WEATHER_EVENT
FOR EACH ROW
BEGIN
    IF NEW.Rainfall < 50 THEN
        -- Insert one claim per active policy in the same district
        INSERT INTO CLAIM (Claim_Status, Claim_Date, Policy_ID, Weather_ID)
        SELECT
            'Pending',
            CURDATE(),
            ip.Policy_ID,
            NEW.Weather_ID
        FROM INSURANCE_POLICY ip
        JOIN FARMER f ON ip.Farmer_ID = f.Farmer_ID
        WHERE f.District   = NEW.District
          AND ip.End_Date  >= CURDATE()
          AND NOT EXISTS (
              SELECT 1 FROM CLAIM c2
              WHERE c2.Policy_ID  = ip.Policy_ID
                AND c2.Weather_ID = NEW.Weather_ID
          );
    END IF;
END //

-- Trigger 2: PREVENT DUPLICATE POLICIES for same farmer on same date
CREATE TRIGGER trg_No_Duplicate_Policy
BEFORE INSERT ON INSURANCE_POLICY
FOR EACH ROW
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM INSURANCE_POLICY
    WHERE Farmer_ID  = NEW.Farmer_ID
      AND Start_Date = NEW.Start_Date
      AND End_Date   = NEW.End_Date;

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Duplicate policy: farmer already has a policy for this period.';
    END IF;
END //

-- Trigger 3: LOG claim status changes (update audit)
--            Requires an audit table first
CREATE TABLE IF NOT EXISTS CLAIM_AUDIT (
    Audit_ID    INT PRIMARY KEY AUTO_INCREMENT,
    Claim_ID    INT,
    Old_Status  VARCHAR(20),
    New_Status  VARCHAR(20),
    Changed_At  DATETIME DEFAULT CURRENT_TIMESTAMP
) //

CREATE TRIGGER trg_Claim_Status_Audit
AFTER UPDATE ON CLAIM
FOR EACH ROW
BEGIN
    IF OLD.Claim_Status <> NEW.Claim_Status THEN
        INSERT INTO CLAIM_AUDIT (Claim_ID, Old_Status, New_Status)
        VALUES (NEW.Claim_ID, OLD.Claim_Status, NEW.Claim_Status);
    END IF;
END //

DELIMITER ;


-- ============================================================
-- SECTION 7 : ADVANCED SELECT QUERIES (ANALYTICAL)
-- ============================================================

-- Q1: All price-distress records (modal < 80% of MSP)
SELECT Crop_Name, District, Price_Date, Modal_Price, MSP, Price_Status
FROM Price_Volatility_View
WHERE Price_Status IN ('DISTRESS', 'SEVERE DISTRESS')
ORDER BY Price_Pct_of_MSP ASC;

-- Q2: District-wise count of distress events
SELECT
    District,
    Crop_Name,
    COUNT(*) AS Distress_Days,
    ROUND(AVG(Modal_Price), 2) AS Avg_Modal_Price,
    MIN(Modal_Price) AS Lowest_Price
FROM Price_Volatility_View
WHERE Price_Status <> 'NORMAL'
GROUP BY District, Crop_Name
ORDER BY Distress_Days DESC;

-- Q3: Total claims and payout per farmer
SELECT
    f.Farmer_ID,
    f.Name,
    f.District,
    COUNT(DISTINCT cl.Claim_ID)      AS Total_Claims,
    SUM(CASE WHEN cl.Claim_Status = 'Approved' THEN 1 ELSE 0 END) AS Approved_Claims,
    COALESCE(SUM(p.Amount), 0)       AS Total_Payout_Received
FROM FARMER f
LEFT JOIN INSURANCE_POLICY ip ON f.Farmer_ID = ip.Farmer_ID
LEFT JOIN CLAIM cl             ON ip.Policy_ID = cl.Policy_ID
LEFT JOIN PAYOUT p             ON cl.Claim_ID  = p.Claim_ID
GROUP BY f.Farmer_ID, f.Name, f.District
ORDER BY Total_Payout_Received DESC;

-- Q4: Crops with highest price volatility using the function
SELECT
    c.Crop_ID,
    c.Crop_Name,
    mp.District,
    Calculate_Volatility(c.Crop_ID, mp.District) AS Volatility_Pct
FROM CROP c
JOIN MANDI_PRICE mp ON c.Crop_ID = mp.Crop_ID
GROUP BY c.Crop_ID, c.Crop_Name, mp.District
ORDER BY Volatility_Pct DESC;

-- Q5: Farmers eligible for claims (via weather events in their district)
SELECT DISTINCT
    f.Name,
    f.District,
    we.Date         AS Weather_Date,
    we.Rainfall,
    Is_Claim_Eligible(we.Weather_ID) AS Eligible
FROM FARMER f
JOIN WEATHER_EVENT we ON f.District = we.District
WHERE Is_Claim_Eligible(we.Weather_ID) = 'YES';

-- Q6: INNER JOIN – Policies with their claim status
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
    COALESCE(cl.Claim_Status, 'No Claim') AS Claim_Status,
    COALESCE(p.Amount, 0)                 AS Payout
FROM FARMER f
LEFT JOIN INSURANCE_POLICY ip ON f.Farmer_ID = ip.Farmer_ID
LEFT JOIN CLAIM cl             ON ip.Policy_ID = cl.Policy_ID
LEFT JOIN PAYOUT p             ON cl.Claim_ID  = p.Claim_ID;

-- Q8: Subquery – Farmers whose modal price fell below MSP
SELECT DISTINCT f.Name, f.District
FROM FARMER f
JOIN FARMER_CROP fc ON f.Farmer_ID = fc.Farmer_ID
WHERE fc.Crop_ID IN (
    SELECT DISTINCT mp.Crop_ID
    FROM MANDI_PRICE mp
    JOIN CROP c ON mp.Crop_ID = c.Crop_ID
    WHERE mp.Modal_Price < c.MSP
);

-- Q9: Aggregate – Average rainfall per district and how many claims it caused
SELECT
    we.District,
    ROUND(AVG(we.Rainfall), 2) AS Avg_Rainfall_mm,
    COUNT(DISTINCT cl.Claim_ID) AS Claims_Generated
FROM WEATHER_EVENT we
LEFT JOIN CLAIM cl ON we.Weather_ID = cl.Weather_ID
GROUP BY we.District
HAVING Avg_Rainfall_mm < 60
ORDER BY Avg_Rainfall_mm ASC;

-- Q10: HAVING – Districts where more than 1 claim was filed
SELECT
    f.District,
    COUNT(cl.Claim_ID) AS Claim_Count
FROM CLAIM cl
JOIN INSURANCE_POLICY ip ON cl.Policy_ID = ip.Policy_ID
JOIN FARMER f             ON ip.Farmer_ID = f.Farmer_ID
GROUP BY f.District
HAVING Claim_Count > 1;

-- Q11: Correlated subquery – Policies with above-average sum insured
SELECT Policy_ID, Farmer_ID, Sum_Insured
FROM INSURANCE_POLICY ip
WHERE Sum_Insured > (
    SELECT AVG(Sum_Insured) FROM INSURANCE_POLICY
);

-- Q12: Scheme enrollment count (GROUP BY)
SELECT
    gs.Scheme_Name,
    COUNT(fsc.Farmer_ID) AS Farmers_Enrolled
FROM GOVERNMENT_SCHEME gs
LEFT JOIN FARMER_SCHEME fsc ON gs.Scheme_ID = fsc.Scheme_ID
GROUP BY gs.Scheme_Name
ORDER BY Farmers_Enrolled DESC;


-- ============================================================
-- SECTION 8 : DML UPDATES AND DELETES
-- ============================================================

-- Update: Approve a specific claim
UPDATE CLAIM
SET Claim_Status = 'Approved'
WHERE Claim_ID = 3;

-- Update: Adjust premium for a farmer
UPDATE INSURANCE_POLICY
SET Premium = Premium * 1.10
WHERE Farmer_ID = 1;

-- Delete: Remove expired policies (safe because no active claims)
DELETE FROM INSURANCE_POLICY
WHERE Policy_ID > 0
AND End_Date < CURDATE()
AND Policy_ID NOT IN (SELECT DISTINCT Policy_ID FROM CLAIM);


-- ============================================================
-- SECTION 9 : TRANSACTION MANAGEMENT DEMO
-- ============================================================

-- Demo: Insert a new policy AND link crop in one atomic transaction
START TRANSACTION;

    INSERT INTO INSURANCE_POLICY (Sum_Insured, Premium, Start_Date, End_Date, Farmer_ID)
    VALUES (70000.00, 1400.00, '2025-01-01', '2025-12-31', 2);

    SET @new_policy_id = LAST_INSERT_ID();

    INSERT INTO POLICY_CROP (Policy_ID, Crop_ID)
    VALUES (@new_policy_id, 1);   -- link to Wheat

COMMIT;

-- Savepoint demo
START TRANSACTION;
    SAVEPOINT before_payout;

    INSERT INTO PAYOUT (Amount, Payment_Date, Claim_ID)
    VALUES (18000.00, CURDATE(), 3);

    -- If something looks wrong, roll back to savepoint only
    -- ROLLBACK TO SAVEPOINT before_payout;

COMMIT;


-- ============================================================
-- SECTION 10 : CALL PROCEDURES AND FUNCTIONS
-- ============================================================

-- Call price trend report for Onion (Crop_ID = 3)
CALL Get_Price_Trend_Report(3);

-- Approve all pending claims in Vidisha
CALL Approve_Claims_By_District('Vidisha');

-- Register a new farmer with Wheat (Crop_ID=1)
CALL Register_Farmer_With_Crop('Lakshmi Bai', 'Sagar', 2.5, 1);

-- Use functions directly in queries
SELECT
    'Onion'             AS Crop,
    'Nashik'            AS District,
    Calculate_Volatility(3, 'Nashik') AS Volatility_Pct;

SELECT Is_Claim_Eligible(1)  AS Weather_1_Eligible;
SELECT Is_Claim_Eligible(2)  AS Weather_2_Eligible;

SELECT Calculate_Payout(1, 10.0) AS Estimated_Payout_Policy1;


-- ============================================================
-- SECTION 11 : VERIFY ALL VIEWS
-- ============================================================

SELECT * FROM Price_Volatility_View    ORDER BY Price_Date DESC;
SELECT * FROM Claim_Detail_View        ORDER BY Claim_ID;
SELECT * FROM Farmer_Portfolio_View    ORDER BY Farmer_ID;
SELECT * FROM CLAIM_AUDIT;

-- ============================================================
-- END OF SCRIPT
-- ============================================================
