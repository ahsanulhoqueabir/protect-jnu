-- 0011_otp_functions.sql
-- Phase 2: atomic OTP operations for the trusted server (docs/api-contract.md section 3, D-012, D-047).
-- All functions: fixed empty search_path, fully qualified names, EXECUTE only for service_role.
-- They are SECURITY INVOKER (the service role bypasses RLS) except revoke_user_sessions (see its comment).
-- The server never sends or receives a plaintext code here: only the HMAC hash.

-- Issue a new code: enforces the resend cooldown and the per-window send limit, supersedes any live
-- code for the same user and purpose, stores the new hash and records the send, all in one transaction.
create or replace function public.otp_issue(
  p_user_id          uuid,
  p_email            text,
  p_purpose          public.otp_purpose,
  p_code_hash        text,
  p_ttl_seconds      integer,
  p_cooldown_seconds integer,
  p_window_seconds   integer,
  p_max_sends        integer
)
returns table (status text, otp_id uuid, retry_after_seconds integer)
language plpgsql
set search_path = ''
as $$
declare
  v_email  text := lower(trim(p_email));
  v_last   timestamptz;
  v_count  integer;
  v_oldest timestamptz;
  v_id     uuid;
begin
  -- Serialise concurrent sends for the same email and purpose.
  perform pg_advisory_xact_lock(hashtextextended(v_email || ':' || p_purpose::text, 0));

  -- Housekeeping: send events older than a day are irrelevant to any window.
  delete from public.otp_send_events where created_at < now() - interval '1 day';

  select max(e.created_at) into v_last
  from public.otp_send_events e
  where e.email = v_email and e.purpose = p_purpose;

  if v_last is not null and v_last > now() - make_interval(secs => p_cooldown_seconds) then
    return query select 'cooldown'::text, null::uuid,
      greatest(1, ceil(extract(epoch from (v_last + make_interval(secs => p_cooldown_seconds) - now())))::integer);
    return;
  end if;

  select count(*), min(e.created_at) into v_count, v_oldest
  from public.otp_send_events e
  where e.email = v_email and e.purpose = p_purpose
    and e.created_at > now() - make_interval(secs => p_window_seconds);

  if v_count >= p_max_sends then
    return query select 'send_limit'::text, null::uuid,
      greatest(1, ceil(extract(epoch from (v_oldest + make_interval(secs => p_window_seconds) - now())))::integer);
    return;
  end if;

  update public.otp_codes c
  set invalidated_at = now()
  where c.user_id = p_user_id and c.purpose = p_purpose
    and c.consumed_at is null and c.invalidated_at is null;

  insert into public.otp_codes (user_id, purpose, code_hash, expires_at)
  values (p_user_id, p_purpose, p_code_hash, now() + make_interval(secs => p_ttl_seconds))
  returning id into v_id;

  insert into public.otp_send_events (email, purpose) values (v_email, p_purpose);

  return query select 'ok'::text, v_id, 0;
end $$;

-- Undo an issue whose email could not be delivered: the code is dead and the send does not count.
-- The send event written by otp_issue has the same created_at (same transaction time) as the code.
create or replace function public.otp_revoke_issue(p_otp_id uuid, p_email text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_purpose public.otp_purpose;
  v_created timestamptz;
begin
  select c.purpose, c.created_at into v_purpose, v_created
  from public.otp_codes c where c.id = p_otp_id;
  if not found then
    return;
  end if;

  update public.otp_codes c
  set invalidated_at = now()
  where c.id = p_otp_id and c.consumed_at is null and c.invalidated_at is null;

  delete from public.otp_send_events e
  where e.email = lower(trim(p_email)) and e.purpose = v_purpose and e.created_at = v_created;
end $$;

-- Start a verification attempt: locks the live code, rejects expired or exhausted codes, and counts the
-- attempt BEFORE the server compares hashes, so concurrent guesses cannot exceed the limit.
-- Returns the stored hash only so the server can compare it in constant time; it never leaves the server.
create or replace function public.otp_begin_attempt(
  p_user_id      uuid,
  p_purpose      public.otp_purpose,
  p_max_attempts integer
)
returns table (status text, otp_id uuid, stored_hash text, attempts_after integer)
language plpgsql
set search_path = ''
as $$
declare
  v_row public.otp_codes%rowtype;
begin
  select * into v_row
  from public.otp_codes c
  where c.user_id = p_user_id and c.purpose = p_purpose
    and c.consumed_at is null and c.invalidated_at is null
  order by c.created_at desc
  limit 1
  for update;

  if not found then
    return query select 'not_found'::text, null::uuid, null::text, 0;
    return;
  end if;

  if v_row.expires_at <= now() then
    return query select 'expired'::text, v_row.id, null::text, v_row.attempts::integer;
    return;
  end if;

  if v_row.attempts >= p_max_attempts then
    return query select 'attempts_exceeded'::text, v_row.id, null::text, v_row.attempts::integer;
    return;
  end if;

  update public.otp_codes c set attempts = c.attempts + 1 where c.id = v_row.id;

  return query select 'ok'::text, v_row.id, v_row.code_hash, (v_row.attempts + 1)::integer;
end $$;

-- Mark a code used. Returns false if it was already used, superseded or expired (single use).
create or replace function public.otp_consume(p_otp_id uuid)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  v_n integer;
begin
  update public.otp_codes c
  set consumed_at = now()
  where c.id = p_otp_id and c.consumed_at is null and c.invalidated_at is null and c.expires_at > now();
  get diagnostics v_n = row_count;
  return v_n = 1;
end $$;

-- Revoke every session of a user (after a password reset, D-016). SECURITY DEFINER on purpose: the
-- Auth API can only sign out with a user's own JWT, which the reset flow does not have, and
-- service_role has no privilege on auth.sessions. Refresh tokens cascade from sessions.
-- Note: access tokens already issued stay valid until they expire (Supabase docs).
create or replace function public.revoke_user_sessions(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from auth.sessions s where s.user_id = p_user_id;
end $$;

-- Only trusted server code may call any of these.
revoke execute on function public.otp_issue(uuid, text, public.otp_purpose, text, integer, integer, integer, integer) from public, anon, authenticated;
revoke execute on function public.otp_revoke_issue(uuid, text)                   from public, anon, authenticated;
revoke execute on function public.otp_begin_attempt(uuid, public.otp_purpose, integer) from public, anon, authenticated;
revoke execute on function public.otp_consume(uuid)                              from public, anon, authenticated;
revoke execute on function public.revoke_user_sessions(uuid)                     from public, anon, authenticated;

grant execute on function public.otp_issue(uuid, text, public.otp_purpose, text, integer, integer, integer, integer) to service_role;
grant execute on function public.otp_revoke_issue(uuid, text)                    to service_role;
grant execute on function public.otp_begin_attempt(uuid, public.otp_purpose, integer) to service_role;
grant execute on function public.otp_consume(uuid)                               to service_role;
grant execute on function public.revoke_user_sessions(uuid)                      to service_role;
