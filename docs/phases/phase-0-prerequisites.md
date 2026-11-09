# Phase 0 — Prerequisites & Scaffolding

## Objectives
Everything needed to start building: accounts, tooling, both apps scaffolded and runnable, MCP connected.

## Requirements covered
Foundation for all; PRD §7.1, 7.2.

## Prerequisites / Open questions to ask first
Q-001 (Supabase/MCP), Q-005 (hosting), Q-014 (tool versions). Ask via AskUserQuestion before step 1.

## Components
- `app/` Flutter project from template (D-025), Android only after cleanup (D-026)
- `web/` Next.js project from template (D-031)
- `web/.env.example`, `.gitignore`
- Supabase project + MCP connection
- Brevo account (sender verification can start now; it has lead time)

## Steps
1. Verify toolchain: `flutter --version`, `flutter doctor`, `node --version`, `npm`/`pnpm` (ask which package manager — OPEN). Record versions in PROGRESS.
2. Confirm Supabase project exists (or user creates it). Record project ref (not keys) in PROGRESS.
3. Connect Supabase MCP; list its tools; record them in `docs/05-supabase-mcp-workflow.md`. Run a read-only query to prove connectivity.
4. `web/` was pre-populated from template `nextjs-supabase` (D-031). Read `web/CLAUDE.md` and `web/docs/README.md`; template uses npm (package-lock.json), so confirm package manager; run `npm install`, `npx tsc --noEmit`, `npm run lint`, `npm run build`, `npm audit`; create `web/.env.local` from `.env.example` placeholders (user supplies real values; never commit).
5. `app/` was pre-populated from the template (D-025). Ask Q-015/Q-016/Q-017, then: rename package + applicationId, remove approved unused platforms/sample features, run `flutter pub get`, `dart run scripts/check.dart`. Read `app/CLAUDE.md` and `app/docs/` first to follow template conventions (`app/` rules apply to Flutter code; root CLAUDE.md wins on conflict).
6. Create `web/.env.example` with variable *names* only (list proposed in phase 1/2 docs; ask if unsure).
7. Create `.gitignore` entries for env files, build outputs. Ask user whether to `git init`.
8. Ask user to start Brevo sender verification (Q-002) so Phase 2 isn't blocked.
9. Smoke test: `web` dev server renders default page; `app` runs on emulator/device showing placeholder.

## Dependencies / integrations
Flutter SDK, Android SDK, Node.js, Supabase MCP, Brevo account.

## Database / API
None.

## Testing & validation
- `npm run build` (web) succeeds; `flutter analyze` and `flutter build apk --debug` succeed.
- MCP read-only query returns.

## Completion criteria
- [ ] Toolchain versions recorded
- [ ] Supabase project reachable via MCP, tool list documented
- [ ] `web/` and `app/` scaffolded, build and run
- [ ] Hosting decision (Q-005) recorded
- [ ] Brevo verification started or blocker logged
- [ ] PROGRESS updated; user confirmed

## Out of scope
Any schema, auth, or feature code.
