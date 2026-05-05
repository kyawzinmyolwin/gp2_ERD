-- COMP639 Project 2 - Required Epic Database Creation Script (LEAN VERSION)
-- Generated from Sprint 1 Required Epic ERD - Lean version
-- Removed: password_reset_token, login_otp (not required by PDF)
-- Adjusted: user.role_id removed, is_super_admin added (PDF multi-group rule)
-- Adjusted: group_membership uses role_id FK instead of group_role string
-- Simplified: audit_log columns reduced to essentials
-- Added: line.colour, trap.sort_order, bait_station.sort_order
-- Database: PostgreSQL

-- =========================================================
-- DROP TABLES
-- =========================================================

DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS bait_station_record CASCADE;
DROP TABLE IF EXISTS bait_station CASCADE;
DROP TABLE IF EXISTS bait_station_type CASCADE;
DROP TABLE IF EXISTS formulation CASCADE;
DROP TABLE IF EXISTS active_ingredient CASCADE;
DROP TABLE IF EXISTS target_species CASCADE;
DROP TABLE IF EXISTS trap CASCADE;
DROP TABLE IF EXISTS trap_type CASCADE;
DROP TABLE IF EXISTS operator_line CASCADE;
DROP TABLE IF EXISTS line CASCADE;
DROP TABLE IF EXISTS group_join_request CASCADE;
DROP TABLE IF EXISTS group_membership CASCADE;
DROP TABLE IF EXISTS group_application CASCADE;
DROP TABLE IF EXISTS conservation_group CASCADE;
DROP TABLE IF EXISTS "user" CASCADE;
DROP TABLE IF EXISTS role CASCADE;

-- =========================================================
-- CORE USER AND ROLE TABLES
-- =========================================================

CREATE TABLE role (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    CONSTRAINT chk_role_name
        CHECK (name IN ('Super Admin', 'Group Coordinator', 'Operator', 'Observer'))
);

CREATE TABLE "user" (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(30),
    emergency_contact_name VARCHAR(200),
    emergency_contact_phone VARCHAR(30),
    is_super_admin BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- CONSERVATION GROUP TABLES
-- =========================================================

CREATE TABLE conservation_group (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE,
    slug VARCHAR(150) NOT NULL UNIQUE,
    description TEXT,
    operational_area_description TEXT,
    logo_url VARCHAR(500),
    region VARCHAR(100),
    visibility VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    coordinator_user_id INTEGER,
    created_by INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_conservation_group_visibility
        CHECK (visibility IN ('Public', 'Private')),

    CONSTRAINT fk_conservation_group_coordinator
        FOREIGN KEY (coordinator_user_id)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_conservation_group_created_by
        FOREIGN KEY (created_by)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

CREATE TABLE group_application (
    id SERIAL PRIMARY KEY,
    applicant_user_id INTEGER NOT NULL,
    proposed_name VARCHAR(150) NOT NULL,
    description TEXT,
    proposed_visibility VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    reviewed_by INTEGER,
    reviewed_at TIMESTAMP,
    rejection_reason TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_group_application_visibility
        CHECK (proposed_visibility IN ('Public', 'Private')),

    CONSTRAINT chk_group_application_status
        CHECK (status IN ('Pending', 'Approved', 'Rejected')),

    CONSTRAINT fk_group_application_applicant
        FOREIGN KEY (applicant_user_id)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_group_application_reviewer
        FOREIGN KEY (reviewed_by)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

CREATE TABLE group_membership (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    membership_status VARCHAR(30) NOT NULL DEFAULT 'Active',
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_group_membership_group_user
        UNIQUE (group_id, user_id),

    CONSTRAINT chk_group_membership_status
        CHECK (membership_status IN ('Active', 'Inactive', 'Pending')),

    CONSTRAINT fk_group_membership_group
        FOREIGN KEY (group_id)
        REFERENCES conservation_group(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_group_membership_user
        FOREIGN KEY (user_id)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_group_membership_role
        FOREIGN KEY (role_id)
        REFERENCES role(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE group_join_request (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    request_status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_by INTEGER,
    decided_at TIMESTAMP,
    decision_reason TEXT,

    CONSTRAINT chk_group_join_request_status
        CHECK (request_status IN ('Pending', 'Approved', 'Rejected')),

    CONSTRAINT fk_group_join_request_group
        FOREIGN KEY (group_id)
        REFERENCES conservation_group(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_group_join_request_user
        FOREIGN KEY (user_id)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_group_join_request_decider
        FOREIGN KEY (decided_by)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    actor_user_id INTEGER,
    target_type VARCHAR(100) NOT NULL,
    target_id INTEGER,
    action VARCHAR(100) NOT NULL,
    performed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audit_log_actor
        FOREIGN KEY (actor_user_id)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

-- =========================================================
-- LINE, TRAP, AND BAIT STATION TABLES
-- =========================================================

CREATE TABLE line (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL,
    name VARCHAR(150) NOT NULL,
    line_type VARCHAR(30) NOT NULL,
    colour VARCHAR(20),
    is_retired BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_line_group_name
        UNIQUE (group_id, name),

    CONSTRAINT chk_line_type
        CHECK (line_type IN ('Trap', 'Bait Station')),

    CONSTRAINT fk_line_group
        FOREIGN KEY (group_id)
        REFERENCES conservation_group(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE operator_line (
    operator_id INTEGER NOT NULL,
    line_id INTEGER NOT NULL,
    assignment_date DATE NOT NULL DEFAULT CURRENT_DATE,

    PRIMARY KEY (operator_id, line_id),

    CONSTRAINT fk_operator_line_operator
        FOREIGN KEY (operator_id)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_operator_line_line
        FOREIGN KEY (line_id)
        REFERENCES line(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE trap_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE trap (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    trap_type_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    line_id INTEGER NOT NULL,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_retired BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_trap_type
        FOREIGN KEY (trap_type_id)
        REFERENCES trap_type(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trap_group
        FOREIGN KEY (group_id)
        REFERENCES conservation_group(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_trap_line
        FOREIGN KEY (line_id)
        REFERENCES line(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE bait_station_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    allow_custom_text BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE bait_station (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    group_id INTEGER NOT NULL,
    line_id INTEGER NOT NULL,
    bait_station_type_id INTEGER NOT NULL,
    custom_type_text VARCHAR(150),
    latitude NUMERIC(10, 7) NOT NULL,
    longitude NUMERIC(10, 7) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_retired BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_bait_station_group
        FOREIGN KEY (group_id)
        REFERENCES conservation_group(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_bait_station_line
        FOREIGN KEY (line_id)
        REFERENCES line(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_bait_station_type
        FOREIGN KEY (bait_station_type_id)
        REFERENCES bait_station_type(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- =========================================================
-- BAIT STATION RECORD LOOKUP TABLES
-- =========================================================

CREATE TABLE target_species (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE active_ingredient (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE formulation (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE bait_station_record (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL,
    bait_station_id INTEGER NOT NULL,
    recorded_at TIMESTAMP NOT NULL,
    recorded_by INTEGER,
    target_species_id INTEGER NOT NULL,
    active_ingredient_id INTEGER NOT NULL,
    formulation_id INTEGER NOT NULL,
    concentration_pct NUMERIC(5, 2) NOT NULL,
    bait_remaining_kg NUMERIC(8, 3) NOT NULL,
    bait_removed_kg NUMERIC(8, 3),
    bait_added_kg NUMERIC(8, 3),
    notes TEXT,

    CONSTRAINT chk_bait_station_record_concentration
        CHECK (concentration_pct >= 0 AND concentration_pct <= 100),

    CONSTRAINT chk_bait_station_record_bait_remaining
        CHECK (bait_remaining_kg >= 0),

    CONSTRAINT chk_bait_station_record_bait_removed
        CHECK (bait_removed_kg IS NULL OR bait_removed_kg >= 0),

    CONSTRAINT chk_bait_station_record_bait_added
        CHECK (bait_added_kg IS NULL OR bait_added_kg >= 0),

    CONSTRAINT fk_bait_station_record_group
        FOREIGN KEY (group_id)
        REFERENCES conservation_group(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_bait_station_record_station
        FOREIGN KEY (bait_station_id)
        REFERENCES bait_station(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_bait_station_record_user
        FOREIGN KEY (recorded_by)
        REFERENCES "user"(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_bait_station_record_target_species
        FOREIGN KEY (target_species_id)
        REFERENCES target_species(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_bait_station_record_active_ingredient
        FOREIGN KEY (active_ingredient_id)
        REFERENCES active_ingredient(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_bait_station_record_formulation
        FOREIGN KEY (formulation_id)
        REFERENCES formulation(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- =========================================================
-- HELPFUL INDEXES
-- =========================================================

CREATE INDEX idx_user_is_super_admin ON "user"(is_super_admin);
CREATE INDEX idx_conservation_group_visibility ON conservation_group(visibility);
CREATE INDEX idx_group_membership_user_id ON group_membership(user_id);
CREATE INDEX idx_group_membership_group_id ON group_membership(group_id);
CREATE INDEX idx_group_membership_role_id ON group_membership(role_id);
CREATE INDEX idx_group_join_request_group_id ON group_join_request(group_id);
CREATE INDEX idx_group_join_request_user_id ON group_join_request(user_id);
CREATE INDEX idx_line_group_id ON line(group_id);
CREATE INDEX idx_operator_line_line_id ON operator_line(line_id);
CREATE INDEX idx_trap_group_id ON trap(group_id);
CREATE INDEX idx_trap_line_id ON trap(line_id);
CREATE INDEX idx_bait_station_group_id ON bait_station(group_id);
CREATE INDEX idx_bait_station_line_id ON bait_station(line_id);
CREATE INDEX idx_bait_station_record_group_id ON bait_station_record(group_id);
CREATE INDEX idx_bait_station_record_station_id ON bait_station_record(bait_station_id);
CREATE INDEX idx_bait_station_record_recorded_at ON bait_station_record(recorded_at);
