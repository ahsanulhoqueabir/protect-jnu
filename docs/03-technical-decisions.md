# Technical Decisions

Status: **DECIDED** (user or PRD) · **OPEN** (must ask the user; agents must not pick) · **PROPOSED** (suggestion awaiting approval)

## Decided
| ID | Decision | Source |
|---|---|---|
| D-001 | ~~Fully custom auth~~ **AMENDED 2026-11-09 by D-027**: Supabase Auth is only the identity/password store (template pattern); OTP, Brevo emails, verification gating and password reset are app-managed in `web/`. Supabase's own emails must still NOT be used | User |
| D-002 | Trusted server code = Next.js API routes in `web/`; Flutter calls over HTTPS | User 2026-11-09 |
| D-027 | Adopt template's Supabase Auth identity (`auth.users` + `profiles`, `auth.admin.createUser`, `signInWithPassword`) with our own OTP/Brevo flow on top | User 2026-11-09 |
| D-028 | Follow PRD 7.6: add RLS policies + client-side Realtime (replaces template's server-only/no-policy model). Mechanism still depends on D-004 | User 2026-11-09 |
| D-029 | Migrations: SQL files in `web/schemas/NNNN_*.sql` (template numbering), applied via Supabase MCP, append-only | User 2026-11-09 |
| D-030 | Web layout = template root-level folders (`services/ schema/ types/ lib/ store/ config/`) and strict route-schema-service layering | User 2026-11-09 |
| D-031 | `web/` is a one-time copy of template `nextjs-supabase` (no push back, no remote). `.env.local` and `mcp.json` not copied | User 2026-11-09 |
| D-007 | Web stack: TypeScript, Tailwind, shadcn/ui, Next.js App Router | User 2026-11-09 |
| D-008 | Flutter: Riverpod, go_router, feature-first | User 2026-11-09 |
| D-025 | `app/` is based on the template https://github.com/ahsanulhoqueabir/flutter (Riverpod 3 manual providers, Dio via `ApiClient`, go_router, shared_preferences, connectivity_plus, `--dart-define-from-file` envs). Copied 2026-11-09 without git history. Its stack is kept; do not swap | User 2026-11-09 |
| D-009 | Supabase = DB, Realtime, RLS; Supabase MCP = dev-time only | PRD 7.2 |
| D-010 | Email via Brevo Transactional API (Free plan); no Supabase email | PRD 7.4 |
| D-011 | Maps: Leaflet + OpenStreetMap, attribution shown | PRD 7.3 |
| D-012 | OTP: 6-digit, CSPRNG, 10 min TTL, 1-use, 5 attempts, 60s cooldown, 3 sends/15 min (configurable), hashed | PRD 5.1 |
| D-013 | Media stays on device | PRD 5.5 |
| D-014 | Roles: `user`, `admin` on profile | PRD 4 |

## Decided by delegation (user said "follow the recommended and best practices", 2026-11-09)
These were chosen by the agent under that delegation. Each is **revisable**: tell the agent to change any of them. Items marked (verify) must be checked against current official docs/MCP before implementation; if verification contradicts the choice, STOP and ask.
| ID | Decision | Notes |
|---|---|---|
| D-004 | For RLS/Realtime use **Supabase-issued session JWTs** (Supabase Auth is the identity store, D-027) so policies use `auth.uid()`; do NOT use the template's custom `jose` JWT for database access | (verify) Template `jwt.helper.ts` may be kept only for non-DB needs, or removed |
| D-005 / D-033 | Short-lived access token (Supabase default, about 1h) + refresh token. Flutter: tokens in encrypted secure storage (not shared_preferences). Web: httpOnly, Secure, SameSite cookies, not localStorage. Remove template's localStorage-persisted bearer token and 15d expiry | (verify) cookie handling with Next 16 docs |
| D-003 | Moot: password hashing is done by Supabase Auth | |
| D-006 | Credentials in `auth.users`; OTP, reset and rate-limit data in dedicated `public` tables with RLS on and no client policies | |
| D-015 | Password policy: minimum 8 characters, max 64, no composition rules, reject very common passwords if feasible | NIST-style |
| D-016 | Password reset = emailed 6-digit OTP via Brevo, same rules as the verification OTP (10 min TTL, single use, 5 attempts, cooldown), then set new password. No deep links needed on mobile | Revokes existing sessions after reset |
| D-017 | Admin provisioning: no public admin signup; first admins created by a one-off server-side script/SQL run by the project team (via MCP), setting role `admin`; later admins promoted the same way | |
| D-018 | Hosting `web/` on Vercel (HTTPS by default) | Needs user's Vercel account; fact of account is still Q-005 |
| D-019 | OTP send rate-limit state stored in a Postgres table | |
| D-020 | Student ID: pattern `^B[0-9]{9}$` (uppercase B + 9 digits; example `B210305040`, digits 2-3 = admission year). Keep validation simple: only this pattern (trim, uppercase before checking); unique per profile. Phone: Bangladesh numbers validated loosely (digits, optional +880) | Same regex in Flutter, Zod schema and DB CHECK |
| D-021 | Any admin may reply to any thread; message shows sender admin name; unread for admins is per thread and cleared when any admin opens it | |
| D-022 | Add alert status `cancelled` (student cancels during the 5s window never creates an alert; `cancelled` is for a student ending an active alert) | Enum: active, acknowledged, resolved, cancelled |
| D-023 | Extra Flutter packages chosen per phase after verifying current versions; HTTP = Dio, prefs = shared_preferences (template); secure storage package for tokens | Confirm each at its phase |
| D-024 | Lists paginated, 20 rows per page, newest first | |
| D-026 | Template cleanup: Dart package `protect_jnu`; Android applicationId `com.protectjnu.app` (change before release if you own a different domain); non-Android platform folders deleted; template's `.claude/` rules kept | Done 2026-11-09. Sample features about, gallery and onboarding removed 2026-11-09 (D-038); `posts` kept as reference |
| D-034 | Adapt template `profiles` to PRD columns (`full_name`, `student_id`, `phone`, `university_email`, role, verification state) in a Phase 1 schema doc, which still goes to the user for approval | Approval gate kept |
| D-036 | Versions: Node.js = current LTS line (installed v24.22.1 is acceptable; Next 16 needs a supported Node, verify against `web/docs/nextjs/16.4.3/`). Flutter = latest stable channel whose Dart satisfies the template's `sdk: ^3.13.7`; confirm with `flutter --version` in Phase 0 and pin via `.fvmrc` or doc note if user wants | (verify) |
| D-037 | OTP email: professional, clean, responsive HTML template (branded header, large code, expiry note, 'ignore if not you' footer), plus plain-text fallback; design previewed to user before use | Q-003 |
| D-035 | Package manager for `web/`: npm (template has package-lock.json) | |
| D-032 | Still a verification task (see below) | |
| D-038 | Phase 0 sample cleanup in `app/`: remove about, gallery and onboarding (and their routes, redirect parameter, settings tiles, storage key, tests); keep `posts` as the reference feature until the first real feature replaces it. `LegalScreen` (terms/privacy placeholder) moved to `features/status/presentation/legal_screen.dart` | User, 2026-11-09 |
| D-039 | Flutter upgraded 3.47.2 → 3.47.9 (Dart 3.13.7) to satisfy template `sdk: ^3.13.7` (closes D-036 verify for Flutter) | User, 2026-11-09 |
| D-058 | Phase 3 closed 2026-11-09 after the user checked every flow on a physical phone. Flutter: removed the template `posts` sample and edit-profile screen (no PRD profile edit); dev backend reached through `adb reverse tcp:3000` (`API_BASE_URL=http://localhost:3000`, debug-only cleartext); adb runs on port 5099 because VS Code holds 5037; tokens only in `flutter_secure_storage`; Supabase client borrows our session through `accessToken` (no Supabase sign-in) | User confirmed / agent, 2026-11-09 |
| D-059 | Phase 4: location permission denied at SOS time -> the alert is still sent, without coordinates (first_latitude/longitude null) | User, 2026-11-09 |
| D-060 | Phase 4: one open alert (active or acknowledged) per student; pressing SOS again opens the existing Active Alert screen instead of creating another | User, 2026-11-09 |
| D-061 | Phase 4 write path: student creates the alert by direct RLS insert; admin acknowledge/resolve goes through a validated Next.js route that enforces transitions and records the admin id (to be documented in api-contract.md; any column addition needs approval) | User, 2026-11-09 |
| D-062 | Phase 4 dashboard notification: Web Audio beep (no asset file) after an 'Enable sound' click, plus toast and highlighted row. Alert card shows name, student ID, time, status; phone/email on the details page only | User, 2026-11-09 |
| D-063 | Phase 4 migration `0013_alerts_one_open_and_admin_ids.sql`: delete the 44 old test alerts (seed accounts student.a/student.b only), add `alerts.acknowledged_by` and `alerts.resolved_by` (uuid, nullable, FK profiles, on delete set null), partial unique index `alerts_one_open_per_user` on (user_id) where status in (active, acknowledged). Approved by user; `apply_migration` declined, so user runs it manually | User, 2026-11-09 |
| D-064 | Phase 4 Flutter (agent proposals, revisable; user to confirm on the phone): location package `geolocator` ^14.0.1 (D-023; verified on pub.dev, API read from the installed source: `checkPermission`, `requestPermission`, `isLocationServiceEnabled`, `getCurrentPosition(locationSettings)`); permissions `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` in the main manifest; the position is requested when the 5 s cancel window starts (runs in parallel) and DROPPED if the student cancels; after the window the alert waits at most 3 s for a position, then is sent without one; position fetch has a 10 s limit; the student may end an ACTIVE alert from the Active Alert screen after a confirm (D-022, RLS allows active -> cancelled only) | Agent (proposal) |
| D-065 | Phase 4 closed on the user's instruction ("complete this phase"; "no need to run any test") before the manual phone/browser checks and with the integration suite not fully green (flaky in parallel, one unexplained failure in a serial run). Both carried as B-015..B-017 in PROGRESS.md; Phase 5 needs the user's explicit go-ahead | User, 2026-11-09 |
| D-066 | Phase 5 answers: location point every 10 s; map trail = last 20 points; foreground notification title "Protect JnU'ins", text "Sharing your location with campus security"; offline queue in local SQLite, newest 500 points kept (package to be verified on pub.dev before use) | User, 2026-11-09 |
| D-067 | Web map = plain Leaflet (no react-leaflet) with public OpenStreetMap tiles and attribution | User, 2026-11-09 |
| D-069 | Phase 5 packages: `sqflite ^2.4.5` for the offline queue (user-approved; version checked on pub.dev 2026-11-09). Foreground service uses geolocator's built-in `ForegroundNotificationConfig` (verified in geolocator_android 5.2.1 source), so no separate foreground-service package | User / agent |
| D-070 | Location dedupe: unique (alert_id, recorded_at) on `locations` (migration 0015, user runs it manually); phone inserts with ON CONFLICT DO NOTHING so a re-sent batch is ignored | User chose dedupe; key = agent's best-practice choice |
| D-071 | Phase 5 closed on the user's instruction without running verify-phase; manual phone/browser checks carried as B-018 in PROGRESS.md | User, 2026-11-09 |
| D-073 | Phase 6 closed on the user's instruction without running verify-phase; manual phone/browser checks carried as B-019 in PROGRESS.md | User, 2026-11-09 |
| D-072 | Phase 6 chat answers: max message length 1000 characters (non-empty after trim; DB CHECK); thread read-only once the alert is resolved or cancelled (history visible, inserts refused by RLS); student is told of new messages in-app only (unread badge, live list, no sound/system notification); offline send shows "failed, tap to retry", no auto-queue; one DB view/RPC for last message + unread count per conversation (migration saved in `web/schemas/`, user runs it manually) | User, 2026-11-09 |
| D-068 | Q-013 answered: the only test phone is the Redmi 21121119SG (Android 11); background tests cover one brand only | User, 2026-11-09 |
| D-057 | Phase 3: user answers (2026-11-09): emergency contacts = name + phone only; phone format = existing DB checks (profiles_phone_format, emergency_contacts_phone_format); web admin first. Agent design, revisable: dashboard session in httpOnly SameSite=Strict cookies `pj_access` (lifetime = token expires_in) and `pj_refresh` (7 days, my proposal, not in PRD); routes `/api/admin/session` (POST login, DELETE logout) and `/api/admin/session/refresh`; `proxy.ts` optimistic cookie check, `app/admin/layout.tsx` authoritative check | User / agent, 2026-11-09 |
| D-056 | Phase 3 manual tests use a physical Android phone (USB debugging, same Wi-Fi as the PC). Prerequisite: fix adb (VS Code process holds port 5037) and accept Android licenses (B-006) | User, 2026-11-09 (Phase 3 not started) |
| D-055 | Phase 3 backend URL: local `web/` dev server (`npm run dev`). Emulator `10.0.2.2:3000`, phone via the PC's LAN IP. Plain http, so a debug-only Android cleartext exception is needed; nothing is deployed. Vercel deploy stays a later step | User, 2026-11-09 (Phase 3 not started) |
| D-054 | Flutter packages for Phase 3: `flutter_secure_storage` for tokens (D-005) and `supabase_flutter` for RLS reads of emergency contacts and later Realtime (given the session from our login API). Package names and versions must be verified (pub.dev / `flutter pub`) before adding; Dio stays for our own API | User, 2026-11-09 (Phase 3 not started) |
| D-053 | UI look: minimal neutral theme, primary colour `#1F3A5F` (same as the approved emails), no logo; restyle later in one theme file. Applies to Flutter and the admin web pages | User, 2026-11-09 (Phase 3 not started) |
| D-052 | University email domain = `@jnu.ac.bd` OR a subdomain `@<label>[.<label>...].jnu.ac.bd` (for example `@cse.jnu.ac.bd`). Look-alikes (`jnu.ac.bd.evil.com`, `xjnu.ac.bd`, `a@b@jnu.ac.bd`, empty or hyphen-edged labels) stay rejected. One pattern in three places: Zod (`web/schema/auth.schema.ts`), DB trigger `handle_new_user()` and CHECK `profiles_university_email_domain` (migration `0012`). PRD 5.1 and the risk table were amended at the owner's request. Reason: the owner's real inbox is `b210305040@cse.jnu.ac.bd`, so students use department subdomains. Supersedes the exact-match wording of PRD 5.1 and FR-AUTH-2 | User, 2026-11-09 |
| D-051 | Web tests use Vitest 5.1.0 (devDependency). To make it install, `@types/node` was bumped from ^20 to ^24 (matches the Node 24 runtime, D-036); `npm audit` unchanged at the 13 accepted findings (D-040). Scripts: `npm test` = unit tests (no network), `npm run test:integration` = real Supabase dev project with email mocked | User, 2026-11-09 |
| D-050 | `docs/api-contract.md` approved with proposals R1-R7: verify-otp returns no session (client logs in next); top-level `code` in error envelope; separate `/admin/login`; JSON tokens in Phase 2, web cookies in Phase 3; 409 `email_taken` for verified emails; re-registering an unverified email never replaces the password (recovery via forgot-password, which also verifies the email); distinct OTP error codes | User, 2026-11-09 |
| D-049 | OTP/reset email design approved as drafted in `docs/email-previews/otp-email.html`. Emails are sent as `htmlContent` ONLY (Brevo docs: one body type per request; both-together is not documented). This drops the plain-text fallback from D-037 | User, 2026-11-09 |
| D-047 | OTP storage: `code_hash` = HMAC-SHA256 keyed with server secret `OTP_HASH_SECRET` over `userId + purpose + code`; constant-time compare. Chosen because a 6-digit code is trivially brute-forced from a plain or salted hash | User, 2026-11-09 |
| D-048 | Env names for OTP config: `OTP_HASH_SECRET`, `OTP_TTL_MINUTES=10`, `OTP_MAX_ATTEMPTS=5`, `OTP_RESEND_COOLDOWN_SECONDS=60`, `OTP_SEND_WINDOW_MINUTES=15`, `OTP_MAX_SENDS_PER_WINDOW=3`. Brevo: `BREVO_API_KEY`, `BREVO_SENDER_EMAIL`, `BREVO_SENDER_NAME`. Template `JWT_SECRET_KEY`, `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN` removed from `.env.example` (custom jose JWT replaced by Supabase tokens, D-004/D-033); closes B-012 once the code is deleted | User, 2026-11-09 |
| D-046 | Generated DB types stay in `web/types/database.types.ts` and must match the live DB. `tsc` and `npm run build` are allowed to fail on 4 template files (services/auth.service.ts, services/profile.service.ts, types/auth.types.ts, types/profile.types.ts; 9 errors on 2026-11-09) until Phase 2 rewrites auth and profile code; fixing them is the FIRST Phase 2 task. Supersedes the 'build passes' state from Phase 0 for `web/` | User, 2026-11-09 |
| D-045 | Adds migration `0010_client_write_guards.sql` to Phase 1: pin alert columns other than `status` for signed-in non-admin clients; limit client message insert to `alert_id, body, sender_id`. Also: user will enable leaked-password protection in the Auth dashboard (B-008) | User, 2026-11-09 |
| D-044 | Phase 1 schema doc `docs/phases/phase-1-schema.md` approved. Q1 remove most client deletes; Q2 chat only while alert active/acknowledged; Q3 max 3 emergency contacts in DB. Approach: keep and extend the live schema (OTP tables, verification column, constraints, RLS hardening as new migrations) | User, 2026-11-09 |
| D-043 | Closes D-032: sign-in gate = option A plus flag. Users are created via `auth.admin.createUser` WITHOUT `email_confirm`; after our OTP verifies, server calls `email_confirm: true` and sets the `profiles` verification flag; server code also checks the flag. Supabase's `email_not_confirmed` error is the enforced gate (verified 2026-11-09) | User, 2026-11-09 |
| D-042 | Phase 0 closed without a device/emulator run of the app (APK builds, 28 tests pass); device smoke test deferred to Phase 3 and tracked as B-006 | User, 2026-11-09 |
| D-041 | `web/`: `docs/nextjs/<version>/` is the sole Next.js reference for agents; `agentRules: false` in `web/next.config.ts` stops `next dev` from appending a block to `web/AGENTS.md` that points at `node_modules/next/dist/docs/`; that block was removed | User, 2026-11-09 |
| D-040 | Known exception to the template's `npm audit` = 0 rule: 13 low/moderate findings via dev tools `shadcn` and `eslint-config-next`; the only fix is a breaking `--force` change. Re-check each phase | User, 2026-11-09 |

## Open (blocking where noted) — consequences of D-001 (custom auth)
| ID | Question | Why it matters | Gate |
|---|---|---|---|

### Follow-ups created by the template decisions (OPEN)
| ID | Question | Gate |
|---|---|---|
| D-032 | Verify (current Supabase docs/MCP) that `auth.admin.createUser` + `signInWithPassword` sends NO Supabase email, and how to block sign-in until OUR OTP verifies. Present verified options; user chooses | Phase 1/2 |

### D-032 verification results (2026-11-09, dev project `bthjjlpylvauiolwrdfn`; user-approved test)
Method: temporary migrations 0004/0005 let one reserved address pass the domain trigger; a throwaway user was created with `auth.admin.createUser` (no `email_confirm`), probed with `signInWithPassword`, then deleted; function restored (md5 of definition equals the original; users 3, profiles 3, no test user left).
| Probe | Result |
|---|---|
| `createUser` without `email_confirm` | succeeds, user unconfirmed. Auth logs for the window show only signup / user_modified / token / delete events: **no mail or SMTP event** (absence in logs; not a docs guarantee) |
| `signInWithPassword` while unconfirmed | 400 `email_not_confirmed`, no session |
| same after `ban_duration: '876000h'` | 400 `user_banned`, no session (also when confirmed) |
| after `email_confirm: true` and `ban_duration: 'none'` | succeeds, session issued |
Not verified: Supabase docs search did not confirm the same statements; the "Confirm email" project setting was inferred from behavior, not read; whether anon-key public sign-up is disabled was not tested.
Options for the sign-in gate (user chooses): (A) create users unconfirmed and call `email_confirm: true` after our OTP verifies (Supabase enforces the gate, no extra state); (B) ban until verified (works, but mixes with real bans); (C) own `profiles` verification flag checked by server code only. Agent recommendation: A plus the profile flag from D-034 as a second check.

Process to close an item: ask the user → record answer here (move to Decided) → log in PROGRESS Decisions.
