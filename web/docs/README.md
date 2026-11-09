# Project docs

Shared, version-controlled documentation. Do not rely on `node_modules` for docs — local installs can differ.

## Next.js 16.4.3 (App Router)

Location: [`docs/nextjs/16.4.3/`](nextjs/16.4.3/index.md) — copied from the docs bundled with `next@16.4.3` (the exact version pinned in `package.json`). Pages Router and community docs are intentionally excluded; this project uses `app/` only.

| Need | Read |
|---|---|
| Project layout, conventions | `01-app/01-getting-started/02-project-structure.md` |
| Layouts, pages, linking | `01-getting-started/03-…`, `04-…` |
| Server vs Client Components | `01-getting-started/05-server-and-client-components.md` |
| Data fetching / mutations | `01-getting-started/06-…`, `07-…` |
| Caching & revalidation | `01-getting-started/08-caching.md`, `09-revalidating.md` |
| **API routes (`route.ts`)** | `01-getting-started/15-route-handlers.md`, `03-api-reference/03-file-conventions/route.md` |
| **Middleware replacement (`proxy.ts`)** | `01-getting-started/16-proxy.md`, `03-api-reference/03-file-conventions/proxy.md` |
| Auth & data security | `02-guides/authentication.md`, `02-guides/data-security.md` |
| Env variables | `02-guides/environment-variables.md` |
| Upgrading | `01-getting-started/18-upgrading.md`, `02-guides/upgrading/` |
| Any API (components, functions, config) | `03-api-reference/` |

## Upgrading Next.js

1. `npm install next@<v> eslint-config-next@<v> --save-exact`
2. `npm run docs:sync` (replaces `docs/nextjs/*` with the new version)
3. Update the version path in `AGENTS.md`, `CLAUDE.md`, and this file; commit the docs with the upgrade.

## Project conventions

- [Architecture](../.claude/rules/architecture.md)
- [Database](../.claude/rules/database.md)
