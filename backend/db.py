# ============================================================
#  db.py — Database connection helper
#  Rental & Flatmate Finder Platform
#  Change YOUR_PASSWORD_HERE to your MySQL root password
# ============================================================

import mysql.connector
from mysql.connector import Error

def get_db_connection():
    """
    Returns a new MySQL connection.
    Called at the start of every route that needs DB access.
    """
    try:
        connection = mysql.connector.connect(
            host='localhost',
            port=3306,
            user='root',
            password='visva',  # ← change this
            database='rental_flatmate_db'
        )
        return connection
    except Error as e:
        print(f"[DB ERROR] Could not connect: {e}")
        return None


def query(sql, params=(), one=False):
    """
    Helper to run a SELECT query and return results.
    - sql:    the SQL string with %s placeholders
    - params: tuple of values to substitute safely
    - one:    if True, return just the first row
    """
    conn = get_db_connection()
    if not conn:
        return None
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(sql, params)
        result = cursor.fetchone() if one else cursor.fetchall()
        return result
    except Error as e:
        print(f"[QUERY ERROR] {e}")
        return None
    finally:
        cursor.close()
        conn.close()


def execute(sql, params=()):
    """
    Helper to run INSERT / UPDATE / DELETE.
    Returns the last inserted row ID (for INSERT),
    or True on success, False on failure.
    """
    conn = get_db_connection()
    if not conn:
        return False
    try:
        cursor = conn.cursor()
        cursor.execute(sql, params)
        conn.commit()
        return cursor.lastrowid or True
    except Error as e:
        print(f"[EXECUTE ERROR] {e}")
        conn.rollback()
        return False
    finally:
        cursor.close()
        conn.close()


def call_procedure(proc_name, args=()):
    """
    Calls a stored procedure by name.
    Example: call_procedure('book_property', (tenant_id, property_id))
    Returns output parameters or True/False.

    NOTE: This calls the stored procedures we wrote in procedures.sql
    book_property() and confirm_lease() are called from here.
    """
    conn = get_db_connection()
    if not conn:
        return False
    try:
        cursor = conn.cursor()
        cursor.callproc(proc_name, args)
        conn.commit()
        # Fetch output parameters
        results = []
        for result in cursor.stored_results():
            results.append(result.fetchall())
        return results or True
    except Error as e:
        print(f"[PROCEDURE ERROR] {e}")
        conn.rollback()
        return False
    finally:
        cursor.close()
        conn.close()
