# Sprint 1 Work Order — Required Epic

## Context

This work order is written against **Sprint1.md** (the Required Epic), not the original PF-LU
SCRUM sprint. The Required Epic involves:

- Renaming the application and building a multi-group architecture
- Replacing the single Admin role with Super Admin, Group Coordinator, Operator, and Observer
- Extending lines to support both Trap Lines and Bait Station Lines
- Reworking authentication to support group selection after login

The new database schema (`create_db.sql`) adds `group_id` as a `NOT NULL` foreign key on
`line`, `trap`, `bait_station`, `trap_catch`, `bait_station_record`, and `incidental_obs`.
**Every route that creates or reads these records must have an active group in session.**
This is a critical architectural difference from the original codebase.

---

## Hard Dependency Chain — Read Before Starting

```
US3 (auth baseline)
  └─► US4 (group selection session)
        └─► ALL other stories that touch group-scoped data
              │
              ├─► US5 (apply to create group)
              │     └─► US6 (Super Admin approves → group exists in DB)
              │           └─► US17 (manage groups), US19 (set public/private),
              │                US20 (join requests), US9 (assign operators)
              │
              ├─► US7, US8, US10 (lines — require group_id in session)
              │
              └─► US11, US12, US13, US14, US15 (bait stations — require group_id in session)
```

**No story that touches a line, trap, bait station, or member record can be fully implemented
until US3 and US4 provide an active `group_id` in the session.** Person A must deliver US3
and US4 before Persons B–E begin integration work.

---

## Story Count

Sprint1.md defines **21 user stories**: US1–US15 and US17–US21 (US16 does not appear in
Sprint1.md and should not be referenced anywhere in this sprint).

---

## 5-Person Allocation

### Person A — Authentication & Group Bootstrapping (4 stories)

**Stories:** US3, US4, US5, US6

**Deliver in this order:** US3 → US4 → US5 → US6

| Story | Summary | Key implementation notes |
|-------|---------|--------------------------|
| US3 | Single account login | Standard username/password login. Also implements forgot-password flow (secure expiring link via `password_reset_token` table) and the "Login with Email Code" OTP flow (6-digit code, 10 min expiry, stored in a `login_otp` table). Neither table exists yet — Person A must add both to the schema. |
| US4 | Post-login group selection | After successful login, query `group_membership` for the user's groups. If one group → go straight to that group's dashboard. If multiple → show group picker (name, logo, user's role in each). If none → show "you don't belong to any group yet" page with options to browse or apply. **Write `group_id` and `group_role` into session here — all other persons depend on this.** |
| US5 | Apply to create a new group | Logged-in users submit a group creation application. Form must capture: group name, description, and proposed visibility (Public/Private — add `proposed_visibility` column to `group_application` table, currently missing from schema). Rejected applications must pre-fill the form on resubmit. |
| US6 | Super Admin reviews applications and appoints GC | Super Admin sees pending applications with name, description, visibility, and applicant info. On approval: create the `conservation_group` row, immediately prompt to appoint applicant as Group Coordinator (single notification covers both approval and appointment). On rejection: notify applicant with reason, pre-fill form for resubmit. If coordinator appointment is skipped, flag group in admin panel as needing a coordinator. |

**Person A also owns:** Adding `proposed_visibility` to `group_application`, adding
`password_reset_token` and `login_otp` tables to the schema, and confirming that `user.role_id`
is only used to mark Super Admin status (per-group roles live in `group_membership.group_role`).

---

### Person B — Discovery, Visibility & Join Flow (4 stories)

**Stories:** US1, US2, US19, US20

**Dependency:** US6 must be complete (groups must exist in the DB) before integration testing.
UI work can begin in parallel using fixture data.

| Story | Summary | Key implementation notes |
|-------|---------|--------------------------|
| US1 | Homepage showing all groups | New homepage style, unrelated to PF-LU. Public groups: show tile/image (add `logo_url` to `conservation_group`) and short description. Private groups: visible but show "Apply to Join" instead of a direct link. Note: `conservation_group` is also missing a `region` column needed for Sprint 2 filtering — add it now as a nullable field to avoid a later migration. |
| US2 | Public group detail page | Show group name, logo, full description, operational area description (add `operational_area_description TEXT` column to `conservation_group`), and public activity info. Show "Join" option. Private group click → redirect to join application page; inform user request is pending. |
| US19 | Group Coordinator sets public/private | Toggle in group settings. Public → any logged-in user can join as Observer without approval. Private → new users must submit join request. Switching from Public to Private retains existing members. Log change with actor and timestamp. |
| US20 | Group Coordinator approves/rejects join requests | Show pending requests: applicant username, message, date. Approve → add to `group_membership` as Observer, notify user. Reject → notify with reason, pre-fill request for resubmit. If group is public, this section is not visible. |

**Person B also owns:** Adding `logo_url`, `operational_area_description`, and `region`
(nullable) columns to `conservation_group`.

---

### Person C — Governance, Roles & Admin Control (4 stories)

**Stories:** US17, US18, US21, US9

**Dependency:** US6 (groups exist), US4 (group session). US9 also depends on US7 (lines exist).

| Story | Summary | Key implementation notes |
|-------|---------|--------------------------|
| US17 | Super Admin manages groups and appoints GCs | List all groups with name, public/private status, assigned GC, member count. Edit group info (name, description, tile image, visibility) — changes reflect immediately on homepage. Appoint/reassign GC: previous GC loses coordinator permissions for that group, both old and new are notified, change is logged. Groups without a GC are flagged. |
| US18 | Super Admin manages system reference data | Manage species, trap types, bait types, active ingredients. New entries appear immediately in all group forms. Editing updates all forms. Deleting an in-use entry: warn user, require confirmation, do not break existing records. All changes logged. Note: `trap_type` is currently a hardcoded `CHECK` constraint — Person C must migrate it to a `trap_type` lookup table consistent with `species`, `bait_type` etc. |
| US21 | Group Coordinator manages member roles | Member list in three tabs: Coordinators / Operators / Observers. Promote Observer → Operator or demote Operator → Observer: permissions update immediately, member is notified, change logged. Remove member: loses access immediately, records intact. If GC is the only coordinator, the demote button for their own entry is disabled. GC cannot see a "remove" button for themselves. |
| US9 | Assign Operators to Lines | Only same-group Operators appear in the selection list. Lines already assigned to the Operator are excluded from the dropdown (prevent duplicate assignments). On assignment: Operator receives a Line Assignment badge notification and can choose to display or hide it on their profile. On removal: Operator loses edit permissions immediately; previously submitted records remain. When a line is retired: all its Operator assignments are removed automatically. |

---

### Person D — Lines & Trap Infrastructure (4 stories)

**Stories:** US7, US8, US10, US11

**Dependency:** US4 (group_id in session). Integration testing requires US6.

| Story | Summary | Key implementation notes |
|-------|---------|--------------------------|
| US7 | Create lines | Lines are scoped to the current group (`group_id` from session, `NOT NULL`). Create form is pre-set to either Trap or Bait Station type based on which tab the GC clicked — no type selection needed. **Required fields: unique line name within the group, and a colour for map display** (colour is new — add a `colour` column to the `line` table). Validation: duplicate name within group is rejected with the form pre-filled. Non-GC users see no create option. |
| US8 | Edit and retire lines | Edit form pre-filled with current values; updatable fields are name and colour. Duplicate name within group is rejected. Retiring a line: status → retired, line disappears from active list, all assigned Operators are notified automatically. Retired lines: historical records are readable but cannot be edited; no new records can be added. |
| US10 | View lines and assets | Lines displayed in two tabs: Trap Lines and Bait Station Lines. Each line shows name and colour. Line detail lists assets in set order with code and current status. Empty-state message when no assets exist. Group members see only lines for their currently selected group. GCs can drag assets to reorder; order saves automatically and is immediately visible to all members. |
| US11 | Create bait stations | Bait stations are scoped to the current group. Required fields: unique code within group, bait station type (from predefined list), latitude, longitude. **If "Other" is selected as the type, a free-text sub-type field becomes required** — this is easy to miss. Validation: duplicate code or missing fields → form stays open with values intact and each field highlighted individually. |

**Person D also owns:** Adding `colour VARCHAR(20) NOT NULL DEFAULT '#3d7a2e'` to the `line`
table and confirming `line.group_id` is wired correctly in all route handlers.

---

### Person E — Bait Station Record Lifecycle (4 stories)

**Stories:** US12, US13, US14, US15

**Dependency:** US11 (bait stations exist), US4 (group session). US13/US14 also depend on US9
(Operator must be assigned to a line before they can add records).

| Story | Summary | Key implementation notes |
|-------|---------|--------------------------|
| US12 | Edit and retire bait stations | GC can edit bait station type and coordinates (code is immutable). Retiring: station disappears from active assignment and recording lists; no new records can be added. Historical records remain readable but not editable. Validation mirrors US11 — form stays open with values intact on failure. |
| US13 | Operators add bait station records | Operator must be assigned to the line. Required fields: date/time (ISO 8601), target species, active ingredient, formulation, concentration, bait remaining (kg). Optional: recorded by, bait removed (kg), bait added (kg), notes. Retired bait stations show no "add record" option. Offline state: form is not accessible; show "You are offline. Records can be added once connection is restored." |
| US14 | Operators edit their own bait station records | Operators can update any field in records they submitted. Records by other users show no edit option. GCs can edit or delete any record in their group regardless of who submitted it. Same offline message as US13. |
| US15 | View and filter bait station records | Records in reverse chronological order with pagination. Each row shows: date/time, target species, active ingredient, bait remaining, recorded by. Filters: date range, line, station, active ingredient, species. No-results message when filters match nothing. Resetting filters restores full list. Only records for the currently selected group are shown. |

---

## Suggested Delivery Timeline

| Phase | Who | What | Gate |
|-------|-----|------|------|
| Week 1, days 1–2 | Person A | US3 (auth), US4 (group session) | Session writes `group_id` — unblock others |
| Week 1, days 3–5 | All | Begin UI scaffolding against fixture data | US3/US4 stable |
| Week 2 | Person A | US5, US6 | Groups exist in DB |
| Week 2 | Person B | US1, US2 | US6 complete for integration |
| Week 2 | Person C | US17, US18 | US6 complete |
| Week 2 | Person D | US7, US8, US10 | US4 complete |
| Week 3 | Person B | US19, US20 | US1/US2 stable |
| Week 3 | Person C | US21, US9 | US17 stable, US7 complete |
| Week 3 | Person D | US11 | US8 stable |
| Week 3 | Person E | US12, US13, US14, US15 | US11 complete, US9 complete |

---

## Schema Changes Required Before Development Begins

The following changes must be made to `create_db.sql` and coordinated across the team
**before** anyone starts route work:

| Change | Owner | Reason |
|--------|-------|--------|
| Add `proposed_visibility VARCHAR(20)` to `group_application` | Person A | US5 requires capturing public/private for the proposed group |
| Add `password_reset_token` table | Person A | US3 forgot-password flow |
| Add `login_otp` table | Person A | US3 email code login flow |
| Add `logo_url VARCHAR(255)` to `conservation_group` | Person B | US1, US2 group tiles |
| Add `operational_area_description TEXT` to `conservation_group` | Person B | US2 group detail page |
| Add `region VARCHAR(100)` (nullable) to `conservation_group` | Person B | Needed for Sprint 2; add now to avoid later migration |
| Migrate `trap.trap_type` CHECK to a `trap_type` lookup table | Person C | US18 Super Admin manages trap types dynamically |
| Add `colour VARCHAR(20) NOT NULL DEFAULT '#3d7a2e'` to `line` | Person D | US7 lines require a colour for map display |
| Add audit log entries for role/membership changes | Person C | US17, US21 require logged actor + timestamp |

---

## What Each Person Must Not Assume

- **Do not assume `session['role']` is the user's group role.** `session['role']` reflects the
  global role (Super Admin vs. everyone else). The per-group role comes from
  `group_membership.group_role` and should be stored separately in session as
  `session['group_role']` after US4 group selection.

- **Do not use the old `Admin` role name** anywhere in route guards, templates, or tests.
  The new roles are `Super Admin`, `Group Coordinator`, `Operator`, `Observer`.

- **Do not scope queries without `group_id`.** Every query against `line`, `trap`,
  `bait_station`, `trap_catch`, `bait_station_record`, and `incidental_obs` must include a
  `WHERE group_id = %s` clause using the session value.

- **US16 does not exist in Sprint1.md.** Do not implement or reference it.
