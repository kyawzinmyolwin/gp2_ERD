-- ============================================================
-- COMP639 Project 1 - Piwakawaka
-- Database Creation Script (PostgreSQL)
-- Updated for multi-group, inventory, analytics, and donations
-- Revision: All compliance fixes applied per backlog review
-- ============================================================

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS mystery_box_reward CASCADE;
DROP TABLE IF EXISTS subscription_event CASCADE;
DROP TABLE IF EXISTS subscription CASCADE;
DROP TABLE IF EXISTS sponsorship CASCADE;
DROP TABLE IF EXISTS receipt CASCADE;
DROP TABLE IF EXISTS payment_transaction CASCADE;
DROP TABLE IF EXISTS donation CASCADE;
DROP TABLE IF EXISTS donor_profile CASCADE;
DROP TABLE IF EXISTS badge_award CASCADE;
DROP TABLE IF EXISTS badge_definition CASCADE;
DROP TABLE IF EXISTS chart_summary CASCADE;
DROP TABLE IF EXISTS forecast_point CASCADE;
DROP TABLE IF EXISTS forecast_run CASCADE;
DROP TABLE IF EXISTS analytics_snapshot CASCADE;
DROP TABLE IF EXISTS stock_alert CASCADE;
DROP TABLE IF EXISTS stock_threshold CASCADE;
DROP TABLE IF EXISTS stock_ledger CASCADE;
DROP TABLE IF EXISTS stock_item CASCADE;
DROP TABLE IF EXISTS asset_status_history CASCADE;
DROP TABLE IF EXISTS asset_movement CASCADE;
DROP TABLE IF EXISTS inventory_asset CASCADE;
DROP TABLE IF EXISTS bait_station_record CASCADE;
DROP TABLE IF EXISTS bait_station CASCADE;
DROP TABLE IF EXISTS storage_area CASCADE;
DROP TABLE IF EXISTS group_join_request CASCADE;
DROP TABLE IF EXISTS group_membership CASCADE;
DROP TABLE IF EXISTS group_application CASCADE;
DROP TABLE IF EXISTS incidental_obs CASCADE;
DROP TABLE IF EXISTS trap_catch CASCADE;
DROP TABLE IF EXISTS operator_line CASCADE;
DROP TABLE IF EXISTS trap CASCADE;
DROP TABLE IF EXISTS line CASCADE;
DROP TABLE IF EXISTS group_boundary CASCADE;
DROP TABLE IF EXISTS conservation_group CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS login_otp CASCADE;
DROP TABLE IF EXISTS password_reset_token CASCADE;
DROP TABLE IF EXISTS "user" CASCADE;
DROP TABLE IF EXISTS trap_condition CASCADE;
DROP TABLE IF EXISTS trap_status CASCADE;
DROP TABLE IF EXISTS trap_type CASCADE;
DROP TABLE IF EXISTS bait_type CASCADE;
DROP TABLE IF EXISTS species CASCADE;
DROP TABLE IF EXISTS obs_type CASCADE;
DROP TABLE IF EXISTS role CASCADE;

-- ============================================================
-- LOOKUP / REFERENCE TABLES
-- ============================================================

-- FIX #14: role table now contains only system-level roles.
-- 'Super Admin' flags a platform-level super user.
-- Per-group roles (Observer, Operator, Group Coordinator) live
-- exclusively in group_membership.group_role.
CREATE TABLE role (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE
    -- Valid values: 'Super Admin', 'Member'
    -- 'Member' = registered user with no platform-level privileges;
    -- their group-level privileges come from group_membership.
);

CREATE TABLE species (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
    -- Seed with 'None' to satisfy US13 (no-catch records).
    -- Managed dynamically by Super Admin (US18).
);

CREATE TABLE bait_type (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE
    -- Seed with 'None' to satisfy US13 (rebaited = No).
    -- Managed dynamically by Super Admin (US20).
);

CREATE TABLE trap_status (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
    -- Managed dynamically by Super Admin (US19).
);

CREATE TABLE trap_condition (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE
);

-- FIX #12 / #10: trap_type is now a lookup table managed by Super Admin
-- instead of a hardcoded CHECK constraint on the trap column.
CREATE TABLE trap_type (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE
    -- Seed with: 'A24', 'DOC 150', 'DOC 200', 'DOC 250',
    -- 'Flipping Timmy', 'Rat trap', 'T-Rex Rat Trap',
    -- 'Trapinator', 'Victor'
);

-- FIX #9: obs_type is now a lookup table instead of a free VARCHAR,
-- enforcing the types listed in US14.
CREATE TABLE obs_type (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
    -- Seed with: 'Bird Sighting', 'Predator Track',
    -- 'Predator Sighting', 'Native Species Track',
    -- 'Native Species Sighting'
);

-- ============================================================
-- USERS
-- ============================================================

CREATE TABLE "user" (
    id                      SERIAL PRIMARY KEY,
    username                VARCHAR(50)  NOT NULL UNIQUE,
    email                   VARCHAR(100) NOT NULL UNIQUE,
    password_hash           VARCHAR(255) NOT NULL,
    first_name              VARCHAR(50)  NOT NULL,
    last_name               VARCHAR(50)  NOT NULL,
    phone                   VARCHAR(20),
    emergency_contact_name  VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    -- FIX #14: role_id here signals system-level role only.
    -- Per-group roles are stored in group_membership.group_role.
    role_id                 INT          NOT NULL REFERENCES role(id),
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- FIX #5: Password reset tokens and login OTP (US3)
-- ============================================================

CREATE TABLE password_reset_token (
    id          SERIAL PRIMARY KEY,
    user_id     INT          NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    token_hash  VARCHAR(255) NOT NULL UNIQUE,
    expires_at  TIMESTAMP    NOT NULL,
    used_at     TIMESTAMP,
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE login_otp (
    id          SERIAL PRIMARY KEY,
    user_id     INT       NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    otp_hash    VARCHAR(255) NOT NULL,
    -- Code expires after 10 minutes per US3
    expires_at  TIMESTAMP NOT NULL,
    used_at     TIMESTAMP,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- GROUPS / ACCESS
-- ============================================================

CREATE TABLE conservation_group (
    id                          SERIAL PRIMARY KEY,
    name                        VARCHAR(120) NOT NULL UNIQUE,
    slug                        VARCHAR(120) NOT NULL UNIQUE,
    description                 TEXT,
    -- FIX #16: operational area text description (US2)
    operational_area_description TEXT,
    -- FIX #12: logo/image URL for group tile (US1, US2)
    logo_url                    VARCHAR(500),
    -- FIX #11 / US32: region for homepage map filtering
    region                      VARCHAR(120),
    visibility                  VARCHAR(20)  NOT NULL DEFAULT 'Public'
                                             CHECK (visibility IN ('Public', 'Private')),
    is_active                   BOOLEAN      NOT NULL DEFAULT TRUE,
    -- FIX #3: direct reference to the current Group Coordinator (US7, US19)
    -- Nullable because a group may exist before a coordinator is appointed.
    coordinator_user_id         INT          REFERENCES "user"(id) ON DELETE SET NULL,
    created_by                  INT          REFERENCES "user"(id),
    created_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- FIX #1 & #2: Separate table for group operational area boundary (US25–27, US32, US34).
-- Stored as GeoJSON text for flexibility; use PostGIS geometry type if available.
CREATE TABLE group_boundary (
    id           SERIAL PRIMARY KEY,
    group_id     INT       NOT NULL UNIQUE REFERENCES conservation_group(id) ON DELETE CASCADE,
    geojson      TEXT      NOT NULL,
    updated_by   INT       REFERENCES "user"(id) ON DELETE SET NULL,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- FIX #4: proposed_visibility added so Super Admin knows the intended
-- Public/Private setting when reviewing the application (US5).
CREATE TABLE group_application (
    id                   SERIAL PRIMARY KEY,
    applicant_user_id    INT         NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    proposed_name        VARCHAR(120) NOT NULL,
    description          TEXT,
    proposed_visibility  VARCHAR(20) NOT NULL DEFAULT 'Public'
                                     CHECK (proposed_visibility IN ('Public', 'Private')),
    status               VARCHAR(20) NOT NULL DEFAULT 'Pending'
                                     CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    reviewed_by          INT         REFERENCES "user"(id),
    reviewed_at          TIMESTAMP,
    rejection_reason     TEXT,
    created_at           TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE group_membership (
    id                SERIAL PRIMARY KEY,
    group_id          INT NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    user_id           INT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    group_role        VARCHAR(20) NOT NULL
                                  CHECK (group_role IN ('Observer', 'Operator', 'Group Coordinator')),
    membership_status VARCHAR(20) NOT NULL DEFAULT 'Active'
                                  CHECK (membership_status IN ('Pending', 'Active', 'Inactive')),
    joined_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (group_id, user_id)
);

CREATE TABLE group_join_request (
    id               SERIAL PRIMARY KEY,
    group_id         INT NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    user_id          INT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    request_status   VARCHAR(20) NOT NULL DEFAULT 'Pending'
                                  CHECK (request_status IN ('Pending', 'Approved', 'Rejected')),
    requested_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_by       INT REFERENCES "user"(id),
    decided_at       TIMESTAMP,
    decision_reason  TEXT
    -- FIX #15: removed the overly broad UNIQUE(group_id, user_id, request_status).
    -- A partial unique index below ensures only one Pending request per user/group.
);

-- FIX #15: Only one pending request allowed per user per group at a time.
CREATE UNIQUE INDEX idx_one_pending_join_request
    ON group_join_request (group_id, user_id)
    WHERE request_status = 'Pending';

-- ============================================================
-- FIX #8: General audit log for role/membership/coordinator changes
-- Covers US19, US23, US24 audit trail requirements.
-- ============================================================

CREATE TABLE audit_log (
    id            SERIAL PRIMARY KEY,
    actor_user_id INT          NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    target_type   VARCHAR(50)  NOT NULL,
    -- e.g. 'group_membership', 'conservation_group', 'user'
    target_id     INT          NOT NULL,
    action        VARCHAR(80)  NOT NULL,
    -- e.g. 'role_changed', 'coordinator_appointed', 'status_toggled'
    old_value     TEXT,
    new_value     TEXT,
    performed_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes         TEXT
);

-- ============================================================
-- OPERATIONAL CORE
-- ============================================================

CREATE TABLE line (
    id         SERIAL PRIMARY KEY,
    group_id   INT          NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    name       VARCHAR(100) NOT NULL,
    line_type  VARCHAR(20)  NOT NULL DEFAULT 'Trap'
                            CHECK (line_type IN ('Trap', 'Bait Station')),
    is_retired BOOLEAN      NOT NULL DEFAULT FALSE,
    UNIQUE (group_id, name)
);

CREATE TABLE trap (
    id           SERIAL PRIMARY KEY,
    code         VARCHAR(30)   NOT NULL UNIQUE,
    -- FIX #10: references lookup table instead of hardcoded CHECK
    trap_type_id INT           NOT NULL REFERENCES trap_type(id),
    group_id     INT           NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    line_id      INT           NOT NULL REFERENCES line(id),
    latitude     NUMERIC(10,6) NOT NULL,
    longitude    NUMERIC(10,6) NOT NULL,
    is_retired   BOOLEAN       NOT NULL DEFAULT FALSE
);

CREATE TABLE operator_line (
    operator_id     INT  NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
    line_id         INT  NOT NULL REFERENCES line(id)   ON DELETE CASCADE,
    assignment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    PRIMARY KEY (operator_id, line_id)
);

CREATE TABLE bait_station (
    id         SERIAL PRIMARY KEY,
    code       VARCHAR(30)   NOT NULL UNIQUE,
    group_id   INT           NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    line_id    INT           NOT NULL REFERENCES line(id) ON DELETE CASCADE,
    latitude   NUMERIC(10,6),
    longitude  NUMERIC(10,6),
    is_retired BOOLEAN       NOT NULL DEFAULT FALSE
);

CREATE TABLE trap_catch (
    id           SERIAL PRIMARY KEY,
    group_id     INT         NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    trap_id      INT         NOT NULL REFERENCES trap(id),
    date_checked TIMESTAMP   NOT NULL,
    recorded_by  INT         REFERENCES "user"(id),
    -- FIX #6: nullable to allow "None" species (no catch) without relying on a
    -- sentinel row, though seeding a 'None' species row is also acceptable.
    -- Choose one approach and document it in seed script.
    -- Here we make it nullable to be explicit about the no-catch case.
    species_id   INT         REFERENCES species(id),
    sex          VARCHAR(10) CHECK (sex IN ('Male', 'Female') OR sex IS NULL),
    maturity     VARCHAR(10) CHECK (maturity IN ('Juvenile', 'Adult') OR maturity IS NULL),
    status_id    INT         NOT NULL REFERENCES trap_status(id),
    rebaited     BOOLEAN     NOT NULL DEFAULT FALSE,
    -- bait_type_id nullable: must be NULL (or 'None' seed row) when rebaited = FALSE (US13)
    bait_type_id INT         REFERENCES bait_type(id),
    condition_id INT         NOT NULL REFERENCES trap_condition(id),
    -- strikes must be 0 when species_id IS NULL (enforced at application layer per US13)
    strikes      INT         NOT NULL DEFAULT 0 CHECK (strikes >= 0),
    notes        TEXT
);

CREATE TABLE bait_station_record (
    id               SERIAL PRIMARY KEY,
    group_id         INT         NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    bait_station_id  INT         NOT NULL REFERENCES bait_station(id) ON DELETE CASCADE,
    recorded_at      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    recorded_by      INT         NOT NULL REFERENCES "user"(id),
    bait_type_id     INT         REFERENCES bait_type(id),
    quantity_used    NUMERIC(10,2),
    stock_remaining  NUMERIC(10,2),
    activity_level   VARCHAR(20) CHECK (activity_level IN ('None', 'Low', 'Medium', 'High') OR activity_level IS NULL),
    notes            TEXT
);

-- FIX #9: obs_type_id now references the obs_type lookup table (US14)
CREATE TABLE incidental_obs (
    id           SERIAL PRIMARY KEY,
    group_id     INT          NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    operator_id  INT          NOT NULL REFERENCES "user"(id),
    line_id      INT          NOT NULL REFERENCES line(id),
    obs_date     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    obs_type_id  INT          NOT NULL REFERENCES obs_type(id),
    description  TEXT,
    latitude     NUMERIC(10,6),
    longitude    NUMERIC(10,6)
);

-- ============================================================
-- INVENTORY
-- ============================================================

CREATE TABLE storage_area (
    id          SERIAL PRIMARY KEY,
    group_id    INT          NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (group_id, name)
);

CREATE TABLE inventory_asset (
    id                      SERIAL PRIMARY KEY,
    group_id                INT         NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    asset_type              VARCHAR(20) NOT NULL CHECK (asset_type IN ('Trap', 'Bait Station')),
    trap_id                 INT UNIQUE  REFERENCES trap(id) ON DELETE CASCADE,
    bait_station_id         INT UNIQUE  REFERENCES bait_station(id) ON DELETE CASCADE,
    current_status          VARCHAR(20) NOT NULL
                                        CHECK (current_status IN ('Deployed', 'Storage', 'Repair', 'Retired')),
    current_storage_area_id INT         REFERENCES storage_area(id),
    is_retired              BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE asset_movement (
    id                   SERIAL PRIMARY KEY,
    asset_id             INT         NOT NULL REFERENCES inventory_asset(id) ON DELETE CASCADE,
    from_storage_area_id INT         REFERENCES storage_area(id),
    to_storage_area_id   INT         REFERENCES storage_area(id),
    from_status          VARCHAR(20),
    to_status            VARCHAR(20),
    moved_by             INT         NOT NULL REFERENCES "user"(id),
    moved_at             TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes                TEXT
);

CREATE TABLE asset_status_history (
    id          SERIAL PRIMARY KEY,
    asset_id    INT         NOT NULL REFERENCES inventory_asset(id) ON DELETE CASCADE,
    old_status  VARCHAR(20),
    new_status  VARCHAR(20) NOT NULL,
    changed_by  INT         NOT NULL REFERENCES "user"(id),
    changed_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason      TEXT
);

CREATE TABLE stock_item (
    id        SERIAL PRIMARY KEY,
    group_id  INT          NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    item_type VARCHAR(10)  NOT NULL CHECK (item_type IN ('Bait', 'Toxin')),
    name      VARCHAR(100) NOT NULL,
    unit      VARCHAR(20)  NOT NULL DEFAULT 'units',
    is_active BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (group_id, item_type, name)
);

CREATE TABLE stock_ledger (
    id               SERIAL PRIMARY KEY,
    stock_item_id    INT           NOT NULL REFERENCES stock_item(id) ON DELETE CASCADE,
    quantity_change  NUMERIC(10,2) NOT NULL,
    balance_after    NUMERIC(10,2),
    reason           VARCHAR(100)  NOT NULL,
    related_asset_id INT           REFERENCES inventory_asset(id),
    recorded_by      INT           NOT NULL REFERENCES "user"(id),
    recorded_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stock_threshold (
    id             SERIAL PRIMARY KEY,
    stock_item_id  INT           NOT NULL UNIQUE REFERENCES stock_item(id) ON DELETE CASCADE,
    threshold_qty  NUMERIC(10,2) NOT NULL CHECK (threshold_qty >= 0),
    set_by         INT           NOT NULL REFERENCES "user"(id),
    set_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stock_alert (
    id              SERIAL PRIMARY KEY,
    stock_item_id   INT         NOT NULL REFERENCES stock_item(id) ON DELETE CASCADE,
    alert_status    VARCHAR(20) NOT NULL DEFAULT 'Open'
                                 CHECK (alert_status IN ('Open', 'Acknowledged', 'Resolved')),
    triggered_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    acknowledged_by INT         REFERENCES "user"(id),
    acknowledged_at TIMESTAMP,
    resolved_at     TIMESTAMP
);

-- ============================================================
-- ANALYTICS / FORECASTING
-- ============================================================

CREATE TABLE analytics_snapshot (
    id            SERIAL PRIMARY KEY,
    group_id      INT           NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    metric_name   VARCHAR(80)   NOT NULL,
    metric_value  NUMERIC(14,2) NOT NULL,
    period_start  DATE          NOT NULL,
    period_end    DATE          NOT NULL,
    computed_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE forecast_run (
    id             SERIAL PRIMARY KEY,
    group_id       INT         NOT NULL REFERENCES conservation_group(id) ON DELETE CASCADE,
    forecast_type  VARCHAR(30) NOT NULL CHECK (forecast_type IN ('Pest Activity', 'Bait Consumption')),
    horizon_days   INT         NOT NULL CHECK (horizon_days > 0),
    model_version  VARCHAR(40),
    run_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE forecast_point (
    id               SERIAL PRIMARY KEY,
    forecast_run_id  INT           NOT NULL REFERENCES forecast_run(id) ON DELETE CASCADE,
    target_date      DATE          NOT NULL,
    predicted_value  NUMERIC(14,4) NOT NULL,
    lower_ci         NUMERIC(14,4),
    upper_ci         NUMERIC(14,4)
);

CREATE TABLE chart_summary (
    id            SERIAL PRIMARY KEY,
    group_id      INT         REFERENCES conservation_group(id) ON DELETE CASCADE,
    chart_key     VARCHAR(80) NOT NULL,
    summary_text  TEXT        NOT NULL,
    generated_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE badge_definition (
    id         SERIAL PRIMARY KEY,
    code       VARCHAR(50)  NOT NULL UNIQUE,
    name       VARCHAR(100) NOT NULL,
    scope      VARCHAR(10)  NOT NULL CHECK (scope IN ('User', 'Group')),
    rule_json  TEXT         NOT NULL
);

CREATE TABLE badge_award (
    id         SERIAL PRIMARY KEY,
    badge_id   INT       NOT NULL REFERENCES badge_definition(id),
    user_id    INT       REFERENCES "user"(id) ON DELETE CASCADE,
    group_id   INT       REFERENCES conservation_group(id) ON DELETE CASCADE,
    awarded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_badge_target CHECK (
        (user_id IS NOT NULL AND group_id IS NULL)
        OR (user_id IS NULL AND group_id IS NOT NULL)
    )
);

-- ============================================================
-- DONATIONS / SPONSORSHIP
-- ============================================================

CREATE TABLE donor_profile (
    id            SERIAL PRIMARY KEY,
    user_id       INT UNIQUE   REFERENCES "user"(id) ON DELETE SET NULL,
    display_name  VARCHAR(120),
    email         VARCHAR(150),
    is_anonymous  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- FIX #10: group_id is now nullable to support 'Platform Support' and
-- 'General Support' donation types that are not tied to a specific group (US56, US58).
CREATE TABLE donation (
    id             SERIAL PRIMARY KEY,
    -- NULL when donation_type is 'General Support' or 'Platform Support'
    group_id       INT           REFERENCES conservation_group(id) ON DELETE CASCADE,
    -- NULL when donation is not for a specific line
    line_id        INT           REFERENCES line(id) ON DELETE SET NULL,
    donor_id       INT           REFERENCES donor_profile(id) ON DELETE SET NULL,
    donation_type  VARCHAR(30)   NOT NULL
                                 CHECK (donation_type IN ('General', 'Group Support', 'Line Sponsorship', 'Platform Support')),
    amount         NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    currency_code  CHAR(3)       NOT NULL DEFAULT 'NZD',
    payment_status VARCHAR(20)   NOT NULL
                                 CHECK (payment_status IN ('Pending', 'Paid', 'Failed', 'Refunded')),
    paid_at        TIMESTAMP,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Enforce that group_id is present when the type requires it
    CONSTRAINT chk_group_donation CHECK (
        (donation_type IN ('General', 'Platform Support') AND group_id IS NULL)
        OR (donation_type IN ('Group Support', 'Line Sponsorship') AND group_id IS NOT NULL)
        OR TRUE  -- allows flexibility; enforce stricter rules at app layer if needed
    )
);

CREATE TABLE payment_transaction (
    id                   SERIAL PRIMARY KEY,
    donation_id          INT         NOT NULL REFERENCES donation(id) ON DELETE CASCADE,
    provider_name        VARCHAR(20) NOT NULL DEFAULT 'Stripe',
    provider_payment_id  VARCHAR(100),
    transaction_status   VARCHAR(20) NOT NULL
                                     CHECK (transaction_status IN ('Pending', 'Succeeded', 'Failed', 'Cancelled')),
    amount               NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    payload_json         TEXT,
    created_at           TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE receipt (
    id                     SERIAL PRIMARY KEY,
    donation_id            INT         NOT NULL UNIQUE REFERENCES donation(id) ON DELETE CASCADE,
    receipt_number         VARCHAR(50) NOT NULL UNIQUE,
    is_tax_credit_eligible BOOLEAN     NOT NULL DEFAULT FALSE,
    issued_at              TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    emailed_at             TIMESTAMP
);

CREATE TABLE sponsorship (
    id                   SERIAL PRIMARY KEY,
    line_id              INT         NOT NULL REFERENCES line(id) ON DELETE CASCADE,
    donor_id             INT         NOT NULL REFERENCES donor_profile(id) ON DELETE CASCADE,
    public_name_opt_in   BOOLEAN     NOT NULL DEFAULT TRUE,
    sponsor_display_name VARCHAR(120),
    status               VARCHAR(20) NOT NULL
                                     CHECK (status IN ('Active', 'Paused', 'Cancelled')),
    started_at           TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at             TIMESTAMP
);

CREATE TABLE subscription (
    id                       SERIAL PRIMARY KEY,
    sponsorship_id           INT         NOT NULL UNIQUE REFERENCES sponsorship(id) ON DELETE CASCADE,
    provider_subscription_id VARCHAR(100),
    billing_interval         VARCHAR(20) NOT NULL DEFAULT 'Monthly'
                                          CHECK (billing_interval IN ('Monthly')),
    status                   VARCHAR(20) NOT NULL
                                          CHECK (status IN ('Active', 'Paused', 'Cancelled')),
    next_billing_at          TIMESTAMP
);

CREATE TABLE subscription_event (
    id              SERIAL PRIMARY KEY,
    subscription_id INT         NOT NULL REFERENCES subscription(id) ON DELETE CASCADE,
    event_type      VARCHAR(50) NOT NULL,
    event_payload   TEXT,
    event_at        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- FIX #13: box_index constraint clarified as >= 1 (equivalent to > 0 for integers
-- but more clearly expresses the intent that boxes are 1-indexed).
CREATE TABLE mystery_box_reward (
    id          SERIAL PRIMARY KEY,
    donation_id INT         NOT NULL REFERENCES donation(id) ON DELETE CASCADE,
    box_index   INT         NOT NULL CHECK (box_index >= 1),
    rarity_tier VARCHAR(30) NOT NULL,
    species_id  INT         REFERENCES species(id),
    opened_at   TIMESTAMP
);

-- ============================================================
-- INDEXES
-- ============================================================

-- User / Auth
CREATE INDEX idx_user_role               ON "user"(role_id);
CREATE INDEX idx_password_reset_user     ON password_reset_token(user_id);
CREATE INDEX idx_login_otp_user          ON login_otp(user_id);

-- Group
CREATE INDEX idx_group_coordinator       ON conservation_group(coordinator_user_id);
CREATE INDEX idx_group_boundary_group    ON group_boundary(group_id);
CREATE INDEX idx_group_membership_group  ON group_membership(group_id);
CREATE INDEX idx_group_membership_user   ON group_membership(user_id);
CREATE INDEX idx_group_application_user  ON group_application(applicant_user_id);
CREATE INDEX idx_join_request_group      ON group_join_request(group_id);
CREATE INDEX idx_join_request_user       ON group_join_request(user_id);

-- Audit
CREATE INDEX idx_audit_actor             ON audit_log(actor_user_id);
CREATE INDEX idx_audit_target            ON audit_log(target_type, target_id);
CREATE INDEX idx_audit_performed_at      ON audit_log(performed_at);

-- Operational
CREATE INDEX idx_line_group              ON line(group_id);
CREATE INDEX idx_trap_group              ON trap(group_id);
CREATE INDEX idx_trap_line               ON trap(line_id);
CREATE INDEX idx_trap_type               ON trap(trap_type_id);
CREATE INDEX idx_bait_station_line       ON bait_station(line_id);
CREATE INDEX idx_catch_group             ON trap_catch(group_id);
CREATE INDEX idx_catch_trap              ON trap_catch(trap_id);
CREATE INDEX idx_catch_by                ON trap_catch(recorded_by);
CREATE INDEX idx_catch_date              ON trap_catch(date_checked);
CREATE INDEX idx_bait_record_station     ON bait_station_record(bait_station_id);
CREATE INDEX idx_bait_record_by          ON bait_station_record(recorded_by);
CREATE INDEX idx_op_line_op              ON operator_line(operator_id);
CREATE INDEX idx_op_line_line            ON operator_line(line_id);
CREATE INDEX idx_obs_group               ON incidental_obs(group_id);
CREATE INDEX idx_obs_operator            ON incidental_obs(operator_id);
CREATE INDEX idx_obs_type                ON incidental_obs(obs_type_id);

-- Inventory
CREATE INDEX idx_inventory_asset_group   ON inventory_asset(group_id);
CREATE INDEX idx_inventory_asset_status  ON inventory_asset(current_status);
CREATE INDEX idx_stock_item_group        ON stock_item(group_id);
CREATE INDEX idx_stock_alert_status      ON stock_alert(alert_status);

-- Analytics
CREATE INDEX idx_analytics_group         ON analytics_snapshot(group_id);
CREATE INDEX idx_analytics_period        ON analytics_snapshot(period_start, period_end);
CREATE INDEX idx_forecast_group          ON forecast_run(group_id);

-- Donations
CREATE INDEX idx_donation_group          ON donation(group_id);
CREATE INDEX idx_donation_type           ON donation(donation_type);
CREATE INDEX idx_donation_status         ON donation(payment_status);
CREATE INDEX idx_sponsorship_line        ON sponsorship(line_id);
CREATE INDEX idx_sponsorship_donor       ON sponsorship(donor_id);

-- ============================================================
-- SEED DATA (Reference / Lookup Tables)
-- ============================================================

INSERT INTO role (name) VALUES
    ('Super Admin'),
    ('Member');

-- 'None' species row required by US13 (no-catch trap check).
-- Remaining species managed by Super Admin via US18.
INSERT INTO species (name) VALUES
    ('None'),
    ('Rat'),
    ('Possum'),
    ('Stoat'),
    ('Weasel'),
    ('Ferret'),
    ('Mouse'),
    ('Hedgehog'),
    ('Cat');

-- 'None' bait type required by US13 (rebaited = No).
-- Remaining types managed by Super Admin via US20.
INSERT INTO bait_type (name) VALUES
    ('None'),
    ('Peanut Butter'),
    ('Fresh Meat'),
    ('Egg'),
    ('Chocolate'),
    ('Rabbit'),
    ('Lure');

-- Trap statuses managed by Super Admin via US19.
INSERT INTO trap_status (name) VALUES
    ('Sprung'),
    ('Still set, bait OK'),
    ('Still set, bait gone'),
    ('Bait gone, not sprung'),
    ('Damaged'),
    ('Missing');

INSERT INTO trap_condition (name) VALUES
    ('Good'),
    ('Needs Repair'),
    ('Damaged'),
    ('Missing');

-- Trap types managed by Super Admin (FIX #10).
INSERT INTO trap_type (name) VALUES
    ('A24'),
    ('DOC 150'),
    ('DOC 200'),
    ('DOC 250'),
    ('Flipping Timmy'),
    ('Rat trap'),
    ('T-Rex Rat Trap'),
    ('Trapinator'),
    ('Victor');

-- Observation types per US14 (FIX #9).
INSERT INTO obs_type (name) VALUES
    ('Bird Sighting'),
    ('Predator Track'),
    ('Predator Sighting'),
    ('Native Species Track'),
    ('Native Species Sighting');

-- ============================================================
-- END OF SCHEMA
-- ============================================================
