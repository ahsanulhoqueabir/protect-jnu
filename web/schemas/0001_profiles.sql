-- 0001_profiles.sql — profiles table (1:1 with auth.users)
-- Convention: migrations are append-only, numbered, idempotent. Never edit an applied file.

create table if not exists public.profiles (
  id          uuid primary key default gen_random_uuid(),
  "user"      uuid not null unique references auth.users (id) on delete cascade,
  email       text not null,
  name        text not null,
  username    text,
  role        text not null default 'user',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Case-insensitive unique username (partial: NULLs allowed many times)
create unique index if not exists profiles_username_key
  on public.profiles (lower(username)) where username is not null;
create index if not exists profiles_email_idx on public.profiles (email);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- All access goes through the server (service role, bypasses RLS).
-- RLS on + no policies = anon/authenticated keys can read/write nothing.
alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
