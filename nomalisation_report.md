Now I have a thorough picture of the whole schema. Let me produce the normalisation analysis.Now I have everything I need. Let me produce the full normalisation analysis report.Now I have everything. Let me write the full normalisation analysis report.Here is the full normalisation analysis. The summary grid above shows the verdict per section; everything that follows explains the reasoning and the specific fixes needed.

---

## Normalisation analysis — `full_schema_all_sprints.sql`

### Quick orientation

The schema is overall well-structured. Sections 3, 4, 5, and 8 are clean through BCNF with no issues. The documented N4 intentional denormalisations (storing `group_id` directly on `trap`, `bait_station`, and the various record tables) are correctly justified and trigger-enforced — they are not violations to fix. The real problems are concentrated in three areas: the inventory section (Section 9), the donations section (Section 11), and two moderate issues in Auth and the Groups section.

---

### 1NF validation — all sections pass

Every column across the schema stores atomic, single-valued data. There are no repeating groups, array columns masquerading as scalars, or comma-delimited lists embedded in a text field. The `forecast_data JSONB` column in `forecast_result` is the closest thing to a multi-valued attribute, but JSONB as a typed document store for computed time-series output is acceptable practice — it is not a normalisation violation because the column as a whole is the single fact being stored.

**Verdict: 1NF satisfied throughout.**

---

### 2NF validation — all sections pass

Every non-key attribute in every table depends on the whole primary key, not a partial subset. The tables with composite natural keys — `operator_line (operator_id, line_id)`, `group_membership (group_id, user_id)`, `bait_stock (group_id, active_ingredient_id, formulation_id)`, `user_species_collection (user_id, species_id)` — all correctly have their non-key attributes depend on the full composite key, not either part alone. The surrogate-key tables are trivially 2NF-compliant.

**Verdict: 2NF satisfied throughout.**

---

### 3NF and BCNF analysis — issues found

#### Section 1 — Auth: one 3NF warning

**`emergency_contact` table — correct fix already applied (N1), but partially.**

The N1 fix extracted `emergency_contact_name` and `emergency_contact_phone` from `user` into a separate `emergency_contact` table to resolve the transitive dependency `phone → name` (a contact person's name and phone describe each other, not the user). This is the right call.

**Remaining issue:** The `emergency_contact` table has the functional dependency `phone → name` (two people can share a phone, but in practice this table is treating `(name, phone)` as a compound natural key). There is currently no unique constraint on `phone` or on `(name, phone)`. Two users could reference two separate `emergency_contact` rows for the same person, creating duplicates. This is not a 3NF violation per se, but it means the deduplication benefit of the extract is not enforced.

**Fix:** Add `UNIQUE (name, phone)` to `emergency_contact`, or add a uniqueness check at the application layer when creating contacts.

---

#### Section 2 — Groups & Membership: two issues

**Issue 2a — `conservation_group.total_donations_nzd` is a 3NF violation (Sprint 5 ALTER)**

The Sprint 5 block adds this column:

```sql
ALTER TABLE conservation_group
    ADD COLUMN IF NOT EXISTS total_donations_nzd NUMERIC(12,2) NOT NULL DEFAULT 0;
```

This is a classic transitive dependency: `total_donations_nzd` is derivable from `SUM(donation.amount_nzd) WHERE group_id = X AND payment_status = 'Completed'`. Storing it denormalised means it must be kept in sync with the `donation` table by application logic or triggers, and it will silently drift if a donation is refunded or a payment status is updated without updating this counter.

The comment says it is "updated on each completed donation", which is an application-level responsibility — but there is no trigger enforcing this, unlike the documented N4 denormalisations elsewhere in the schema.

**Severity:** Moderate. This will cause data inconsistencies in production unless a trigger or consistent update pathway is established.

**Fix:** Remove the column and compute the total with an aggregate query or a database view:
```sql
CREATE VIEW group_donation_totals AS
    SELECT group_id, SUM(amount_nzd) AS total_donations_nzd
    FROM donation
    WHERE payment_status = 'Completed'
    GROUP BY group_id;
```

If denormalisation is genuinely needed for display performance, add a trigger on `donation` that updates the counter whenever `payment_status` changes to or from `'Completed'`.

**Issue 2b — `conservation_group.charity_reg_number` partial transitive dependency**

Also added in the Sprint 5 ALTER:
```sql
ADD COLUMN IF NOT EXISTS is_registered_charity BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS charity_reg_number VARCHAR(50),
```

There is an implied functional dependency: `is_registered_charity = TRUE → charity_reg_number IS NOT NULL`. The inverse is also implied: a non-null `charity_reg_number` means the group is registered. These two columns partially determine each other but neither enforces the other. A group could have `is_registered_charity = FALSE` with a non-null `charity_reg_number`, or `is_registered_charity = TRUE` with a NULL number.

**Fix:** Add a check constraint:
```sql
CONSTRAINT chk_charity_consistency
    CHECK (
        (is_registered_charity = FALSE AND charity_reg_number IS NULL)
        OR (is_registered_charity = TRUE AND charity_reg_number IS NOT NULL)
    )
```

---

#### Sections 6 & 7 — Assets and Records: documented intentional denormalisations (N4)

The `group_id` columns on `trap`, `bait_station`, `trap_catch`, `incidental_obs`, and `bait_station_record` violate 3NF: `group_id` is transitively determined by the asset's `line_id` (since `line_id → group_id` via the `line` table). The schema documents this as N4 and enforces it with triggers on every INSERT and UPDATE. This is a well-reasoned intentional denormalisation — the rationale (eliminating a JOIN on every authenticated request) is valid, and the trigger enforcement means the data cannot drift.

**Verdict: These are documented and acceptable. No fix required.**

---

#### Section 9 — Inventory Management: three issues (most serious)

**Issue 9a — `asset_inventory` uses a polymorphic non-referencing `asset_id` (BCNF violation)**

```sql
CREATE TABLE asset_inventory (
    asset_type  VARCHAR(20) NOT NULL CHECK (asset_type IN ('Trap', 'Bait Station')),
    asset_id    INT         NOT NULL,
    ...
    UNIQUE (asset_type, asset_id)
);
```

The `asset_id` column has no foreign key constraint. PostgreSQL cannot enforce referential integrity conditionally based on `asset_type`. The schema comment says "Application enforces referential integrity; a trigger validates asset_id" — but no such trigger is defined in Section 12. The trigger section only has the N4 group_id sync functions and the bait station custom text check. The promised `asset_id` validation trigger is missing entirely.

This means any integer value can be inserted as `asset_id` regardless of whether a corresponding `trap` or `bait_station` row exists. This is a data integrity gap.

**Severity:** High. Orphaned inventory records are possible.

**Fix option A (preferred):** Split into two tables, eliminating the polymorphic pattern:
```sql
CREATE TABLE trap_inventory (
    id              SERIAL  PRIMARY KEY,
    trap_id         INT     NOT NULL UNIQUE REFERENCES trap(id) ON DELETE CASCADE,
    group_id        INT     NOT NULL REFERENCES conservation_group(id),
    status_id       INT     NOT NULL REFERENCES asset_status(id),
    storage_area_id INT     REFERENCES storage_area(id),
    line_id         INT     REFERENCES line(id),
    purchase_date   DATE,
    updated_by      INT     REFERENCES "user"(id),
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bait_station_inventory (
    id              SERIAL  PRIMARY KEY,
    bait_station_id INT     NOT NULL UNIQUE REFERENCES bait_station(id) ON DELETE CASCADE,
    -- same columns as above
);
```

**Fix option B:** Add the missing trigger that validates `asset_id` against the appropriate table based on `asset_type`.

**Issue 9b — `asset_history` has the same polymorphic problem**

```sql
CREATE TABLE asset_history (
    asset_type VARCHAR(20) NOT NULL CHECK (asset_type IN ('Trap', 'Bait Station')),
    asset_id   INT         NOT NULL,
    ...
);
```

Again, no FK on `asset_id`. The trigger `fn_sync_asset_history_group_id` does look up `asset_inventory` to get `group_id`, which would catch non-existent `asset_id` values indirectly, but only if a matching `asset_inventory` row exists first. If `asset_inventory` itself has an orphaned record, this trigger will silently succeed.

**Fix:** Same as 9a — split into `trap_history` and `bait_station_history`, or add an explicit validation trigger.

**Issue 9c — `from_status` and `to_status` in `asset_history` are free VARCHAR, not FK references**

```sql
from_status  VARCHAR(30),
to_status    VARCHAR(30),
```

The valid status values are defined in the `asset_status` lookup table, but `asset_history` stores them as free text. This means the history log can contain status strings that do not match any current `asset_status` record, and status labels could diverge over time if `asset_status.name` is edited.

**Fix:** Reference the lookup table by ID:
```sql
from_status_id INT REFERENCES asset_status(id),
to_status_id   INT REFERENCES asset_status(id),
```

Similarly, `from_location` and `to_location` are plain `VARCHAR(200)` descriptions. This is more defensible (storage areas and lines have variable names), but it means the history cannot be queried reliably by location — consider storing `from_storage_area_id` and `to_line_id` FKs alongside the text descriptions for queryability.

---

#### Section 10 — Analytics & Badges: two issues

**Issue 10a — `chart_summary` UNIQUE constraint is NULL-unsafe**

```sql
UNIQUE (group_id, chart_type, period_key)
```

In PostgreSQL, `NULL` values are not considered equal for UNIQUE constraint purposes. Since `group_id` is nullable (NULL = platform-wide summary), multiple platform-wide rows with the same `(chart_type, period_key)` can coexist because `(NULL, 'X', 'Y') ≠ (NULL, 'X', 'Y')` in a unique index.

**Fix:** Add a partial unique index for the platform-wide case:
```sql
CREATE UNIQUE INDEX idx_chart_summary_platform
    ON chart_summary (chart_type, period_key)
    WHERE group_id IS NULL;
```

**Issue 10b — `forecast_result` has no uniqueness constraint**

Multiple forecast rows can be inserted for the same `(group_id, forecast_type, forecast_period)`, meaning cached forecasts can accumulate without the old ones being replaced. This is likely unintentional — the table is described as a cache.

**Fix:**
```sql
CREATE UNIQUE INDEX idx_forecast_result_unique
    ON forecast_result (group_id, asset_type, asset_id, forecast_type, forecast_period)
    WHERE group_id IS NOT NULL;

CREATE UNIQUE INDEX idx_forecast_result_platform
    ON forecast_result (forecast_type, forecast_period)
    WHERE group_id IS NULL;
```

---

#### Section 11 — Donations & Gamification: three issues

**Issue 11a — `donation` table contains donor personal data alongside transaction data (3NF violation)**

```sql
CREATE TABLE donation (
    donor_name   VARCHAR(200),
    donor_email  VARCHAR(254),
    is_anonymous BOOLEAN,
    ...
);
```

`donor_name` and `donor_email` describe the donor, not the donation transaction. A donor who makes five donations has their name and email copied into five rows. If a donor updates their email, all historical rows are stale. This is a textbook transitive dependency: `user_id → donor_name, donor_email` (when the donor is a registered user).

The original `create_db.sql` used a separate `donor_profile` table to address this, but that design was not carried forward to `full_schema_all_sprints.sql`.

**Severity:** Moderate. Violates 3NF and creates a GDPR/privacy concern — deleting a user's personal data requires updating every donation row.

**Fix:** Restore the `donor_profile` table and reference it from `donation`:
```sql
CREATE TABLE donor_profile (
    id           SERIAL      PRIMARY KEY,
    user_id      INT         UNIQUE REFERENCES "user"(id) ON DELETE SET NULL,
    display_name VARCHAR(200),
    email        VARCHAR(254),
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE
);
```

Then `donation` references `donor_profile_id` rather than storing name/email inline.

**Issue 11b — `line_sponsorship.stripe_subscription_id` duplicates `donation.stripe_subscription_id`**

Both tables store a `stripe_subscription_id`:
```sql
-- in donation:
stripe_subscription_id VARCHAR(255) UNIQUE,

-- in line_sponsorship:
stripe_subscription_id VARCHAR(255),
```

This means the same Stripe subscription ID is stored in two places, and they must be kept in sync. There is no FK between them, no trigger enforcing consistency, and no unique constraint on `line_sponsorship.stripe_subscription_id`.

**Severity:** Moderate. Could cause reconciliation errors if one is updated without the other.

**Fix:** Remove `stripe_subscription_id` from `line_sponsorship` and look it up via the `donation_id` FK:
```sql
-- Look up via: donation.stripe_subscription_id WHERE donation.id = line_sponsorship.donation_id
```

**Issue 11c — `mystery_box.box_count` is a stored derived value without constraint**

```sql
box_count    INT NOT NULL CHECK (box_count >= 1),
opened_count INT NOT NULL DEFAULT 0,
```

`box_count` is computed from `donation.amount_nzd` (every $5 = 1 box, plus bonuses). If `donation.amount_nzd` is ever updated (e.g. a refund followed by a new amount), `box_count` will not automatically update. There is no trigger linking the two.

This also means `opened_count` can in theory exceed `box_count` with no constraint enforcing `opened_count <= box_count`.

**Fix:**
```sql
CONSTRAINT chk_mystery_box_opened
    CHECK (opened_count >= 0 AND opened_count <= box_count)
```

And document clearly that `box_count` is set once at donation confirmation time and is immutable (add `NOT NULL` on the column and create it only via application logic at donation completion).

---

### Summary of required fixes

| # | Section | Severity | Fix needed |
|---|---------|----------|-----------|
| F1 | S1 Auth | Low | Add `UNIQUE (name, phone)` to `emergency_contact` |
| F2 | S2 Groups | Moderate | Remove `total_donations_nzd`; replace with a view or trigger |
| F3 | S2 Groups | Low | Add `CHECK` constraint enforcing `charity_reg_number` ↔ `is_registered_charity` consistency |
| F4 | S9 Inventory | High | Add missing `asset_id` validation trigger on `asset_inventory` and `asset_history`, or split into typed tables |
| F5 | S9 Inventory | Moderate | Replace `from_status`/`to_status` VARCHAR with FK references to `asset_status` |
| F6 | S10 Analytics | Low | Add NULL-safe unique index on `chart_summary` for platform-wide rows |
| F7 | S10 Analytics | Low | Add uniqueness index on `forecast_result` |
| F8 | S11 Donations | Moderate | Extract donor personal data (`donor_name`, `donor_email`) into a `donor_profile` table |
| F9 | S11 Donations | Moderate | Remove duplicate `stripe_subscription_id` from `line_sponsorship` |
| F10 | S11 Donations | Low | Add `CHECK (opened_count <= box_count)` to `mystery_box` |

**What is correct and should not change:** The documented N4 intentional denormalisations (group_id on record tables), the N1 emergency contact extract, the N2 slug retain, the N3 `allow_custom_text` removal, all of Sections 3–5 and 8, and the overall separation of system roles from group-scoped roles. The schema foundations from Sprint 1 are solid — the issues are concentrated in the Sprint 3 inventory polymorphism and Sprint 5 donation modelling.