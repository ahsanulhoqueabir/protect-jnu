-- 0007_auth_otp_tables.sql
-- Phase 1, approved in docs/phases/phase-1-schema.md (D-006, D-012, D-016, D-019, D-044).
-- OTP records and send-rate-limit events. RLS ON, NO policies, no client privileges:
-- only trusted server code (service_role) may read or write these tables (PRD 7.6).

do $$
begin
  if not exists (select 1 from pg_type where typname = 'otp_purpose' and typnamespace = 'public'::regnamespace) then
    create type public.otp_purpose as enum ('email_verification', 'password_reset');
  end if;
end $$;

create table if not exists public.otp_codes (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  purpose        public.otp_purpose not null,
  code_hash      text not null,                       -- HMAC of the code; plaintext is never stored
  expires_at     timestamptz not null,
  attempts       smallint not null default 0 check (attempts >= 0),
  consumed_at    timestamptz,                         -- single use
  invalidated_at timestamptz,                         -- set when a newer code replaces this one
  created_at     timestamptz not null default now()
);

create index if not exists idx_otp_codes_user_purpose_created
  on public.otp_codes (user_id, purpose, created_at desc);

-- At most one live (unused, not invalidated) code per user and purpose.
create unique index if not exists uq_otp_codes_one_live
  on public.otp_codes (user_id, purpose)
  where consumed_at is null and invalidated_at is null;

create table if not exists public.otp_send_events (
  id         uuid primary key default gen_random_uuid(),
  email      text not null check (email = lower(email)),
  purpose    public.otp_purpose not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_otp_send_events_email_purpose_created
  on public.otp_send_events (email, purpose, created_at desc);

alter table public.otp_codes       enable row level security;
alter table public.otp_send_events enable row level security;

revoke all on table public.otp_codes       from anon, authenticated;
revoke all on table public.otp_send_events from anon, authenticated;
grant  all on table public.otp_codes       to service_role;
grant  all on table public.otp_send_events to service_role;
