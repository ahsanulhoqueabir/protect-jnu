-- 0010_client_write_guards.sql  (PROPOSED, needs user approval; not in the approved schema doc)
-- Found while verifying 0008 (2026-11-09):
--  G1: a student cancelling their own alert can also set acknowledged_at, resolved_at,
--      cancelled_at and the first coordinates. Reports count a student as supported when
--      acknowledged_at is set, so that value must not be client-forgeable.
--  G2: students can set sent_at and read_at when inserting a message (forge order, hide unread).

-- G2: clients insert only alert_id, body and sender_id; id, sent_at, read_at use defaults.
revoke insert on table public.messages from authenticated;
grant  insert (alert_id, body, sender_id) on table public.messages to authenticated;

-- G1: for a signed-in NON-admin (a student client) pin every column except status.
--     Admins and trusted server code (service_role: auth.uid() is null) are not pinned.
--     Existing behaviour is kept: last_updated_at, started_at and user_id pins, and the
--     timestamp set on status change.
create or replace function public.set_alert_status_timestamps()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.last_updated_at = now();
  new.started_at = old.started_at;
  new.user_id = old.user_id;

  if (select auth.uid()) is not null and not (select public.is_admin()) then
    new.acknowledged_at = old.acknowledged_at;
    new.resolved_at     = old.resolved_at;
    new.cancelled_at    = old.cancelled_at;
    new.first_latitude  = old.first_latitude;
    new.first_longitude = old.first_longitude;
  end if;

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

revoke execute on function public.set_alert_status_timestamps() from public, anon, authenticated;
