-- 0008_rls_hardening.sql
-- Phase 1, approved in docs/phases/phase-1-schema.md section 2.3 (H1-H7, H9) and D-044.
-- Q1: remove most client deletes. Q2: chat only while alert is active/acknowledged.
-- Q3: max 3 emergency contacts. Policies keep the existing (select auth.uid()) pattern.

-- H4: clients may edit only name and phone on their own profile (not student_id,
--     university_email, role or email_verified_at). Row policies stay as they are.
revoke update on table public.profiles from authenticated;
grant  update (full_name, phone) on table public.profiles to authenticated;

-- H3: clients may update only read_at on messages (never body or sender_id).
revoke update on table public.messages from authenticated;
grant  update (read_at) on table public.messages to authenticated;

-- H1: a student may only raise a new alert in status 'active' and may only set
--     user_id and the first coordinates; every other column uses its default.
drop policy if exists "students insert own alerts" on public.alerts;
create policy "students insert own alerts" on public.alerts
  for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'active'::public.alert_status);
revoke insert on table public.alerts from authenticated;
grant  insert (user_id, first_latitude, first_longitude) on table public.alerts to authenticated;

-- H2: a location may only be added to the student's own alert while it is open.
drop policy if exists "students insert own locations" on public.locations;
create policy "students insert own locations" on public.locations
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.alerts a
      where a.id = locations.alert_id
        and a.user_id = (select auth.uid())
        and a.status in ('active'::public.alert_status, 'acknowledged'::public.alert_status)
    )
  );

-- H6: students post only on their own open alert; H9: admins post only as themselves.
drop policy if exists "students insert own messages" on public.messages;
create policy "students insert own messages" on public.messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (
      select 1 from public.alerts a
      where a.id = messages.alert_id
        and a.user_id = (select auth.uid())
        and a.status in ('active'::public.alert_status, 'acknowledged'::public.alert_status)
    )
  );

drop policy if exists "admins insert messages on any thread" on public.messages;
create policy "admins insert messages on any thread" on public.messages
  for insert to authenticated
  with check ((select public.is_admin()) and sender_id = (select auth.uid()));

-- H5 (Q1): no client deletes except a student's own emergency contacts.
drop policy if exists "students delete own profile"   on public.profiles;
drop policy if exists "admins delete all profiles"    on public.profiles;
drop policy if exists "admins delete all alerts"      on public.alerts;
drop policy if exists "students delete own messages"  on public.messages;
drop policy if exists "admins delete all messages"    on public.messages;
drop policy if exists "students delete own locations" on public.locations;
drop policy if exists "admins delete all locations"   on public.locations;
revoke delete on table public.profiles, public.alerts, public.messages, public.locations
  from authenticated;

-- H7 (Q3): at most 3 emergency contacts per student. The advisory lock serialises
--          concurrent inserts for the same student so the count cannot be raced.
create or replace function public.enforce_max_emergency_contacts()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text, 0));
  if (select count(*) from public.emergency_contacts where user_id = new.user_id) >= 3 then
    raise exception 'A student can have at most 3 emergency contacts'
      using errcode = 'check_violation';
  end if;
  return new;
end $$;

drop trigger if exists trg_emergency_contacts_max on public.emergency_contacts;
create trigger trg_emergency_contacts_max
  before insert on public.emergency_contacts
  for each row execute function public.enforce_max_emergency_contacts();
