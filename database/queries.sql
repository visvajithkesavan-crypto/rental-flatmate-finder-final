-- ============================================================
--  Rental & Flatmate Finder Platform
--  queries.sql — Nested & Correlated Subqueries
--  Database Course Assignment | 2nd Year CS | Group Project
-- ============================================================

USE rental_flatmate_db;

-- ============================================================
--  NESTED SUBQUERIES
--  The inner query runs ONCE and returns a result.
--  The outer query uses that result.
--  Inner query has NO reference to the outer query's rows.
-- ============================================================


-- ------------------------------------------------------------
-- NESTED QUERY 1:
-- Find all properties that have never received any booking.
--
-- WHY USEFUL: Landlords can see which listings are getting
-- zero interest so they can lower the rent or improve the
-- listing description.
--
-- HOW IT WORKS:
--   Inner query  → gets all property_ids that HAVE bookings
--   Outer query  → finds properties NOT in that list
-- ------------------------------------------------------------
SELECT
    p.property_id,
    p.title,
    p.rent,
    p.property_type,
    l.city,
    l.area
FROM PROPERTY p
JOIN LOCATION l ON p.location_id = l.location_id
WHERE p.property_id NOT IN (
    -- Inner query: get all property IDs that have at least one booking
    SELECT DISTINCT property_id
    FROM BOOKING
);


-- ------------------------------------------------------------
-- NESTED QUERY 2:
-- Find all properties whose rent is below the average rent
-- across the entire platform.
--
-- WHY USEFUL: Tenants looking for budget-friendly options
-- can instantly filter for below-average priced listings.
--
-- HOW IT WORKS:
--   Inner query  → calculates the overall average rent
--   Outer query  → returns properties cheaper than that average
-- ------------------------------------------------------------
SELECT
    p.property_id,
    p.title,
    p.rent,
    p.property_type,
    l.city,
    l.area
FROM PROPERTY p
JOIN LOCATION l ON p.location_id = l.location_id
WHERE p.status = 'available'
  AND p.rent < (
    -- Inner query: calculate average rent of ALL properties
    SELECT AVG(rent)
    FROM PROPERTY
);


-- ============================================================
--  CORRELATED SUBQUERIES
--  The inner query runs ONCE FOR EVERY ROW of the outer query.
--  The inner query references a column from the outer query.
--  You can spot a correlated subquery by looking for an alias
--  from the outer query used inside the inner query.
-- ============================================================


-- ------------------------------------------------------------
-- CORRELATED QUERY 1:
-- Find all tenants who have made more bookings than
-- the average number of bookings per tenant.
--
-- WHY USEFUL: Identifies highly active users on the platform —
-- useful for sending loyalty rewards or priority support.
--
-- HOW IT WORKS:
-- For EACH user in the outer query (aliased as u):
--   Inner query counts how many bookings THAT specific user made
--   If their count > overall average bookings per tenant → include them
--
-- The key: WHERE b2.tenant_id = u.user_id
-- This is what makes it correlated — inner query references
-- u.user_id from the outer query.
-- ------------------------------------------------------------
SELECT
    u.user_id,
    u.name,
    u.email,
    -- Count bookings for this specific user
    (SELECT COUNT(*)
     FROM BOOKING b2
     WHERE b2.tenant_id = u.user_id) AS total_bookings
FROM USER u
WHERE u.role IN ('tenant', 'both')
  AND (
    -- Correlated: count bookings for THIS user (u.user_id)
    SELECT COUNT(*)
    FROM BOOKING b
    WHERE b.tenant_id = u.user_id
  ) > (
    -- Overall average bookings per tenant (runs once)
    SELECT AVG(booking_count)
    FROM (
        SELECT COUNT(*) AS booking_count
        FROM BOOKING
        GROUP BY tenant_id
    ) AS avg_table
);


-- ------------------------------------------------------------
-- CORRELATED QUERY 2:
-- Find all properties whose rent is below the average rent
-- of properties in THE SAME CITY.
--
-- WHY USEFUL: Much smarter than Query 2 above — instead of
-- comparing to the global average, this compares each property
-- to others in its own city. A property at 12,000/month is
-- cheap in Mumbai but expensive in a smaller city.
--
-- HOW IT WORKS:
-- For EACH property in the outer query (aliased as p1):
--   Inner query calculates the average rent of properties
--   in the SAME city as p1 (p2.location_id matched to city)
--
-- The key: WHERE loc2.city = loc1.city
-- This is what makes it correlated — inner query references
-- loc1.city which comes from the outer query's JOIN.
-- ------------------------------------------------------------
SELECT
    p1.property_id,
    p1.title,
    p1.rent,
    p1.property_type,
    loc1.city,
    loc1.area,
    -- Show the city average for comparison
    (SELECT ROUND(AVG(p2.rent), 2)
     FROM PROPERTY p2
     JOIN LOCATION loc2 ON p2.location_id = loc2.location_id
     WHERE loc2.city = loc1.city) AS city_avg_rent
FROM PROPERTY p1
JOIN LOCATION loc1 ON p1.location_id = loc1.location_id
WHERE p1.status = 'available'
  AND p1.rent < (
    -- Correlated: average rent of properties in THE SAME CITY as p1
    SELECT AVG(p2.rent)
    FROM PROPERTY p2
    JOIN LOCATION loc2 ON p2.location_id = loc2.location_id
    WHERE loc2.city = loc1.city
    -- loc1.city references the OUTER query — this is the correlation
);

-- ============================================================
--  END OF queries.sql
--  Next file: functions.sql
-- ============================================================