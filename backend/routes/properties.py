# ============================================================
#  routes/properties.py — Property routes
#  Rental & Flatmate Finder Platform
# ============================================================

from flask import Blueprint, request, jsonify
from db import query, execute, call_procedure

# Blueprint groups all property-related routes together
# OUTSIDE COURSE: Flask Blueprint is a way to split routes
# across multiple files instead of putting everything in app.py
properties_bp = Blueprint('properties', __name__)


# ── GET all available properties ──────────────────────────────
# URL: GET /api/properties
# Supports filters: ?city=Chennai&type=apartment&max_price=20000
@properties_bp.route('/api/properties', methods=['GET'])
def get_properties():
    city      = request.args.get('city')
    prop_type = request.args.get('type')
    max_price = request.args.get('max_price', type=int)
    min_price = request.args.get('min_price', type=int, default=0)

    # Build SQL dynamically based on filters provided
    # This maps to PROPERTY table from schema.sql
    sql = """
        SELECT
            p.property_id,
            p.title,
            p.rent,
            p.size_sqft,
            p.property_type,
            p.status,
            p.listed_at,
            l.city,
            l.area,
            l.pincode,
            u.name       AS landlord_name,
            u.reputation_score AS landlord_rating
        FROM PROPERTY p
        JOIN LOCATION l ON p.location_id = l.location_id
        JOIN USER u     ON p.landlord_id  = u.user_id
        WHERE p.status = 'available'
    """
    params = []

    if city:
        sql += " AND l.city = %s"
        params.append(city)
    if prop_type:
        sql += " AND p.property_type = %s"
        params.append(prop_type)
    if max_price:
        sql += " AND p.rent <= %s"
        params.append(max_price)
    if min_price:
        sql += " AND p.rent >= %s"
        params.append(min_price)

    sql += " ORDER BY p.listed_at DESC"

    properties = query(sql, tuple(params))
    return jsonify({'success': True, 'data': properties})


# ── GET single property with amenities ────────────────────────
# URL: GET /api/properties/<id>
@properties_bp.route('/api/properties/<int:property_id>', methods=['GET'])
def get_property(property_id):
    # Fetch property details
    prop = query("""
        SELECT
            p.*,
            l.city, l.area, l.pincode,
            u.name AS landlord_name,
            u.reputation_score AS landlord_rating,
            u.user_id AS landlord_id
        FROM PROPERTY p
        JOIN LOCATION l ON p.location_id = l.location_id
        JOIN USER u     ON p.landlord_id  = u.user_id
        WHERE p.property_id = %s
    """, (property_id,), one=True)

    if not prop:
        return jsonify({'success': False, 'message': 'Property not found'}), 404

    # Fetch amenities for this property
    # Uses PROPERTY_AMENITY junction table + AMENITY table
    amenities = query("""
        SELECT a.amenity_name, a.category
        FROM PROPERTY_AMENITY pa
        JOIN AMENITY a ON pa.amenity_id = a.amenity_id
        WHERE pa.property_id = %s
    """, (property_id,))

    prop['amenities'] = amenities or []
    return jsonify({'success': True, 'data': prop})


# ── GET properties below city average (correlated subquery) ───
# URL: GET /api/properties/below-city-average
# This endpoint runs the correlated subquery from queries.sql
@properties_bp.route('/api/properties/below-city-average', methods=['GET'])
def below_city_average():
    # This is the correlated subquery from queries.sql
    # For each property, the inner query calculates avg rent
    # in the SAME city — that's what makes it correlated
    results = query("""
        SELECT
            p1.property_id,
            p1.title,
            p1.rent,
            p1.property_type,
            loc1.city,
            loc1.area,
            (SELECT ROUND(AVG(p2.rent), 2)
             FROM PROPERTY p2
             JOIN LOCATION loc2 ON p2.location_id = loc2.location_id
             WHERE loc2.city = loc1.city) AS city_avg_rent
        FROM PROPERTY p1
        JOIN LOCATION loc1 ON p1.location_id = loc1.location_id
        WHERE p1.status = 'available'
          AND p1.rent < (
              SELECT AVG(p2.rent)
              FROM PROPERTY p2
              JOIN LOCATION loc2 ON p2.location_id = loc2.location_id
              WHERE loc2.city = loc1.city
          )
        ORDER BY p1.rent ASC
    """)
    return jsonify({'success': True, 'data': results})
