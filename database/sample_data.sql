-- ============================================================
--  Rental & Flatmate Finder Platform
--  sample_data.sql — Realistic test data for all 11 tables
--  Database Course Assignment | 2nd Year CS | Group Project
--
--  Insert order matters — parent tables first.
--  USER → LOCATION → PROPERTY → AMENITY →
--  PROPERTY_AMENITY → FLATMATE_PROFILE → FLATMATE_MATCH →
--  BOOKING → LEASE → REVIEW → NOTIFICATION
-- ============================================================

USE rental_flatmate_db;

-- ============================================================
-- TABLE 1: USER
-- 10 users — mix of tenants, landlords, and both
-- ============================================================
INSERT INTO USER (name, email, phone, role, reputation_score) VALUES
('Arjun Sharma',    'arjun@gmail.com',    '9876543210', 'landlord', 4.5),
('Priya Menon',     'priya@gmail.com',    '9876543211', 'tenant',   4.2),
('Rahul Verma',     'rahul@gmail.com',    '9876543212', 'both',     3.8),
('Sneha Iyer',      'sneha@gmail.com',    '9876543213', 'tenant',   4.0),
('Karan Patel',     'karan@gmail.com',    '9876543214', 'landlord', 4.7),
('Divya Nair',      'divya@gmail.com',    '9876543215', 'tenant',   3.5),
('Amit Singh',      'amit@gmail.com',     '9876543216', 'both',     4.1),
('Meera Pillai',    'meera@gmail.com',    '9876543217', 'tenant',   4.3),
('Rohan Gupta',     'rohan@gmail.com',    '9876543218', 'landlord', 3.9),
('Ananya Krishnan', 'ananya@gmail.com',   '9876543219', 'tenant',   4.6);
-- user_id: Arjun=1, Priya=2, Rahul=3, Sneha=4, Karan=5,
--          Divya=6, Amit=7, Meera=8, Rohan=9, Ananya=10

-- ============================================================
-- TABLE 2: LOCATION
-- 6 locations across Chennai and Bangalore
-- ============================================================
INSERT INTO LOCATION (city, area, pincode) VALUES
('Chennai',    'Adyar',          '600020'),
('Chennai',    'Anna Nagar',     '600040'),
('Chennai',    'T Nagar',        '600017'),
('Bangalore',  'Koramangala',    '560034'),
('Bangalore',  'Indiranagar',    '560038'),
('Bangalore',  'Whitefield',     '560066');
-- location_id: Adyar=1, Anna Nagar=2, T Nagar=3,
--              Koramangala=4, Indiranagar=5, Whitefield=6

-- ============================================================
-- TABLE 3: PROPERTY
-- 8 properties — mix of types, prices, and statuses
-- Landlords: Arjun(1), Karan(5), Rahul(3), Rohan(9), Amit(7)
-- ============================================================
INSERT INTO PROPERTY (landlord_id, location_id, title, rent, size_sqft, property_type, status) VALUES
(1, 1, '2BHK Apartment in Adyar',          18000, 950,  'apartment', 'available'),
(1, 2, 'Spacious Studio near Anna Nagar',   9500, 450,  'studio',    'available'),
(5, 4, 'Modern 1BHK in Koramangala',       22000, 700,  'apartment', 'available'),
(5, 5, 'PG Accommodation in Indiranagar',   8000, 200,  'pg',        'booked'),
(3, 3, '3BHK House in T Nagar',            35000, 1400, 'house',     'available'),
(9, 6, '1BHK Flat in Whitefield',          15000, 600,  'apartment', 'rented'),
(7, 4, 'Cozy Studio in Koramangala',       11000, 400,  'studio',    'available'),
(9, 5, '2BHK near Indiranagar Metro',      25000, 850,  'apartment', 'available');
-- property_id: 1=Adyar 2BHK, 2=Anna Nagar Studio, 3=Koramangala 1BHK
--              4=Indiranagar PG, 5=T Nagar House, 6=Whitefield 1BHK
--              7=Koramangala Studio, 8=Indiranagar 2BHK

-- ============================================================
-- TABLE 4: AMENITY
-- 10 common amenities
-- ============================================================
INSERT INTO AMENITY (amenity_name, category) VALUES
('WiFi',             'utilities'),
('Air Conditioning', 'comfort'),
('Parking',          'transport'),
('Power Backup',     'utilities'),
('Security Guard',   'security'),
('CCTV',             'security'),
('Gym',              'comfort'),
('Swimming Pool',    'comfort'),
('Lift',             'transport'),
('Washing Machine',  'utilities');
-- amenity_id: WiFi=1, AC=2, Parking=3, Power Backup=4,
--             Security=5, CCTV=6, Gym=7, Pool=8, Lift=9, WM=10

-- ============================================================
-- TABLE 5: PROPERTY_AMENITY
-- Which property has which amenities
-- ============================================================
INSERT INTO PROPERTY_AMENITY (property_id, amenity_id) VALUES
-- Property 1: 2BHK Adyar — WiFi, AC, Parking, Power Backup, Lift
(1, 1), (1, 2), (1, 3), (1, 4), (1, 9),
-- Property 2: Studio Anna Nagar — WiFi, AC, Washing Machine
(2, 1), (2, 2), (2, 10),
-- Property 3: 1BHK Koramangala — WiFi, AC, Parking, Gym, Lift, CCTV
(3, 1), (3, 2), (3, 3), (3, 7), (3, 9), (3, 6),
-- Property 4: PG Indiranagar — WiFi, Security Guard, CCTV
(4, 1), (4, 5), (4, 6),
-- Property 5: House T Nagar — WiFi, AC, Parking, Power Backup, Gym, Pool
(5, 1), (5, 2), (5, 3), (5, 4), (5, 7), (5, 8),
-- Property 6: Whitefield 1BHK — WiFi, AC, Lift
(6, 1), (6, 2), (6, 9),
-- Property 7: Studio Koramangala — WiFi, Washing Machine
(7, 1), (7, 10),
-- Property 8: Indiranagar 2BHK — WiFi, AC, Parking, Security, Lift
(8, 1), (8, 2), (8, 3), (8, 5), (8, 9);

-- ============================================================
-- TABLE 6: FLATMATE_PROFILE
-- 6 users have filled in flatmate preferences
-- ============================================================
INSERT INTO FLATMATE_PROFILE (user_id, budget_min, budget_max, sleep_schedule, diet, study_hours, preferred_area) VALUES
(2,  7000,  12000, 'early_bird', 'veg',     'morning', 'Chennai'),
(3,  10000, 18000, 'night_owl',  'non_veg', 'night',   'Bangalore'),
(4,  6000,  10000, 'early_bird', 'veg',     'morning', 'Chennai'),
(6,  8000,  14000, 'flexible',   'any',     'morning', 'Bangalore'),
(8,  9000,  16000, 'night_owl',  'veg',     'night',   'Chennai'),
(10, 11000, 20000, 'early_bird', 'veg',     'morning', 'Bangalore');

-- ============================================================
-- TABLE 7: FLATMATE_MATCH
-- Compatibility matches calculated between users
-- ============================================================
INSERT INTO FLATMATE_MATCH (user1_id, user2_id, match_score, status) VALUES
(2,  4,  88.5, 'accepted'),
-- Priya & Sneha: both early birds, both veg, both Chennai
(2,  8,  72.0, 'pending'),
-- Priya & Meera: same diet, different sleep schedule
(3,  7,  65.0, 'pending'),
-- Rahul & Amit: both Bangalore, both night-ish
(6,  10, 78.5, 'accepted'),
-- Divya & Ananya: both Bangalore, compatible budgets
(4,  8,  55.0, 'declined'),
-- Sneha & Meera: declined
(8,  10, 80.0, 'pending');
-- Meera & Ananya: both veg, both night owls

-- ============================================================
-- TABLE 8: BOOKING
-- Tenant booking requests
-- Designed so some properties have multiple bookings (for
-- correlated query 1 to show above-average tenants)
-- ============================================================
INSERT INTO BOOKING (tenant_id, property_id, status) VALUES
(2,  1, 'confirmed'),   -- Priya booked Adyar 2BHK
(4,  2, 'pending'),     -- Sneha requested Anna Nagar Studio
(6,  3, 'confirmed'),   -- Divya booked Koramangala 1BHK
(8,  5, 'pending'),     -- Meera requested T Nagar House
(10, 7, 'confirmed'),   -- Ananya booked Koramangala Studio
(2,  7, 'cancelled'),   -- Priya also tried Koramangala Studio (cancelled)
(4,  5, 'pending'),     -- Sneha also tried T Nagar House
(8,  3, 'cancelled'),   -- Meera also tried Koramangala 1BHK
(2,  3, 'pending'),     -- Priya also trying Koramangala 1BHK
(10, 8, 'pending');     -- Ananya trying Indiranagar 2BHK
-- Priya(2) has 3 bookings, Sneha(4) has 2, Ananya(10) has 2
-- These will show up in the correlated query for above-avg tenants

-- ============================================================
-- TABLE 9: LEASE
-- Confirmed leases from confirmed bookings
-- booking_id 1 → Priya in Adyar 2BHK
-- booking_id 3 → Divya in Koramangala 1BHK
-- booking_id 5 → Ananya in Koramangala Studio
-- ============================================================
INSERT INTO LEASE (booking_id, start_date, end_date, monthly_rent, signed_at) VALUES
(1, '2025-01-01', '2025-12-31', 17500, '2025-01-01 10:00:00'),
-- Priya negotiated 17500 (listed was 18000)
(3, '2025-02-01', '2026-01-31', 22000, '2025-02-01 11:00:00'),
-- Divya at listed price
(5, '2025-03-01', '2026-02-28', 10800, '2025-03-01 09:00:00');
-- Ananya negotiated 10800 (listed was 11000)

-- ============================================================
-- TABLE 10: REVIEW
-- Post-lease reviews — tenants review landlords and vice versa
-- lease_id 1 → Priya(2) and Arjun(1)
-- lease_id 2 → Divya(6) and Karan(5)
-- ============================================================
INSERT INTO REVIEW (lease_id, reviewer_id, reviewee_id, rating, comment) VALUES
(1, 2, 1, 5, 'Arjun is an excellent landlord. Very responsive and the apartment was exactly as described.'),
(1, 1, 2, 4, 'Priya was a great tenant. Paid rent on time and kept the apartment clean.'),
(2, 6, 5, 4, 'Karan was helpful and the property was well maintained.'),
(2, 5, 6, 5, 'Divya was a wonderful tenant. Highly recommend.');

-- ============================================================
-- TABLE 11: NOTIFICATION
-- In the real system these are auto-inserted by triggers.
-- We insert a few manually here for initial testing only.
-- Once triggers.sql is run, this table fills automatically.
-- ============================================================
INSERT INTO NOTIFICATION (user_id, type, message, is_read) VALUES
(1, 'booking_request',  'Priya Menon has requested to book your property: 2BHK Apartment in Adyar.', TRUE),
(5, 'booking_request',  'Divya Nair has requested to book your property: Modern 1BHK in Koramangala.', TRUE),
(2, 'lease_confirmed',  'Your lease for 2BHK Apartment in Adyar has been confirmed. Move-in: Jan 1 2025.', TRUE),
(4, 'match_found',      'You have a new flatmate match with Priya Menon! Compatibility score: 88.5', FALSE),
(8, 'match_found',      'You have a new flatmate match with Priya Menon! Compatibility score: 72.0', FALSE),
(10,'match_found',      'You have a new flatmate match with Divya Nair! Compatibility score: 78.5', FALSE);

-- ============================================================
-- QUICK VERIFICATION QUERIES
-- Run these to confirm data was inserted correctly
-- ============================================================

-- Check row counts for all tables
SELECT 'USER'              AS table_name, COUNT(*) AS total FROM USER             UNION ALL
SELECT 'LOCATION',                        COUNT(*)          FROM LOCATION          UNION ALL
SELECT 'PROPERTY',                        COUNT(*)          FROM PROPERTY          UNION ALL
SELECT 'AMENITY',                         COUNT(*)          FROM AMENITY           UNION ALL
SELECT 'PROPERTY_AMENITY',                COUNT(*)          FROM PROPERTY_AMENITY  UNION ALL
SELECT 'FLATMATE_PROFILE',                COUNT(*)          FROM FLATMATE_PROFILE  UNION ALL
SELECT 'FLATMATE_MATCH',                  COUNT(*)          FROM FLATMATE_MATCH    UNION ALL
SELECT 'BOOKING',                         COUNT(*)          FROM BOOKING           UNION ALL
SELECT 'LEASE',                           COUNT(*)          FROM LEASE             UNION ALL
SELECT 'REVIEW',                          COUNT(*)          FROM REVIEW            UNION ALL
SELECT 'NOTIFICATION',                    COUNT(*)          FROM NOTIFICATION;

-- ============================================================
--  END OF sample_data.sql
-- ============================================================