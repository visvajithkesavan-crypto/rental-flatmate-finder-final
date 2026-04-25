-- ============================================================
--  Rental & Flatmate Finder Platform
--  functions.sql — Stored Functions
--  Database Course Assignment | 2nd Year CS | Group Project
--
--  A stored function:
--  - Takes input parameters
--  - Performs a calculation
--  - Returns a SINGLE value
--  - Can be called inside a SELECT statement
--
--  We have 2 functions:
--  1. calculate_compatibility(user1_id, user2_id) → FLOAT
--  2. get_average_rating(p_user_id)               → FLOAT
-- ============================================================

USE rental_flatmate_db;

-- Required in MySQL before defining functions/procedures
-- Tells MySQL that $$ is the end of the function, not ;
DELIMITER $$

-- ============================================================
-- FUNCTION 1: calculate_compatibility
--
-- PURPOSE:
--   The heart of the flatmate matching engine.
--   Takes two user IDs, looks at their FLATMATE_PROFILE,
--   compares their preferences, and returns a score 0–100.
--
-- HOW THE SCORE IS CALCULATED:
--   We compare 3 preference fields between the two users:
--   1. sleep_schedule match  → worth 35 points
--   2. diet match            → worth 35 points
--   3. budget overlap        → worth 30 points
--   Total possible           → 100 points
--
-- OUTSIDE COURSE NOTE:
--   The budget overlap formula uses LEAST() and GREATEST()
--   which are standard MySQL functions — taught in most
--   SQL courses but flagging just in case.
--   Formula: overlap = LEAST(max1,max2) - GREATEST(min1,min2)
--   If overlap > 0, budgets are compatible.
--
-- HOW TO CALL IT:
--   SELECT calculate_compatibility(2, 4);
--   → Returns 88.5 (Priya and Sneha are very compatible)
-- ============================================================
CREATE FUNCTION calculate_compatibility(
    p_user1_id INT,
    p_user2_id INT
)
RETURNS FLOAT
DETERMINISTIC
READS SQL DATA
BEGIN
    -- Variables to store profile data for user 1
    DECLARE v_sleep1     VARCHAR(20);
    DECLARE v_diet1      VARCHAR(20);
    DECLARE v_bud_min1   DECIMAL(10,2);
    DECLARE v_bud_max1   DECIMAL(10,2);

    -- Variables to store profile data for user 2
    DECLARE v_sleep2     VARCHAR(20);
    DECLARE v_diet2      VARCHAR(20);
    DECLARE v_bud_min2   DECIMAL(10,2);
    DECLARE v_bud_max2   DECIMAL(10,2);

    -- Variables for scoring
    DECLARE v_score      FLOAT DEFAULT 0;
    DECLARE v_overlap    DECIMAL(10,2);

    -- ── Step 1: Fetch user 1's flatmate profile ──────────────
    SELECT sleep_schedule, diet, budget_min, budget_max
    INTO   v_sleep1, v_diet1, v_bud_min1, v_bud_max1
    FROM   FLATMATE_PROFILE
    WHERE  user_id = p_user1_id;

    -- ── Step 2: Fetch user 2's flatmate profile ──────────────
    SELECT sleep_schedule, diet, budget_min, budget_max
    INTO   v_sleep2, v_diet2, v_bud_min2, v_bud_max2
    FROM   FLATMATE_PROFILE
    WHERE  user_id = p_user2_id;

    -- ── Step 3: Compare sleep schedules (worth 35 points) ────
    -- Exact match = 35 points
    -- One of them is 'flexible' = 20 points (partial match)
    -- No match = 0 points
    IF v_sleep1 = v_sleep2 THEN
        SET v_score = v_score + 35;
    ELSEIF v_sleep1 = 'flexible' OR v_sleep2 = 'flexible' THEN
        SET v_score = v_score + 20;
    END IF;

    -- ── Step 4: Compare diet preferences (worth 35 points) ───
    -- Exact match = 35 points
    -- One of them is 'any' = 20 points (partial match)
    -- No match = 0 points
    IF v_diet1 = v_diet2 THEN
        SET v_score = v_score + 35;
    ELSEIF v_diet1 = 'any' OR v_diet2 = 'any' THEN
        SET v_score = v_score + 20;
    END IF;

    -- ── Step 5: Check budget overlap (worth 30 points) ───────
    -- Calculate how much the two budget ranges overlap.
    -- LEAST(max1, max2) gives the lower of the two maximums.
    -- GREATEST(min1, min2) gives the higher of the two minimums.
    -- If overlap > 0, they can afford to live together.
    --
    -- OUTSIDE COURSE: LEAST() and GREATEST() are built-in
    -- MySQL functions for finding min/max across columns.
    SET v_overlap = LEAST(v_bud_max1, v_bud_max2)
                  - GREATEST(v_bud_min1, v_bud_min2);

    IF v_overlap > 0 THEN
        SET v_score = v_score + 30;
    END IF;

    -- ── Step 6: Return the final score ───────────────────────
    RETURN ROUND(v_score, 2);

END$$

-- ============================================================
-- FUNCTION 2: get_average_rating
--
-- PURPOSE:
--   Returns the average rating a user has received
--   across all their reviews as a reviewee.
--   Used to display star ratings on user profiles.
--   Also called by the trigger in triggers.sql to update
--   USER.reputation_score after every new review.
--
-- HOW TO CALL IT:
--   SELECT get_average_rating(1);
--   → Returns 4.50 (Arjun received two 5-star and one 4-star)
--
--   SELECT get_average_rating(999);
--   → Returns 0.00 (user with no reviews gets 0, not NULL)
-- ============================================================
CREATE FUNCTION get_average_rating(
    p_user_id INT
)
RETURNS FLOAT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_avg FLOAT;

    -- Calculate average rating for this user as a reviewee
    SELECT AVG(rating)
    INTO   v_avg
    FROM   REVIEW
    WHERE  reviewee_id = p_user_id;

    -- IFNULL: if user has no reviews, return 0.0 instead of NULL
    -- OUTSIDE COURSE: IFNULL() is a MySQL-specific function.
    -- Standard SQL equivalent is COALESCE() which works the same way.
    RETURN ROUND(IFNULL(v_avg, 0.0), 2);

END$$

-- Reset delimiter back to normal
DELIMITER ;

-- ============================================================
-- TEST YOUR FUNCTIONS
-- Run these SELECT statements after creating the functions
-- to verify they work correctly with your sample data
-- ============================================================

-- Test 1: Priya(2) and Sneha(4) — both early birds, both veg
-- Expected result: 35 (sleep) + 35 (diet) + 30 (budget) = 100
-- But Priya budget: 7000-12000, Sneha: 6000-10000 → overlap exists
SELECT calculate_compatibility(2, 4) AS compatibility_score;

-- Test 2: Priya(2) and Meera(8) — Priya=early_bird, Meera=night_owl
-- Expected: 0 (sleep) + 35 (both veg) + 30 (budget overlap) = 65
SELECT calculate_compatibility(2, 8) AS compatibility_score;

-- Test 3: Arjun(1) — received ratings of 5 and 4
-- Expected average: (5 + 4) / 2 = 4.50
SELECT get_average_rating(1) AS avg_rating;

-- Test 4: Priya(2) — received rating of 4
-- Expected: 4.00
SELECT get_average_rating(2) AS avg_rating;

-- Test 5: Show compatibility scores for all existing matches
-- alongside the stored match_score to compare
SELECT
    fm.match_id,
    u1.name                                    AS user1,
    u2.name                                    AS user2,
    fm.match_score                             AS stored_score,
    calculate_compatibility(fm.user1_id,
                            fm.user2_id)       AS calculated_score,
    fm.status
FROM FLATMATE_MATCH fm
JOIN USER u1 ON fm.user1_id = u1.user_id
JOIN USER u2 ON fm.user2_id = u2.user_id;

-- ============================================================
--  END OF functions.sql
--  Next file: procedures.sql
-- ============================================================