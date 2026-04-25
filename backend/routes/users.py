# ============================================================
#  routes/users.py — User login and register routes
#  Rental & Flatmate Finder Platform
# ============================================================

from flask import Blueprint, request, jsonify, session
from db import query, execute

users_bp = Blueprint('users', __name__)


# ── REGISTER a new user ───────────────────────────────────────
# URL: POST /api/register
# Body: { name, email, phone, role }
# Inserts a new row into USER table
@users_bp.route('/api/register', methods=['POST'])
def register():
    data  = request.get_json()
    name  = data.get('name', '').strip()
    email = data.get('email', '').strip().lower()
    phone = data.get('phone', '').strip()
    role  = data.get('role', 'tenant')

    # Validate required fields
    if not name or not email or not phone:
        return jsonify({'success': False, 'message': 'Name, email and phone are required'}), 400

    # Check if email already exists (UNIQUE constraint in USER table)
    existing = query("SELECT user_id FROM USER WHERE email = %s", (email,), one=True)
    if existing:
        return jsonify({'success': False, 'message': 'Email already registered'}), 409

    # Insert new user into USER table
    # reputation_score defaults to 0.0 as defined in schema.sql
    user_id = execute("""
        INSERT INTO USER (name, email, phone, role)
        VALUES (%s, %s, %s, %s)
    """, (name, email, phone, role))

    if not user_id:
        return jsonify({'success': False, 'message': 'Registration failed'}), 500

    # Store user in session so they stay logged in
    # OUTSIDE COURSE: Flask sessions store data on the server side
    session['user_id']   = user_id
    session['user_name'] = name
    session['user_role'] = role

    return jsonify({
        'success': True,
        'message': 'Account created successfully',
        'user_id': user_id
    })


# ── LOGIN ─────────────────────────────────────────────────────
# URL: POST /api/login
# Body: { email }
# NOTE: In a real app you would check a hashed password.
# For the assignment we just verify the email exists in USER.
@users_bp.route('/api/login', methods=['POST'])
def login():
    data  = request.get_json()
    email = data.get('email', '').strip().lower()

    if not email:
        return jsonify({'success': False, 'message': 'Email is required'}), 400

    # Look up user in USER table
    user = query("""
        SELECT user_id, name, email, role, reputation_score
        FROM USER
        WHERE email = %s
    """, (email,), one=True)

    if not user:
        return jsonify({'success': False, 'message': 'No account found with this email'}), 404

    # Store in session
    session['user_id']   = user['user_id']
    session['user_name'] = user['name']
    session['user_role'] = user['role']

    return jsonify({
        'success':  True,
        'message':  'Login successful',
        'user':     user
    })


# ── GET user profile ──────────────────────────────────────────
# URL: GET /api/users/<id>
@users_bp.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    user = query("""
        SELECT user_id, name, email, phone, role, reputation_score, created_at
        FROM USER WHERE user_id = %s
    """, (user_id,), one=True)

    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404

    return jsonify({'success': True, 'data': user})


# ── LOGOUT ────────────────────────────────────────────────────
# URL: POST /api/logout
@users_bp.route('/api/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({'success': True, 'message': 'Logged out'})


# ── GET current logged-in user ────────────────────────────────
# URL: GET /api/me
@users_bp.route('/api/me', methods=['GET'])
def me():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not logged in'}), 401

    user = query("""
        SELECT user_id, name, email, role, reputation_score
        FROM USER WHERE user_id = %s
    """, (session['user_id'],), one=True)

    return jsonify({'success': True, 'data': user})
