# Agent instructions (all coding agents)

## This is NOT the Next.js you know

This project uses **Next.js 16.4.3**, which has breaking changes — APIs, conventions, and file structure may differ from your training data (e.g. `proxy.ts` replaces `middleware.ts`). Before writing Next.js code, read the relevant guide in the **committed docs: [`docs/nextjs/16.4.3/`](docs/nextjs/16.4.3/index.md)** (task → doc map in [`docs/README.md`](docs/README.md)). Do NOT read from `node_modules/next/dist/docs/` — local installs may differ. Heed deprecation notices.

## Project conventions (mandatory)

Layered architecture: route → shared Zod schema → service (only layer allowed to touch Supabase) → DB (tables / views / RPC). Types live flat in `types/<domain>.types.ts`; Zod in `schema/`; SQL migrations in `schemas/`.

- Architecture: [`.claude/rules/architecture.md`](.claude/rules/architecture.md)
- Database: [`.claude/rules/database.md`](.claude/rules/database.md)
- Workflows: skills in `.claude/skills/` (`new-domain`, `new-api-endpoint`, `new-migration`) — follow them step by step even if your tool doesn't auto-load skills.

## Before finishing

`npx tsc --noEmit` · `npm run lint` · `npm run build` · `npm audit` (keep at 0).
