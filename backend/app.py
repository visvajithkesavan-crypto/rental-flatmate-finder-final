# ============================================================
#  app.py — Main Flask application
#  Rental & Flatmate Finder Platform
#  Database Course Assignment | 2nd Year CS | Group Project
#
#  HOW TO RUN:
#  1. Open terminal in the backend/ folder
#  2. pip install flask mysql-connector-python
#  3. python app.py
#  4. Open http://127.0.0.1:5000 in your browser
# ============================================================

from flask import Flask, render_template, send_from_directory
import os

# ── App setup ─────────────────────────────────────────────────
app = Flask(
    __name__,
    # Tell Flask where to find HTML files
    template_folder=os.path.join('..', 'frontend', 'templates'),
    # Tell Flask where to find CSS/JS files
    static_folder=os.path.join('..', 'frontend', 'static')
)

# Secret key for session management
# OUTSIDE COURSE: Flask sessions need a secret key to sign cookies
# In production this should be a long random string stored in .env
app.secret_key = 'rentmate-dbms-assignment-2025'

# ── Register blueprints (route groups) ────────────────────────
from routes.properties import properties_bp
from routes.users      import users_bp
from routes.bookings   import bookings_bp
from routes.flatmates  import flatmates_bp

app.register_blueprint(properties_bp)
app.register_blueprint(users_bp)
app.register_blueprint(bookings_bp)
app.register_blueprint(flatmates_bp)

# ── Page routes (serve HTML files) ────────────────────────────
# These routes serve the HTML pages when a user visits the URL

@app.route('/')
def index():
    # Serves frontend/templates/index.html
    return render_template('index.html')

@app.route('/properties')
def properties():
    return render_template('properties.html')

@app.route('/property')
def property_detail_default():
    return render_template('property_detail.html')

@app.route('/property/<int:property_id>')
def property_detail(property_id):
    return render_template('property_detail.html')

@app.route('/flatmates')
def flatmates():
    return render_template('flatmates.html')

@app.route('/dashboard')
def dashboard():
    return render_template('dashboard.html')

@app.route('/auth')
def auth():
    return render_template('auth.html')

@app.route('/profile')
def profile():
    return render_template('profile.html')

# ── Health check route ─────────────────────────────────────────
# URL: GET /api/health
# Useful for testing if Flask + DB are both running
@app.route('/api/health')
def health():
    from db import get_db_connection
    conn = get_db_connection()
    db_ok = conn is not None
    if conn:
        conn.close()
    return {
        'flask': 'running',
        'database': 'connected' if db_ok else 'error',
        'project': 'Rental & Flatmate Finder',
        'course': 'Database Management Systems'
    }

# ── Run the app ───────────────────────────────────────────────
if __name__ == '__main__':
    print("=" * 50)
    print("  RentMate — Rental & Flatmate Finder")
    print("  DBMS Course Assignment | 2nd Year CS")
    print("=" * 50)
    print("  Running at: http://127.0.0.1:5000")
    print("  Health check: http://127.0.0.1:5000/api/health")
    print("=" * 50)
    # debug=True means Flask auto-reloads when you save a file
    # OUTSIDE COURSE: Never use debug=True in production
    import os
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=False, host='0.0.0.0', port=port)