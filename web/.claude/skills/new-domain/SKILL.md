---
name: new-domain
description: Scaffold a complete new feature domain (e.g. "posts", "orders") following this template's architecture — migration, types, Zod schema, service, API routes, store. Use when adding a new entity/resource to the app.
---

Follow `.claude/rules/architecture.md` and `.claude/rules/database.md`. Reference implementation: the `profile` / `auth` domains. Replace `x` with the singular domain name.

Do these in order, then verify:

1. **Migration** `schemas/NNNN_x.sql` (next number): table (uuid PK, timestamps, FKs, indexes, RLS on, revoke from anon/authenticated), `x_public` view if clients shouldn't see all columns, RPC for any multi-write operation.
2. **`types/database.types.ts`**: add Table Row/Insert/Update, View, and Function entries.
3. **`types/x.types.ts`**: derive from `Database` (`XInsert`, `XUpdate = Partial<Omit<…>>`, `PublicX`); params via `z.infer`. No duplicated columns.
4. **`schema/x.schema.ts`**: `createXSchema`, `updateXSchema = createXSchema.partial()`, query/pagination schema. Shared by forms and routes.
5. **`services/x.service.ts`**: `class XService` with static methods returning `ServiceResult<T>`; the only file touching Supabase for this domain; use RPC for atomic ops and views for reads.
6. **`app/api/x/route.ts`** (+ `[id]/route.ts`): `withAuth` → `parseBody` → service → `ok`/`fail`. No Supabase import.
7. **`store/x.store.ts`** (if client state is needed): zustand + `api_client`, mirroring `auth.store.ts`.
8. Verify: `npx tsc --noEmit`, `npm run lint`, `npm run build`, `npm audit`.
