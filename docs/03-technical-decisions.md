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
| D-026 | Template cleanup: Dart package `protect_jnu`; Android applicationId `com.protectjnu.app` (change before release if you own a different domain); non-Android platform folders deleted; template's `.claude/` rules kept | Done 2026-11-09 except sample-feature removal (needs analyzer) |
| D-034 | Adapt template `profiles` to PRD columns (`full_name`, `student_id`, `phone`, `university_email`, role, verification state) in a Phase 1 schema doc, which still goes to the user for approval | Approval gate kept |
| D-036 | Versions: Node.js = current LTS line (installed v24.22.1 is acceptable; Next 16 needs a supported Node, verify against `web/docs/nextjs/16.4.3/`). Flutter = latest stable channel whose Dart satisfies the template's `sdk: ^3.13.7`; confirm with `flutter --version` in Phase 0 and pin via `.fvmrc` or doc note if user wants | (verify) |
| D-037 | OTP email: professional, clean, responsive HTML template (branded header, large code, expiry note, 'ignore if not you' footer), plus plain-text fallback; design previewed to user before use | Q-003 |
| D-035 | Package manager for `web/`: npm (template has package-lock.json) | |
| D-032 | Still a verification task (see below) | |

## Open (blocking where noted) — consequences of D-001 (custom auth)
| ID | Question | Why it matters | Gate |
|---|---|---|---|

### Follow-ups created by the template decisions (OPEN)
| ID | Question | Gate |
|---|---|---|
| D-032 | Verify (current Supabase docs/MCP) that `auth.admin.createUser` + `signInWithPassword` sends NO Supabase email, and how to block sign-in until OUR OTP verifies. Present verified options; user chooses | Phase 1/2 |

Process to close an item: ask the user → record answer here (move to Decided) → log in PROGRESS Decisions.
