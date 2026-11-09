# Architecture (template rules — follow in every feature)

Stack: Next.js 16.4.3 (App Router; read the committed docs in `docs/nextjs/16.4.3/` first, never `node_modules`) · React 19 · Supabase (service-role, server-only) · custom JWT (`jose`) · Zustand + axios · Zod 4 · Tailwind 4 + shadcn/ui.

## Request flow (strict, one direction)

```
UI/page → store (zustand) → lib/api/api-client (axios) → app/api/**/route.ts
        → parseBody(schema) → services/<domain>.service.ts → Supabase (tables / views / RPC)
```

| Layer | Folder | Responsibility | Must NOT |
|---|---|---|---|
| Route | `app/api/**/route.ts` | HTTP only: `withAuth`, `parseBody`, call service, `ok()`/`fail()` | import Supabase, contain business logic |
| Validation | `schema/<domain>.schema.ts` | Zod schemas shared by client forms AND routes | be redefined elsewhere |
| Service | `services/<domain>.service.ts` | Business logic + ALL Supabase queries/writes/RPC | return raw throws; import `next/server` |
| Types | `types/<domain>.types.ts` | Domain types (flat folder, no subfolders) | redeclare DB columns |
| DB history | `schemas/NNNN_*.sql` | Append-only migrations (tables, views, RPC, triggers, RLS) | be edited once applied |
| Client state | `store/<domain>.store.ts` | Zustand + `api_client` calls | call Supabase |
| Lib | `lib/` | Infra helpers (`api/`: response, middleware, validate, supabase client) | hold domain logic |

Naming trap: `schema/` (singular) = Zod. `schemas/` (plural) = SQL migrations.

## Hard rules

1. **No Supabase import outside `services/` and `lib/api/supabase.ts`.** Routes call services only.
2. **Services return `ServiceResult<T>`** (`success()` / `failure()` from `lib/service-result.ts`), wrap in try/catch with `toMessage(err)`. Routes map failure → HTTP status.
3. **Validate every request body/query with a shared Zod schema** via `parseBody`. Client forms use the same schema's `safeParse`. Never hand-check fields.
4. **Types:** flat `types/<domain>.types.ts`. Derive, don't duplicate: `Pick`/`Omit`/`Partial`/`Required`/`Record`/`Extract`/`Exclude`, `z.infer<typeof schema>`, and `Database["public"]["Tables"][...]`. `types/database.types.ts` is the only place columns are declared (regenerate with `supabase gen types`).
5. **Never expose full DB rows to the client.** Return a view/projection type (e.g. `PublicProfile` from `profiles_public`).
6. **Responses:** `ok({data,message,statusCode})` / `fail({error,statusCode})`; shape `{success, data?, message?, error?}`. Statuses: 400 bad input, 401 unauth, 403 forbidden, 404 missing, 422 validation, 500 unexpected.
7. **Protected routes** use `withAuth(({ req, user }) => …)`; `user` is `JwtPayload`. Authorize by role/ownership in the service, not the client.
8. **Secrets:** server vars never `NEXT_PUBLIC_`; read via `config/env.config.ts`; `.env.example` must hold placeholders only.
9. **Never call `signIn*` on the service-role singleton** — use `createSupabaseAuthClient()`.
10. Imports use `@/` alias. Match the surrounding code style; run `npx tsc --noEmit` and `npm run lint` before finishing.
11. **Dependencies:** run `npm audit` after any install; keep it at 0. CLI-only tools (`shadcn`) go in devDependencies. Pin `next` and `eslint-config-next` to the same exact version.
