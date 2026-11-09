---
name: nextjs-conventions
description: Use when writing or modifying code in web/ (Next.js admin dashboard and trusted server API).
---

# Next.js Conventions (web/)

- Next.js App Router, TypeScript strict, Tailwind, shadcn/ui. Verify APIs against the installed Next.js version's docs (they change between majors); do not rely on memory.
- Template layout (D-030): routes (`app/api/**`) -> `parseBody(schema)` -> `services/*` (only layer importing Supabase) -> DB; `ServiceResult`, `ok()/fail()`, `withAuth`. Read `web/CLAUDE.md`, `web/AGENTS.md`, `web/.claude/rules/*`, `web/docs/nextjs/16.4.3/` first. Template workflows: `web/.claude/skills/{new-domain,new-api-endpoint,new-migration}`. Template rule 'server-only, no RLS policies' is overridden by D-028.
- Server-only code lives in `services/` and `lib/api/supabase.ts`. Secrets read from server env only; never `NEXT_PUBLIC_*` for secrets. Maintain `.env.example` (names only).
- Every API route: validate input (server-side), authenticate, authorize (admin routes check role), return documented error shapes from `docs/api-contract.md`.
- Never log OTPs, tokens, hashes, API keys.
- Leaflet: client-only dynamic import, OSM attribution visible, tile-error fallback.
- Realtime subscriptions: clean up on unmount; refetch on reconnect.
- CSV export: admin-only; guard against formula injection.
- New dependency → confirm with user, verify current version, record it.
- Run lint, typecheck, build, and tests before marking tasks done.
