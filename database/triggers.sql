-- ============================================================
--  Rental & Flatmate Finder Platform
--  triggers.sql — Database Triggers
--  Database Course Assignment | 2nd Year CS | Group Project
--
--  A trigger:
--  - Fires AUTOMATICALLY when a specified event happens
--  - Events: INSERT, UPDATE, or DELETE on a table
--  - Timing: BEFORE or AFTER the event
--  - Cannot be called manually — it just fires on its own
--  - Application code never needs to call it
--
--  Key difference from procedures:
--  Procedure → called manually with CALL
--  Trigger   → fires automatically on a DB event
--
--  We have 3 triggers:
--  1. after_booking_insert
--     → Fires after INSERT on BOOKING
--     → Auto-notifies the landlord of the new request
--
--  2. after_review_insert
--     → Fires after INSERT on REVIEW
--     → Auto-updates the reviewee's reputation_score in USER
--     → Calls get_average_rating() function we wrote earlier
--
--  3. after_match_insert
--     → Fires after INSERT on FLATMATE_MATCH
--     → Auto-notifies BOTH users about their new match
-- ============================================================

USE rental_flatmate_db;

DELIMITER $$

-- ============================================================
-- TRIGGER 1: after_booking_insert
--
-- FIRES: After a new row is inserted into BOOKING
-- DOES:  Looks up the landlord of that property and inserts
--        a notification into the NOTIFICATION table for them.
--
-- HOW IT WORKS:
--   NEW.column_name → refers to the values just inserted
--   We join PROPERTY to find who the landlord is,
--   then insert a notification for that landlord.
--
-- REAL WORLD USE:
--   When Priya books Arjun's property, Arjun gets an instant
--   notification without any extra application code.
-- ============================================================
CREATE TRIGGER after_booking_insert
AFTER INSERT ON BOOKING
FOR EACH ROW
BEGIN
    -- Variables to store landlord info and property title
    DECLARE v_landlord_id  INT;
    DECLARE v_title        VARCHAR(200);
    DECLARE v_tenant_name  VARCHAR(100);

    -- Get the landlord_id and property title
    -- from the property that was just booked
    SELECT p.landlord_id, p.title
    INTO   v_landlord_id, v_title
    FROM   PROPERTY p
    WHERE  p.property_id = NEW.property_id;

    -- Get the tenant's name for the notification message
    SELECT name
    INTO   v_tenant_name
    FROM   USER
    WHERE  user_id = NEW.tenant_id;

    -- Insert notification for the landlord
    INSERT INTO NOTIFICATION (user_id, type, message)
    VALUES (
        v_landlord_id,
        'booking_request',
        CONCAT(v_tenant_name, ' has requested to book your property: ', v_title, '.')
        -- CONCAT() joins strings together
        -- OUTSIDE COURSE: CONCAT() is standard SQL but worth noting
    );

END$$


-- ============================================================
-- TRIGGER 2: after_review_insert
--
-- FIRES: After a new row is inserted into REVIEW
-- DOES:
--   1. Updates the reviewee's reputation_score in USER
--      by calling our get_average_rating() function
--   2. Inserts a notification for the reviewee
--      telling them they received a new review
--
-- WHY THIS IS IMPRESSIVE:
--   This trigger CALLS our stored function get_average_rating()
--   That means two course concepts work together:
--   function + trigger in one demonstration.
--
-- HOW IT WORKS:
--   NEW.reviewee_id → the person who just got reviewed
--   NEW.rating      → the rating just given
--   We recalculate their average using get_average_rating()
--   and update USER.reputation_score immediately.
-- ============================================================
CREATE TRIGGER after_review_insert
AFTER INSERT ON REVIEW
FOR EACH ROW
BEGIN
    DECLARE v_new_avg      FLOAT;
    DECLARE v_reviewer_name VARCHAR(100);

    -- Step 1: Recalculate the reviewee's average rating
    -- using the function we wrote in functions.sql
    SET v_new_avg = get_average_rating(NEW.reviewee_id);

    -- Step 2: Update reputation_score in USER table
    UPDATE USER
    SET    reputation_score = v_new_avg
    WHERE  user_id = NEW.reviewee_id;

    -- Step 3: Get the reviewer's name for the notification
    SELECT name
    INTO   v_reviewer_name
    FROM   USER
    WHERE  user_id = NEW.reviewer_id;

    -- Step 4: Notify the reviewee about their new review
    INSERT INTO NOTIFICATION (user_id, type, message)
    VALUES (
        NEW.reviewee_id,
        'new_review',
        CONCAT(
            v_reviewer_name,
            ' left you a ', NEW.rating, '-star review. ',
            'Your new reputation score is: ', v_new_avg, '.'
        )
    );

END$$


-- ============================================================
-- TRIGGER 3: after_match_insert
--
-- FIRES: After a new row is inserted into FLATMATE_MATCH
-- DOES:  Notifies BOTH users about their compatibility match.
--        Two notification rows are inserted — one per user.
--
-- WHY TWO NOTIFICATIONS:
--   Both user1 and user2 need to know about the match.
--   We insert two separate rows into NOTIFICATION,
--   one for each user, with a personalised message.
--
-- HOW IT WORKS:
--   NEW.user1_id    → first user in the match
--   NEW.user2_id    → second user in the match
--   NEW.match_score → the compatibility score calculated
-- ============================================================
CREATE TRIGGER after_match_insert
AFTER INSERT ON FLATMATE_MATCH
FOR EACH ROW
BEGIN
    DECLARE v_name1 VARCHAR(100);
    DECLARE v_name2 VARCHAR(100);

    -- Get both users' names
    SELECT name INTO v_name1 FROM USER WHERE user_id = NEW.user1_id;
    SELECT name INTO v_name2 FROM USER WHERE user_id = NEW.user2_id;

    -- Notify user1 about their match with user2
    INSERT INTO NOTIFICATION (user_id, type, message)
    VALUES (
        NEW.user1_id,
        'match_found',
        CONCAT(
            'You have a new flatmate match with ', v_name2,
            '! Compatibility score: ', NEW.match_score, '/100.'
        )
    );

    -- Notify user2 about their match with user1
    INSERT INTO NOTIFICATION (user_id, type, message)
    VALUES (
        NEW.user2_id,
        'match_found',
        CONCAT(
            'You have a new flatmate match with ', v_name1,
            '! Compatibility score: ', NEW.match_score, '/100.'
        )
    );

END$$

-- Reset delimiter back to normal
DELIMITER ;

-- ============================================================
-- TEST YOUR TRIGGERS
-- Triggers fire automatically — we just do the INSERT
-- and check the NOTIFICATION table to confirm they fired
-- ============================================================

-- ── TEST TRIGGER 1: after_booking_insert ──────────────────

-- Insert a new booking: Sneha(4) books Property 8
-- (Indiranagar 2BHK — currently available, landlord is Rohan=9)
INSERT INTO BOOKING (tenant_id, property_id, status)
VALUES (4, 8, 'pending');

-- Verify: Rohan(9) should have received a notification
SELECT *
FROM   NOTIFICATION
WHERE  user_id = 9
ORDER  BY created_at DESC
LIMIT  1;

-- ── TEST TRIGGER 2: after_review_insert ───────────────────

-- Check Karan's(5) current reputation score before review
SELECT user_id, name, reputation_score
FROM   USER
WHERE  user_id = 5;

-- Insert a new review: Meera(8) reviews Karan(5) with 3 stars
-- First we need a lease where Karan is landlord
-- We use lease_id 2 (Divya rented from Karan)
INSERT INTO REVIEW (lease_id, reviewer_id, reviewee_id, rating, comment)
VALUES (2, 8, 5, 3, 'Property was okay but maintenance could be better.');

-- Verify: Karan's reputation_score should now be updated
-- Previous reviews on Karan: ratings 4 and 5 from lease_id 2
-- New rating: 3 → new average = (4 + 5 + 3) / 3 = 4.00
SELECT user_id, name, reputation_score
FROM   USER
WHERE  user_id = 5;

-- Verify: Karan should have received a notification
SELECT *
FROM   NOTIFICATION
WHERE  user_id = 5
ORDER  BY created_at DESC
LIMIT  1;

-- ── TEST TRIGGER 3: after_match_insert ────────────────────

-- Insert a new flatmate match between Sneha(4) and Ananya(10)
-- Use calculate_compatibility to get real score
INSERT INTO FLATMATE_MATCH (user1_id, user2_id, match_score, status)
VALUES (4, 10, calculate_compatibility(4, 10), 'pending');

-- Verify: BOTH Sneha(4) and Ananya(10) should have notifications
SELECT u.name, n.type, n.message, n.created_at
FROM   NOTIFICATION n
JOIN   USER u ON n.user_id = u.user_id
WHERE  n.user_id IN (4, 10)
  AND  n.type = 'match_found'
ORDER  BY n.created_at DESC
LIMIT  2;

-- ============================================================
-- FINAL CHECK: See all notifications generated by triggers
-- ============================================================
SELECT
    n.notif_id,
    u.name       AS notified_user,
    n.type,
    n.message,
    n.is_read,
    n.created_at
FROM   NOTIFICATION n
JOIN   USER u ON n.user_id = u.user_id
ORDER  BY n.created_at DESC;

-- ============================================================
--  END OF triggers.sql
--  ALL SQL FILES COMPLETE:
--  schema.sql       ✓
--  sample_data.sql  ✓
--  queries.sql      ✓
--  functions.sql    ✓
--  procedures.sql   ✓
--  triggers.sql     ✓
-- ============================================================