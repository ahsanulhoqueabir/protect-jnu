# PROGRESS

Last updated: 2026-11-09
**Current phase:** Phase 0 — In progress (tasks 1–3a done; see Phase 0 tasks)

Legend: `[ ]` pending · `[~]` in progress · `[x]` done (with evidence) · `[!]` blocked

## Phase overview
| # | Phase | Status | Depends on |
|---|---|---|---|
| 0 | Prerequisites, accounts, scaffolding | Not started | — |
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
- [ ] 8. Ask user to start Brevo sender verification (Q-002)
- [~] 9. Smoke tests: web `npm run dev` served `/`, `/login`, `/signup` all HTTP 200 (2026-11-09). `next dev` had appended a block to `web/AGENTS.md` pointing at `node_modules/next/dist/docs/`; removed and disabled with `agentRules: false` in `web/next.config.ts` (D-041); verified after a fresh `next dev` run (HTTP 200, block not regenerated, `tsc` clean). App: `flutter build apk --debug --dart-define-from-file=config/dev.json` succeeded (`Built buildpp\outputslutter-apkpp-debug.apk`, 2026-11-09); emulator/device run NOT done, blocked by B-006.

## Blockers
| ID | Blocker | Needed from | Affects |
|---|---|---|---|
| B-001 | Supabase project exists, MCP connected (user says). Agent must confirm MCP tools are visible in its session | Agent | Phase 0 |
| B-002 | Brevo sender address and API key location (`web/.env.local`) needed | User | Phase 2 |
| B-003 | D-032: verify Supabase Auth sends no email and can gate sign-in until OTP | Agent+User | Phase 1/2 |
| B-004 | RESOLVED 2026-11-09: Flutter upgraded to 3.47.9 (D-039) | — | — |
| B-005 | RESOLVED as accepted exception 2026-11-09 (D-040) | — | — |
| B-006 | `flutter doctor`: Android licenses not accepted; adb fails because port 5037 is held by Code.exe (PID 24392), which answers HTTP. Blocks emulator/device smoke test | User | Phase 0 |

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
