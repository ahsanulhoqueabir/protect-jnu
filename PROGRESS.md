# PROGRESS

Last updated: 2026-11-09
**Current phase:** Phase 0 — Not started (planning/docs complete, awaiting user answers to open questions)

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
(see `docs/phases/phase-0-prerequisites.md`; copy task checkboxes here when the phase starts)

## Blockers
| ID | Blocker | Needed from | Affects |
|---|---|---|---|
| B-001 | Supabase project exists, MCP connected (user says). Agent must confirm MCP tools are visible in its session | Agent | Phase 0 |
| B-002 | Brevo sender address and API key location (`web/.env.local`) needed | User | Phase 2 |
| B-003 | D-032: verify Supabase Auth sends no email and can gate sign-in until OTP | Agent+User | Phase 1/2 |

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
| 2026-11-09 | D-008 | Flutter: Riverpod + go_router, feature-first | User |

## Change log
- 2026-11-09: User answers recorded (Supabase/Brevo/Vercel ready, no deadline, student ID format, license OK).
- 2026-11-09: Delegated decisions recorded. `app/`: renamed to `protect_jnu` / `com.protectjnu.app`, removed ios/linux/macos/windows/web folders; sample features (posts, gallery, onboarding, about) NOT yet removed and `config/*.json` still has placeholder API URL and USE_MOCK_AUTH (needs Flutter analyzer; Flutter not available in this shell). Not built.
- 2026-11-09: Web template (nextjs-supabase) copied into `web/` (not installed or built; `.env.local` and `mcp.json` excluded). Docs updated for D-027 to D-034.
- 2026-11-09: Template copied into `app/` (not yet built/renamed; `flutter pub get` not run).
- 2026-11-09: Initial structure and documentation created. PRD moved to `docs/PRD.md`.
