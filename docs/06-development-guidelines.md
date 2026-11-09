# Development Guidelines

## Anti-hallucination protocol
1. Requirement not in PRD/docs/user answers → it's undecided → ask.
2. Library/API usage → check official docs or package source first; state the version used; record added dependencies in the phase doc and PROGRESS.
3. Do not invent endpoints, columns, enum values, env var names. Define them in docs first (API contract / schema section of the phase), then implement.
4. Mark anything unverified as such in your response. Never claim tests passed without running them.
5. Prefer small, reviewable changes; one phase task at a time.

## API contract rule
Every server endpoint is documented in `docs/api-contract.md` (create in Phase 2, extend later) with: method, path, auth, request/response JSON, error codes, rate limits. Flutter and web both implement against this file, not against each other's code.

## Security
- Secrets only in server env (`web/.env.local`, hosting env). Provide `web/.env.example` with names only.
- `NEXT_PUBLIC_*` variables must never hold secrets.
- Validate all input on the server (e.g. zod — PROPOSED, confirm). Email domain check server-side.
- Generic auth errors where enumeration is a risk (confirm wording with user).
- No OTP/token/hash/API-key in logs or error bodies.
- HTTPS only; no cleartext traffic config in Android release.

## Web (`web/`)
TypeScript strict. Template layering (D-030): route → Zod schema → `services/` (only layer touching Supabase). Read `web/CLAUDE.md` and `web/docs/nextjs/16.4.3/` first. Admin API routes: authenticate + check role on every request. UI via shadcn/ui + Tailwind. Leaflet loaded client-side only (dynamic import, no SSR). Show OSM attribution.

## Flutter (`app/`)
Feature-first, Riverpod providers per feature, go_router with auth/verification guards. No secrets in assets. Android only (min SDK 26 = Android 8.0, derived from PRD). Location only after SOS. Handle permission denial states explicitly.

## Testing
- Server: unit tests for OTP logic (expiry, reuse, attempts, cooldown, rate limit); integration tests for endpoints with Brevo mocked, plus a manual real-delivery check.
- DB: RLS matrix via MCP.
- Flutter: unit/widget tests for guards and SOS timer logic; manual device tests for foreground service, camera, offline queue.
- Web: component/route tests where cheap; manual E2E of alert → map → chat → resolve.
- Each phase doc lists its validation steps; run them all before marking done.

## Git (when repo initialized — not yet a git repo)
Branch per phase `phase-N-<slug>`; conventional commits; never commit `.env*` (except `.env.example`), keys, or build artifacts. Ask the user before `git init`/pushing.

## Definition of done (any task)
Implemented · tests/validation run with results noted · docs updated (decisions, API contract, schema) · PROGRESS.md updated.
