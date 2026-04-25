-- ============================================================
--  Rental & Flatmate Finder Platform
--  procedures.sql — Stored Procedures
--  Database Course Assignment | 2nd Year CS | Group Project
--
--  A stored procedure:
--  - Takes input parameters (and optional OUT parameters)
--  - Executes multiple SQL statements as one unit
--  - Can INSERT, UPDATE, DELETE across multiple tables
--  - Called using CALL statement, not inside SELECT
--  - Uses transactions to ensure all steps succeed or none do
--
--  Key difference from functions:
--  Function  → returns a single value, used in SELECT
--  Procedure → executes actions, called with CALL
--
--  We have 2 procedures:
--  1. book_property(tenant_id, property_id, OUT booking_id)
--  2. confirm_lease(booking_id, start_date, end_date, rent)
-- ============================================================

USE rental_flatmate_db;

DELIMITER $$

-- ============================================================
-- PROCEDURE 1: book_property
--
-- PURPOSE:
--   Handles the entire booking process atomically.
--   When a tenant wants to book a property, this procedure:
--   1. Checks if the property is actually available
--   2. Creates the booking record
--   3. Updates the property status to 'booked'
--   4. All 3 steps happen together or not at all (transaction)
--
-- PARAMETERS:
--   p_tenant_id   → IN:  the user_id of the tenant booking
--   p_property_id → IN:  the property_id being booked
--   p_booking_id  → OUT: returns the new booking_id created
--                        so the application knows what was made
--
-- OUTSIDE COURSE NOTE:
--   TRANSACTION, COMMIT, ROLLBACK are standard SQL concepts
--   taught in DB courses. They ensure data consistency —
--   if any step fails, all changes are undone (ROLLBACK).
--   SIGNAL SQLSTATE is MySQL's way of throwing a custom error.
--
-- HOW TO CALL IT:
--   CALL book_property(4, 1, @new_booking_id);
--   SELECT @new_booking_id;
-- ============================================================
CREATE PROCEDURE book_property(
    IN  p_tenant_id   INT,
    IN  p_property_id INT,
    OUT p_booking_id  INT
)
BEGIN
    -- Variable to store current property status
    DECLARE v_status VARCHAR(20);

    -- Error handler: if anything goes wrong, rollback all changes
    -- OUTSIDE COURSE: DECLARE HANDLER is MySQL-specific syntax
    -- for catching errors inside stored procedures.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- ── Start transaction ─────────────────────────────────────
    -- Everything below is treated as ONE operation.
    -- Either ALL steps succeed, or NONE of them are saved.
    START TRANSACTION;

        -- ── Step 1: Check property availability ──────────────
        -- Lock the row so no other booking can happen
        -- simultaneously (prevents double booking)
        -- OUTSIDE COURSE: SELECT ... FOR UPDATE is a row-level
        -- lock used in concurrent environments.
        SELECT status
        INTO   v_status
        FROM   PROPERTY
        WHERE  property_id = p_property_id
        FOR UPDATE;

        -- If property is not available, throw an error
        IF v_status != 'available' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Property is not available for booking.';
        END IF;

        -- ── Step 2: Create the booking record ────────────────
        INSERT INTO BOOKING (tenant_id, property_id, status)
        VALUES (p_tenant_id, p_property_id, 'pending');

        -- Capture the auto-generated booking_id
        SET p_booking_id = LAST_INSERT_ID();

        -- ── Step 3: Update property status to 'booked' ───────
        UPDATE PROPERTY
        SET    status = 'booked'
        WHERE  property_id = p_property_id;

    -- ── Commit: save all changes permanently ─────────────────
    COMMIT;

END$$


-- ============================================================
-- PROCEDURE 2: confirm_lease
--
-- PURPOSE:
--   Called when a landlord confirms a booking.
--   This procedure:
--   1. Verifies the booking exists and is in 'pending' status
--   2. Updates booking status to 'confirmed'
--   3. Creates a LEASE record linked to this booking
--   4. Updates the property status to 'rented'
--   5. All steps happen atomically (transaction)
--
-- PARAMETERS:
--   p_booking_id   → IN: the booking being confirmed
--   p_start_date   → IN: lease start date
--   p_end_date     → IN: lease end date
--   p_monthly_rent → IN: agreed monthly rent (may differ
--                        from listed property rent)
--   p_lease_id     → OUT: returns the new lease_id created
--
-- HOW TO CALL IT:
--   CALL confirm_lease(4, '2025-05-01', '2026-04-30', 9500, @new_lease_id);
--   SELECT @new_lease_id;
-- ============================================================
CREATE PROCEDURE confirm_lease(
    IN  p_booking_id    INT,
    IN  p_start_date    DATE,
    IN  p_end_date      DATE,
    IN  p_monthly_rent  DECIMAL(10,2),
    OUT p_lease_id      INT
)
BEGIN
    -- Variables to store booking details
    DECLARE v_booking_status  VARCHAR(20);
    DECLARE v_property_id     INT;

    -- Error handler: rollback everything if any step fails
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- ── Start transaction ─────────────────────────────────────
    START TRANSACTION;

        -- ── Step 1: Verify booking exists and is pending ─────
        SELECT status, property_id
        INTO   v_booking_status, v_property_id
        FROM   BOOKING
        WHERE  booking_id = p_booking_id
        FOR UPDATE;

        -- Check booking is in the right state
        IF v_booking_status != 'pending' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking is not in pending status.';
        END IF;

        -- Check dates are valid
        IF p_end_date <= p_start_date THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'End date must be after start date.';
        END IF;

        -- ── Step 2: Update booking status to confirmed ────────
        UPDATE BOOKING
        SET    status = 'confirmed'
        WHERE  booking_id = p_booking_id;

        -- ── Step 3: Create the lease record ───────────────────
        INSERT INTO LEASE (booking_id, start_date, end_date, monthly_rent)
        VALUES (p_booking_id, p_start_date, p_end_date, p_monthly_rent);

        -- Capture the auto-generated lease_id
        SET p_lease_id = LAST_INSERT_ID();

        -- ── Step 4: Update property status to 'rented' ────────
        UPDATE PROPERTY
        SET    status = 'rented'
        WHERE  property_id = v_property_id;

    -- ── Commit all changes ────────────────────────────────────
    COMMIT;

END$$

-- Reset delimiter back to normal
DELIMITER ;

-- ============================================================
-- TEST YOUR PROCEDURES
-- Run these CALL statements after creating the procedures
-- ============================================================

-- Test 1: Book property 5 (T Nagar House) for Meera(8)
-- Property 5 is currently 'available' so this should succeed
CALL book_property(8, 5, @new_booking_id);
SELECT @new_booking_id AS new_booking_id;

-- Verify: property 5 status should now be 'booked'
SELECT property_id, title, status
FROM   PROPERTY
WHERE  property_id = 5;

-- Verify: new booking should appear in BOOKING table
SELECT * FROM BOOKING WHERE booking_id = @new_booking_id;

-- ──────────────────────────────────────────────────────────────

-- Test 2: Confirm the booking we just created into a lease
-- Using the booking_id returned from Test 1
CALL confirm_lease(
    @new_booking_id,
    '2025-06-01',
    '2026-05-31',
    34000,
    @new_lease_id
);
SELECT @new_lease_id AS new_lease_id;

-- Verify: booking status should now be 'confirmed'
SELECT booking_id, status FROM BOOKING WHERE booking_id = @new_booking_id;

-- Verify: new lease should appear in LEASE table
SELECT * FROM LEASE WHERE lease_id = @new_lease_id;

-- Verify: property 5 status should now be 'rented'
SELECT property_id, title, status FROM PROPERTY WHERE property_id = 5;

-- ============================================================
--  END OF procedures.sql
--  Next file: triggers.sql
-- ============================================================