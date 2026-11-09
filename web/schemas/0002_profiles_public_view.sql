-- 0002_profiles_public_view.sql — client-safe projection of profiles
-- security_invoker: the view runs with the caller's privileges (RLS still applies).
create or replace view public.profiles_public
with (security_invoker = true) as
  select id, email, name, username, role
  from public.profiles;

revoke all on public.profiles_public from anon, authenticated;
