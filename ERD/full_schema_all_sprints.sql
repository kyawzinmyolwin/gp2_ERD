-- =============================================================================
-- Conservation Group Platform — Full Multi-Sprint Database Schema
-- Covers: Sprint 1 (Required Epic) · Sprint 2 (Location) · Sprint 3 (Inventory)
--         Sprint 4 (Analytics & Records) · Sprint 5 (Donations & Gamification)
--
-- Base: schema_validated.sql (normalisation-validated Sprint 1 schema)
-- Database: PostgreSQL 14+
-- =============================================================================
--
-- NORMALISATION DECISIONS (inherited from schema_validated.sql):
--   N1. emergency_contact extracted from user (3NF fix)
--   N2. conservation_group.slug retained as user-editable (intentional denorm)
--   N3. bait_station_type.allow_custom_text removed (3NF fix)
--   N4. group_id on asset/record tables retained for perf + access-control
--       (intentional denorm, enforced by triggers)
--
-- SPRINT COVERAGE MAP:
--   Section  1  —  System Roles & Auth                     (Sprint 1)
--   Section  2  —  Groups & Membership                     (Sprint 1)
--   Section  3  —  Audit Log                               (Sprint 1)
--   Section  4  —  Lines & Operator Assignments            (Sprint 1)
--   Section  5  —  Reference / Lookup Tables               (Sprint 1)
--   Section  6  —  Assets: Traps & Bait Stations           (Sprint 1)
--   Section  7  —  Field Records & Observations            (Sprint 1)
--   Section  8  —  Location & Map Data                     (Sprint 2)
--   Section  9  —  Inventory Management                    (Sprint 3)
--   Section 10  —  Analytics, Badges & Forecasts           (Sprint 4)
--   Section 11  —  Donations, Sponsorships & Gamification  (Sprint 5)
--   Section 12  —  Triggers (denorm + constraint enforcement)
--   Section 13  —  Indexes
--   Section 14  —  Seed Data
-- =============================================================================


-- =============================================================================
-- DROP ALL TABLES (reverse dependency order)
-- =============================================================================

DROP TABLE IF EXISTS line_sponsorship          CASCADE;
DROP TABLE IF EXISTS mystery_box_item          CASCADE;
DROP TABLE IF EXISTS mystery_box               CASCADE;
DROP TABLE IF EXISTS nz_species                CASCADE;
DROP TABLE IF EXISTS donation_receipt          CASCADE;
DROP TABLE IF EXISTS donation                  CASCADE;
DROP TABLE IF EXISTS donation_type             CASCADE;
DROP TABLE IF EXISTS group_badge               CASCADE;
DROP TABLE IF EXISTS user_badge                CASCADE;
DROP TABLE IF EXISTS badge                     CASCADE;
DROP TABLE IF EXISTS badge_category            CASCADE;
DROP TABLE IF EXISTS forecast_result           CASCADE;
DROP TABLE IF EXISTS bait_stock_transaction    CASCADE;
DROP TABLE IF EXISTS bait_stock                CASCADE;
DROP TABLE IF EXISTS asset_history             CASCADE;
DROP TABLE IF EXISTS storage_area              CASCADE;
DROP TABLE IF EXISTS group_operational_area    CASCADE;
DROP TABLE IF EXISTS incidental_obs            CASCADE;
DROP TABLE IF EXISTS bait_station_record       CASCADE;
DROP TABLE IF EXISTS trap_catch                CASCADE;
DROP TABLE IF EXISTS bait_station              CASCADE;
DROP TABLE IF EXISTS trap                      CASCADE;
DROP TABLE IF EXISTS trap_condition            CASCADE;
DROP TABLE IF EXISTS trap_status               CASCADE;
DROP TABLE IF EXISTS bait_type                 CASCADE;
DROP TABLE IF EXISTS species                   CASCADE;
DROP TABLE IF EXISTS formulation               CASCADE;
DROP TABLE IF EXISTS active_ingredient         CASCADE;
DROP TABLE IF EXISTS target_species            CASCADE;
DROP TABLE IF EXISTS bait_station_type         CASCADE;
DROP TABLE IF EXISTS trap_type                 CASCADE;
DROP TABLE IF EXISTS operator_line             CASCADE;
DROP TABLE IF EXISTS line                      CASCADE;
DROP TABLE IF EXISTS audit_log                 CASCADE;
DROP TABLE IF EXISTS group_join_request        CASCADE;
DROP TABLE IF EXISTS group_membership          CASCADE;
DROP TABLE IF EXISTS group_application         CASCADE;
DROP TABLE IF EXISTS conservation_group        CASCADE;
DROP TABLE IF EXISTS login_otp                 CASCADE;
DROP TABLE IF EXISTS password_reset_token      CASCADE;
DROP TABLE IF EXISTS "user"                    CASCADE;
DROP TABLE IF EXISTS emergency_contact         CASCADE;
DROP TABLE IF EXISTS role                      CASCADE;

DROP FUNCTION IF EXISTS fn_sync_trap_group_id()                    CASCADE;
DROP FUNCTION IF EXISTS fn_sync_bait_station_group_id()            CASCADE;
DROP FUNCTION IF EXISTS fn_sync_trap_catch_group_id()              CASCADE;
DROP FUNCTION IF EXISTS fn_sync_incidental_obs_group_id()          CASCADE;
DROP FUNCTION IF EXISTS fn_sync_bait_station_record_group_id()     CASCADE;
DROP FUNCTION IF EXISTS fn_check_bait_station_custom_text()        CASCADE;
DROP FUNCTION IF EXISTS fn_sync_asset_history_group_id()           CASCADE;
DROP FUNCTION IF EXISTS fn_sync_bait_stock_transaction_group_id()  CASCADE;


-- =============================================================================
-- SECTION 1 — SYSTEM ROLES & AUTH                                   (Sprint 1)
-- =============================================================================

-- System-level roles only. Group-scoped roles live in group_membership.
CREATE TABLE role (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE
    -- values: 'Super Admin', 'Member'
);

-- N1: Emergency contact is an independent entity (3NF fix).
CREATE TABLE emergency_contact (
    id    SERIAL       PRIMARY KEY,
    name  VARCHAR(120) NOT NULL,
    phone VARCHAR(30)  NOT NULL
);

CREATE TABLE "user" (
    id                   SERIAL       PRIMARY KEY,
    username             VARCHAR(100) NOT NULL UNIQUE,
    email                VARCHAR(254) NOT NULL UNIQUE,
    password_hash        VARCHAR(255) NOT NULL,
    first_name           VARCHAR(100) NOT NULL,
    last_name            VARCHAR(100) NOT NULL,
    phone                VARCHAR(30),
    emergency_contact_id INT          REFERENCES emergency_contact(id) ON DELETE SET NULL,
    role_id              INT          NOT NULL REFERENCES role(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Password reset via secure emailed link (US3)
CREATE TABLE password_reset_token (
    id         SERIAL       PRIMARY KEY,
    user_id    INT          NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP    NOT NULL,
    is_used    BOOLEAN      NOT NULL DEFAULT FALSE,
    used_at    TIMESTAMP,
    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6-digit email OTP alternative login (US3)
CREATE TABLE login_otp (
    id         SERIAL       PRIMARY KEY,
    user_id    INT          NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE,
    otp_hash   VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP    NOT NULL,
    is_used    BOOLEAN      NOT NULL DEFAULT FALSE,
    used_at    TIMESTAMP,
    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- =============================================================================
-- SECTION 2 — GROUPS & MEMBERSHIP                                   (Sprint 1)
-- =============================================================================

-- Conservation Group.
-- coordinator_user_id is nullable: group is created first, coordinator appointed after.
-- N2: slug is user-editable (intentional divergence from name allowed).
CREATE TABLE conservation_group (
    id                           SERIAL       PRIMARY KEY,
    name                         VARCHAR(150) NOT NULL UNIQUE,
    slug                         VARCHAR(150) NOT NULL UNIQUE,
    description                  TEXT,
    operational_area_description TEXT,          -- US2: text description of area
    logo_url                     VARCHAR(500),  -- US1: tile image
    region                       VARCHAR(100),  -- US32: region filter
    visibility                   VARCHAR(10)  NOT NULL DEFAULT 'Public'
                                     CHECK (visibility IN ('Public', 'Private')),
    is_active                    BOOLEAN      NOT NULL DEFAULT TRUE,
    coordinator_user_id          INT          REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    created_by                   INT          REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    created_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Group Application — users apply to form a new group (US5, US6)
CREATE TABLE group_application (
    id                  SERIAL       PRIMARY KEY,
    applicant_user_id   INT          NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE,
    proposed_name       VARCHAR(150) NOT NULL,
    description         TEXT         NOT NULL,
    proposed_visibility VARCHAR(10)  NOT NULL DEFAULT 'Public'
                            CHECK (proposed_visibility IN ('Public', 'Private')),
    status              VARCHAR(10)  NOT NULL DEFAULT 'Pending'
                            CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    reviewed_by         INT          REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    reviewed_at         TIMESTAMP,
    rejection_reason    TEXT,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Group Membership — one record per user per group, role is group-scoped (US21)
-- Natural CK: (group_id, user_id). 2NF satisfied: all non-keys depend on full CK.
-- 'Group Coordinator' matches exactly what app stores in session (Issue 10 fix).
CREATE TABLE group_membership (
    id                SERIAL      PRIMARY KEY,
    group_id          INT         NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    user_id           INT         NOT NULL REFERENCES "user"(id)             ON UPDATE CASCADE ON DELETE CASCADE,
    group_role        VARCHAR(30) NOT NULL
                          CHECK (group_role IN ('Observer', 'Operator', 'Group Coordinator')),
    membership_status VARCHAR(20) NOT NULL DEFAULT 'Active'
                          CHECK (membership_status IN ('Active', 'Inactive', 'Suspended')),
    joined_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (group_id, user_id)
);

-- Group Join Request — private group access requests (US20)
-- Partial unique index below: one pending request per user per group.
CREATE TABLE group_join_request (
    id              SERIAL      PRIMARY KEY,
    group_id        INT         NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    user_id         INT         NOT NULL REFERENCES "user"(id)             ON UPDATE CASCADE ON DELETE CASCADE,
    request_status  VARCHAR(10) NOT NULL DEFAULT 'Pending'
                        CHECK (request_status IN ('Pending', 'Approved', 'Rejected')),
    requested_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_by      INT         REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    decided_at      TIMESTAMP,
    decision_reason TEXT
);


-- =============================================================================
-- SECTION 3 — AUDIT LOG                                             (Sprint 1)
-- =============================================================================

-- Append-only event log. group_id added for efficient group-scoped queries (US24).
-- old_value / new_value as TEXT is deliberate generic design.
CREATE TABLE audit_log (
    id            SERIAL      PRIMARY KEY,
    actor_user_id INT         REFERENCES "user"(id)             ON UPDATE CASCADE ON DELETE SET NULL,
    group_id      INT         REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE SET NULL,
    target_type   VARCHAR(60) NOT NULL,   -- e.g. 'user', 'group', 'trap', 'membership'
    target_id     INT,
    action        VARCHAR(60) NOT NULL,   -- e.g. 'create', 'update', 'retire', 'approve'
    old_value     TEXT,
    new_value     TEXT,
    performed_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes         TEXT
);


-- =============================================================================
-- SECTION 4 — LINES & OPERATOR ASSIGNMENTS                          (Sprint 1)
-- =============================================================================

-- Line (Trap Line or Bait Station Line)
-- CK: (group_id, name) — names unique within a group (US7).
-- colour: hex string for map display (US7 fix, Issue 6).
CREATE TABLE line (
    id         SERIAL       PRIMARY KEY,
    group_id   INT          NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    name       VARCHAR(150) NOT NULL,
    line_type  VARCHAR(20)  NOT NULL CHECK (line_type IN ('Trap', 'Bait Station')),
    colour     VARCHAR(7)   NOT NULL DEFAULT '#3d7a2e',   -- hex, e.g. '#3d7a2e'
    is_retired BOOLEAN      NOT NULL DEFAULT FALSE,

    UNIQUE (group_id, name)
);

-- Operator → Line assignment (US9)
-- 2NF: assignment_date depends on the full composite PK, not either FK alone.
CREATE TABLE operator_line (
    operator_id     INT  NOT NULL REFERENCES "user"(id)  ON UPDATE CASCADE ON DELETE CASCADE,
    line_id         INT  NOT NULL REFERENCES line(id)    ON UPDATE CASCADE ON DELETE CASCADE,
    assignment_date DATE NOT NULL DEFAULT CURRENT_DATE,

    PRIMARY KEY (operator_id, line_id)
);


-- =============================================================================
-- SECTION 5 — REFERENCE / LOOKUP TABLES          (Sprint 1, managed by Super Admin US18)
-- All tables: (id PK, name UK) — trivially 1NF–BCNF.
-- =============================================================================

CREATE TABLE trap_type (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

-- N3 fix: allow_custom_text removed. App checks name = 'Other' directly.
-- Trigger enforces custom_type_text IS NOT NULL when type = 'Other'.
CREATE TABLE bait_station_type (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE   -- includes 'Other'
);

-- Bait station record lookups
CREATE TABLE target_species (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE   -- Rats, Mice, Possums, etc.
);

CREATE TABLE active_ingredient (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE   -- Brodifacoum, Cyanide, etc.
);

CREATE TABLE formulation (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE   -- Cereal, Pellet, etc.
);

-- Trap catch lookups
CREATE TABLE species (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE   -- Rat, Mouse, Possum, Stoat, etc.
);

CREATE TABLE bait_type (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE   -- Peanut butter, Egg, Chocolate, etc.
);

CREATE TABLE trap_status (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE    -- Caught, Empty, Sprung, Stolen, etc.
);

CREATE TABLE trap_condition (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE    -- Good, Needs Repair, Destroyed, etc.
);


-- =============================================================================
-- SECTION 6 — ASSETS: TRAPS & BAIT STATIONS                        (Sprint 1)
--
-- N4 (intentional denorm): group_id stored directly on trap and bait_station
-- even though it is derivable via line_id → line.group_id.
-- Rationale: (a) every authenticated request checks group membership — avoiding
-- the extra JOIN on the hottest query path matters at scale; (b) UNIQUE(group_id,
-- code) requires group_id as a direct column.
-- Trigger fn_sync_trap_group_id / fn_sync_bait_station_group_id (Section 12)
-- auto-populates group_id from line on every INSERT/UPDATE, so it cannot drift.
-- =============================================================================

-- Trap (US11 equivalent for traps)
-- display_order: persists drag-and-drop ordering (US10 fix, Issue 9).
-- UNIQUE(group_id, code): codes unique within a group (Issue 8).
CREATE TABLE trap (
    id            SERIAL        PRIMARY KEY,
    code          VARCHAR(20)   NOT NULL,
    trap_type_id  INT           NOT NULL REFERENCES trap_type(id)            ON UPDATE CASCADE ON DELETE RESTRICT,
    group_id      INT           NOT NULL REFERENCES conservation_group(id)   ON UPDATE CASCADE ON DELETE CASCADE,  -- N4 denorm
    line_id       INT           NOT NULL REFERENCES line(id)                 ON UPDATE CASCADE ON DELETE RESTRICT,
    latitude      NUMERIC(10,7) NOT NULL,
    longitude     NUMERIC(10,7) NOT NULL,
    display_order INT           NOT NULL DEFAULT 0,
    is_retired    BOOLEAN       NOT NULL DEFAULT FALSE,

    UNIQUE (group_id, code)
);

-- Bait Station (US11)
-- custom_type_text: required when bait_station_type.name = 'Other' (trigger enforced).
CREATE TABLE bait_station (
    id                   SERIAL        PRIMARY KEY,
    code                 VARCHAR(20)   NOT NULL,
    group_id             INT           NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,  -- N4 denorm
    line_id              INT           NOT NULL REFERENCES line(id)               ON UPDATE CASCADE ON DELETE RESTRICT,
    bait_station_type_id INT           NOT NULL REFERENCES bait_station_type(id)  ON UPDATE CASCADE ON DELETE RESTRICT,
    custom_type_text     VARCHAR(150),  -- required when type = 'Other' (trigger enforced)
    latitude             NUMERIC(10,7) NOT NULL,
    longitude            NUMERIC(10,7) NOT NULL,
    display_order        INT           NOT NULL DEFAULT 0,
    is_retired           BOOLEAN       NOT NULL DEFAULT FALSE,

    UNIQUE (group_id, code)
);


-- =============================================================================
-- SECTION 7 — FIELD RECORDS & OBSERVATIONS                          (Sprint 1)
-- =============================================================================

-- Trap Catch Record (US13-equivalent for traps, from ERD_analysis Issue 1)
-- N4: group_id denorm via trap_id → line_id → group_id. Trigger-enforced.
-- sex / maturity: describe the individual caught animal, not the species — no FD violation.
CREATE TABLE trap_catch (
    id           SERIAL      PRIMARY KEY,
    group_id     INT         NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,  -- N4 denorm
    trap_id      INT         NOT NULL REFERENCES trap(id)               ON UPDATE CASCADE ON DELETE CASCADE,
    date_checked TIMESTAMP   NOT NULL,
    recorded_by  INT         REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    species_id   INT         NOT NULL REFERENCES species(id)      ON UPDATE CASCADE ON DELETE RESTRICT,
    sex          VARCHAR(10) CHECK (sex IN ('Male', 'Female') OR sex IS NULL),
    maturity     VARCHAR(10) CHECK (maturity IN ('Juvenile', 'Adult') OR maturity IS NULL),
    status_id    INT         NOT NULL REFERENCES trap_status(id)   ON UPDATE CASCADE ON DELETE RESTRICT,
    rebaited     BOOLEAN     NOT NULL DEFAULT FALSE,
    bait_type_id INT         NOT NULL REFERENCES bait_type(id)     ON UPDATE CASCADE ON DELETE RESTRICT,
    condition_id INT         NOT NULL REFERENCES trap_condition(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    strikes      INT         NOT NULL DEFAULT 0 CHECK (strikes >= 0),
    notes        TEXT
);

-- Incidental Observation (US14 from ERD_analysis Issue 2)
-- N4: group_id denorm via line_id → group_id. Trigger-enforced.
CREATE TABLE incidental_obs (
    id          SERIAL        PRIMARY KEY,
    group_id    INT           NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,  -- N4 denorm
    operator_id INT           NOT NULL REFERENCES "user"(id)             ON UPDATE CASCADE ON DELETE RESTRICT,
    line_id     INT           NOT NULL REFERENCES line(id)               ON UPDATE CASCADE ON DELETE RESTRICT,
    obs_date    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    obs_type    VARCHAR(60)   NOT NULL
                    CHECK (obs_type IN (
                        'Bird sighting',
                        'Predator track',
                        'Predator sighting',
                        'Native species track or sighting',
                        'Other'
                    )),
    description TEXT,
    latitude    NUMERIC(10,7),
    longitude   NUMERIC(10,7)
);

-- Bait Station Record (US13)
-- N4: group_id denorm via bait_station_id → bait_station.group_id. Trigger-enforced.
-- bait_remaining_kg is an OBSERVED physical measurement, not computed — storing
-- all three kg fields independently is correct (operators count what's physically there).
-- recorded_by NOT NULL: required for ownership-based edit rules (US14).
CREATE TABLE bait_station_record (
    id                   SERIAL        PRIMARY KEY,
    group_id             INT           NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,  -- N4 denorm
    bait_station_id      INT           NOT NULL REFERENCES bait_station(id)       ON UPDATE CASCADE ON DELETE CASCADE,
    recorded_at          TIMESTAMP     NOT NULL,
    recorded_by          INT           NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    target_species_id    INT           NOT NULL REFERENCES target_species(id)     ON UPDATE CASCADE ON DELETE RESTRICT,
    active_ingredient_id INT           NOT NULL REFERENCES active_ingredient(id)  ON UPDATE CASCADE ON DELETE RESTRICT,
    formulation_id       INT           NOT NULL REFERENCES formulation(id)        ON UPDATE CASCADE ON DELETE RESTRICT,
    concentration_pct    NUMERIC(6,3)  NOT NULL CHECK (concentration_pct >= 0 AND concentration_pct <= 100),
    bait_remaining_kg    NUMERIC(8,3)  NOT NULL CHECK (bait_remaining_kg >= 0),
    bait_removed_kg      NUMERIC(8,3)           CHECK (bait_removed_kg  IS NULL OR bait_removed_kg  >= 0),
    bait_added_kg        NUMERIC(8,3)           CHECK (bait_added_kg    IS NULL OR bait_added_kg    >= 0),
    notes                TEXT
);

-- =============================================================================
-- SECTION 8 — LOCATION & MAP DATA                                   (Sprint 2)
--
-- E2US1–E2US3: Group operational area (one polygon per group)
-- E2US4–E2US6: Trap/bait station coordinates (already on asset tables)
-- E2US8: Homepage map shows all group areas
-- Polygon vertices stored as ordered JSON array OR as a companion vertex table.
-- We use a companion vertex table so coordinates are individually queryable
-- and the ordering is explicit.
-- =============================================================================

-- One operational area polygon per group (E2US1, E2US2, E2US3)
-- The boundary is defined as an ordered set of (lat, lng) vertices in
-- group_operational_area_vertex.
CREATE TABLE group_operational_area (
    id         SERIAL    PRIMARY KEY,
    group_id   INT       NOT NULL UNIQUE REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    created_by INT       REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    updated_by INT       REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Ordered polygon vertices. vertex_order determines the polygon drawing sequence.
-- Minimum 3 vertices required (enforced at application level per E2US1 UX rules).
CREATE TABLE group_operational_area_vertex (
    id           SERIAL        PRIMARY KEY,
    area_id      INT           NOT NULL REFERENCES group_operational_area(id) ON UPDATE CASCADE ON DELETE CASCADE,
    vertex_order INT           NOT NULL,   -- 1-based sequence; determines polygon closure order
    latitude     NUMERIC(10,7) NOT NULL,
    longitude    NUMERIC(10,7) NOT NULL,

    UNIQUE (area_id, vertex_order)
);

-- Line path: optional polyline overlay on map (E2US3 — lines displayed as polylines)
-- A line's path is a series of ordered waypoints connecting its assets visually.
-- If no path is defined, Leaflet can auto-connect asset markers in display_order.
CREATE TABLE line_path_vertex (
    id           SERIAL        PRIMARY KEY,
    line_id      INT           NOT NULL REFERENCES line(id) ON UPDATE CASCADE ON DELETE CASCADE,
    vertex_order INT           NOT NULL,
    latitude     NUMERIC(10,7) NOT NULL,
    longitude    NUMERIC(10,7) NOT NULL,

    UNIQUE (line_id, vertex_order)
);


-- =============================================================================
-- SECTION 9 — INVENTORY MANAGEMENT                                  (Sprint 3)
--
-- US35: Storage areas per group
-- US36: View storage contents
-- US37: Add newly purchased assets to inventory
-- US38: Change asset status (deploy, return to storage, send for repair)
-- US39: Retire assets
-- US40: Operator status updates
-- US41: Bait/toxin stock tracking and alerts
-- US42: Full asset history timeline
-- US43: Super Admin cross-group inventory view
-- US44: Map marker colours reflect inventory status
-- US45: Inventory analytics
-- =============================================================================

-- Storage Area (US35)
-- One group can have many named storage areas.
-- CK: (group_id, name) — names unique within a group.
CREATE TABLE storage_area (
    id                   SERIAL       PRIMARY KEY,
    group_id             INT          NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    name                 VARCHAR(150) NOT NULL,
    location_description TEXT,
    latitude             NUMERIC(10,7),   -- optional coordinates for map display (Sprint 2 integration)
    longitude            NUMERIC(10,7),
    is_archived          BOOLEAN      NOT NULL DEFAULT FALSE,
    created_by           INT          REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (group_id, name)
);

-- Asset Status lookup (used by both trap and bait_station inventory records)
-- Values: 'In Storage', 'Active', 'Under Repair', 'Retired'
-- Stored as a lookup table so new statuses can be added without schema changes.
CREATE TABLE asset_status (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE
    -- 'In Storage' | 'Active' | 'Under Repair' | 'Retired'
);

-- Asset Inventory State
-- Tracks the CURRENT state of each trap and bait station in the inventory.
-- This is a separate table from the asset itself so that:
--   (a) the asset table stays focused on physical description
--   (b) status changes can be logged in asset_history without touching the asset row
-- asset_type: 'Trap' or 'Bait Station' — avoids a polymorphic FK to two tables.
-- asset_id: references trap.id OR bait_station.id depending on asset_type.
--   Application enforces referential integrity; PostgreSQL does not support
--   conditional FKs natively. A trigger (Section 12) validates asset_id.
CREATE TABLE asset_inventory (
    id              SERIAL    PRIMARY KEY,
    asset_type      VARCHAR(20) NOT NULL CHECK (asset_type IN ('Trap', 'Bait Station')),
    asset_id        INT         NOT NULL,
    group_id        INT         NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    status_id       INT         NOT NULL REFERENCES asset_status(id)       ON UPDATE CASCADE ON DELETE RESTRICT,
    storage_area_id INT         REFERENCES storage_area(id)                ON UPDATE CASCADE ON DELETE SET NULL,
    -- storage_area_id is populated when status = 'In Storage'; NULL when deployed or under repair
    line_id         INT         REFERENCES line(id)                        ON UPDATE CASCADE ON DELETE SET NULL,
    -- line_id is populated when status = 'Active'; NULL when in storage
    purchase_date   DATE,       -- US37: date of acquisition
    updated_by      INT         REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    updated_at      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- One inventory record per asset
    UNIQUE (asset_type, asset_id)
);

-- Asset History Timeline (US42)
-- Append-only log of every status/location change for an asset.
-- N4 (intentional denorm): group_id stored for efficient group-scoped queries.
-- Trigger fn_sync_asset_history_group_id auto-populates from asset_inventory.
CREATE TABLE asset_history (
    id                  SERIAL      PRIMARY KEY,
    asset_type          VARCHAR(20) NOT NULL CHECK (asset_type IN ('Trap', 'Bait Station')),
    asset_id            INT         NOT NULL,
    group_id            INT         NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,  -- N4 denorm
    action              VARCHAR(50) NOT NULL,
    -- e.g. 'Added to inventory', 'Deployed to line', 'Returned to storage',
    --      'Sent for repair', 'Marked as fixed', 'Retired'
    from_status         VARCHAR(30),
    to_status           VARCHAR(30),
    from_location       VARCHAR(200),   -- descriptive: line name or storage area name
    to_location         VARCHAR(200),
    performed_by        INT         REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    performed_at        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes               TEXT
);

-- Bait Stock (US41)
-- Tracks current stock levels of bait/toxin types per group.
-- One row per (group_id, active_ingredient_id, formulation_id) combination.
CREATE TABLE bait_stock (
    id                   SERIAL       PRIMARY KEY,
    group_id             INT          NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    active_ingredient_id INT          NOT NULL REFERENCES active_ingredient(id)  ON UPDATE CASCADE ON DELETE RESTRICT,
    formulation_id       INT          NOT NULL REFERENCES formulation(id)         ON UPDATE CASCADE ON DELETE RESTRICT,
    current_stock_kg     NUMERIC(10,3) NOT NULL DEFAULT 0 CHECK (current_stock_kg >= 0),
    low_stock_threshold_kg NUMERIC(10,3)         CHECK (low_stock_threshold_kg IS NULL OR low_stock_threshold_kg >= 0),
    -- NULL threshold = no alert configured for this item
    updated_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (group_id, active_ingredient_id, formulation_id)
);

-- Bait Stock Transaction (US41 — stock movement audit trail)
-- Records every addition or removal that changes current_stock_kg.
-- N4: group_id denorm for efficient group queries. Trigger-enforced.
CREATE TABLE bait_stock_transaction (
    id                   SERIAL        PRIMARY KEY,
    bait_stock_id        INT           NOT NULL REFERENCES bait_stock(id) ON UPDATE CASCADE ON DELETE CASCADE,
    group_id             INT           NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,  -- N4 denorm
    transaction_type     VARCHAR(20)   NOT NULL CHECK (transaction_type IN ('Added', 'Removed', 'Adjustment')),
    quantity_kg          NUMERIC(10,3) NOT NULL,   -- positive = added; negative = removed
    stock_after_kg       NUMERIC(10,3) NOT NULL,   -- snapshot of stock level after this transaction
    performed_by         INT           REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    performed_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes                TEXT
);

-- In-system notification for low/out-of-stock alerts (US41)
CREATE TABLE stock_alert (
    id              SERIAL      PRIMARY KEY,
    group_id        INT         NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    bait_stock_id   INT         NOT NULL REFERENCES bait_stock(id)         ON UPDATE CASCADE ON DELETE CASCADE,
    alert_type      VARCHAR(20) NOT NULL CHECK (alert_type IN ('Low', 'Out of Stock')),
    triggered_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_dismissed    BOOLEAN     NOT NULL DEFAULT FALSE,
    dismissed_by    INT         REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    dismissed_at    TIMESTAMP
);

-- =============================================================================
-- SECTION 10 — ANALYTICS, BADGES & FORECASTS                        (Sprint 4)
--
-- US46: 12 months simulated data (seed data only — no new tables needed)
-- US47: Super Admin cross-group analytics dashboard (views/queries, no new tables)
-- US48: Group member analytics dashboard (views/queries, no new tables)
-- US49: AI-generated text summary per chart (stored summaries cached here)
-- US51: Individual and group badges for milestones
-- US52: 30-day pest activity forecast
-- US53: Predicted bait consumption per station
-- US54: Platform-wide pest activity forecast (Super Admin)
-- US55: Plain-language forecast explanation (stored with forecast)
-- =============================================================================

-- Chart Summary Cache (US49)
-- Stores auto-generated text summaries alongside the chart they describe.
-- Keyed by (group_id, chart_type, period_key) so summaries are refreshed per period.
-- NULL group_id = platform-wide summary (Super Admin, US47).
CREATE TABLE chart_summary (
    id           SERIAL       PRIMARY KEY,
    group_id     INT          REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    chart_type   VARCHAR(80)  NOT NULL,
    -- e.g. 'catch_by_species', 'bait_usage_trend', 'activity_by_line', 'platform_overview'
    period_key   VARCHAR(30)  NOT NULL,
    -- e.g. '2025-Q1', '2025-04', 'last_30_days'
    summary_text TEXT         NOT NULL,
    generated_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (group_id, chart_type, period_key)
);

-- Badge Category (US51) — groups badges into themes
CREATE TABLE badge_category (
    id   SERIAL       PRIMARY KEY,
    name VARCHAR(80)  NOT NULL UNIQUE
    -- e.g. 'Catch Milestones', 'Bait Records', 'Consistency', 'Group Achievements'
);

-- Badge Definition (US51)
CREATE TABLE badge (
    id               SERIAL       PRIMARY KEY,
    category_id      INT          NOT NULL REFERENCES badge_category(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    name             VARCHAR(100) NOT NULL UNIQUE,
    description      TEXT         NOT NULL,
    icon_url         VARCHAR(500),
    milestone_value  INT,         -- e.g. 100 (catches), 12 (consecutive months), etc.
    milestone_unit   VARCHAR(50), -- e.g. 'catches', 'bait_records', 'months_active'
    scope            VARCHAR(20)  NOT NULL CHECK (scope IN ('Individual', 'Group')),
    -- Individual = awarded to a user; Group = awarded to a conservation group
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE
);

-- User Badge Award (US51 — individual milestone)
CREATE TABLE user_badge (
    id           SERIAL    PRIMARY KEY,
    user_id      INT       NOT NULL REFERENCES "user"(id)              ON UPDATE CASCADE ON DELETE CASCADE,
    badge_id     INT       NOT NULL REFERENCES badge(id)               ON UPDATE CASCADE ON DELETE CASCADE,
    group_id     INT       REFERENCES conservation_group(id)           ON UPDATE CASCADE ON DELETE SET NULL,
    -- group context in which the badge was earned (NULL for platform-wide badges)
    earned_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_displayed BOOLEAN   NOT NULL DEFAULT TRUE,   -- user can hide badges from profile

    UNIQUE (user_id, badge_id, group_id)
);

-- Group Badge Award (US51 — group milestone)
CREATE TABLE group_badge (
    id        SERIAL    PRIMARY KEY,
    group_id  INT       NOT NULL REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    badge_id  INT       NOT NULL REFERENCES badge(id)              ON UPDATE CASCADE ON DELETE CASCADE,
    earned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (group_id, badge_id)
);

-- Forecast Result (US52, US53, US54, US55)
-- Stores computed forecast outputs so they can be served without re-computation.
-- NULL group_id = platform-wide forecast (US54).
-- forecast_type distinguishes between pest activity and bait consumption forecasts.
CREATE TABLE forecast_result (
    id                SERIAL       PRIMARY KEY,
    group_id          INT          REFERENCES conservation_group(id) ON UPDATE CASCADE ON DELETE CASCADE,
    -- NULL = platform-wide (Super Admin, US54)
    asset_id          INT,         -- NULL = group-level forecast; populated for per-station (US53)
    asset_type        VARCHAR(20)  CHECK (asset_type IN ('Trap', 'Bait Station') OR asset_type IS NULL),
    forecast_type     VARCHAR(40)  NOT NULL
                          CHECK (forecast_type IN ('Pest Activity', 'Bait Consumption')),
    forecast_period   VARCHAR(30)  NOT NULL,   -- e.g. '2025-05-01_to_2025-05-30'
    forecast_data     JSONB        NOT NULL,   -- daily predicted values as JSON array
    explanation_text  TEXT,                   -- US55: plain-language explanation
    generated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- =============================================================================
-- SECTION 11 — DONATIONS, SPONSORSHIPS & GAMIFICATION               (Sprint 5)
--
-- US56: Quick donation with amount selector
-- US57: Donor contact details, anonymous option
-- US58: Stripe checkout integration (webhook events stored)
-- US59: Tax receipt eligibility by group charitable status
-- US60: Receipt generation and resend
-- US61: Donation links on public group pages and nav
-- US62: Group Coordinator donation summary
-- US63: Super Admin cross-group donation management
-- US64: Line sponsorship — donor name on line detail page
-- US65: Mystery box reveal — species draws based on donation amount
-- US66: Browse lines by native species (GBIF data)
-- US67: Monthly line sponsorship subscription
-- US68: Manage sponsorship (pause, cancel, resume)
-- =============================================================================

-- Donation Type lookup (US56, US62, US63)
-- Values: 'Group Donation', 'General Support', 'Platform Support'
CREATE TABLE donation_type (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- Donation (US56, US57, US58)
-- Records every completed donation transaction.
-- group_id: NULL for General Support or Platform Support donations.
-- stripe_payment_intent_id: stored for webhook reconciliation (US58).
-- is_anonymous: when TRUE, donor_name is not surfaced in any UI (US57).
CREATE TABLE donation (
    id                       SERIAL        PRIMARY KEY,
    donation_type_id         INT           NOT NULL REFERENCES donation_type(id)        ON UPDATE CASCADE ON DELETE RESTRICT,
    group_id                 INT           REFERENCES conservation_group(id)            ON UPDATE CASCADE ON DELETE SET NULL,
    user_id                  INT           REFERENCES "user"(id)                        ON UPDATE CASCADE ON DELETE SET NULL,
    -- NULL if donor is not a registered user (guest checkout)
    donor_name               VARCHAR(200),   -- required for tax receipt; NULL if anonymous
    donor_email              VARCHAR(254),   -- for receipt delivery
    support_message          TEXT,
    amount_nzd               NUMERIC(10,2) NOT NULL CHECK (amount_nzd > 0),
    is_anonymous             BOOLEAN       NOT NULL DEFAULT FALSE,
    is_recurring             BOOLEAN       NOT NULL DEFAULT FALSE,
    stripe_payment_intent_id VARCHAR(255)  UNIQUE,   -- Stripe pi_xxx or sub_xxx
    stripe_subscription_id   VARCHAR(255)  UNIQUE,   -- populated for recurring donations
    payment_status           VARCHAR(20)   NOT NULL DEFAULT 'Pending'
                                 CHECK (payment_status IN ('Pending', 'Completed', 'Failed', 'Refunded')),
    donated_at               TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Donation Receipt (US59, US60)
-- One receipt per completed non-anonymous donation.
-- is_tax_eligible: determined by group's charitable_status (see conservation_group extension below).
CREATE TABLE donation_receipt (
    id                   SERIAL       PRIMARY KEY,
    donation_id          INT          NOT NULL UNIQUE REFERENCES donation(id) ON UPDATE CASCADE ON DELETE CASCADE,
    receipt_number       VARCHAR(50)  NOT NULL UNIQUE,   -- human-readable, e.g. 'RCP-2025-001234'
    is_tax_eligible      BOOLEAN      NOT NULL DEFAULT FALSE,
    charity_name         VARCHAR(200),
    charity_reg_number   VARCHAR(50),
    receipt_pdf_url      VARCHAR(500),   -- stored PDF path/URL (US60 download)
    sent_to_email        VARCHAR(254),
    sent_at              TIMESTAMP,
    generated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Line Sponsorship (US64, US67, US68)
-- Records active and historical sponsorships of a specific line.
-- status lifecycle: 'Active' → 'Paused' → 'Active' | 'Cancelled'
CREATE TABLE line_sponsorship (
    id                     SERIAL        PRIMARY KEY,
    line_id                INT           NOT NULL REFERENCES line(id)    ON UPDATE CASCADE ON DELETE CASCADE,
    donation_id            INT           NOT NULL REFERENCES donation(id) ON UPDATE CASCADE ON DELETE CASCADE,
    user_id                INT           REFERENCES "user"(id)           ON UPDATE CASCADE ON DELETE SET NULL,
    sponsor_display_name   VARCHAR(200),   -- name shown on line detail page (US64); NULL if anonymous
    status                 VARCHAR(20)   NOT NULL DEFAULT 'Active'
                               CHECK (status IN ('Active', 'Paused', 'Cancelled')),
    monthly_amount_nzd     NUMERIC(10,2) NOT NULL CHECK (monthly_amount_nzd > 0),
    stripe_subscription_id VARCHAR(255),
    started_at             TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paused_at              TIMESTAMP,
    cancelled_at           TIMESTAMP,
    next_payment_at        TIMESTAMP     -- Stripe next billing cycle
);

-- NZ Species (US65, US66)
-- Stores species data sourced from GBIF for the mystery box draw and line browsing.
-- Updated periodically via GBIF API calls (application-level job).
-- iucn_status: determines mystery box rarity tier.
CREATE TABLE nz_species (
    id           SERIAL       PRIMARY KEY,
    gbif_id      INT          UNIQUE,    -- GBIF taxon key for attribution
    common_name  VARCHAR(200) NOT NULL,
    scientific_name VARCHAR(200),
    iucn_status  VARCHAR(5)   NOT NULL
                     CHECK (iucn_status IN ('LC', 'NT', 'VU', 'EN', 'CR')),
    -- LC=Least Concern, NT=Near Threatened, VU=Vulnerable, EN=Endangered, CR=Critically Endangered
    image_url    VARCHAR(500),
    description  TEXT,
    -- Geographic bounding box: used to filter species by group's operational area (US65)
    min_latitude  NUMERIC(10,7),
    max_latitude  NUMERIC(10,7),
    min_longitude NUMERIC(10,7),
    max_longitude NUMERIC(10,7),
    gbif_fetched_at TIMESTAMP   -- last time this record was refreshed from GBIF
);

-- Mystery Box Session (US65)
-- Created when a supporter completes a donation and is directed to the reveal page.
-- box_count: computed from donation amount (every $5 = 1 box; bonuses for $100+, $200+).
CREATE TABLE mystery_box (
    id            SERIAL        PRIMARY KEY,
    donation_id   INT           NOT NULL REFERENCES donation(id) ON UPDATE CASCADE ON DELETE CASCADE,
    user_id       INT           REFERENCES "user"(id)            ON UPDATE CASCADE ON DELETE SET NULL,
    box_count     INT           NOT NULL CHECK (box_count >= 1),
    opened_count  INT           NOT NULL DEFAULT 0,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Mystery Box Item (US65)
-- One row per box in a session. species_id populated on open (not pre-drawn).
-- is_bonus: TRUE for guaranteed EN/CR bonus boxes ($100+/$200+ donations).
CREATE TABLE mystery_box_item (
    id          SERIAL      PRIMARY KEY,
    box_id      INT         NOT NULL REFERENCES mystery_box(id)  ON UPDATE CASCADE ON DELETE CASCADE,
    item_order  INT         NOT NULL,   -- 1-based sequence within the session
    species_id  INT         REFERENCES nz_species(id) ON UPDATE CASCADE ON DELETE SET NULL,
    -- NULL until the box is actually opened
    is_bonus    BOOLEAN     NOT NULL DEFAULT FALSE,
    bonus_tier  VARCHAR(5)  CHECK (bonus_tier IN ('EN', 'CR') OR bonus_tier IS NULL),
    opened_at   TIMESTAMP,   -- NULL until opened

    UNIQUE (box_id, item_order)
);

-- User Species Collection (US65 — "growing collection shown after each reveal")
-- Tracks every distinct species a user has collected across all donations.
CREATE TABLE user_species_collection (
    id          SERIAL    PRIMARY KEY,
    user_id     INT       NOT NULL REFERENCES "user"(id)       ON UPDATE CASCADE ON DELETE CASCADE,
    species_id  INT       NOT NULL REFERENCES nz_species(id)   ON UPDATE CASCADE ON DELETE CASCADE,
    first_collected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    collect_count      INT       NOT NULL DEFAULT 1,   -- how many times drawn

    UNIQUE (user_id, species_id)
);

-- Stripe Webhook Event Log (US58 — reconciliation and debugging)
-- Stores raw webhook payloads before processing so events can be replayed.
CREATE TABLE stripe_webhook_event (
    id              SERIAL      PRIMARY KEY,
    stripe_event_id VARCHAR(255) NOT NULL UNIQUE,   -- Stripe evt_xxx
    event_type      VARCHAR(100) NOT NULL,
    payload         JSONB        NOT NULL,
    processed       BOOLEAN      NOT NULL DEFAULT FALSE,
    processed_at    TIMESTAMP,
    error_message   TEXT,
    received_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Conservation Group — additional columns needed for Sprint 5
-- (Added via ALTER to keep section grouping clean and not modify the original table definition)
ALTER TABLE conservation_group
    ADD COLUMN IF NOT EXISTS is_registered_charity BOOLEAN  NOT NULL DEFAULT FALSE,
    -- US59: determines tax receipt eligibility
    ADD COLUMN IF NOT EXISTS charity_reg_number    VARCHAR(50),
    ADD COLUMN IF NOT EXISTS total_donations_nzd   NUMERIC(12,2) NOT NULL DEFAULT 0;
    -- US61: displayed on public group page; updated on each completed donation


-- =============================================================================
-- SECTION 12 — TRIGGERS (denorm enforcement & constraint validation)
-- =============================================================================

-- N4: Auto-populate trap.group_id from line.group_id on INSERT/UPDATE
CREATE OR REPLACE FUNCTION fn_sync_trap_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id FROM line WHERE id = NEW.line_id;
    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'trap.line_id % does not resolve to a valid group', NEW.line_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_trap_group_id_sync
    BEFORE INSERT OR UPDATE OF line_id ON trap
    FOR EACH ROW EXECUTE FUNCTION fn_sync_trap_group_id();


-- N4: Auto-populate bait_station.group_id from line.group_id
CREATE OR REPLACE FUNCTION fn_sync_bait_station_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id FROM line WHERE id = NEW.line_id;
    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'bait_station.line_id % does not resolve to a valid group', NEW.line_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bait_station_group_id_sync
    BEFORE INSERT OR UPDATE OF line_id ON bait_station
    FOR EACH ROW EXECUTE FUNCTION fn_sync_bait_station_group_id();


-- N4: Auto-populate trap_catch.group_id from trap.group_id
CREATE OR REPLACE FUNCTION fn_sync_trap_catch_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id FROM trap WHERE id = NEW.trap_id;
    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'trap_catch.trap_id % does not resolve to a valid group', NEW.trap_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_trap_catch_group_id_sync
    BEFORE INSERT OR UPDATE OF trap_id ON trap_catch
    FOR EACH ROW EXECUTE FUNCTION fn_sync_trap_catch_group_id();


-- N4: Auto-populate incidental_obs.group_id from line.group_id
CREATE OR REPLACE FUNCTION fn_sync_incidental_obs_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id FROM line WHERE id = NEW.line_id;
    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'incidental_obs.line_id % does not resolve to a valid group', NEW.line_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_incidental_obs_group_id_sync
    BEFORE INSERT OR UPDATE OF line_id ON incidental_obs
    FOR EACH ROW EXECUTE FUNCTION fn_sync_incidental_obs_group_id();


-- N4: Auto-populate bait_station_record.group_id from bait_station.group_id
CREATE OR REPLACE FUNCTION fn_sync_bait_station_record_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id FROM bait_station WHERE id = NEW.bait_station_id;
    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'bait_station_record.bait_station_id % does not resolve to a valid group', NEW.bait_station_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bait_station_record_group_id_sync
    BEFORE INSERT OR UPDATE OF bait_station_id ON bait_station_record
    FOR EACH ROW EXECUTE FUNCTION fn_sync_bait_station_record_group_id();


-- N4: Auto-populate asset_history.group_id from asset_inventory.group_id
CREATE OR REPLACE FUNCTION fn_sync_asset_history_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id
    FROM asset_inventory
    WHERE asset_type = NEW.asset_type AND asset_id = NEW.asset_id
    LIMIT 1;
    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'asset_history: no inventory record found for % id %', NEW.asset_type, NEW.asset_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_asset_history_group_id_sync
    BEFORE INSERT ON asset_history
    FOR EACH ROW EXECUTE FUNCTION fn_sync_asset_history_group_id();


-- N4: Auto-populate bait_stock_transaction.group_id from bait_stock.group_id
CREATE OR REPLACE FUNCTION fn_sync_bait_stock_transaction_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id FROM bait_stock WHERE id = NEW.bait_stock_id;
    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'bait_stock_transaction.bait_stock_id % does not resolve to a valid group', NEW.bait_stock_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bait_stock_transaction_group_id_sync
    BEFORE INSERT ON bait_stock_transaction
    FOR EACH ROW EXECUTE FUNCTION fn_sync_bait_stock_transaction_group_id();


-- N3: Enforce custom_type_text IS NOT NULL when bait_station_type.name = 'Other'
CREATE OR REPLACE FUNCTION fn_check_bait_station_custom_text()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_type_name VARCHAR(100);
BEGIN
    SELECT name INTO v_type_name FROM bait_station_type WHERE id = NEW.bait_station_type_id;
    IF v_type_name = 'Other' AND (NEW.custom_type_text IS NULL OR TRIM(NEW.custom_type_text) = '') THEN
        RAISE EXCEPTION 'custom_type_text is required when bait station type is Other';
    END IF;
    -- Clear custom text when type is not 'Other' to prevent orphaned data
    IF v_type_name != 'Other' THEN
        NEW.custom_type_text := NULL;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bait_station_custom_text
    BEFORE INSERT OR UPDATE OF bait_station_type_id, custom_type_text ON bait_station
    FOR EACH ROW EXECUTE FUNCTION fn_check_bait_station_custom_text();


-- Partial unique index: one PENDING join request per user per group (Issue 4)
CREATE UNIQUE INDEX idx_one_pending_join_request
    ON group_join_request (group_id, user_id)
    WHERE request_status = 'Pending';


-- =============================================================================
-- SECTION 13 — INDEXES
-- =============================================================================

-- Auth (partial: only index unused tokens — the common lookup case)
CREATE INDEX idx_password_reset_token_user  ON password_reset_token(user_id) WHERE NOT is_used;
CREATE INDEX idx_login_otp_user             ON login_otp(user_id)            WHERE NOT is_used;

-- User
CREATE INDEX idx_user_role_id               ON "user"(role_id);

-- Group visibility (homepage filter, US1)
CREATE INDEX idx_conservation_group_vis     ON conservation_group(visibility);
CREATE INDEX idx_conservation_group_region  ON conservation_group(region);

-- Membership — hit on every authenticated request
CREATE INDEX idx_group_membership_user      ON group_membership(user_id);
CREATE INDEX idx_group_membership_group     ON group_membership(group_id);

-- Join requests
CREATE INDEX idx_group_join_request_group   ON group_join_request(group_id);
CREATE INDEX idx_group_join_request_user    ON group_join_request(user_id);

-- Lines
CREATE INDEX idx_line_group_id              ON line(group_id);
CREATE INDEX idx_line_type                  ON line(line_type);

-- Operator assignments
CREATE INDEX idx_operator_line_line_id      ON operator_line(line_id);

-- Assets
CREATE INDEX idx_trap_group_line            ON trap(group_id, line_id);
CREATE INDEX idx_trap_line_display_order    ON trap(line_id, display_order);
CREATE INDEX idx_bait_station_group_line    ON bait_station(group_id, line_id);
CREATE INDEX idx_bait_station_display_order ON bait_station(line_id, display_order);

-- Trap catches (analytics queries: filter by date, species, group)
CREATE INDEX idx_trap_catch_trap            ON trap_catch(trap_id);
CREATE INDEX idx_trap_catch_group           ON trap_catch(group_id);
CREATE INDEX idx_trap_catch_date            ON trap_catch(date_checked);
CREATE INDEX idx_trap_catch_species         ON trap_catch(species_id);

-- Bait station records
CREATE INDEX idx_bait_station_record_bs     ON bait_station_record(bait_station_id);
CREATE INDEX idx_bait_station_record_group  ON bait_station_record(group_id);
CREATE INDEX idx_bait_station_record_date   ON bait_station_record(recorded_at);

-- Incidental observations
CREATE INDEX idx_incidental_obs_group       ON incidental_obs(group_id);
CREATE INDEX idx_incidental_obs_line        ON incidental_obs(line_id);

-- Audit log
CREATE INDEX idx_audit_log_actor            ON audit_log(actor_user_id);
CREATE INDEX idx_audit_log_group            ON audit_log(group_id);
CREATE INDEX idx_audit_log_performed_at     ON audit_log(performed_at);

-- Map / location
CREATE INDEX idx_group_op_area_group        ON group_operational_area(group_id);

-- Inventory
CREATE INDEX idx_asset_inventory_group      ON asset_inventory(group_id);
CREATE INDEX idx_asset_inventory_asset      ON asset_inventory(asset_type, asset_id);
CREATE INDEX idx_asset_inventory_status     ON asset_inventory(status_id);
CREATE INDEX idx_asset_inventory_storage    ON asset_inventory(storage_area_id);
CREATE INDEX idx_asset_history_asset        ON asset_history(asset_type, asset_id);
CREATE INDEX idx_asset_history_group        ON asset_history(group_id);
CREATE INDEX idx_asset_history_at           ON asset_history(performed_at);
CREATE INDEX idx_storage_area_group         ON storage_area(group_id);
CREATE INDEX idx_bait_stock_group           ON bait_stock(group_id);
CREATE INDEX idx_bait_stock_tx_stock        ON bait_stock_transaction(bait_stock_id);
CREATE INDEX idx_stock_alert_group          ON stock_alert(group_id) WHERE NOT is_dismissed;

-- Donations
CREATE INDEX idx_donation_group             ON donation(group_id);
CREATE INDEX idx_donation_user              ON donation(user_id);
CREATE INDEX idx_donation_status            ON donation(payment_status);
CREATE INDEX idx_donation_at                ON donation(donated_at);
CREATE INDEX idx_line_sponsorship_line      ON line_sponsorship(line_id);
CREATE INDEX idx_line_sponsorship_status    ON line_sponsorship(status);
CREATE INDEX idx_mystery_box_donation       ON mystery_box(donation_id);
CREATE INDEX idx_mystery_box_item_box       ON mystery_box_item(box_id);
CREATE INDEX idx_user_species_user          ON user_species_collection(user_id);
CREATE INDEX idx_stripe_webhook_processed   ON stripe_webhook_event(processed) WHERE NOT processed;

-- Analytics / forecasts
CREATE INDEX idx_forecast_group             ON forecast_result(group_id);
CREATE INDEX idx_forecast_type_period       ON forecast_result(forecast_type, forecast_period);
CREATE INDEX idx_chart_summary_group_type   ON chart_summary(group_id, chart_type);

-- Badges
CREATE INDEX idx_user_badge_user            ON user_badge(user_id);
CREATE INDEX idx_group_badge_group          ON group_badge(group_id);

-- NZ Species
CREATE INDEX idx_nz_species_iucn            ON nz_species(iucn_status);


-- =============================================================================
-- SECTION 14 — SEED DATA
-- =============================================================================

-- System roles
INSERT INTO role (name) VALUES ('Super Admin'), ('Member');

-- Asset statuses (Sprint 3 inventory lifecycle)
INSERT INTO asset_status (name) VALUES
    ('In Storage'),
    ('Active'),
    ('Under Repair'),
    ('Retired');

-- Donation types (Sprint 5)
INSERT INTO donation_type (name) VALUES
    ('Group Donation'),
    ('General Support'),
    ('Platform Support');

-- Badge categories (Sprint 4)
INSERT INTO badge_category (name) VALUES
    ('Catch Milestones'),
    ('Bait Records'),
    ('Consistency'),
    ('Group Achievements'),
    ('Community');

-- Trap statuses (common field values)
INSERT INTO trap_status (name) VALUES
    ('Caught'),
    ('Empty'),
    ('Sprung - No Catch'),
    ('Stolen'),
    ('Destroyed'),
    ('Not Checked');

-- Trap conditions
INSERT INTO trap_condition (name) VALUES
    ('Good'),
    ('Needs Repair'),
    ('Destroyed');

-- Common NZ predator species (trap catch)
INSERT INTO species (name) VALUES
    ('Rat'),
    ('Mouse'),
    ('Possum'),
    ('Stoat'),
    ('Ferret'),
    ('Weasel'),
    ('Hedgehog'),
    ('Cat'),
    ('Other');

-- Common bait types
INSERT INTO bait_type (name) VALUES
    ('Peanut Butter'),
    ('Egg'),
    ('Chocolate'),
    ('Rabbit'),
    ('Fresh Meat'),
    ('Lure'),
    ('None'),
    ('Other');

-- Common active ingredients
INSERT INTO active_ingredient (name) VALUES
    ('Brodifacoum'),
    ('Bromadiolone'),
    ('Diphacinone'),
    ('Pindone'),
    ('Sodium Fluoroacetate (1080)'),
    ('Cyanide (SSOC)'),
    ('Zinc Phosphide'),
    ('Cholecalciferol');

-- Common formulations
INSERT INTO formulation (name) VALUES
    ('Cereal Bait'),
    ('Pellet'),
    ('Paste'),
    ('Wax Block'),
    ('Gel'),
    ('Grain');

-- Common target species (bait station records)
INSERT INTO target_species (name) VALUES
    ('Rats'),
    ('Mice'),
    ('Possums'),
    ('Stoats'),
    ('All Mustelids'),
    ('All Rodents');

-- Bait station type 'Other' must exist so the custom_type_text trigger has a target
INSERT INTO bait_station_type (name) VALUES
    ('Peranode'),
    ('Goodnature A24'),
    ('DOC 150'),
    ('DOC 200'),
    ('Sentinel'),
    ('Protecta LP'),
    ('Protecta Sidekick'),
    ('Philproof'),
    ('Philproof Miniphi'),
    ('Ratabout'),
    ('Tomahawk'),
    ('Hexagonal'),
    ('Round'),
    ('Square'),
    ('Triangular'),
    ('Other');
