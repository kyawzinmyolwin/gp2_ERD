-- =============================================================================
-- Conservation Group Platform — Normalisation-Validated Schema
-- Validated against 1NF, 2NF, 3NF, and BCNF
-- =============================================================================
--
-- NORMALISATION CHANGES FROM PREVIOUS VERSION:
--
--  N1. [3NF FIX]  user.emergency_contact_* extracted to emergency_contact table
--                 FD violated: emergency_contact_phone → emergency_contact_name
--                 (contact details described a person, not the user)
--
--  N2. [3NF NOTE] conservation_group.slug retained as intentional denormalisation
--                 FD: name → slug — slug is user-editable (custom URLs), so it
--                 is NOT a pure derivation. Documented. App enforces sync on save.
--
--  N3. [3NF FIX]  bait_station_type.allow_custom_text removed
--                 FD violated: name → allow_custom_text
--                 (allow_custom_text was TRUE iff name = 'Other' — pure derivation)
--                 Application checks name = 'Other' directly.
--
--  N4. [3NF NOTE] group_id on trap, bait_station, trap_catch, incidental_obs,
--                 bait_station_record retained as intentional denormalisation
--                 FD: line_id → group_id (or trap_id → group_id etc.)
--                 Retained for: (a) access-control checks on every request,
--                 (b) avoiding costly multi-join queries on high-traffic tables.
--                 Consistency enforced by triggers (see bottom of file).
--
-- =============================================================================


-- =============================================================================
-- SECTION 1 — SYSTEM / AUTH
-- =============================================================================

-- Role: system-level only. Group-scoped roles live in group_membership.
-- 1NF–BCNF: trivially satisfied (2-column, both candidate keys).
CREATE TABLE role (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE  -- 'Super Admin' | 'Member'
);


-- N1: Emergency contact extracted — it is an independent entity.
-- A contact person has their own identity independent of which user lists them.
-- 1NF–BCNF: satisfied. (name, phone) could be a composite candidate key but
-- surrogate PK is simpler and handles duplicates safely.
CREATE TABLE emergency_contact (
    id    SERIAL       PRIMARY KEY,
    name  VARCHAR(120) NOT NULL,
    phone VARCHAR(30)  NOT NULL
);


-- User: all remaining columns depend solely on user.id.
-- CKs: id, username, email — all three are candidate keys.
-- 3NF: no transitive deps remain after extracting emergency_contact.
-- BCNF: satisfied (every determinant is a candidate key).
CREATE TABLE "user" (
    id                    SERIAL       PRIMARY KEY,
    username              VARCHAR(60)  NOT NULL UNIQUE,
    email                 VARCHAR(254) NOT NULL UNIQUE,
    password_hash         VARCHAR(255) NOT NULL,
    first_name            VARCHAR(60)  NOT NULL,
    last_name             VARCHAR(60)  NOT NULL,
    phone                 VARCHAR(30),
    emergency_contact_id  INT          REFERENCES emergency_contact(id),  -- N1
    role_id               INT          NOT NULL REFERENCES role(id),
    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Auth tokens — all columns describe a single token event (id PK).
-- 1NF–BCNF: satisfied. token_hash is a candidate key on password_reset_token.
CREATE TABLE password_reset_token (
    id          SERIAL       PRIMARY KEY,
    user_id     INT          NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    token_hash  VARCHAR(255) NOT NULL UNIQUE,
    expires_at  TIMESTAMP    NOT NULL,
    is_used     BOOLEAN      NOT NULL DEFAULT FALSE,
    used_at     TIMESTAMP,
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE login_otp (
    id          SERIAL       PRIMARY KEY,
    user_id     INT          NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    otp_hash    VARCHAR(255) NOT NULL,
    expires_at  TIMESTAMP    NOT NULL,
    is_used     BOOLEAN      NOT NULL DEFAULT FALSE,
    used_at     TIMESTAMP,
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- =============================================================================
-- SECTION 2 — GROUPS & MEMBERSHIP
-- =============================================================================

-- Conservation Group.
-- N2: slug retained as independently user-editable field (custom URLs).
--     Although slug is often derived from name, it can diverge intentionally.
--     Application layer syncs slug on group creation; user may override later.
-- CKs: id, name, slug — all three candidate keys.
-- 3NF: no transitive deps (slug is not auto-derived; coordinator_user_id nullable
--      to break circular FK — group created first, coordinator assigned after).
CREATE TABLE conservation_group (
    id                           SERIAL       PRIMARY KEY,
    name                         VARCHAR(120) NOT NULL UNIQUE,
    slug                         VARCHAR(120) NOT NULL UNIQUE,  -- N2: user-editable
    description                  TEXT,
    operational_area_description TEXT,
    logo_url                     VARCHAR(500),
    region                       VARCHAR(100),
    visibility                   VARCHAR(10)  NOT NULL DEFAULT 'Public'
                                     CHECK (visibility IN ('Public', 'Private')),
    is_active                    BOOLEAN      NOT NULL DEFAULT TRUE,
    coordinator_user_id          INT          REFERENCES "user"(id),  -- nullable: set after creation
    created_by                   INT          NOT NULL REFERENCES "user"(id),
    created_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Group Application — all columns depend on id (PK).
-- 1NF–BCNF: satisfied.
CREATE TABLE group_application (
    id                  SERIAL       PRIMARY KEY,
    applicant_user_id   INT          NOT NULL REFERENCES "user"(id),
    proposed_name       VARCHAR(120) NOT NULL,
    description         TEXT         NOT NULL,
    proposed_visibility VARCHAR(10)  NOT NULL DEFAULT 'Public'
                            CHECK (proposed_visibility IN ('Public', 'Private')),
    status              VARCHAR(10)  NOT NULL DEFAULT 'Pending'
                            CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    reviewed_by         INT          REFERENCES "user"(id),
    reviewed_at         TIMESTAMP,
    rejection_reason    TEXT,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Group Membership — junction between user and group.
-- Natural CK: (group_id, user_id) — enforced by UNIQUE constraint.
-- 2NF: group_role, membership_status, joined_at all depend on the FULL
--      composite key (group_id, user_id), not on either part alone.
-- 3NF/BCNF: no transitive deps among non-key attributes.
CREATE TABLE group_membership (
    id                SERIAL      PRIMARY KEY,
    group_id          INT         NOT NULL REFERENCES conservation_group(id),
    user_id           INT         NOT NULL REFERENCES "user"(id),
    group_role        VARCHAR(30) NOT NULL
                          CHECK (group_role IN ('Observer', 'Operator', 'Group Coordinator')),
    membership_status VARCHAR(20) NOT NULL DEFAULT 'Active'
                          CHECK (membership_status IN ('Active', 'Inactive', 'Suspended')),
    joined_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (group_id, user_id)
);


-- Group Join Request — one pending request per user per group (partial unique index).
-- 1NF–BCNF: satisfied.
CREATE TABLE group_join_request (
    id              SERIAL      PRIMARY KEY,
    group_id        INT         NOT NULL REFERENCES conservation_group(id),
    user_id         INT         NOT NULL REFERENCES "user"(id),
    request_status  VARCHAR(10) NOT NULL DEFAULT 'Pending'
                        CHECK (request_status IN ('Pending', 'Approved', 'Rejected')),
    requested_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_by      INT         REFERENCES "user"(id),
    decided_at      TIMESTAMP,
    decision_reason TEXT
);

-- Partial unique index: only one PENDING request per user per group
CREATE UNIQUE INDEX idx_one_pending_join_request
    ON group_join_request (group_id, user_id)
    WHERE request_status = 'Pending';


-- =============================================================================
-- SECTION 3 — AUDIT
-- =============================================================================

-- Audit Log — append-only event record. All columns describe a single event.
-- old_value / new_value as TEXT is deliberate generic design (not a NF violation).
-- group_id added for group-scoped audit queries (avoids JOIN through target tables).
-- 1NF–BCNF: satisfied.
CREATE TABLE audit_log (
    id            SERIAL      PRIMARY KEY,
    actor_user_id INT         REFERENCES "user"(id),
    group_id      INT         REFERENCES conservation_group(id),
    target_type   VARCHAR(60) NOT NULL,
    target_id     INT,
    action        VARCHAR(60) NOT NULL,
    old_value     TEXT,
    new_value     TEXT,
    performed_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes         TEXT
);


-- =============================================================================
-- SECTION 4 — LINES & OPERATOR ASSIGNMENTS
-- =============================================================================

-- Line — all non-key attributes depend solely on id.
-- CK: (group_id, name) — enforced by UNIQUE.
-- 1NF–BCNF: satisfied.
CREATE TABLE line (
    id         SERIAL       PRIMARY KEY,
    group_id   INT          NOT NULL REFERENCES conservation_group(id),
    name       VARCHAR(120) NOT NULL,
    line_type  VARCHAR(20)  NOT NULL
                   CHECK (line_type IN ('Trap', 'Bait Station')),
    colour     VARCHAR(7)   NOT NULL DEFAULT '#3d7a2e',
    is_retired BOOLEAN      NOT NULL DEFAULT FALSE,

    UNIQUE (group_id, name)
);


-- Operator–Line assignment — pure junction table.
-- PK is natural composite (operator_id, line_id).
-- 2NF: assignment_date depends on the FULL composite PK (when THIS operator
--      was assigned to THIS line) — not on either FK alone.
-- 1NF–BCNF: satisfied.
CREATE TABLE operator_line (
    operator_id     INT  NOT NULL REFERENCES "user"(id),
    line_id         INT  NOT NULL REFERENCES line(id),
    assignment_date DATE NOT NULL DEFAULT CURRENT_DATE,

    PRIMARY KEY (operator_id, line_id)
);


-- =============================================================================
-- SECTION 5 — REFERENCE / LOOKUP TABLES  (Super Admin managed)
-- All lookup tables: (id PK, name UK) — trivially 1NF–BCNF.
-- =============================================================================

CREATE TABLE trap_type (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

-- N3: allow_custom_text REMOVED — it was a pure derivation of name.
--     Application checks: if bait_station_type.name = 'Other' → require custom text.
CREATE TABLE bait_station_type (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE  -- includes 'Other' as a valid value
);

CREATE TABLE target_species (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE active_ingredient (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE formulation (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE species (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE bait_type (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE trap_status (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE trap_condition (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE
);


-- =============================================================================
-- SECTION 6 — ASSETS (Traps and Bait Stations)
-- =============================================================================

-- Trap
-- N4: group_id is a denormalised copy of line.group_id, retained for:
--     (a) access-control: every request checks group membership
--     (b) performance: avoids JOIN on high-traffic asset queries
--     (c) UNIQUE(group_id, code): codes must be unique within a group
--     Consistency enforced by trigger trg_trap_group_id_sync (see Section 8).
-- 3NF violation acknowledged and documented — this is an intentional denorm.
-- All other columns depend solely on id. No further violations.
CREATE TABLE trap (
    id             SERIAL        PRIMARY KEY,
    code           VARCHAR(20)   NOT NULL,
    trap_type_id   INT           NOT NULL REFERENCES trap_type(id),
    group_id       INT           NOT NULL REFERENCES conservation_group(id),  -- N4: denorm
    line_id        INT           NOT NULL REFERENCES line(id),
    latitude       NUMERIC(10,6) NOT NULL,
    longitude      NUMERIC(10,6) NOT NULL,
    display_order  INT           NOT NULL DEFAULT 0,
    is_retired     BOOLEAN       NOT NULL DEFAULT FALSE,

    UNIQUE (group_id, code)
);


-- Bait Station
-- N4: same group_id denorm rationale as trap.
-- custom_type_text: conditionally required when bait_station_type.name = 'Other'.
--   This is a conditional constraint (not a NF violation).
--   Enforced by trigger trg_bait_station_custom_text (see Section 8).
CREATE TABLE bait_station (
    id                   SERIAL        PRIMARY KEY,
    code                 VARCHAR(20)   NOT NULL,
    group_id             INT           NOT NULL REFERENCES conservation_group(id),  -- N4: denorm
    line_id              INT           NOT NULL REFERENCES line(id),
    bait_station_type_id INT           NOT NULL REFERENCES bait_station_type(id),
    custom_type_text     VARCHAR(120),  -- required when type name = 'Other' (trigger enforced)
    latitude             NUMERIC(10,6) NOT NULL,
    longitude            NUMERIC(10,6) NOT NULL,
    display_order        INT           NOT NULL DEFAULT 0,
    is_retired           BOOLEAN       NOT NULL DEFAULT FALSE,

    UNIQUE (group_id, code)
);


-- =============================================================================
-- SECTION 7 — RECORDS & OBSERVATIONS
-- =============================================================================

-- Trap Catch
-- N4: group_id denorm via trap_id → line_id → group_id. Same rationale.
-- sex / maturity: describe the individual animal caught, NOT the species.
--   No FD: species_id → sex (a rat can be male or female). No violation.
-- All other columns: single facts about this catch event. 1NF–BCNF satisfied.
CREATE TABLE trap_catch (
    id            SERIAL      PRIMARY KEY,
    group_id      INT         NOT NULL REFERENCES conservation_group(id),  -- N4: denorm
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


-- Incidental Observation
-- N4: group_id denorm via line_id → group_id. Same rationale.
-- obs_type: CHECK constraint uses a fixed set. If obs types need to grow,
--   consider extracting to a lookup table (obs_type table). For now, fixed.
-- 1NF–BCNF: satisfied (after documenting N4 denorm).
CREATE TABLE incidental_obs (
    id          SERIAL        PRIMARY KEY,
    group_id    INT           NOT NULL REFERENCES conservation_group(id),  -- N4: denorm
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


-- Bait Station Record
-- N4: group_id denorm via bait_station_id → line_id → group_id. Same rationale.
-- bait_remaining_kg is an OBSERVED measurement (physically counted), not computed.
--   It is NOT derivable from previous_remaining - removed + added because:
--   (a) bait can evaporate, degrade, be eaten partially — independent of additions/removals
--   (b) operators measure what is there, not what the formula says should be there.
--   No FD: bait_remaining_kg is an atomic independent fact. No violation.
-- recorded_by: NOT NULL — required for ownership-based edit rules (US14).
-- 1NF–BCNF: satisfied.
CREATE TABLE bait_station_record (
    id                   SERIAL        PRIMARY KEY,
    group_id             INT           NOT NULL REFERENCES conservation_group(id),  -- N4: denorm
    bait_station_id      INT           NOT NULL REFERENCES bait_station(id),
    recorded_at          TIMESTAMP     NOT NULL,
    recorded_by          INT           NOT NULL REFERENCES "user"(id),
    target_species_id    INT           NOT NULL REFERENCES target_species(id),
    active_ingredient_id INT           NOT NULL REFERENCES active_ingredient(id),
    formulation_id       INT           NOT NULL REFERENCES formulation(id),
    concentration_pct    NUMERIC(6,3)  NOT NULL,
    bait_remaining_kg    NUMERIC(8,3)  NOT NULL,
    bait_removed_kg      NUMERIC(8,3),
    bait_added_kg        NUMERIC(8,3),
    notes                TEXT
);


-- =============================================================================
-- SECTION 8 — TRIGGERS (enforcing documented denormalisations & constraints)
-- =============================================================================

-- N4: Enforce trap.group_id = line.group_id on every INSERT or UPDATE to trap
CREATE OR REPLACE FUNCTION fn_sync_trap_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id
    FROM line WHERE id = NEW.line_id;

    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'trap.line_id % does not resolve to a valid group', NEW.line_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_trap_group_id_sync
    BEFORE INSERT OR UPDATE OF line_id ON trap
    FOR EACH ROW EXECUTE FUNCTION fn_sync_trap_group_id();


-- N4: Enforce bait_station.group_id = line.group_id
CREATE OR REPLACE FUNCTION fn_sync_bait_station_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id
    FROM line WHERE id = NEW.line_id;

    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'bait_station.line_id % does not resolve to a valid group', NEW.line_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bait_station_group_id_sync
    BEFORE INSERT OR UPDATE OF line_id ON bait_station
    FOR EACH ROW EXECUTE FUNCTION fn_sync_bait_station_group_id();


-- N4: Enforce trap_catch.group_id = trap.group_id
CREATE OR REPLACE FUNCTION fn_sync_trap_catch_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id
    FROM trap WHERE id = NEW.trap_id;

    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'trap_catch.trap_id % does not resolve to a valid group', NEW.trap_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_trap_catch_group_id_sync
    BEFORE INSERT OR UPDATE OF trap_id ON trap_catch
    FOR EACH ROW EXECUTE FUNCTION fn_sync_trap_catch_group_id();


-- N4: Enforce incidental_obs.group_id = line.group_id
CREATE OR REPLACE FUNCTION fn_sync_incidental_obs_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id
    FROM line WHERE id = NEW.line_id;

    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'incidental_obs.line_id % does not resolve to a valid group', NEW.line_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_incidental_obs_group_id_sync
    BEFORE INSERT OR UPDATE OF line_id ON incidental_obs
    FOR EACH ROW EXECUTE FUNCTION fn_sync_incidental_obs_group_id();


-- N4: Enforce bait_station_record.group_id = bait_station.group_id
CREATE OR REPLACE FUNCTION fn_sync_bait_station_record_group_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT group_id INTO NEW.group_id
    FROM bait_station WHERE id = NEW.bait_station_id;

    IF NEW.group_id IS NULL THEN
        RAISE EXCEPTION 'bait_station_record.bait_station_id % does not resolve to a valid group', NEW.bait_station_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bait_station_record_group_id_sync
    BEFORE INSERT OR UPDATE OF bait_station_id ON bait_station_record
    FOR EACH ROW EXECUTE FUNCTION fn_sync_bait_station_record_group_id();


-- N3: Enforce custom_type_text is required when bait_station_type.name = 'Other'
CREATE OR REPLACE FUNCTION fn_check_bait_station_custom_text()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_type_name VARCHAR(80);
BEGIN
    SELECT name INTO v_type_name
    FROM bait_station_type WHERE id = NEW.bait_station_type_id;

    IF v_type_name = 'Other' AND (NEW.custom_type_text IS NULL OR TRIM(NEW.custom_type_text) = '') THEN
        RAISE EXCEPTION 'custom_type_text is required when bait station type is Other';
    END IF;

    IF v_type_name != 'Other' AND NEW.custom_type_text IS NOT NULL THEN
        -- Clear custom text if type is not 'Other' (prevents orphaned data)
        NEW.custom_type_text := NULL;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bait_station_custom_text
    BEFORE INSERT OR UPDATE OF bait_station_type_id, custom_type_text ON bait_station
    FOR EACH ROW EXECUTE FUNCTION fn_check_bait_station_custom_text();


-- =============================================================================
-- SECTION 9 — INDEXES
-- =============================================================================

-- Auth
CREATE INDEX idx_password_reset_token_user ON password_reset_token(user_id) WHERE NOT is_used;
CREATE INDEX idx_login_otp_user            ON login_otp(user_id)            WHERE NOT is_used;

-- Membership / access checks (hit on every authenticated request)
CREATE INDEX idx_group_membership_user  ON group_membership(user_id);
CREATE INDEX idx_group_membership_group ON group_membership(group_id);

-- Asset queries by group and line
CREATE INDEX idx_trap_group_line         ON trap(group_id, line_id);
CREATE INDEX idx_bait_station_group_line ON bait_station(group_id, line_id);

-- Record lookups
CREATE INDEX idx_trap_catch_trap              ON trap_catch(trap_id);
CREATE INDEX idx_trap_catch_group             ON trap_catch(group_id);
CREATE INDEX idx_bait_station_record_bs       ON bait_station_record(bait_station_id);
CREATE INDEX idx_bait_station_record_group    ON bait_station_record(group_id);
CREATE INDEX idx_incidental_obs_group         ON incidental_obs(group_id);

-- Audit log
CREATE INDEX idx_audit_log_actor ON audit_log(actor_user_id);
CREATE INDEX idx_audit_log_group ON audit_log(group_id);


-- =============================================================================
-- SECTION 10 — SEED DATA
-- =============================================================================

INSERT INTO role (name) VALUES ('Super Admin'), ('Member');
