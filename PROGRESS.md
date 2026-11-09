# PROGRESS

Last updated: 2026-11-09
**Current phase:** Phase 2 closed 2026-11-09. Phase 3 NOT STARTED: the user asked to stop before Phase 3 (2026-11-09); waiting for an explicit go-ahead. Phase 3 gating decisions D-053 to D-056 are already recorded

Legend: `[ ]` pending · `[~]` in progress · `[x]` done (with evidence) · `[!]` blocked

## Phase overview
| # | Phase | Status | Depends on |
|---|---|---|---|
| 0 | Prerequisites, accounts, scaffolding | Done 2026-11-09 (user-confirmed; device run deferred, D-042) | — |
| 1 | Supabase schema, RLS, domain enforcement, custom auth data model | Done 2026-11-09 (user-confirmed; open items B-008, B-009, B-012 carried) | 0 |
| 2 | OTP lifecycle + Brevo integration (server) | Done 2026-11-09 (user-confirmed; both real emails looked good) | 1 |
| 3 | Auth flows: Flutter + Admin web | Not started | 2 |
| 4 | SOS flow + live alerts list | Not started | 3 |
| 5 | Live location + Leaflet map | Not started | 4 |
| 6 | Real-time chat | Not started | 4 |
| 7 | Photo/video capture + local gallery | Not started | 3 (SOS integration: 4) |
| 8 | Reports + CSV export | Not started | 4 |
| 9 | Full testing, bug fixing, demo/report prep | Not started | 1–8 |

## Planning tasks (this session)
- [x] Analyze PRD
- [x] Create `app/`, `web/`, `docs/` structure
- [x] Write roadmap, architecture, decisions, guidelines, per-phase docs
- [x] Write CLAUDE.md and CLI skills
- [ ] User answers open questions (see below)

## Phase 0 tasks
Status: In progress (started 2026-11-09). Spec: `docs/phases/phase-0-prerequisites.md`.
- [x] 1. Toolchain: Node v24.22.1, npm 11.19.0 (npm per D-035), Flutter 3.47.2 stable (`flutter --version` output). `flutter doctor` not yet run.
- [x] 2. Supabase project ref `bthjjlpylvauiolwrdfn`; user confirmed 2026-11-09 it is a dev project with disposable data (existing tables: profiles 3 rows, emergency_contacts 5, alerts 12, locations 5, messages 3; all RLS on). Phase 1 may replace them.
- [x] 3a. MCP connected: `get_project_url` and `list_tables` returned. Tool list not yet documented in `docs/05-supabase-mcp-workflow.md`.
- [x] 3b. MCP tool list documented in `docs/05-supabase-mcp-workflow.md`
- [~] 4. web: `npm install`, `npx tsc --noEmit`, `npm run lint`, `npm run build` all pass (2026-11-09). `npm audit fix` (non-breaking) cleared the high-severity finding; `npm audit` still NOT 0: 13 remain (2 low, 11 moderate) via direct dev deps `shadcn` and `eslint-config-next`; the offered fix is a breaking `--force` change to shadcn (B-005). `.env.local` already exists with the same variable names as the example (values not read), gitignored.
- [x] 5. app: Flutter upgraded to 3.47.9 / Dart 3.13.7 (D-039); `flutter pub get` OK; about, gallery, onboarding removed, posts kept (D-038); `dart run scripts/check.dart` output: format OK, analyze 0 issues, 28 tests passed, "All checks passed". App docs updated. Not yet built as APK.
- [x] 6. `web/.env.example` exists with names and is tracked; compared against `.env.local` by name only. 2026-11-09: user asked to add Brevo names: added `BREVO_API_KEY`, `BREVO_SENDER_EMAIL`, `BREVO_SENDER_NAME` (empty; user fills real values in `web/.env.local`). Names are the agent's choice (not in docs); `config/env.config.ts` not yet wired (Phase 2).
- [x] 7. Git repo already exists at project root (commit `a93da74 init`, no remote), so no `git init` needed; only `web/.env.example` tracked among env files. `web/.gitignore` covers `.env*`; `app/.gitignore` covers `*.env`.
- [x] 8. Brevo: user added real values to `web/.env.local` (2026-11-09); verified-sender status not independently confirmed
- [x] 9. (device run deferred to Phase 3 by user, D-042) Smoke tests: web `npm run dev` served `/`, `/login`, `/signup` all HTTP 200 (2026-11-09). `next dev` had appended a block to `web/AGENTS.md` pointing at `node_modules/next/dist/docs/`; removed and disabled with `agentRules: false` in `web/next.config.ts` (D-041); verified after a fresh `next dev` run (HTTP 200, block not regenerated, `tsc` clean). App: `flutter build apk --debug --dart-define-from-file=config/dev.json` succeeded (`Built buildpp\outputslutter-apkpp-debug.apk`, 2026-11-09); emulator/device run NOT done, blocked by B-006.

### Phase 0 verify-phase run (2026-11-09)
- PASS web: `npm run build` compiled, `npm run lint` clean, `npx tsc --noEmit` exit 0; dev server 200 on `/`, `/login`, `/signup`. `npm audit` 13 low/moderate = accepted exception (D-040).
- PASS app: `dart run scripts/check.dart` all passed (28 tests); `flutter build apk --debug` built `app-debug.apk`.
- PASS MCP: `get_project_url`, `list_tables` returned; tool list in docs/05.
- PASS security sweep: no secret names in `app/lib|config|test`; no extra `NEXT_PUBLIC_` vars; only `web/.env.example` tracked, `web/.env.local` gitignored; one `console.error` in `web/lib/api/server-navigation-helper.ts` logs status, message, url only (no tokens).
- PASS env: Brevo names in `.env.example`; user states real values added to `.env.local` (values not read).
- NOT DONE: app run on emulator/device. `flutter devices` fails: adb protocol fault, port 5037 held by Code.exe; same error on port 5038; no Android emulator or AVD installed (`D:\Flutter\AndroidSDK\emulator` missing). Brevo sender verification status not confirmed by agent (Q-002).
- Hosting Q-005: Vercel (recorded).

## Phase 2 tasks
Status: DONE 2026-11-09, user-confirmed. Spec: `docs/phases/phase-2-otp-brevo.md`. Prerequisite Phase 1 done and user-confirmed. `web/.env.local` has all 9 variables filled (names checked, values not read), including BREVO_API_KEY / BREVO_SENDER_EMAIL / BREVO_SENDER_NAME.
- [x] T0. (D-046) Done: the 4 template files were rewritten for the real schema, types regenerated after 0011 (`database.types.ts`), `npx tsc --noEmit` = 0 errors, lint clean, build OK
- [x] 0. Email design approved by user 2026-11-09 (D-049): `docs/email-previews/otp-email.html`; sent as HTML only
- [x] 1. Brevo API verified from official docs 2026-11-09 (read by a web-fetch subagent; pages: developers.brevo.com/reference/sendtransacemail, /docs/send-a-transactional-email, /docs/api-limits, /docs/limit-headers). VERIFIED: `POST https://api.brevo.com/v3/smtp/email`; header `api-key: <key>` (guide also lists `content-type: application/json`, `accept: application/json`); body `sender {name (max 70), email}` (must be registered and verified), `to [{email, name?}]`, `subject`, `htmlContent`, `textContent`; success 201 with `messageId`; 400 body `{code, message}`; 429 on rate limit with `x-sib-ratelimit-limit/-remaining/-reset` headers; POST /v3/smtp/email limit 1,000 RPS on the general tier. NOT STATED in docs: whether `htmlContent` and `textContent` may be sent together (the guide says to pick ONE body type per request, which conflicts with D-037's plain-text fallback); error shape for an unverified sender; 401/403 bodies; htmlContent size limit. The reference also lists an OAuth `Authorization` bearer header without saying how it relates to `api-key`; we use `api-key` only. Decision on both-bodies pending (B-013)
- [x] 2. Env names confirmed (D-048); `.env.example` updated (OTP_* added, JWT_* removed); `config/env.config.ts` reads Brevo and OTP settings; user set `OTP_HASH_SECRET` (64 chars) in `.env.local`. NOTE: `.env.local` still contains the old JWT_* lines (unused now); safe to delete
- [x] 3. `docs/api-contract.md` drafted and APPROVED by user 2026-11-09 (D-050), R1-R7 as written. A security flaw in the first R6 draft (password replacement on re-register) was found in self-review and fixed before approval
- [x] 4. OTP generation and storage: `lib/otp.ts`, `services/otp.service.ts`, DB functions in `0011_otp_functions.sql` (user ran it manually; verified by MCP: 5 functions, EXECUTE only for postgres/service_role). Evidence: `tests/integration/otp-rules.test.ts` 24 passed (hash-only storage, 600 s expiry, zero attempts, code equals HMAC of the emailed code, one live code per user+purpose)
- [x] 5. OTP verification rules: tested against the real DB: expired code rejected, 5 wrong attempts then the 6th (even correct) refused, correct code on attempt 5 accepted, 12 parallel guesses -> exactly 5 counted and 7 refused, single use (parallel consume -> exactly one wins), superseded code rejected, code does not cross users or purposes (otp-rules.test.ts, auth-flows.test.ts)
- [x] 6. Throttling: 60 s cooldown rejects an immediate second send with retry_after_seconds 1-60 and sends no email; 4th send in the window refused with a retry time; window expiry restores sending; limits are per email and per purpose (otp-rules.test.ts)
- [x] 7. Brevo client: unit tests with mocked fetch (email.test.ts): correct URL, `api-key` header, HTML-only body, only HTTP 201 counts as sent (400/401/403/429/500/502/200/202 and network errors do not), logs and returned errors contain neither the code, the API key nor the provider body. Failed send leaves no live code and does not count toward the limit (5 failures in a row do not exhaust the limit). REAL delivery still to be tested (task 13)
- [x] 8. Register: non-university and look-alike domains rejected on the server (422 email_domain_not_allowed), account created UNVERIFIED with no session or code in the response, email/student-ID normalised, 409s, concurrent registration yields one account, unverified re-register keeps the original password (auth-flows.test.ts). A bug found by the concurrency test (500 when two registrations raced) was fixed in `AuthService.register`
- [x] 9. Verify: wrong code -> otp_invalid with attempts_remaining, right code -> verified (profile `email_verified_at` set and Auth user confirmed), no session in the response, reuse -> otp_not_found, unknown email indistinguishable (auth-flows.test.ts)
- [x] 10. Login/refresh/logout/me: unverified login 403 with no session, Supabase itself refuses an unverified user without our API (D-043), verified login returns user + Supabase session, wrong password and unknown email identical 401, refresh rotates the refresh token, logout revokes that session only (its refresh token dies, other sessions live). OBSERVED: the access token of a logged-out session is refused by `/me` with 401 at once (our per-request `getUser` check), although Supabase documents that such tokens stay valid until expiry. Admin login: student -> 403 not_admin and no session; admin -> 200 (auth-flows.test.ts)
- [x] 11. Password reset: unknown email gets the same answer and no email; reset sets the new password, old password fails, sessions that existed before the reset are revoked (old refresh token 401), code single use, wrong code leaves the password unchanged, weak password rejected before the code is touched, resetting an unverified account verifies the email (auth-flows.test.ts)
- [x] 12. `withAdmin` / `withAuth` exercised with real tokens: no token 401, student 403 not_admin, admin 200, and demoting an admin makes the same still-valid token 403 on the next request (role re-read every time); a profile with `email_verified_at` cleared is refused 403 even with a valid Supabase token
- [x] 13. Tests complete 2026-11-09. AUTOMATED: `npm test` = 5 files / 81 unit tests passed; `npm run test:integration` = 2 files / 64 tests passed against the real dev project with email mocked (domain subdomain test included; 0 leftover test users/otp rows/send events afterwards); `npx tsc --noEmit` 0 errors; `npm run lint` clean; `npm run build` OK with all 10 auth routes; trigger-level domain check 13/13 (rolled back). MANUAL REAL-EMAIL (user inbox `b210305040@cse.jnu.ac.bd`, throwaway account with fake student ID B999999999, deleted afterwards): register -> Brevo HTTP 201, DB row correct (unverified, live, 600 s, 64-hex HMAC, 1 send recorded); user read the 6-digit code from the real inbox -> verify HTTP 200, login 200, /me 200 (role user); forgot-password -> second real email (user read the reset code); reset with `12345678` -> HTTP 422 validation_failed (very-common-password rule, code untouched: 0 attempts, still live); reset with a generated password and the same code -> 200, old password 401, new password 200, reset code consumed; account deleted, DB back to 3 users / 3 profiles / 0 otp rows. Earlier mis-addressed send: one verification email went to `b210305040@jnu.ac.bd` (not the user's address) before the correction. No Supabase email: auth logs for the 10:47-10:53Z integration run and the 11:04-11:13Z manual run show 0 confirmation/recovery/invite events, 0 SMTP and 0 real mail mentions. Secret-value sweep (SUPABASE_SECRET_KEY, OTP_HASH_SECRET, BREVO_API_KEY) over .next/static, app/, web source, public/, docs/: none found

## Phase 1 tasks
Status: DONE 2026-11-09, user-confirmed. Spec: `docs/phases/phase-1-database-rls.md`. Prerequisite Phase 0 done and user-confirmed (D-042).
- [x] 1. MCP baseline (2026-11-09, read-only). Project already holds a schema applied 2026-11-08 via 16 migrations (`initial_schema_*`, `fix_*`, `harden_profiles_role_policy`, `grant_gotrue_*`, `normalize_auth_users_string_columns`) whose SQL is NOT in `web/schemas/` (repo has only template 0001-0003). Tables: profiles (3 rows), emergency_contacts (5), alerts (12), locations (5), messages (3); RLS on, 28 policies, `is_admin()`/`current_role()` security-definer helpers, triggers `set_updated_at`, `set_alert_status_timestamps`, `on_auth_user_created`→`handle_new_user`; enums `alert_status` (active, acknowledged, resolved, cancelled) and `user_role`; Realtime publication already contains alerts, locations, messages; `alerts` already has acknowledged_at, cancelled_at, first_latitude/longitude, last_updated_at. GAPS vs docs: no CHECK on `student_id` or on `@jnu.ac.bd` email, `student_id` not unique, no verification-state column, no OTP/reset/rate-limit tables, `profiles.phone` nullable, no `web/schemas` mirror of applied SQL, advisors not yet run, RLS matrix not run.
- [x] 2. Close open decisions. D-032 verified empirically 2026-11-09 (results in docs/03; migrations 0004 bypass and 0005 restore applied via MCP, function md5 restored, users 3/profiles 3, test user deleted); user chose option A + profile flag (D-043). Existing-DB approach decided: keep and extend. Still open: schema doc approval.
- [x] 3. `docs/phases/phase-1-schema.md` written and approved by user 2026-11-09 (D-044)
- [x] 4. (n/a: enums, core tables, FKs and indexes already exist in the live DB; see baseline in task 1)
- [x] 5. `web/schemas/0006_profiles_verification_and_constraints.sql`: `apply_migration` was declined 3 times, then the user ran it MANUALLY in the SQL editor (2026-11-09). Verified by MCP query: `email_verified_at` exists; profiles_phone_format, profiles_student_id_key, profiles_university_email_domain, emergency_contacts_phone_format valid; `profiles_student_id_format` present as NOT VALID (3 old rows not scanned); `idx_profiles_student_id` dropped; `handle_new_user()` unchanged (md5 equals original); not in `list_migrations` (manual run). Earlier detail: declined (2026-11-09). Attempt 1 included rewriting 3 test rows and the `handle_new_user()` change; attempt 2 dropped the row rewrite (NOT VALID check); attempt 3 also dropped the trigger change (user said the trigger change was the concern for attempt 2, but attempt 3 was declined too). Reason for the third decline unknown; waiting for the user. DB unchanged by 0006.
- [x] 6. `0007_auth_otp_tables.sql` applied via `apply_migration` (`auth_otp_tables`, 2026-11-09): enum `otp_purpose`, tables `otp_codes`, `otp_send_events`, RLS on, no policies, no anon/authenticated privileges (verification query result below)
- [x] 7. `0008_rls_hardening.sql`: `apply_migration` declined, user ran it MANUALLY (2026-11-09). Verified by MCP query: only remaining DELETE policy is `emergency_contacts / students delete own contacts`; `authenticated` DELETE only on emergency_contacts; profiles UPDATE columns = full_name, phone; messages UPDATE column = read_at; alerts INSERT columns = user_id, first_latitude, first_longitude; locations table grants INSERT, SELECT; policies `students insert own alerts/locations/messages` and `admins insert messages on any thread` present; trigger `trg_emergency_contacts_max` enabled. Behavior (reject bad inserts) not yet exercised: that is the RLS matrix, step 12
- [x] 8. Realtime (verified, no migration needed; websocket delivery to a real client not tested, deferred to Phase 4): publication `supabase_realtime` contains alerts, locations, messages only; replica identity FULL on alerts and messages, default on locations. NOT yet verified: that a student's websocket subscription receives only own rows (to be covered with the RLS matrix)
- [x] 9. Admin provisioning (D-017): runbook `web/schemas/admin-provisioning.md` written (admins promoted from verified normal accounts via SQL by project team). Not executed against a real account yet
- [x] 10. `web/schemas/` holds 0000 (verbatim baseline of the 16 earlier migrations), 0004-0010 and README notes. 0009 and 0010 were run manually by the user and verified by MCP query 2026-11-09 (search_path fixed on 3 functions; EXECUTE only for postgres/service_role except `authenticated` on is_admin/current_role/current_user_id; `idx_messages_sender_id` exists; messages INSERT columns = alert_id, body, sender_id; alert trigger contains the `auth.uid()` guard). Manual runs do not appear in `list_migrations`
- [x] 11. Advisors re-run after 0009/0010 (2026-11-09 08:18Z): no critical findings. Remaining security: INFO otp tables no policy (intended); WARN authenticated can execute `is_admin()` and `current_role()` (required by RLS policies, accepted); WARN leaked password protection still disabled (user to enable, B-008). Remaining performance: INFO 6 unused indexes (new DB); WARN 6 multiple_permissive_policies (accepted). First run detail: advisors run 2026-11-09 (security + performance), none critical. Security: INFO rls_enabled_no_policy on otp_codes/otp_send_events (intended); WARN function_search_path_mutable x3; WARN anon and authenticated can execute 4 security-definer functions; WARN leaked password protection disabled (Auth dashboard setting, needs user, cannot be set via MCP). Performance: INFO unindexed FK messages.sender_id; INFO 5 unused indexes (ignored, new DB); WARN 6 multiple_permissive_policies (admin plus student policy on the same action; accepted for now). Fix drafted in `0009_advisor_fixes.sql` (search_path, EXECUTE revokes, sender_id index), not yet applied; `is_admin()` and `current_role()` stay executable by `authenticated` because RLS policies call them. Re-run advisors after 0009
- [x] 12. RLS matrix: 70 cases, 70 passed, 0 failed (2026-11-09). Script `web/scripts/phase1-rls-matrix.sql`, results `docs/phases/phase-1-rls-test-matrix.md`. Transaction rolled back (0 leftover test users). Not covered: real PostgREST JWTs and Realtime websocket delivery
- [x] 13. Types generated via MCP and written to `web/types/database.types.ts` (2026-11-09, after 0006-0008; 0009/0010 change no columns). SIDE EFFECT: `npx tsc --noEmit` now reports 9 errors in template auth/profile code that targets the old profiles shape (`user`, `email`, `name`, `username`, view `profiles_public`): services/auth.service.ts, services/profile.service.ts, types/auth.types.ts, types/profile.types.ts. Not fixed here (Phase 2/3 rewrite that code); `npm run build` therefore fails until then (build not re-run after the type change). Awaiting user decision (B-010)

### Phase 2 verify-phase run (2026-11-09)
- PASS api-contract approved (D-050) and implemented: 10 routes under `/api/auth` (register, verify-otp, resend-otp, login, admin/login, refresh, logout, me, forgot-password, reset-password); `docs/api-contract.md`.
- PASS all OTP rules tested: 6 digits via CSPRNG, HMAC-SHA256 hash only (D-047), 10 min expiry, single use, 5 attempts then locked (parallel guesses cannot exceed it), 60 s resend cooldown, 3 sends per 15 min, new code supersedes old, failed delivery leaves no live code and does not count toward the limit, domain enforced on the server, unverified login denied.
- PASS real Brevo email delivered to a real inbox (both the verification and the reset email); sent HTML-only per D-049.
- PASS no Supabase email used (auth logs, two windows). Supabase sign-in gate for unverified users confirmed (D-043).
- PASS secrets only server-side (value sweep, `NEXT_PUBLIC_*` limited to the Supabase URL and publishable key).
- PASS logs: `no-secrets-in-logs` source scan + runtime log checks in the Brevo client tests.
- NOTE: `npm audit` unchanged at the 13 accepted findings (D-040), `@types/node` bumped to ^24 (D-051).
- NOTE: `web/.env.local` still contains unused `JWT_*` lines (safe to delete); its `JWT_SECRET_KEY` equalled the public template placeholder (B-012), now moot because the custom JWT code is deleted.
- OPEN (carried): B-008 leaked-password protection (user), B-009 broad auth.* grants decision (note: `service_role` no longer shows delete on auth.sessions; the session-revoke function does not depend on it), B-011 informational test alerts.
- Changes beyond the original plan: D-052 domain now includes subdomains (PRD 5.1 amended); migrations 0011 (OTP functions) and 0012 (subdomain rule) run manually by the user.

### Phase 1 verify-phase run (2026-11-09)
- PASS migrations: 0004-0010 applied and mirrored in `web/schemas/` (0006, 0008, 0009, 0010 run manually by the user; 0004, 0005, 0007 via MCP). Each manual one verified by MCP query. 0000 baseline mirrors the 16 pre-existing migrations.
- PASS RLS matrix: 70/70 (docs/phases/phase-1-rls-test-matrix.md), transaction rolled back, no leftovers.
- PASS Realtime publication: alerts, locations, messages. NOT TESTED: websocket delivery to a real client.
- PASS advisors: no critical findings; accepted warnings listed in task 11. OPEN: leaked password protection (B-008).
- PASS types: generated; `tsc` fails in 4 template files by user decision D-046.
- PASS decisions: D-003 moot, D-004 (RLS via `auth.uid()`; matrix used authenticated role with `sub` claim), D-005/006/017/020/022 all recorded; D-032 closed by D-043; D-044/045/046 added.
- PASS secrets sweep: no secret names or keys in `app/lib|config`, `web/types`, `web/schemas`, `web/scripts`; only `web/.env.example` tracked among env files and it holds placeholders (secret key placeholder length 24 vs real 41). FINDING B-012: JWT_SECRET_KEY in `.env.local` equals the committed placeholder.
- Requirements: FR-AUTH-2 (domain check in DB trigger plus CHECK, matrix D1), FR-AUTH-7 (unconfirmed user gets no session, D-032 test; OTP flow itself is Phase 2), FR-AUTH-11 (admin by SQL promotion only, runbook; dashboard rejection is Phase 3), NFR-2 (RLS on all 7 tables), NFR-3 (location insert only on own open alert, admin-only read; matrix L1-L8).
- Open before closing: B-008 (user enables leaked-password protection), B-009 (keep or revoke broad auth.* grants), B-011 (unexplained test alerts, informational), B-012 (JWT secret).

## Blockers
| ID | Blocker | Needed from | Affects |
|---|---|---|---|
| B-001 | Supabase project exists, MCP connected (user says). Agent must confirm MCP tools are visible in its session | Agent | Phase 0 |
| B-002 | Brevo sender address and API key location (`web/.env.local`) needed | User | Phase 2 |
| B-003 | D-032: verify Supabase Auth sends no email and can gate sign-in until OTP | Agent+User | Phase 1/2 |
| B-004 | RESOLVED 2026-11-09: Flutter upgraded to 3.47.9 (D-039) | — | — |
| B-005 | RESOLVED as accepted exception 2026-11-09 (D-040) | — | — |
| B-007 | `apply_migration` declined for 0006 (x3) and 0008 (x1); user ran both manually; 0007 went through. Pending: user runs 0009 (and 0010 if approved) manually | User | Phase 1 |
| B-008 | User will enable leaked password protection in the Auth dashboard (2026-11-09); agent to re-run advisors and confirm | User | Phase 1 |
| B-010 | RESOLVED 2026-11-09 (D-046): user accepts broken `tsc`/`build` in 4 template files until Phase 2; first Phase 2 task is to fix them | — | — |
| B-013 | RESOLVED 2026-11-09 (D-049): HTML only | — | — |
| B-014 | RESOLVED 2026-11-09: user confirmed both emails reached the inbox and looked good; Phase 2 closed | — | — |
| B-012 | `web/.env.local` `JWT_SECRET_KEY` equals the placeholder committed in `web/.env.example` (compared by equality only, value not printed), so it is a publicly known value. Template `jose` JWT is slated for removal in Phase 2 (D-004/D-005); until then generate a random secret (e.g. 32+ random bytes) and put it only in `.env.local`. `SUPABASE_SECRET_KEY` and the two other Supabase values in `.env.local` differ from the example (good) | User | Phase 2 |
| B-011 | Unexplained test data: 30 cancelled alerts (one user, 07:55-07:57Z) and 2 active alerts (08:02Z, 08:04Z) exist, created today before the RLS matrix; not created by the agent's migrations or the matrix (rolled back). Probably the user's own testing; confirm or ignore | User | none |
| B-009 | O1 (docs/phases/phase-1-schema.md 2.7): earlier migrations granted broad DML on auth.* tables to `authenticator` and `service_role`, probably unnecessary. Decide: keep or revoke | User | Phase 1 |
| B-006 | (deferred to Phase 3, D-042) `flutter doctor`: Android licenses not accepted; adb fails because port 5037 is held by Code.exe (PID 24392), which answers HTTP. Blocks emulator/device smoke test | User | Phase 0 |

## Open questions (full list: docs/07-open-questions.md)
Remaining: Brevo verified sender address (Q-002), report/demo format (Q-004), test devices (deferred, Q-013). All others answered.

## Decisions log
| Date | ID | Decision | By |
|---|---|---|---|
| 2026-11-09 | D-001 | AMENDED by D-027: Supabase Auth as identity store; OTP/Brevo/gating app-managed | User |
| 2026-11-09 | D-027–D-031 | Adopt template auth identity; PRD RLS + client Realtime; migrations in `web/schemas/` applied via MCP; template layout; one-time copy, no push | User |
| 2026-11-09 | D-002 | Trusted server = Next.js API routes in `web/` | User |
| 2026-11-09 | D-007 | Web: TS + Tailwind + shadcn/ui, App Router | User |
| 2026-11-09 | D-004/005/015-024/026/033-035 | Decided by agent under user delegation ("follow recommended and best practices"); see docs/03, revisable | User (delegated) |
| 2026-11-09 | D-020/D-036/D-037 | Student ID `^B\d{9}$`; stable Node LTS + stable Flutter; professional HTML OTP email | User |
| 2026-11-09 | D-025 | `app/` based on template github.com/ahsanulhoqueabir/flutter | User |
| 2026-11-09 | D-042 | Close Phase 0 with device smoke test deferred to Phase 3 | User |
| 2026-11-09 | D-053..D-056 | Phase 3 gating answers (recorded only, Phase 3 not started): minimal neutral theme #1F3A5F; flutter_secure_storage + supabase_flutter (versions to verify); local dev server as backend URL; physical Android phone for tests | User |
| 2026-11-09 | D-052 | Email domain = jnu.ac.bd or any subdomain; PRD 5.1 amended | User |
| 2026-11-09 | D-051 | Vitest as test runner; @types/node bumped to ^24 | User |
| 2026-11-09 | D-050 | API contract approved (R1-R7) | User |
| 2026-11-09 | D-049 | Email design approved; HTML-only bodies | User |
| 2026-11-09 | D-047/D-048 | OTP stored as HMAC-SHA256 with server secret; OTP_* env names; JWT_* env dropped | User |
| 2026-11-09 | D-046 | Keep generated types; accept template auth/profile compile errors until Phase 2 | User |
| 2026-11-09 | D-045 | Add 0010 client write guards; user enables leaked-password protection | User |
| 2026-11-09 | D-044 | Phase 1 schema doc approved; Q1-Q3 answers | User |
| 2026-11-09 | D-043 | D-032 closed: unconfirmed-user gate plus profile verification flag | User |
| 2026-11-09 | D-041 | `docs/nextjs/` sole Next.js reference; `agentRules: false`; generated AGENTS.md block removed | User |
| 2026-11-09 | D-038/D-039/D-040 | Remove about/gallery/onboarding samples (keep posts); Flutter upgraded to 3.47.9; accept dev-tool npm audit findings | User |
| 2026-11-09 | D-008 | Flutter: Riverpod + go_router, feature-first | User |

## Change log
- 2026-11-09: Phase 0 work: web installs/builds; app on Flutter 3.47.9 with samples removed and checks passing; Supabase project confirmed disposable dev.
- 2026-11-09: User answers recorded (Supabase/Brevo/Vercel ready, no deadline, student ID format, license OK).
- 2026-11-09: Delegated decisions recorded. `app/`: renamed to `protect_jnu` / `com.protectjnu.app`, removed ios/linux/macos/windows/web folders; sample features (posts, gallery, onboarding, about) NOT yet removed and `config/*.json` still has placeholder API URL and USE_MOCK_AUTH (needs Flutter analyzer; Flutter not available in this shell). Not built.
- 2026-11-09: Web template (nextjs-supabase) copied into `web/` (not installed or built; `.env.local` and `mcp.json` excluded). Docs updated for D-027 to D-034.
- 2026-11-09: Template copied into `app/` (not yet built/renamed; `flutter pub get` not run).
- 2026-11-09: Initial structure and documentation created. PRD moved to `docs/PRD.md`.
