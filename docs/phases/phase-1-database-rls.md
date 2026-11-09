# Phase 1 — Database, RLS & Auth Data Model

## Objectives
Create the full Supabase schema with RLS and server-side domain enforcement, designed for the **custom auth** decision (D-001). Verified through Supabase MCP.

## Requirements covered
FR-AUTH-2, 7, 11; NFR-2, NFR-3; PRD §5.1, 7.5, 7.6.

## Prerequisites
Phase 0 complete.

## Open questions to resolve BEFORE migrations
D-003 (hash algo), D-004 (RLS/JWT strategy), D-005 (sessions), D-006 (credential tables / `auth.users` usage), D-017 (admin provisioning), D-020 (ID/phone formats), D-022 (cancelled status). Agent presents *verified* options from current Supabase docs for D-004 and waits for the user.

## Components (tables — columns beyond the PRD are PROPOSED until approved)
PRD-defined: `profiles`, `emergency_contacts`, `alerts`, `locations`, `messages`, OTP verification records.
Additional tables implied by custom auth (PROPOSED, need approval): credentials/password hash storage, session/refresh tokens, password-reset tokens, OTP send rate-limit data.
Enums: `role (user|admin)`, `alert_status (active|acknowledged|resolved [+ cancelled? D-022])`, OTP purpose (`email_verification`, `password_reset` if OTP-based).
Alerts need fields to support reports (acknowledged_at etc.) — PRD lists only `started_at`, `resolved_at`; reports need "acknowledged" timestamps (PRD 5.6). **Ask** before adding.

## Steps
1. MCP: inspect project (tables, extensions, existing policies). Record baseline.
2. Close open decisions; write them into `03-technical-decisions.md`.
3. Write schema design doc `docs/phases/phase-1-schema.md` (tables, columns, types, constraints, indexes, FKs). Get user approval.
4. Migration 1: enums + core tables + FKs + indexes.
5. Migration 2: student ID CHECK `student_id ~ '^B[0-9]{9}$'` and domain constraint — `university_email` CHECK ending `@jnu.ac.bd` (case-insensitive, normalized lowercase), unique constraints (email, student_id).
6. Migration 3: auth/OTP/reset/rate-limit tables; RLS enabled with **no** client policies.
7. Migration 4: RLS policies per PRD §7.6 (students own data; admins read all alerts/related, message on any thread; no client write access to OTP/reset/credentials; students cannot change their own `role`).
8. Migration 5: add `alerts`, `locations`, `messages` to Realtime publication (verify mechanism via MCP/docs).
9. Admin provisioning mechanism (per D-017).
10. Save all migration SQL to `web/schemas/`.
11. Run MCP advisors; fix findings.
12. Execute RLS test matrix (2 students + admin + anon) per `05-supabase-mcp-workflow.md`.
13. Generate TS types into `web/types/database.types.ts`.

## Dependencies / integrations
Supabase MCP. No Brevo yet.

## Database / API
This phase *is* the database. No API endpoints.

## Testing & validation
- MCP queries prove: RLS enabled on every table; policy list matches design; domain CHECK rejects `x@gmail.com`; unverified-state rule representable.
- RLS matrix 100% pass, saved to `phase-1-rls-test-matrix.md`.
- Advisors: no unresolved critical findings.

## Completion criteria
- [ ] All decisions D-003/4/5/6/17/20/22 recorded
- [ ] Schema doc approved by user
- [ ] Migrations applied + mirrored in repo
- [ ] RLS matrix passes
- [ ] Realtime publication verified
- [ ] Types generated; PROGRESS updated; user confirmed

## Out of scope
OTP logic, emailing, UI.
