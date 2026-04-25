-- ============================================================
--  Rental & Flatmate Finder Platform
--  schema.sql — All CREATE TABLE statements
--  Database Course Assignment | 2nd Year CS | Group Project
--
--  Run order matters — parent tables must exist before
--  child tables that reference them via FK.
--  Order: USER → LOCATION → PROPERTY → AMENITY →
--         PROPERTY_AMENITY → FLATMATE_PROFILE →
--         FLATMATE_MATCH → BOOKING → LEASE → REVIEW →
--         NOTIFICATION
-- ============================================================

-- Step 1: Create and select the database
CREATE DATABASE IF NOT EXISTS rental_flatmate_db;
USE rental_flatmate_db;

-- ============================================================
-- TABLE 1: USER
-- Stores all platform users — tenants, landlords, or both.
-- Role field distinguishes what features each user can access.
-- ============================================================
CREATE TABLE USER (
    user_id          INT            PRIMARY KEY AUTO_INCREMENT,
    name             VARCHAR(100)   NOT NULL,
    email            VARCHAR(150)   NOT NULL UNIQUE,
    phone            VARCHAR(15)    NOT NULL UNIQUE,
    role             ENUM('tenant', 'landlord', 'both') NOT NULL,
    reputation_score FLOAT          DEFAULT 0.0,
    created_at       TIMESTAMP      DEFAULT NOW(),

    -- Reputation must be between 0 and 5 (like a star rating)
    CONSTRAINT chk_reputation CHECK (reputation_score >= 0 AND reputation_score <= 5)
);

-- ============================================================
-- TABLE 2: LOCATION
-- Stores city, area, and pincode separately.
-- REASON: If city were stored directly in PROPERTY, then
-- property_id → city → pincode would be a transitive
-- dependency, violating 3NF. Separate table fixes this.
-- ============================================================
CREATE TABLE LOCATION (
    location_id  INT           PRIMARY KEY AUTO_INCREMENT,
    city         VARCHAR(100)  NOT NULL,
    area         VARCHAR(100)  NOT NULL,
    pincode      VARCHAR(10)   NOT NULL
);

-- ============================================================
-- TABLE 3: PROPERTY
-- Rental listings posted by landlords.
-- References USER (landlord) and LOCATION.
-- Amenities are NOT stored here — see PROPERTY_AMENITY.
-- ============================================================
CREATE TABLE PROPERTY (
    property_id   INT              PRIMARY KEY AUTO_INCREMENT,
    landlord_id   INT              NOT NULL,
    location_id   INT              NOT NULL,
    title         VARCHAR(200)     NOT NULL,
    rent          DECIMAL(10, 2)   NOT NULL,
    size_sqft     INT,
    property_type ENUM('apartment', 'house', 'pg', 'studio') NOT NULL,
    status        ENUM('available', 'booked', 'rented')      DEFAULT 'available',
    listed_at     TIMESTAMP        DEFAULT NOW(),

    CONSTRAINT fk_property_landlord  FOREIGN KEY (landlord_id)  REFERENCES USER(user_id),
    CONSTRAINT fk_property_location  FOREIGN KEY (location_id)  REFERENCES LOCATION(location_id),
    CONSTRAINT chk_rent              CHECK (rent > 0),
    CONSTRAINT chk_size              CHECK (size_sqft IS NULL OR size_sqft > 0)
);

-- ============================================================
-- TABLE 4: AMENITY
-- Master list of all possible amenities.
-- REASON: Storing "WiFi,AC,Parking" as a comma list inside
-- PROPERTY would violate 1NF (non-atomic values).
-- This table stores each amenity exactly once (UNIQUE).
-- ============================================================
CREATE TABLE AMENITY (
    amenity_id   INT          PRIMARY KEY AUTO_INCREMENT,
    amenity_name VARCHAR(100) NOT NULL UNIQUE,
    category     VARCHAR(50)  NOT NULL
    -- category examples: 'utilities', 'security', 'comfort', 'transport'
);

-- ============================================================
-- TABLE 5: PROPERTY_AMENITY  (Junction Table)
-- Resolves the M:N relationship between PROPERTY and AMENITY.
-- One property can have many amenities.
-- One amenity (e.g. WiFi) can appear in many properties.
-- NOTE: Junction tables with no extra attributes are
-- automatically in 3NF — nothing to create transitive deps.
-- ============================================================
CREATE TABLE PROPERTY_AMENITY (
    prop_amenity_id INT  PRIMARY KEY AUTO_INCREMENT,
    property_id     INT  NOT NULL,
    amenity_id      INT  NOT NULL,

    CONSTRAINT fk_pa_property FOREIGN KEY (property_id) REFERENCES PROPERTY(property_id)
        ON DELETE CASCADE,
        -- If a property is deleted, its amenity links are also removed
    CONSTRAINT fk_pa_amenity  FOREIGN KEY (amenity_id)  REFERENCES AMENITY(amenity_id),
    CONSTRAINT uq_pa_pair     UNIQUE (property_id, amenity_id)
    -- Prevents duplicate (property, amenity) pairs
);

-- ============================================================
-- TABLE 6: FLATMATE_PROFILE
-- Stores preferences of users looking for flatmates.
-- UNIQUE on user_id enforces the 1:1 relationship with USER
-- at the database level — one profile per user maximum.
-- ============================================================
CREATE TABLE FLATMATE_PROFILE (
    profile_id      INT             PRIMARY KEY AUTO_INCREMENT,
    user_id         INT             NOT NULL UNIQUE,
    -- UNIQUE enforces 1:1 with USER
    budget_min      DECIMAL(10, 2)  NOT NULL,
    budget_max      DECIMAL(10, 2)  NOT NULL,
    sleep_schedule  ENUM('early_bird', 'night_owl', 'flexible') DEFAULT 'flexible',
    diet            ENUM('veg', 'non_veg', 'vegan', 'any')      DEFAULT 'any',
    study_hours     VARCHAR(50),
    preferred_area  VARCHAR(100),

    CONSTRAINT fk_fp_user      FOREIGN KEY (user_id) REFERENCES USER(user_id),
    CONSTRAINT chk_budget_min  CHECK (budget_min > 0),
    CONSTRAINT chk_budget_max  CHECK (budget_max >= budget_min)
);

-- ============================================================
-- TABLE 7: FLATMATE_MATCH
-- Compatibility match records between two users.
-- SELF-REFERENCING: Both user1_id and user2_id are FKs
-- that reference the same USER table.
-- This is the most advanced design in the project.
-- ============================================================
CREATE TABLE FLATMATE_MATCH (
    match_id    INT       PRIMARY KEY AUTO_INCREMENT,
    user1_id    INT       NOT NULL,
    user2_id    INT       NOT NULL,
    match_score FLOAT     NOT NULL,
    status      ENUM('pending', 'accepted', 'declined') DEFAULT 'pending',
    created_at  TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_fm_user1      FOREIGN KEY (user1_id)   REFERENCES USER(user_id),
    CONSTRAINT fk_fm_user2      FOREIGN KEY (user2_id)   REFERENCES USER(user_id),
    CONSTRAINT chk_no_self      CHECK (user2_id != user1_id),
    -- Prevents a user from being matched with themselves
    CONSTRAINT chk_match_score  CHECK (match_score BETWEEN 0 AND 100),
    CONSTRAINT uq_match_pair    UNIQUE (user1_id, user2_id)
    -- Prevents duplicate match records for the same pair
);

-- ============================================================
-- TABLE 8: BOOKING
-- Tenant requests to rent a property.
-- A booking triggers a notification to the landlord
-- (handled by a trigger defined in triggers.sql).
-- ============================================================
CREATE TABLE BOOKING (
    booking_id   INT       PRIMARY KEY AUTO_INCREMENT,
    tenant_id    INT       NOT NULL,
    property_id  INT       NOT NULL,
    status       ENUM('pending', 'confirmed', 'cancelled') DEFAULT 'pending',
    requested_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_bk_tenant   FOREIGN KEY (tenant_id)   REFERENCES USER(user_id),
    CONSTRAINT fk_bk_property FOREIGN KEY (property_id) REFERENCES PROPERTY(property_id)
);

-- ============================================================
-- TABLE 9: LEASE
-- Confirmed rental agreement created after a booking
-- is accepted by the landlord.
-- UNIQUE on booking_id enforces the 1:1 relationship
-- with BOOKING — one booking = one lease maximum.
-- monthly_rent stored here separately because the
-- negotiated rent may differ from the listed property rent.
-- ============================================================
CREATE TABLE LEASE (
    lease_id      INT             PRIMARY KEY AUTO_INCREMENT,
    booking_id    INT             NOT NULL UNIQUE,
    -- UNIQUE enforces 1:1 with BOOKING
    start_date    DATE            NOT NULL,
    end_date      DATE            NOT NULL,
    monthly_rent  DECIMAL(10, 2)  NOT NULL,
    signed_at     TIMESTAMP       DEFAULT NOW(),

    CONSTRAINT fk_ls_booking     FOREIGN KEY (booking_id) REFERENCES BOOKING(booking_id),
    CONSTRAINT chk_dates         CHECK (end_date > start_date),
    CONSTRAINT chk_monthly_rent  CHECK (monthly_rent > 0)
);

-- ============================================================
-- TABLE 10: REVIEW
-- Post-lease ratings between tenants and landlords.
-- Both reviewer_id and reviewee_id reference USER —
-- same self-referencing pattern as FLATMATE_MATCH.
-- A trigger on this table updates USER.reputation_score
-- automatically after every new review (see triggers.sql).
-- ============================================================
CREATE TABLE REVIEW (
    review_id    INT       PRIMARY KEY AUTO_INCREMENT,
    lease_id     INT       NOT NULL,
    reviewer_id  INT       NOT NULL,
    reviewee_id  INT       NOT NULL,
    rating       INT       NOT NULL,
    comment      TEXT,
    created_at   TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_rv_lease     FOREIGN KEY (lease_id)    REFERENCES LEASE(lease_id),
    CONSTRAINT fk_rv_reviewer  FOREIGN KEY (reviewer_id) REFERENCES USER(user_id),
    CONSTRAINT fk_rv_reviewee  FOREIGN KEY (reviewee_id) REFERENCES USER(user_id),
    CONSTRAINT chk_rating      CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_no_self_rv  CHECK (reviewee_id != reviewer_id)
    -- Cannot review yourself
);

-- ============================================================
-- TABLE 11: NOTIFICATION
-- Auto-generated alerts for all key platform events.
-- IMPORTANT: Application code NEVER inserts here directly.
-- Every row is inserted automatically by a database trigger.
-- Triggers fire on: new BOOKING, new FLATMATE_MATCH,
-- confirmed LEASE, new REVIEW.
-- ============================================================
CREATE TABLE NOTIFICATION (
    notif_id   INT       PRIMARY KEY AUTO_INCREMENT,
    user_id    INT       NOT NULL,
    type       VARCHAR(50) NOT NULL,
    -- type examples: 'booking_request', 'match_found',
    --                'lease_confirmed', 'new_review'
    message    TEXT      NOT NULL,
    is_read    BOOLEAN   DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES USER(user_id)
);

-- ============================================================
--  END OF SCHEMA
--  Next file: queries.sql  (nested + correlated subqueries)
--  Then:      functions.sql, procedures.sql, triggers.sql
-- ============================================================