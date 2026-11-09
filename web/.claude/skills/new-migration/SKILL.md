---
name: new-migration
description: Create a Supabase SQL migration (table, view, RPC function, trigger, index, RLS) in the schemas/ folder and sync database types. Use for any database change.
---

1. Load the `supabase-postgres-best-practices` skill and read `.claude/rules/database.md`.
2. List `schemas/`; create `schemas/NNNN_snake_description.sql` with the next number. Never edit an applied file — add a new one.
3. Make it idempotent. Atomic multi-step logic → RPC function; always-together rows → trigger; client-safe/complex reads → `security_invoker` view.

RPC skeleton:

```sql
create or replace function public.verb_noun(p_id uuid, p_qty int)
returns public.some_table
language plpgsql
set search_path = ''
as $$
declare r public.some_table;
begin
  -- all statements here commit or roll back together
  update public.some_table set qty = qty - p_qty where id = p_id returning * into r;
  if r.qty < 0 then raise exception 'Insufficient quantity'; end if;
  return r;
end $$;

revoke execute on function public.verb_noun(uuid, int) from public, anon, authenticated;
grant execute on function public.verb_noun(uuid, int) to service_role;
```

4. Update `types/database.types.ts` (Tables / Views / Functions `Args` + `Returns`).
5. Call it only from a service: `getSupabaseServerClient().rpc("verb_noun", { p_id, p_qty })`.
6. Tell the user to apply the SQL (Supabase SQL editor or `supabase db push`); you cannot assume it was applied.
