import mysql.connector

def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="DBMS123",   # <-- apna actual MySQL password
        database="crop_insurance_db",
        port=3306
    )