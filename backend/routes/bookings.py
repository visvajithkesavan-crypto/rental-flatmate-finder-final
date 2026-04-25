# ============================================================
#  routes/bookings.py — Booking and lease routes
#  Rental & Flatmate Finder Platform
# ============================================================

from flask import Blueprint, request, jsonify, session
from db import query, execute, call_procedure

bookings_bp = Blueprint('bookings', __name__)


# ── CREATE a new booking ──────────────────────────────────────
# URL: POST /api/bookings
# Body: { property_id }
# Calls the book_property() stored procedure from procedures.sql
# The procedure checks availability, creates booking, updates
# property status — all in one atomic transaction
@bookings_bp.route('/api/bookings', methods=['POST'])
def create_booking():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Please login first'}), 401

    data        = request.get_json()
    property_id = data.get('property_id')
    tenant_id   = session['user_id']

    if not property_id:
        return jsonify({'success': False, 'message': 'Property ID is required'}), 400

    # Call the stored procedure book_property() from procedures.sql
    # This is atomic: check availability + create booking + update status
    # OUTSIDE COURSE: Calling stored procedures from Python uses callproc()
    result = call_procedure('book_property', (tenant_id, property_id, 0))

    if not result:
        return jsonify({
            'success': False,
            'message': 'Booking failed. Property may not be available.'
        }), 400

    # The trigger after_booking_insert fires automatically here
    # It inserts a notification for the landlord without us doing anything
    return jsonify({
        'success': True,
        'message': 'Booking request sent! The landlord will be notified.'
    })


# ── GET all bookings for logged-in user ───────────────────────
# URL: GET /api/bookings
@bookings_bp.route('/api/bookings', methods=['GET'])
def get_my_bookings():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Please login first'}), 401

    bookings = query("""
        SELECT
            b.booking_id,
            b.status,
            b.requested_at,
            p.title        AS property_title,
            p.rent,
            p.property_type,
            l.city,
            l.area,
            u.name         AS landlord_name,
            u.reputation_score AS landlord_rating
        FROM BOOKING b
        JOIN PROPERTY p ON b.property_id = p.property_id
        JOIN LOCATION l ON p.location_id  = l.location_id
        JOIN USER u     ON p.landlord_id  = u.user_id
        WHERE b.tenant_id = %s
        ORDER BY b.requested_at DESC
    """, (session['user_id'],))

    return jsonify({'success': True, 'data': bookings})


# ── CANCEL a booking ──────────────────────────────────────────
# URL: PUT /api/bookings/<id>/cancel
@bookings_bp.route('/api/bookings/<int:booking_id>/cancel', methods=['PUT'])
def cancel_booking(booking_id):
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Please login first'}), 401

    # Verify this booking belongs to the logged-in user
    booking = query("""
        SELECT booking_id, status, property_id FROM BOOKING
        WHERE booking_id = %s AND tenant_id = %s
    """, (booking_id, session['user_id']), one=True)

    if not booking:
        return jsonify({'success': False, 'message': 'Booking not found'}), 404

    if booking['status'] == 'cancelled':
        return jsonify({'success': False, 'message': 'Already cancelled'}), 400

    # Cancel the booking
    execute("UPDATE BOOKING SET status = 'cancelled' WHERE booking_id = %s", (booking_id,))

    # Free up the property if it was marked as booked
    execute("""
        UPDATE PROPERTY SET status = 'available'
        WHERE property_id = %s AND status = 'booked'
    """, (booking['property_id'],))

    return jsonify({'success': True, 'message': 'Booking cancelled'})


# ── GET all leases for logged-in user ─────────────────────────
# URL: GET /api/leases
@bookings_bp.route('/api/leases', methods=['GET'])
def get_my_leases():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Please login first'}), 401

    leases = query("""
        SELECT
            ls.lease_id,
            ls.start_date,
            ls.end_date,
            ls.monthly_rent,
            ls.signed_at,
            p.title        AS property_title,
            p.property_type,
            l.city,
            l.area,
            u.name         AS landlord_name
        FROM LEASE ls
        JOIN BOOKING b  ON ls.booking_id  = b.booking_id
        JOIN PROPERTY p ON b.property_id  = p.property_id
        JOIN LOCATION l ON p.location_id   = l.location_id
        JOIN USER u     ON p.landlord_id   = u.user_id
        WHERE b.tenant_id = %s
        ORDER BY ls.signed_at DESC
    """, (session['user_id'],))

    return jsonify({'success': True, 'data': leases})


# ── GET notifications for logged-in user ──────────────────────
# URL: GET /api/notifications
# These are auto-inserted by triggers — this just reads them
@bookings_bp.route('/api/notifications', methods=['GET'])
def get_notifications():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Please login first'}), 401

    notifications = query("""
        SELECT notif_id, type, message, is_read, created_at
        FROM NOTIFICATION
        WHERE user_id = %s
        ORDER BY created_at DESC
    """, (session['user_id'],))

    return jsonify({'success': True, 'data': notifications})


# ── MARK notification as read ─────────────────────────────────
# URL: PUT /api/notifications/<id>/read
@bookings_bp.route('/api/notifications/<int:notif_id>/read', methods=['PUT'])
def mark_read(notif_id):
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Please login first'}), 401

    execute("""
        UPDATE NOTIFICATION SET is_read = TRUE
        WHERE notif_id = %s AND user_id = %s
    """, (notif_id, session['user_id']))

    return jsonify({'success': True})
