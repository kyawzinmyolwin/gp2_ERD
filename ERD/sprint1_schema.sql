-- =============================================================================
-- Conservation Group Platform — Complete Database Schema
-- Based on Sprint 1 ERD Draft with all fixes from ERD_analysis.md applied
-- =============================================================================
-- Fix summary applied:
--   🔴 Issue 1:  Added trap_catch table (and species, bait_type, trap_status, trap_condition)
--   🔴 Issue 2:  Added incidental_obs table
--   🔴 Issue 3:  Added UNIQUE(group_id, user_id) on group_membership
--   🔴 Issue 4:  Added partial unique index on group_join_request (one pending per user/group)
--   🔴 Issue 5:  Made conservation_group.coordinator_user_id nullable (circular FK fix)
--   🟡 Issue 6:  Added colour column to line
--   🟡 Issue 7:  Added UNIQUE(group_id, name) on line
--   🟡 Issue 8:  Added UNIQUE(group_id, code) on bait_station (and trap)
--   🟡 Issue 9:  Added display_order on trap and bait_station
--   🟡 Issue 10: Fixed group_role CHECK to use 'Group Coordinator'
--   🟠 Issue 11: Application-level note on line_type enforcement
--   🟠 Issue 12: Added is_used boolean on login_otp and password_reset_token
--   🟠 Issue 13: Added group_id on audit_log
--   🟠 Issue 14: Made bait_station_record.recorded_by NOT NULL
-- =============================================================================


-- -----------------------------------------------------------------------------
-- SYSTEM-LEVEL ROLES
-- Super Admin is system-level; group-scoped roles live in group_membership
-- -----------------------------------------------------------------------------

CREATE TABLE role (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE  -- 'Super Admin' or 'Member'
);


-- -----------------------------------------------------------------------------
-- USERS
-- -----------------------------------------------------------------------------

CREATE TABLE "user" (
    id                       SERIAL       PRIMARY KEY,
    username                 VARCHAR(60)  NOT NULL UNIQUE,
    email                    VARCHAR(254) NOT NULL UNIQUE,
    password_hash            VARCHAR(255) NOT NULL,
    first_name               VARCHAR(60)  NOT NULL,
    last_name                VARCHAR(60)  NOT NULL,
    phone                    VARCHAR(30),
    emergency_contact_name   VARCHAR(120),
    emergency_contact_phone  VARCHAR(30),
    role_id                  INT          NOT NULL REFERENCES role(id),
    is_active                BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at               TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- -----------------------------------------------------------------------------
-- AUTHENTICATION TOKENS
-- Fix Issue 12: added is_used boolean for fast index queries
-- -----------------------------------------------------------------------------

CREATE TABLE password_reset_token (
    id         SERIAL      PRIMARY KEY,
    user_id    INT         NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP   NOT NULL,
    is_used    BOOLEAN     NOT NULL DEFAULT FALSE,  -- Issue 12
    used_at    TIMESTAMP,
    created_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE login_otp (
    id         SERIAL      PRIMARY KEY,
    user_id    INT         NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    otp_hash   VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP   NOT NULL,
    is_used    BOOLEAN     NOT NULL DEFAULT FALSE,  -- Issue 12
    used_at    TIMESTAMP,
    created_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- -----------------------------------------------------------------------------
-- CONSERVATION GROUPS
-- Fix Issue 5: coordinator_user_id is nullable — group is created first,
--              coordinator appointed afterward (avoids circular FK deadlock)
-- -----------------------------------------------------------------------------

CREATE TABLE conservation_group (
    id                          SERIAL       PRIMARY KEY,
    name                        VARCHAR(120) NOT NULL UNIQUE,
    slug                        VARCHAR(120) NOT NULL UNIQUE,
    description                 TEXT,
    operational_area_description TEXT,
    logo_url                    VARCHAR(500),
    region                      VARCHAR(100),
    visibility                  VARCHAR(10)  NOT NULL DEFAULT 'Public'
                                    CHECK (visibility IN ('Public', 'Private')),
    is_active                   BOOLEAN      NOT NULL DEFAULT TRUE,
    coordinator_user_id         INT          REFERENCES "user"(id),  -- Issue 5: nullable
    created_by                  INT          NOT NULL REFERENCES "user"(id),
    created_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- -----------------------------------------------------------------------------
-- GROUP APPLICATIONS (users applying to form a new group)
-- -----------------------------------------------------------------------------

CREATE TABLE group_application (
    id                   SERIAL      PRIMARY KEY,
    applicant_user_id    INT         NOT NULL REFERENCES "user"(id),
    proposed_name        VARCHAR(120) NOT NULL,
    description          TEXT        NOT NULL,
    proposed_visibility  VARCHAR(10) NOT NULL DEFAULT 'Public'
                             CHECK (proposed_visibility IN ('Public', 'Private')),
    status               VARCHAR(10) NOT NULL DEFAULT 'Pending'
                             CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    reviewed_by          INT         REFERENCES "user"(id),
    reviewed_at          TIMESTAMP,
    rejection_reason     TEXT,
    created_at           TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- -----------------------------------------------------------------------------
-- GROUP MEMBERSHIP
-- Fix Issue 3: UNIQUE(group_id, user_id) — one record per user per group
-- Fix Issue 10: group_role uses 'Group Coordinator' (two words, matches roles)
-- -----------------------------------------------------------------------------

CREATE TABLE group_membership (
    id                SERIAL      PRIMARY KEY,
    group_id          INT         NOT NULL REFERENCES conservation_group(id),
    user_id           INT         NOT NULL REFERENCES "user"(id),
    group_role        VARCHAR(30) NOT NULL
                          CHECK (group_role IN ('Observer', 'Operator', 'Group Coordinator')),  -- Issue 10
    membership_status VARCHAR(20) NOT NULL DEFAULT 'Active'
                          CHECK (membership_status IN ('Active', 'Inactive', 'Suspended')),
    joined_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (group_id, user_id)  -- Issue 3
);


-- -----------------------------------------------------------------------------
-- GROUP JOIN REQUESTS (for Private groups)
-- Fix Issue 4: partial unique index added below (one pending request per user/group)
-- -----------------------------------------------------------------------------

CREATE TABLE group_join_request (
    id             SERIAL      PRIMARY KEY,
    group_id       INT         NOT NULL REFERENCES conservation_group(id),
    user_id        INT         NOT NULL REFERENCES "user"(id),
    request_status VARCHAR(10) NOT NULL DEFAULT 'Pending'
                       CHECK (request_status IN ('Pending', 'Approved', 'Rejected')),
    requested_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_by     INT         REFERENCES "user"(id),
    decided_at     TIMESTAMP,
    decision_reason TEXT
);

-- Issue 4: only one pending request allowed per user per group
CREATE UNIQUE INDEX idx_one_pending_join_request
    ON group_join_request (group_id, user_id)
    WHERE request_status = 'Pending';


-- -----------------------------------------------------------------------------
-- AUDIT LOG
-- Fix Issue 13: added group_id for efficient group-scoped audit queries
-- -----------------------------------------------------------------------------

CREATE TABLE audit_log (
    id            SERIAL       PRIMARY KEY,
    actor_user_id INT          REFERENCES "user"(id),
    group_id      INT          REFERENCES conservation_group(id),  -- Issue 13
    target_type   VARCHAR(60)  NOT NULL,
    target_id     INT,
    action        VARCHAR(60)  NOT NULL,
    old_value     TEXT,
    new_value     TEXT,
    performed_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes         TEXT
);


-- -----------------------------------------------------------------------------
-- LINES (Trap Lines and Bait Station Lines)
-- Fix Issue 6: added colour column
-- Fix Issue 7: added UNIQUE(group_id, name)
-- -----------------------------------------------------------------------------

CREATE TABLE line (
    id         SERIAL      PRIMARY KEY,
    group_id   INT         NOT NULL REFERENCES conservation_group(id),
    name       VARCHAR(120) NOT NULL,
    line_type  VARCHAR(20) NOT NULL
                   CHECK (line_type IN ('Trap', 'Bait Station')),
    colour     VARCHAR(7)  NOT NULL DEFAULT '#3d7a2e',  -- Issue 6: hex colour for map display
    is_retired BOOLEAN     NOT NULL DEFAULT FALSE,

    UNIQUE (group_id, name)  -- Issue 7
);


-- -----------------------------------------------------------------------------
-- OPERATOR-LINE ASSIGNMENTS
-- -----------------------------------------------------------------------------

CREATE TABLE operator_line (
    operator_id     INT  NOT NULL REFERENCES "user"(id),
    line_id         INT  NOT NULL REFERENCES line(id),
    assignment_date DATE NOT NULL DEFAULT CURRENT_DATE,

    PRIMARY KEY (operator_id, line_id)
);


-- =============================================================================
-- REFERENCE / LOOKUP TABLES (managed by Super Admin)
-- =============================================================================

CREATE TABLE trap_type (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE bait_station_type (
    id                SERIAL      PRIMARY KEY,
    name              VARCHAR(80) NOT NULL UNIQUE,  -- 23 PDF types plus 'Other'
    allow_custom_text BOOLEAN     NOT NULL DEFAULT FALSE  -- TRUE only for 'Other'
);

CREATE TABLE target_species (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE  -- Rats, Mice, Possums, etc.
);

CREATE TABLE active_ingredient (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE  -- Brodifacoum, Cyanide, etc.
);

CREATE TABLE formulation (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE  -- Cereal, Pellet, etc.
);

-- Issue 1: lookup tables required by trap_catch (previously missing entirely)
CREATE TABLE species (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE  -- Rat, Mouse, Possum, Stoat, etc.
);

CREATE TABLE bait_type (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE  -- Peanut butter, Egg, etc.
);

CREATE TABLE trap_status (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE  -- Caught, Empty, Sprung, Stolen, etc.
);

CREATE TABLE trap_condition (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE  -- Good, Needs Repair, etc.
);


-- =============================================================================
-- TRAPS
-- Fix Issue 8: added UNIQUE(group_id, code)
-- Fix Issue 9: added display_order for drag-and-drop ordering
-- Note Issue 11: line_type='Trap' enforcement is an application-level constraint
-- =============================================================================

CREATE TABLE trap (
    id             SERIAL        PRIMARY KEY,
    code           VARCHAR(20)   NOT NULL,
    trap_type_id   INT           NOT NULL REFERENCES trap_type(id),
    group_id       INT           NOT NULL REFERENCES conservation_group(id),
    line_id        INT           NOT NULL REFERENCES line(id),
    latitude       NUMERIC(10,6) NOT NULL,
    longitude      NUMERIC(10,6) NOT NULL,
    display_order  INT           NOT NULL DEFAULT 0,  -- Issue 9
    is_retired     BOOLEAN       NOT NULL DEFAULT FALSE,

    UNIQUE (group_id, code)  -- Issue 8
);


-- =============================================================================
-- BAIT STATIONS
-- Fix Issue 8: added UNIQUE(group_id, code)
-- Fix Issue 9: added display_order for drag-and-drop ordering
-- Note Issue 11: line_type='Bait Station' enforcement is an application-level constraint
-- =============================================================================

CREATE TABLE bait_station (
    id                   SERIAL        PRIMARY KEY,
    code                 VARCHAR(20)   NOT NULL,
    group_id             INT           NOT NULL REFERENCES conservation_group(id),
    line_id              INT           NOT NULL REFERENCES line(id),
    bait_station_type_id INT           NOT NULL REFERENCES bait_station_type(id),
    custom_type_text     VARCHAR(120),             -- required when type is 'Other'
    latitude             NUMERIC(10,6) NOT NULL,
    longitude            NUMERIC(10,6) NOT NULL,
    display_order        INT           NOT NULL DEFAULT 0,  -- Issue 9
    is_retired           BOOLEAN       NOT NULL DEFAULT FALSE,

    UNIQUE (group_id, code)  -- Issue 8
);


-- =============================================================================
-- TRAP CATCHES
-- Fix Issue 1: this table was missing entirely from the original ERD draft
-- =============================================================================

CREATE TABLE trap_catch (
    id            SERIAL      PRIMARY KEY,
    group_id      INT         NOT NULL REFERENCES conservation_group(id),
    trap_id       INT         NOT NULL REFERENCES trap(id),
    date_checked  TIMESTAMP   NOT NULL,
    recorded_by   INT         REFERENCES "user"(id),
    species_id    INT         NOT NULL REFERENCES species(id),
    sex           VARCHAR(10) CHECK (sex IN ('Male', 'Female') OR sex IS NULL),
    maturity      VARCHAR(10) CHECK (maturity IN ('Juvenile', 'Adult') OR maturity IS NULL),
    status_id     INT         NOT NULL REFERENCES trap_status(id),
    rebaited      BOOLEAN     NOT NULL DEFAULT FALSE,
    bait_type_id  INT         NOT NULL REFERENCES bait_type(id),
    condition_id  INT         NOT NULL REFERENCES trap_condition(id),
    strikes       INT         NOT NULL DEFAULT 0 CHECK (strikes >= 0),
    notes         TEXT
);


-- =============================================================================
-- INCIDENTAL OBSERVATIONS
-- Fix Issue 2: this table was missing entirely from the original ERD draft
-- =============================================================================

CREATE TABLE incidental_obs (
    id          SERIAL        PRIMARY KEY,
    group_id    INT           NOT NULL REFERENCES conservation_group(id),
    operator_id INT           NOT NULL REFERENCES "user"(id),
    line_id     INT           NOT NULL REFERENCES line(id),
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
    latitude    NUMERIC(10,6),
    longitude   NUMERIC(10,6)
);


-- =============================================================================
-- BAIT STATION RECORDS
-- Fix Issue 14: recorded_by is NOT NULL (needed for ownership-based edit rules)
-- =============================================================================

CREATE TABLE bait_station_record (
    id                  SERIAL        PRIMARY KEY,
    group_id            INT           NOT NULL REFERENCES conservation_group(id),
    bait_station_id     INT           NOT NULL REFERENCES bait_station(id),
    recorded_at         TIMESTAMP     NOT NULL,        -- ISO 8601
    recorded_by         INT           NOT NULL REFERENCES "user"(id),  -- Issue 14: NOT NULL
    target_species_id   INT           NOT NULL REFERENCES target_species(id),
    active_ingredient_id INT          NOT NULL REFERENCES active_ingredient(id),
    formulation_id      INT           NOT NULL REFERENCES formulation(id),
    concentration_pct   NUMERIC(6,3)  NOT NULL,
    bait_remaining_kg   NUMERIC(8,3)  NOT NULL,
    bait_removed_kg     NUMERIC(8,3),
    bait_added_kg       NUMERIC(8,3),
    notes               TEXT
);


-- =============================================================================
-- USEFUL INDEXES
-- =============================================================================

-- Auth lookups
CREATE INDEX idx_password_reset_token_user ON password_reset_token(user_id) WHERE NOT is_used;
CREATE INDEX idx_login_otp_user            ON login_otp(user_id)            WHERE NOT is_used;

-- Membership / access checks
CREATE INDEX idx_group_membership_user  ON group_membership(user_id);
CREATE INDEX idx_group_membership_group ON group_membership(group_id);

-- Group-scoped asset queries
CREATE INDEX idx_trap_group_line          ON trap(group_id, line_id);
CREATE INDEX idx_bait_station_group_line  ON bait_station(group_id, line_id);

-- Record lookups
CREATE INDEX idx_trap_catch_trap          ON trap_catch(trap_id);
CREATE INDEX idx_trap_catch_group         ON trap_catch(group_id);
CREATE INDEX idx_bait_station_record_bs   ON bait_station_record(bait_station_id);
CREATE INDEX idx_bait_station_record_group ON bait_station_record(group_id);
CREATE INDEX idx_incidental_obs_group     ON incidental_obs(group_id);

-- Audit log
CREATE INDEX idx_audit_log_actor ON audit_log(actor_user_id);
CREATE INDEX idx_audit_log_group ON audit_log(group_id);


-- =============================================================================
-- SEED DATA — System roles
-- =============================================================================

INSERT INTO role (name) VALUES ('Super Admin'), ('Member');
