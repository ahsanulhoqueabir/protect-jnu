# Database rules (senior-architect checklist)

All DB changes are SQL files in `schemas/NNNN_description.sql` — numbered, append-only, idempotent (`if not exists`, `create or replace`, `drop … if exists`). Update `types/database.types.ts` in the same change.

## Atomicity — choose the mechanism
- **Several writes must all succeed or all fail → one Postgres function (RPC)**, called from the service with `supabase.rpc("fn_name", args)`. Never chain multiple `.insert()` calls from Node and "clean up" on failure.
- **A row must always accompany another row** (e.g. profile per auth user) → trigger in the same transaction (see `0003_handle_new_user.sql`).
- Single-statement writes need no RPC.
- RPC conventions: name `verb_noun`, params prefixed `p_`, `language plpgsql`, `set search_path = ''` + fully qualified names, `security invoker` by default; `security definer` only with an explicit reason, and `revoke execute … from public, anon, authenticated` then grant to `service_role`. Raise exceptions with clear messages; the service surfaces `error.message`. Add the function to `Database["public"]["Functions"]` with `Args`/`Returns`.

## Views
- Use for client-safe projections (`profiles_public`) and repeated joins/aggregations. Create with `security_invoker = true`. Services query the view, not the join. Add to `Database["public"]["Views"]`.

## Tables
- `uuid` PK (`gen_random_uuid()`), `created_at`/`updated_at timestamptz` with `set_updated_at` trigger, `references … on delete` chosen deliberately.
- Index every FK and every column used in `where`/`order by`; use partial / expression indexes where they fit; unique constraints in the DB, not just app code (map the violation to a friendly 409).
- Enable RLS on every table. Server uses the service role; `revoke all … from anon, authenticated` unless a client-direct policy is intentionally added.

## Queries
- Select only needed columns (no `select("*")` on wide/hot tables); paginate with `.range()` / keyset on indexed columns; never unbounded lists.
- `.maybeSingle()` when zero rows is valid; `.single()` only when exactly one is guaranteed.
- Batch with `upsert`/`in()`/RPC instead of loops of round-trips.
