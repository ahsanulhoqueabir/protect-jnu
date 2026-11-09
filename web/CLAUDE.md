# CLAUDE.md

@AGENTS.md
@.claude/rules/architecture.md
@.claude/rules/database.md

## Project

Reusable Next.js 16.4.3 (App Router) + Supabase starter: custom JWT auth, Zustand + axios on the client, Zod 4 validation, Tailwind 4 + shadcn/ui. Treat it as the template for future projects — keep the architecture intact when adding features.

## Commands

- `npm run dev` / `npm run build` / `npm run lint` / `npx tsc --noEmit` / `npm audit`
- `npm run docs:sync` — refresh `docs/nextjs/<version>/` after upgrading `next`

## How to work here

1. **Next.js questions or code:** read `docs/nextjs/16.4.3/` first (map in `docs/README.md`); never `node_modules/next/dist/docs/`.
2. **New feature / entity:** use the `new-domain` skill. **Single endpoint:** `new-api-endpoint`. **DB change:** `new-migration` (and load the `supabase-postgres-best-practices` skill).
3. **Layering is non-negotiable:** routes never import Supabase; services own all queries/RPC and return `ServiceResult`; request bodies are validated with schemas from `schema/`; types derive from `types/database.types.ts` instead of redeclaring columns.
4. **Database:** atomic multi-write → RPC; paired rows → trigger; client-facing reads → `security_invoker` views. SQL goes in `schemas/NNNN_*.sql`, append-only; tell the user to apply it.
5. **Never** commit secrets (`.env*` is gitignored except `.env.example`) or edit `docs/nextjs/*` by hand.
6. Match surrounding code style; verify with the commands above before reporting done.
