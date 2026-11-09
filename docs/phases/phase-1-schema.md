# Phase 1 — Schema Design (APPROVED 2026-11-09)

Status: **approved by the user 2026-11-09** with these answers: Q1 remove most client deletes (students keep delete only on own emergency contacts; no client deletes for admins); Q2 students can chat only while the alert is `active` or `acknowledged`; Q3 max 3 emergency contacts enforced in the DB. Everything else approved as written. Nothing below except "Already applied" exists until its migration is applied. Basis: PRD 5.1, 7.5, 7.6; decisions D-004, D-006, D-012, D-016, D-017, D-019, D-020, D-022, D-027, D-028, D-034, D-043; approach "keep and extend" (user, 2026-11-09). Dev project `bthjjlpylvauiolwrdfn`, test data is disposable.

## 1. Already applied (baseline, read from the live DB on 2026-11-09)
Applied on 2026-11-08 through 16 migrations whose SQL is not in the repo. Phase 1 saves a snapshot as `web/schemas/0000_baseline_applied_2026-11-08.sql` (documentation only, never re-run). The template files `0001`–`0003` target columns that do not exist in the live DB (`"user"`, `name`, `username`); they are stale and are left in place (append-only) with a note in `web/schemas/README.md`.

| Table | Columns (live) |
|---|---|
| `profiles` | id (FK auth.users, cascade), full_name, student_id, university_email (unique), phone (nullable), role `user_role`, created_at, updated_at |
| `emergency_contacts` | id, user_id (FK profiles, cascade), name, phone, created_at |
| `alerts` | id, user_id, status `alert_status`, started_at, acknowledged_at, resolved_at, cancelled_at, first_latitude, first_longitude, last_updated_at |
| `locations` | id, alert_id (cascade), user_id, latitude, longitude, accuracy, recorded_at |
| `messages` | id, alert_id (cascade), sender_id, body, sent_at, read_at |

Also live: enums `alert_status` (active, acknowledged, resolved, cancelled) and `user_role` (user, admin); helper functions `is_admin()`, `current_role()`, `current_user_id()`; triggers `set_updated_at`, `set_alert_status_timestamps`, `on_auth_user_created` → `handle_new_user()` (domain check on `auth.users`); 28 RLS policies; Realtime publication contains alerts, locations, messages; `anon` has no table grants.

## 2. Proposed changes (each is a new numbered migration)

### 2.1 `0006` profiles: verification state and format constraints
| Change | Detail | Source |
|---|---|---|
| New column `email_verified_at timestamptz null` | Verification state. Set by server after OTP verifies, together with `email_confirm: true` (D-043). Not writable by clients | PRD 7.5, D-043 |
| CHECK `student_id ~ '^B[0-9]{9}$'` | Same regex as Flutter and Zod | D-020 |
| UNIQUE `student_id` | Replace the plain index `idx_profiles_student_id` | PRD 5.1 / Phase 1 step 5 |
| CHECK `university_email = lower(university_email) and university_email ~ '^[^@]+@jnu\.ac\.bd$'` | In addition to the existing trigger check | PRD 5.1 |
| CHECK on `phone` when not null | **Proposed:** `^(\+880)?[0-9]{10,11}$` (D-020 says "digits, optional +880"; the length bounds are my addition). Same rule on `emergency_contacts.phone` | D-020 (length proposed) |
| `handle_new_user()` | **Not changed** (user declined the trigger change 2026-11-09). Trim and uppercase of `student_id` is done by server code in Phase 2; the CHECK rejects anything that is not exactly `B` + 9 digits | D-020 |
| Existing rows | The 3 test profiles have no valid student ID (0 of 3 match). **Decided 2026-11-09 (user declined rewriting them):** existing rows are not touched; the student-ID check is added `NOT VALID` (new rows and any UPDATE of a row are checked; old rows are not scanned). Consequence: those 3 rows cannot be updated until their ID is fixed, then `validate constraint` runs. The RLS matrix uses fresh test users | user |

### 2.2 `0007` OTP and rate-limit tables (D-006, D-012, D-016, D-019)
RLS enabled, **no policies**, `revoke all` from `anon` and `authenticated`, grants to `service_role` only.

`otp_purpose` enum: `email_verification`, `password_reset`.

`otp_codes`
| Column | Type | Notes |
|---|---|---|
| id | uuid pk | `gen_random_uuid()` |
| user_id | uuid not null | FK `auth.users(id)` on delete cascade |
| purpose | `otp_purpose` not null | |
| code_hash | text not null | HMAC of the code with a server secret; plaintext never stored |
| expires_at | timestamptz not null | created_at + 10 min (set by server) |
| attempts | smallint not null default 0 | server enforces max 5 |
| consumed_at | timestamptz null | single use |
| invalidated_at | timestamptz null | set when a newer code is issued |
| created_at | timestamptz not null default now() | |

Indexes: `(user_id, purpose, created_at desc)`; partial UNIQUE `(user_id, purpose) where consumed_at is null and invalidated_at is null` so at most one live code per user and purpose.

`otp_send_events` (resend cooldown 60 s, 3 sends per 15 min, both configurable in server code)
| Column | Type | Notes |
|---|---|---|
| id | uuid pk | |
| email | text not null | lowercase; keyed by email so unknown addresses are limited too without revealing existence |
| purpose | `otp_purpose` not null | |
| created_at | timestamptz not null default now() | |

Index `(email, purpose, created_at desc)`. Old rows are deleted by server code on each send; no pg_cron (not installed) is proposed. Sessions need no table (D-005, Supabase tokens). New server secret for the code hash (name chosen in Phase 2, added to `.env.example` then).

### 2.3 `0008` RLS and grant hardening of the existing policies
Review of the live policies against PRD 7.6 found these gaps (all confirmed from the policy and grant listing):
| # | Gap today | Proposed fix |
|---|---|---|
| H1 | `students insert own alerts` checks only `user_id`; a student can insert an alert with status `resolved` or any timestamps | WITH CHECK also `status = 'active'` |
| H2 | `students insert own locations` checks only `user_id`; `alert_id` can point at another student's alert | WITH CHECK the alert belongs to the student and is `active` or `acknowledged` |
| H3 | `students mark read on own threads` is a row policy with UPDATE granted on all columns; a student can edit `body` or `sender_id` | Column grant: `update (read_at)` only for `authenticated` on `messages` |
| H4 | `authenticated` has UPDATE on all `profiles` columns; `student_id`, `university_email`, and the new `email_verified_at` are client-editable (only `role` is pinned) | Column grant: `update (full_name, phone)` only |
| H5 | Student DELETE on own profile, messages, locations; admin DELETE on all five tables, from clients | **Decided Q1:** drop those policies and revoke DELETE from `authenticated` on profiles, alerts, locations, messages; students keep delete on own emergency contacts |
| H6 | Students can post messages on resolved or cancelled alerts | **Decided Q2:** student INSERT only on own alert with status `active` or `acknowledged`; admins can still post on any thread |
| H7 | No limit on emergency contacts (PRD: add 2–3 after first login) | **Decided Q3:** trigger rejects a fourth contact per student (advisory lock against concurrent inserts); minimum of 2 stays app-side |
| H9 | `admins insert messages on any thread` does not check `sender_id`, so an admin can post as another user | WITH CHECK also `sender_id = auth.uid()` (found while writing 0008) |
| H8 | Security-definer helpers in `public` (`is_admin`, `current_role`, `rls_auto_enable`) may be callable through the API | Check with `get_advisors` (step 11) and revoke execute from `anon` where not needed |

### 2.4 Columns beyond the PRD table already on `alerts`
`acknowledged_at` (needed by PRD 5.6 reports), `cancelled_at`, `first_latitude`, `first_longitude`, `last_updated_at`. They exist now; the phase rules say to ask before adding. **Proposed: keep all five** (reports need `acknowledged_at`; the others support the cancel flow, the initial location in PRD 5.2, and the dashboard "latest update"). Drop any you do not want.

### 2.5 Realtime (step 8)
`alerts`, `locations`, `messages` are already in `supabase_realtime`. No change planned. Step 8 verifies replica identity and that an authenticated student only receives their own rows (RLS applies to Postgres Changes).

### 2.6 Admin provisioning (D-017, PRD 5.1)
**Proposed:** admins register through the normal signup and OTP flow with their own `@jnu.ac.bd` email and student ID, then the project team promotes the verified account with a one-off SQL statement run through MCP (`update public.profiles set role = 'admin' where university_email = ...`). The existing client policy already stops a student changing their own role. This keeps `student_id` NOT NULL and the domain rule uniform. Procedure saved as `web/schemas/admin-provisioning.md` (a runbook, not a migration). The existing admin test row keeps its non-conforming ID for now (see 2.1).

### 2.7 Additions found during verification (2026-11-09)
| # | Finding | Fix |
|---|---|---|
| A1 | Advisors: 3 functions with mutable `search_path`; 4 security-definer functions executable by `anon`/`PUBLIC`; unindexed FK `messages.sender_id` | `0009_advisor_fixes.sql` (mechanical, no behavior change). `is_admin()` and `current_role()` stay executable by `authenticated` because RLS policies call them |
| G1 | A student cancelling their own alert can also set `acknowledged_at`, `resolved_at`, `cancelled_at`, first coordinates (reports count `acknowledged_at`) | `0010_client_write_guards.sql`: trigger pins those columns for a signed-in non-admin; admins and service role unaffected. **Approved by user 2026-11-09 (D-045)** |
| G2 | Students can set `sent_at` and `read_at` on message insert | `0010`: insert grant limited to `alert_id, body, sender_id`. **Approved (D-045)** |
| O1 | Earlier migrations granted `select/insert/update/delete` on `auth.users`, `auth.identities`, `auth.sessions`, `auth.flow_state`, `auth.one_time_tokens`, `auth.mfa_*` to `authenticator` and `service_role` as a workaround for a 500 on password grant that the last baseline migration shows was caused by NULL string columns on a hand-inserted probe user. These grants may be unnecessary. **Not changed**; flagged for your decision | none yet |

## 3. Migration plan
`0000` baseline (verbatim copy of the 16 migrations applied 2026-11-08; documentation only, never re-run) · `0004`/`0005` D-032 test bypass and restore (applied via MCP) · `0006` profiles (applied manually by user) · `0007` OTP tables (applied via MCP) · `0008` RLS hardening (applied manually by user) · `0009` advisor fixes · `0010` client write guards · admin provisioning runbook `admin-provisioning.md` · Realtime verified, no migration · types regenerated into `web/types/database.types.ts`.

## 4. Test plan (steps 11–12)
Advisors clean of critical findings; RLS matrix with student A, student B, admin and anon over all seven tables including each gap above (A cannot insert a location on B's alert, cannot edit `body`, cannot set `student_id`, cannot insert a non-active alert); results saved to `phase-1-rls-test-matrix.md`.
