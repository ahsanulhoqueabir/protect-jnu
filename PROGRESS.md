# PROGRESS

Last updated: 2026-11-09
**Current phase:** Phase 1 — In progress (baseline done; waiting on user answers before schema doc)

Legend: `[ ]` pending · `[~]` in progress · `[x]` done (with evidence) · `[!]` blocked

## Phase overview
| # | Phase | Status | Depends on |
|---|---|---|---|
| 0 | Prerequisites, accounts, scaffolding | Done 2026-11-09 (user-confirmed; device run deferred, D-042) | — |
| 1 | Supabase schema, RLS, domain enforcement, custom auth data model | Not started | 0 |
| 2 | OTP lifecycle + Brevo integration (server) | Not started | 1 |
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

## Phase 1 tasks
Status: In progress (started 2026-11-09). Spec: `docs/phases/phase-1-database-rls.md`. Prerequisite Phase 0 done and user-confirmed (D-042).
- [x] 1. MCP baseline (2026-11-09, read-only). Project already holds a schema applied 2026-11-08 via 16 migrations (`initial_schema_*`, `fix_*`, `harden_profiles_role_policy`, `grant_gotrue_*`, `normalize_auth_users_string_columns`) whose SQL is NOT in `web/schemas/` (repo has only template 0001-0003). Tables: profiles (3 rows), emergency_contacts (5), alerts (12), locations (5), messages (3); RLS on, 28 policies, `is_admin()`/`current_role()` security-definer helpers, triggers `set_updated_at`, `set_alert_status_timestamps`, `on_auth_user_created`→`handle_new_user`; enums `alert_status` (active, acknowledged, resolved, cancelled) and `user_role`; Realtime publication already contains alerts, locations, messages; `alerts` already has acknowledged_at, cancelled_at, first_latitude/longitude, last_updated_at. GAPS vs docs: no CHECK on `student_id` or on `@jnu.ac.bd` email, `student_id` not unique, no verification-state column, no OTP/reset/rate-limit tables, `profiles.phone` nullable, no `web/schemas` mirror of applied SQL, advisors not yet run, RLS matrix not run.
- [~] 2. Close open decisions. D-032 verified empirically 2026-11-09 (results in docs/03; migrations 0004 bypass and 0005 restore applied via MCP, function md5 restored, users 3/profiles 3, test user deleted); user chose option A + profile flag (D-043). Existing-DB approach decided: keep and extend. Still open: schema doc approval.
- [x] 3. `docs/phases/phase-1-schema.md` written and approved by user 2026-11-09 (D-044)
- [x] 4. (n/a: enums, core tables, FKs and indexes already exist in the live DB; see baseline in task 1)
- [x] 5. `web/schemas/0006_profiles_verification_and_constraints.sql`: `apply_migration` was declined 3 times, then the user ran it MANUALLY in the SQL editor (2026-11-09). Verified by MCP query: `email_verified_at` exists; profiles_phone_format, profiles_student_id_key, profiles_university_email_domain, emergency_contacts_phone_format valid; `profiles_student_id_format` present as NOT VALID (3 old rows not scanned); `idx_profiles_student_id` dropped; `handle_new_user()` unchanged (md5 equals original); not in `list_migrations` (manual run). Earlier detail: declined (2026-11-09). Attempt 1 included rewriting 3 test rows and the `handle_new_user()` change; attempt 2 dropped the row rewrite (NOT VALID check); attempt 3 also dropped the trigger change (user said the trigger change was the concern for attempt 2, but attempt 3 was declined too). Reason for the third decline unknown; waiting for the user. DB unchanged by 0006.
- [x] 6. `0007_auth_otp_tables.sql` applied via `apply_migration` (`auth_otp_tables`, 2026-11-09): enum `otp_purpose`, tables `otp_codes`, `otp_send_events`, RLS on, no policies, no anon/authenticated privileges (verification query result below)
- [x] 7. `0008_rls_hardening.sql`: `apply_migration` declined, user ran it MANUALLY (2026-11-09). Verified by MCP query: only remaining DELETE policy is `emergency_contacts / students delete own contacts`; `authenticated` DELETE only on emergency_contacts; profiles UPDATE columns = full_name, phone; messages UPDATE column = read_at; alerts INSERT columns = user_id, first_latitude, first_longitude; locations table grants INSERT, SELECT; policies `students insert own alerts/locations/messages` and `admins insert messages on any thread` present; trigger `trg_emergency_contacts_max` enabled. Behavior (reject bad inserts) not yet exercised: that is the RLS matrix, step 12
- [~] 8. Realtime (verified, no migration needed): publication `supabase_realtime` contains alerts, locations, messages only; replica identity FULL on alerts and messages, default on locations. NOT yet verified: that a student's websocket subscription receives only own rows (to be covered with the RLS matrix)
- [x] 9. Admin provisioning (D-017): runbook `web/schemas/admin-provisioning.md` written (admins promoted from verified normal accounts via SQL by project team). Not executed against a real account yet
- [~] 10. `web/schemas/` holds 0000 (verbatim baseline of the 16 earlier migrations, read from `supabase_migrations.schema_migrations`), 0004-0010 and README notes. 0009 and 0010 written, not yet applied
- [~] 11. Advisors run 2026-11-09 (security + performance), none critical. Security: INFO rls_enabled_no_policy on otp_codes/otp_send_events (intended); WARN function_search_path_mutable x3; WARN anon and authenticated can execute 4 security-definer functions; WARN leaked password protection disabled (Auth dashboard setting, needs user, cannot be set via MCP). Performance: INFO unindexed FK messages.sender_id; INFO 5 unused indexes (ignored, new DB); WARN 6 multiple_permissive_policies (admin plus student policy on the same action; accepted for now). Fix drafted in `0009_advisor_fixes.sql` (search_path, EXECUTE revokes, sender_id index), not yet applied; `is_admin()` and `current_role()` stay executable by `authenticated` because RLS policies call them. Re-run advisors after 0009
- [ ] 12. RLS test matrix (2 students + admin + anon) -> `phase-1-rls-test-matrix.md`
- [~] 13. Types generated via MCP and written to `web/types/database.types.ts` (2026-11-09, after 0006-0008; 0009/0010 change no columns). SIDE EFFECT: `npx tsc --noEmit` now reports 9 errors in template auth/profile code that targets the old profiles shape (`user`, `email`, `name`, `username`, view `profiles_public`): services/auth.service.ts, services/profile.service.ts, types/auth.types.ts, types/profile.types.ts. Not fixed here (Phase 2/3 rewrite that code); `npm run build` therefore fails until then (build not re-run after the type change). Awaiting user decision (B-010)

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
