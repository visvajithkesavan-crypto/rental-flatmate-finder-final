# ============================================================
#  routes/flatmates.py — Flatmate matching routes
#  Rental & Flatmate Finder Platform
# ============================================================

from flask import Blueprint, request, jsonify, session
from db import query, execute

flatmates_bp = Blueprint('flatmates', __name__)


# ── GET all flatmate profiles ─────────────────────────────────
# URL: GET /api/flatmates
# Supports filters: ?city=Chennai&diet=veg&sleep=early_bird
@flatmates_bp.route('/api/flatmates', methods=['GET'])
def get_flatmates():
    city  = request.args.get('city')
    diet  = request.args.get('diet')
    sleep = request.args.get('sleep')

    sql = """
        SELECT
            fp.profile_id,
            fp.budget_min,
            fp.budget_max,
            fp.sleep_schedule,
            fp.diet,
            fp.study_hours,
            fp.preferred_area,
            u.user_id,
            u.name,
            u.reputation_score
        FROM FLATMATE_PROFILE fp
        JOIN USER u ON fp.user_id = u.user_id
        WHERE 1=1
    """
    params = []

    if city:
        sql += " AND fp.preferred_area LIKE %s"
        params.append(f'%{city}%')
    if diet:
        sql += " AND fp.diet = %s"
        params.append(diet)
    if sleep:
        sql += " AND fp.sleep_schedule = %s"
        params.append(sleep)

    profiles = query(sql, tuple(params))
    return jsonify({'success': True, 'data': profiles})


# ── GET compatibility score between two users ─────────────────
# URL: GET /api/flatmates/score?user1=2&user2=4
# Calls the calculate_compatibility() stored function from functions.sql
@flatmates_bp.route('/api/flatmates/score', methods=['GET'])
def get_score():
    user1 = request.args.get('user1', type=int)
    user2 = request.args.get('user2', type=int)

    if not user1 or not user2:
        return jsonify({'success': False, 'message': 'Both user IDs required'}), 400

    # Call the stored function calculate_compatibility()
    # written in functions.sql
    result = query(
        "SELECT calculate_compatibility(%s, %s) AS score",
        (user1, user2),
        one=True
    )

    score = result['score'] if result else 0
    return jsonify({'success': True, 'score': score})


# ── GET all matches for logged-in user ────────────────────────
# URL: GET /api/flatmates/matches
@flatmates_bp.route('/api/flatmates/matches', methods=['GET'])
def get_my_matches():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Please login first'}), 401

    user_id = session['user_id']

    # Find all matches where user is user1 OR user2
    matches = query("""
        SELECT
            fm.match_id,
            fm.match_score,
            fm.status,
            fm.created_at,
            CASE
                WHEN fm.user1_id = %s THEN u2.user_id
                ELSE u1.user_id
            END AS other_user_id,
            CASE
                WHEN fm.user1_id = %s THEN u2.name
                ELSE u1.name
            END AS other_user_name,
            CASE
                WHEN fm.user1_id = %s THEN u2.reputation_score
                ELSE u1.reputation_score
            END AS other_user_rating
        FROM FLATMATE_MATCH fm
        JOIN USER u1 ON fm.user1_id = u1.user_id
        JOIN USER u2 ON fm.user2_id = u2.user_id
        WHERE fm.user1_id = %s OR fm.user2_id = %s
        ORDER BY fm.match_score DESC
    """, (user_id, user_id, user_id, user_id, user_id))

    return jsonify({'success': True, 'data': matches})


# ── SEND a match request ──────────────────────────────────────
# URL: POST /api/flatmates/connect
# Body: { receiver_id }
# Inserts into FLATMATE_MATCH → triggers after_match_insert
# → both users get notifications automatically
@flatmates_bp.route('/api/flatmates/connect', methods=['POST'])
def send_match():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Please login first'}), 401

    data        = request.get_json()
    receiver_id = data.get('receiver_id')
    sender_id   = session['user_id']

    if not receiver_id:
        return jsonify({'success': False, 'message': 'Receiver ID required'}), 400

    if receiver_id == sender_id:
        return jsonify({'success': False, 'message': 'Cannot match with yourself'}), 400

    # Check if match already exists
    existing = query("""
        SELECT match_id FROM FLATMATE_MATCH
        WHERE (user1_id = %s AND user2_id = %s)
           OR (user1_id = %s AND user2_id = %s)
    """, (sender_id, receiver_id, receiver_id, sender_id), one=True)

    if existing:
        return jsonify({'success': False, 'message': 'Match already exists'}), 409

    # Calculate compatibility score using stored function
    score_result = query(
        "SELECT calculate_compatibility(%s, %s) AS score",
        (sender_id, receiver_id),
        one=True
    )
    score = score_result['score'] if score_result else 0

    # Insert into FLATMATE_MATCH
    # This fires the after_match_insert trigger automatically
    # which inserts notifications for BOTH users
    match_id = execute("""
        INSERT INTO FLATMATE_MATCH (user1_id, user2_id, match_score, status)
        VALUES (%s, %s, %s, 'pending')
    """, (sender_id, receiver_id, score))

    if not match_id:
        return jsonify({'success': False, 'message': 'Failed to send request'}), 500

    return jsonify({
        'success':    True,
        'message':    'Match request sent! Both users have been notified.',
        'match_score': score
    })


# ── ACCEPT or DECLINE a match ─────────────────────────────────
# URL: PUT /api/flatmates/matches/<id>
# Body: { action: 'accepted' | 'declined' }
@flatmates_bp.route('/api/flatmates/matches/<int:match_id>', methods=['PUT'])
def update_match(match_id):
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Please login first'}), 401

    data   = request.get_json()
    action = data.get('action')

    if action not in ('accepted', 'declined'):
        return jsonify({'success': False, 'message': 'Action must be accepted or declined'}), 400

    execute("""
        UPDATE FLATMATE_MATCH SET status = %s
        WHERE match_id = %s
          AND (user1_id = %s OR user2_id = %s)
    """, (action, match_id, session['user_id'], session['user_id']))

    return jsonify({'success': True, 'message': f'Match {action}'})
