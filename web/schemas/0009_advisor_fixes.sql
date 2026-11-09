-- 0009_advisor_fixes.sql
-- Phase 1 step 11: fixes for Supabase advisor findings (2026-11-09). No behavior change.
-- Findings: function_search_path_mutable (3), anon/authenticated_security_definer_function_executable (4),
-- unindexed_foreign_keys (messages.sender_id).

-- 1. Fixed search_path on the three functions that had none. All objects they touch are
--    schema-qualified (auth.uid) or typed by context, so an empty path is safe.
alter function public.set_updated_at()             set search_path = '';
alter function public.set_alert_status_timestamps() set search_path = '';
alter function public.current_user_id()            set search_path = '';

-- 2. Execute privileges. Functions default to EXECUTE for PUBLIC (and so anon).
--    RLS policies call is_admin() and current_role() as the signed-in role, so
--    `authenticated` keeps EXECUTE on those two; anon never needs them.
revoke execute on function public.is_admin()       from public, anon;
revoke execute on function public.current_role()   from public, anon;
grant  execute on function public.is_admin()       to authenticated, service_role;
grant  execute on function public.current_role()   to authenticated, service_role;

revoke execute on function public.current_user_id() from public, anon;
grant  execute on function public.current_user_id() to authenticated, service_role;

-- Trigger and event-trigger functions are never called through the API; triggers do not
-- check the firing user's EXECUTE privilege.
revoke execute on function public.handle_new_user()               from public, anon, authenticated;
revoke execute on function public.rls_auto_enable()               from public, anon, authenticated;
revoke execute on function public.enforce_max_emergency_contacts() from public, anon, authenticated;
revoke execute on function public.set_updated_at()                from public, anon, authenticated;
revoke execute on function public.set_alert_status_timestamps()   from public, anon, authenticated;

-- 3. Index the foreign key used by message lookups per sender.
create index if not exists idx_messages_sender_id on public.messages (sender_id);
