# Implementation Roadmap

PRD §9 defines 9 phases. This plan adds **Phase 0** (accounts, tooling, scaffolding) because nothing else can start without it.

| Phase | Name | Outcome | Depends on | Detail |
|---|---|---|---|---|
| 0 | Prerequisites & scaffolding | Accounts ready, both apps scaffolded and running "hello" | — | [phase-0](phases/phase-0-prerequisites.md) |
| 1 | Database, RLS, auth data model | Schema + RLS + domain enforcement applied via MCP and tested | 0 | [phase-1](phases/phase-1-database-rls.md) |
| 2 | OTP + Brevo server | Register/verify/reset/login API working with real emails | 1 | [phase-2](phases/phase-2-otp-brevo.md) |
| 3 | Auth UIs | Flutter + web auth flows, emergency contacts | 2 | [phase-3](phases/phase-3-auth-flows.md) |
| 4 | SOS + live alerts | SOS creates alert; dashboard shows it live; status workflow | 3 | [phase-4](phases/phase-4-sos-alerts.md) |
| 5 | Live location + map | Foreground service, offline queue, Leaflet map with trail | 4 | [phase-5](phases/phase-5-location-map.md) |
| 6 | Real-time chat | Per-alert chat, unread counts | 4 | [phase-6](phases/phase-6-chat.md) |
| 7 | Media capture | Camera + local gallery | 3 | [phase-7](phases/phase-7-media.md) |
| 8 | Reports | Monthly/yearly stats, chart, CSV | 4 | [phase-8](phases/phase-8-reports.md) |
| 9 | Testing & release prep | E2E on real phones, bug fixes, demo/report | 1–8 | [phase-9](phases/phase-9-testing-release.md) |
| 10 | Admin features in the mobile app | Role-based admin screens in Flutter, notifications (added 2026-11-21, D-078) | 9 | [phase-10](phases/phase-10-admin-mobile.md) |

## Gates
- A phase is done only when **all** its completion criteria are checked with evidence in PROGRESS.md **and** the user confirms.
- Phases 6, 7, 8 are independent of each other once their dependencies are met; default order is numeric unless the user says otherwise.
- Open questions gating a phase (see [07-open-questions.md](07-open-questions.md)) must be answered before its first task.

## Standard phase document template
Each phase file has: Objectives · Requirements covered · Prerequisites · Open questions · Components · Step-by-step · Dependencies/integrations · Database & API · Testing/validation · Completion criteria · Out of scope.
