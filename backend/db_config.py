import cx_Oracle

# ── Change these values to match your Oracle setup ──────────
DB_USER     = "SYSTEM"
DB_PASSWORD = "Oracle123"   # whatever you set during installation
DB_DSN      = "localhost/XE"
# ────────────────────────────────────────────────────────────

def get_connection():
    """Returns a fresh Oracle DB connection."""
    try:
        conn = cx_Oracle.connect(
            user=DB_USER,
            password=DB_PASSWORD,
            dsn=DB_DSN
        )
        return conn
    except cx_Oracle.DatabaseError as e:
        print(f"Database connection failed: {e}")
        raise
