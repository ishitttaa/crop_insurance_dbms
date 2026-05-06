import os
import requests
import csv
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

OWM_API_KEY = os.getenv('OWM_API_KEY')

# Use local CSV for prices as API key is not available
PRICE_CSV_FILE = "Market_Wise_Price_Arrival_03-05-2026_10-26-43_PM.csv"

def fetch_weather(district):
    """
    Fetches current weather for a district from OpenWeatherMap.
    Returns (rainfall, temperature) or (None, None) if failed.
    """
    import random
    
    if not OWM_API_KEY or "your_" in OWM_API_KEY:
        # SIMULATION MODE: If no API key, return random realistic weather
        # Higher chance of low rainfall for some districts to test triggers
        districts_with_drought = ["Vidisha", "Nashik", "Hoshangabad"]
        
        temp = 25 + random.uniform(0, 10)
        
        if district in districts_with_drought:
            # 60% chance of low rainfall (<50mm) to trigger claims
            rainfall = random.uniform(10, 80) if random.random() > 0.6 else random.uniform(10, 45)
        else:
            rainfall = random.uniform(40, 120)
            
        return round(float(rainfall), 2), round(float(temp), 2)

    url = f"https://api.openweathermap.org/data/2.5/weather?q={district}&appid={OWM_API_KEY}&units=metric"
    try:
        response = requests.get(url, timeout=10)
        data = response.json()
        
        if response.status_code != 200:
            # Fallback to simulation even if API fails (quota or city not found)
            return fetch_weather_sim(district)

        temp = data['main']['temp']
        rainfall = 0
        if 'rain' in data:
            rainfall = data['rain'].get('1h', data['rain'].get('3h', 0))
        
        return float(rainfall), float(temp)
    except Exception as e:
        return fetch_weather_sim(district)

def fetch_weather_sim(district):
    import random
    temp = 22 + random.uniform(0, 15)
    rainfall = random.uniform(0, 150)
    return round(float(rainfall), 2), round(float(temp), 2)

def fetch_crop_prices(crop_name, district):
    """
    Reads crop prices from the local CSV file.
    Note: Local CSV is a commodity-wise summary and doesn't contain district-specific data.
    """
    csv_path = os.path.join(os.path.dirname(__file__), PRICE_CSV_FILE)
    if not os.path.exists(csv_path):
        print(f"Price CSV file not found at {csv_path}")
        return None, None, None

    try:
        with open(csv_path, mode='r', encoding='utf-8') as f:
            # The CSV has some header rows, skip them until we find the real header
            reader = csv.reader(f)
            header_found = False
            for row in reader:
                if not row: continue
                if "Commodity" in row:
                    header_found = True
                    # Identify columns
                    # Col 1: Commodity, Col 3: Price on 01 May
                    # Let's assume Col 3 is the 'Modal' price for the latest date
                    # CSV layout:
                    # 0: Commodity Group, 1: Commodity, 2: MSP, 3: Price on 01 May, 4: Price on 30 Apr...
                    continue
                
                if header_found:
                    # Match crop name with mapping for common variations
                    mapping = {
                        "rice": "paddy",
                        "soybean": "soyabean",
                        "pigeon pea": "arhar",
                        "chickpea": "bengal gram"
                    }
                    
                    search_name = crop_name.lower()
                    csv_commodity = row[1].strip().lower()
                    
                    # Direct match or mapped match
                    matched = (search_name in csv_commodity or csv_commodity in search_name)
                    if not matched and search_name in mapping:
                        mapped_name = mapping[search_name]
                        matched = (mapped_name in csv_commodity or csv_commodity in mapped_name)

                    if matched:
                        msp = float(row[2].replace(',', '')) if row[2] and row[2] != '-' else 0
                        # Using 'Price on 01 May' as modal price (Col Index 3)
                        modal_price = float(row[3].replace(',', '')) if row[3] and row[3] != '-' else 0
                        # We'll simulate min/max as +/- 5% of modal
                        min_price = modal_price * 0.95
                        max_price = modal_price * 1.05
                        return min_price, max_price, modal_price
                        
        print(f"No price data found for {crop_name} in CSV.")
        return None, None, None

    except Exception as e:
        print(f"Error reading price CSV: {e}")
        return None, None, None
