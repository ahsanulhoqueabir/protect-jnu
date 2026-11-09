-- 0000_baseline_applied_2026-11-08.sql
-- DOCUMENTATION ONLY. DO NOT RE-RUN.
-- Verbatim copy of the 16 migrations that were already applied to the dev project
-- (bthjjlpylvauiolwrdfn) on 2026-11-08, before the repo tracked migrations. Read from
-- supabase_migrations.schema_migrations on 2026-11-09. Later migrations 0004+ build on this.
-- NOTE: web/schemas/0001-0003 (template) describe a different, older profiles shape and are stale.
-- NOTE: later migrations changed several of these objects (see 0006, 0008, 0009, 0010).

-- ============================================================================
-- 20261108124818  initial_schema_types
-- ============================================================================
-- Phase 01 — extension and enums
create extension if not exists pgcrypto with schema extensions;

do $$ begin
  create type public.user_role as enum ('user', 'admin');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.alert_status as enum ('active', 'acknowledged', 'resolved', 'cancelled');
exception when duplicate_object then null;
end $$;

-- ============================================================================
-- 20261108124823  initial_schema_tables
-- ============================================================================
-- Phase 01 — tables
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  student_id text not null,
  university_email text not null unique,
  phone text,
  role public.user_role not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  phone text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.alert_status not null default 'active',
  started_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  cancelled_at timestamptz,
  first_latitude double precision,
  first_longitude double precision,
  last_updated_at timestamptz not null default now()
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  accuracy double precision,
  recorded_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  sent_at timestamptz not null default now(),
  read_at timestamptz
);

-- ============================================================================
-- 20261108124827  initial_schema_indexes
-- ============================================================================
-- Phase 01 — indexes
create index if not exists idx_profiles_role on public.profiles (role);
create index if not exists idx_profiles_student_id on public.profiles (student_id);

create index if not exists idx_emergency_contacts_user_id on public.emergency_contacts (user_id);

create index if not exists idx_alerts_user_id on public.alerts (user_id);
create index if not exists idx_alerts_status on public.alerts (status);
create index if not exists idx_alerts_started_at on public.alerts (started_at);

create index if not exists idx_locations_alert_recorded_at on public.locations (alert_id, recorded_at desc);
create index if not exists idx_locations_user_id on public.locations (user_id);

create index if not exists idx_messages_alert_sent_at on public.messages (alert_id, sent_at);
create index if not exists idx_messages_alert_unread on public.messages (alert_id) where read_at is null;

-- ============================================================================
-- 20261108124836  initial_schema_triggers
-- ============================================================================
-- Phase 01 — triggers
-- 3.1 handle_new_user: profile creation + anchored domain enforcement (FR-AUTH-02, RISK-03)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(coalesce(new.email, '')));
  v_full_name text := coalesce(new.raw_user_meta_data ->> 'full_name', '');
  v_student_id text := coalesce(new.raw_user_meta_data ->> 'student_id', '');
begin
  if v_email !~ '^[^@]+@jnu\.ac\.bd$' then
    raise exception 'Only @jnu.ac.bd email addresses are allowed'
      using errcode = 'check_violation';
  end if;

  insert into public.profiles (id, full_name, student_id, university_email)
  values (new.id, v_full_name, v_student_id, v_email);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3.2 set_updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_set_updated_at on public.profiles;
create trigger trg_profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- 3.3 set_alert_status_timestamps
create or replace function public.set_alert_status_timestamps()
returns trigger
language plpgsql
as $$
begin
  new.last_updated_at = now();

  if new.status is distinct from old.status then
    case new.status
      when 'acknowledged' then
        new.acknowledged_at = coalesce(new.acknowledged_at, now());
      when 'resolved' then
        new.resolved_at = coalesce(new.resolved_at, now());
      when 'cancelled' then
        new.cancelled_at = coalesce(new.cancelled_at, now());
    end case;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_alerts_set_status_timestamps on public.alerts;
create trigger trg_alerts_set_status_timestamps
  before update on public.alerts
  for each row execute function public.set_alert_status_timestamps();

-- ============================================================================
-- 20261108124842  initial_schema_rls_helpers
-- ============================================================================
-- Phase 01 — RLS helper functions
-- is_admin is security definer so it can read profiles regardless of the policy being evaluated.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

create or replace function public.current_user_id()
returns uuid
language sql
stable
as $$ select auth.uid(); $$;

-- Enable RLS on every table (NFR-SEC-03)
alter table public.profiles          enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.alerts            enable row level security;
alter table public.locations         enable row level security;
alter table public.messages          enable row level security;

-- ============================================================================
-- 20261108124847  initial_schema_rls_profiles
-- ============================================================================
-- Phase 01 — RLS policies: profiles
-- Student: read own row only.
drop policy if exists "students read own profile" on public.profiles;
create policy "students read own profile"
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()));

-- Admin: read all profiles.
drop policy if exists "admins read all profiles" on public.profiles;
create policy "admins read all profiles"
  on public.profiles for select
  to authenticated
  using ((select public.is_admin()));

-- Student: update own row, but role must stay pinned to its current value (no self-promotion).
drop policy if exists "students update own profile" on public.profiles;
create policy "students update own profile"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (
    id = (select auth.uid())
    and role = (select p.role from public.profiles p where p.id = (select auth.uid()))
  );

-- Admin: update any profile (this is the only path to role = 'admin').
drop policy if exists "admins update all profiles" on public.profiles;
create policy "admins update all profiles"
  on public.profiles for update
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- Student: delete own row.
drop policy if exists "students delete own profile" on public.profiles;
create policy "students delete own profile"
  on public.profiles for delete
  to authenticated
  using (id = (select auth.uid()));

-- Admin: delete any profile.
drop policy if exists "admins delete all profiles" on public.profiles;
create policy "admins delete all profiles"
  on public.profiles for delete
  to authenticated
  using ((select public.is_admin()));

-- ============================================================================
-- 20261108124852  initial_schema_rls_contacts_alerts
-- ============================================================================
-- Phase 01 — RLS policies: emergency_contacts
drop policy if exists "students read own contacts" on public.emergency_contacts;
create policy "students read own contacts"
  on public.emergency_contacts for select
  to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

drop policy if exists "students insert own contacts" on public.emergency_contacts;
create policy "students insert own contacts"
  on public.emergency_contacts for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "students update own contacts" on public.emergency_contacts;
create policy "students update own contacts"
  on public.emergency_contacts for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "students delete own contacts" on public.emergency_contacts;
create policy "students delete own contacts"
  on public.emergency_contacts for delete
  to authenticated
  using (user_id = (select auth.uid()));

-- Phase 01 — RLS policies: alerts
drop policy if exists "students read own alerts" on public.alerts;
create policy "students read own alerts"
  on public.alerts for select
  to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

drop policy if exists "students insert own alerts" on public.alerts;
create policy "students insert own alerts"
  on public.alerts for insert
  to authenticated
  with check (user_id = (select auth.uid()));

-- Student update is restricted to active -> cancelled only (FR-SOS-05).
-- A student cannot acknowledge or resolve their own alert.
drop policy if exists "students cancel own active alerts" on public.alerts;
create policy "students cancel own active alerts"
  on public.alerts for update
  to authenticated
  using (user_id = (select auth.uid()) and status = 'active')
  with check (
    user_id = (select auth.uid())
    and status = 'cancelled'
    and started_at = (select a.started_at from public.alerts a where a.id = alerts.id)
  );

-- Admin: update any alert, any status (FR-SOS-04).
drop policy if exists "admins update all alerts" on public.alerts;
create policy "admins update all alerts"
  on public.alerts for update
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

drop policy if exists "admins delete all alerts" on public.alerts;
create policy "admins delete all alerts"
  on public.alerts for delete
  to authenticated
  using ((select public.is_admin()));

-- ============================================================================
-- 20261108124858  initial_schema_rls_locations_messages
-- ============================================================================
-- Phase 01 — RLS policies: locations
drop policy if exists "students read own locations" on public.locations;
create policy "students read own locations"
  on public.locations for select
  to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

drop policy if exists "students insert own locations" on public.locations;
create policy "students insert own locations"
  on public.locations for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "students delete own locations" on public.locations;
create policy "students delete own locations"
  on public.locations for delete
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "admins delete all locations" on public.locations;
create policy "admins delete all locations"
  on public.locations for delete
  to authenticated
  using ((select public.is_admin()));

-- Phase 01 — RLS policies: messages
-- One thread per alert: a student may read messages on their own alerts.
drop policy if exists "students read messages on own threads" on public.messages;
create policy "students read messages on own threads"
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1 from public.alerts a
      where a.id = messages.alert_id
        and (a.user_id = (select auth.uid()) or (select public.is_admin()))
    )
  );

-- A student may only insert as themselves, on their own alert's thread.
drop policy if exists "students insert own messages" on public.messages;
create policy "students insert own messages"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (
      select 1 from public.alerts a
      where a.id = messages.alert_id
        and (a.user_id = (select auth.uid()) or (select public.is_admin()))
    )
  );

-- Mark-read on own threads.
drop policy if exists "students mark read on own threads" on public.messages;
create policy "students mark read on own threads"
  on public.messages for update
  to authenticated
  using (
    exists (
      select 1 from public.alerts a
      where a.id = messages.alert_id
        and (a.user_id = (select auth.uid()) or (select public.is_admin()))
    )
  )
  with check (
    exists (
      select 1 from public.alerts a
      where a.id = messages.alert_id
        and (a.user_id = (select auth.uid()) or (select public.is_admin()))
    )
  );

-- Students may delete their own messages only.
drop policy if exists "students delete own messages" on public.messages;
create policy "students delete own messages"
  on public.messages for delete
  to authenticated
  using (sender_id = (select auth.uid()));

-- Admins: read all messages, insert on any thread, delete any message.
drop policy if exists "admins read all messages" on public.messages;
create policy "admins read all messages"
  on public.messages for select
  to authenticated
  using ((select public.is_admin()));

drop policy if exists "admins insert messages on any thread" on public.messages;
create policy "admins insert messages on any thread"
  on public.messages for insert
  to authenticated
  with check ((select public.is_admin()));

drop policy if exists "admins update all messages" on public.messages;
create policy "admins update all messages"
  on public.messages for update
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

drop policy if exists "admins delete all messages" on public.messages;
create policy "admins delete all messages"
  on public.messages for delete
  to authenticated
  using ((select public.is_admin()));

-- ============================================================================
-- 20261108124916  initial_schema_grants
-- ============================================================================
-- Phase 01 — tighten table grants (data-model §4)
-- anon gets no access at all; authenticated gets exactly the operations the policies cover.
revoke all on public.profiles          from anon, authenticated;
revoke all on public.emergency_contacts from anon, authenticated;
revoke all on public.alerts            from anon, authenticated;
revoke all on public.locations         from anon, authenticated;
revoke all on public.messages          from anon, authenticated;

grant select, update, delete on public.profiles          to authenticated;
grant select, insert, update, delete on public.emergency_contacts to authenticated;
grant select, insert, update, delete on public.alerts      to authenticated;
grant select, insert, delete        on public.locations   to authenticated;
grant select, insert, update, delete on public.messages    to authenticated;

-- The trigger inserts into profiles as security definer; grant the function's
-- owner the needed rights explicitly and keep anon out of the table entirely.
grant usage on schema public to anon, authenticated;

-- ============================================================================
-- 20261108125021  fix_alerts_update_policy_recursion
-- ============================================================================
-- Phase 01 fix — infinite recursion in the student alerts UPDATE policy.
--
-- The WITH CHECK clause contained a subquery on public.alerts, which re-entered
-- the same policy and triggered "infinite recursion detected in policy for
-- relation alerts". The started_at guard is dropped; the ownership and the
-- status restriction still hold, and the trigger enforces the timestamps.
--
-- The recursion-safe way to pin a column to its existing value in a WITH CHECK
-- is to compare against the OLD row via a BEFORE UPDATE trigger, not a
-- subquery against the same table.
create or replace function public.set_alert_status_timestamps()
returns trigger
language plpgsql
as $$
begin
  new.last_updated_at = now();

  -- Pin started_at: it is the report-period source (FR-RPT-04) and must not
  -- be editable after the alert is created.
  new.started_at = old.started_at;

  -- Pin the user_id owner: ownership cannot change after creation.
  new.user_id = old.user_id;

  if new.status is distinct from old.status then
    case new.status
      when 'acknowledged' then
        new.acknowledged_at = coalesce(new.acknowledged_at, now());
      when 'resolved' then
        new.resolved_at = coalesce(new.resolved_at, now());
      when 'cancelled' then
        new.cancelled_at = coalesce(new.cancelled_at, now());
    end case;
  end if;

  return new;
end;
$$;

drop policy if exists "students cancel own active alerts" on public.alerts;
create policy "students cancel own active alerts"
  on public.alerts for update
  to authenticated
  using (user_id = (select auth.uid()) and status = 'active')
  with check (
    user_id = (select auth.uid())
    and status = 'cancelled'
  );

-- ============================================================================
-- 20261108125029  fix_profiles_update_policy_recursion
-- ============================================================================
-- Phase 01 fix — infinite recursion in the student profiles UPDATE policy.
--
-- The WITH CHECK clause compared `role` against a subquery on public.profiles,
-- which re-entered the same policy and raised 42P17. The role pin now lives in
-- the BEFORE UPDATE trigger, which reads OLD.role without touching the
-- table's own policy. The policy keeps the ownership check.
--
-- The trigger also runs for admins, so the pin is applied only when the actor
-- is not an admin — otherwise the admin promotion path (seeding.md §3.2)
-- would break.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();

  -- A student cannot change their own role (FR-AUTH-06, self-promotion hole).
  -- Admins may, via the admin update policy.
  if not (select public.is_admin()) then
    new.role = old.role;
  end if;

  return new;
end;
$$;

drop policy if exists "students update own profile" on public.profiles;
create policy "students update own profile"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ============================================================================
-- 20261108125056  harden_profiles_role_policy
-- ============================================================================
-- Phase 01 — make the student role change a hard denial, not a silent revert.
--
-- The WITH CHECK needs to know the caller's current role without re-entering
-- the profiles policy. current_role() is security definer, so it reads the
-- table under the definer's rights and bypasses RLS — no recursion, and the
-- matrix case 11 gets a real 42501 instead of a silent no-op.

create or replace function public.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select p.role from public.profiles p where p.id = (select auth.uid());
$$;

drop policy if exists "students update own profile" on public.profiles;
create policy "students update own profile"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (
    id = (select auth.uid())
    and role = (select public.current_role())
  );

-- ============================================================================
-- 20261108125106  move_role_pin_from_trigger_to_policy
-- ============================================================================
-- Phase 01 — move the role pin out of the trigger and into the policy.
--
-- The trigger ran BEFORE the WITH CHECK and reset role to old.role, so the
-- policy then compared the already-corrected row and the self-promotion
-- silently succeeded instead of being denied. Enforcing the role pin only in
-- the policy makes case 11 a hard 42501, which is what the matrix expects.
--
-- The trigger keeps the updated_at maintenance only.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================================
-- 20261108125832  grant_gotrue_role_access_to_auth_schema
-- ============================================================================
-- Phase 01 — GoTrue role grants.
--
-- The password grant failed with "Database error querying schema" (500) for
-- every user. The acting role needs SELECT on auth.users / auth.identities
-- to look the user up. Neither `service_role` nor `authenticator` had it:
-- the auth tables are owned by `supabase_auth_admin`, and RLS is enabled with
-- no policies, so a non-owner role sees zero rows.
--
-- Grant the read access GoTrue needs. It is scoped to the auth schema's own
-- tables and does not touch the public schema.
grant usage on schema auth to authenticator, service_role;

grant select on auth.users      to authenticator, service_role;
grant select on auth.identities to authenticator, service_role;
grant select on auth.sessions   to authenticator, service_role;
grant select on auth.flow_state to authenticator, service_role;
grant select on auth.one_time_tokens to authenticator, service_role;

-- ============================================================================
-- 20261108125901  grant_gotrue_full_auth_schema_access
-- ============================================================================
-- Phase 01 — complete GoTrue access to the auth schema.
--
-- GoTrue's client connection authenticates as `authenticator`, which inherits
-- anon/authenticated/service_role. The auth tables are owned by
-- `supabase_auth_admin` and have RLS enabled with no policies, so only the
-- owner or a BYPASSRLS role with explicit table grants can read them.
-- `service_role` has rolbypassrls but had no table grants at all, so the
-- password grant failed with "Database error querying schema" (500) for every
-- user — including the correct password.
--
-- Grant the full CRUD GoTrue needs on its own schema's tables. This is scoped
-- to the `auth` schema and does not widen access to `public`.

grant usage on schema auth to authenticator, service_role;

grant select, insert, update, delete on auth.users      to authenticator, service_role;
grant select, insert, update, delete on auth.identities to authenticator, service_role;
grant select, insert, update, delete on auth.sessions   to authenticator, service_role;
grant select, insert, update, delete on auth.flow_state to authenticator, service_role;
grant select, insert, update, delete on auth.one_time_tokens to authenticator, service_role;
grant select, insert, update, delete on auth.mfa_factors, auth.mfa_challenges, auth.mfa_amr_claims
  to authenticator, service_role;

-- ============================================================================
-- 20261108125915  normalize_auth_users_string_columns
-- ============================================================================
-- Phase 01 — normalise the auth.users string columns.
--
-- A row inserted directly into auth.users leaves several of GoTrue's string
-- columns as NULL, where GoTrue's own writes always store '' (empty string).
-- GoTrue scans these columns into Go string fields; a NULL there fails the
-- scan and surfaces as "Database error querying schema" (500) on every
-- request that touches the row — including a password grant with the correct
-- password.
--
-- The columns are all generated/defaulted text fields with no semantic
-- meaning when empty, so '' is the correct "unset" value.
--
-- Note: confirmed_at and identities.email are GENERATED columns and cannot be
-- written directly.

update auth.users
   set confirmation_token        = coalesce(confirmation_token, ''),
       recovery_token            = coalesce(recovery_token, ''),
       email_change              = coalesce(email_change, ''),
       email_change_token_new    = coalesce(email_change_token_new, ''),
       email_change_token_current = coalesce(email_change_token_current, ''),
       reauthentication_token    = coalesce(reauthentication_token, ''),
       phone_change              = coalesce(phone_change, ''),
       phone_change_token        = coalesce(phone_change_token, '')
 where email = 'probe2.test@jnu.ac.bd';
