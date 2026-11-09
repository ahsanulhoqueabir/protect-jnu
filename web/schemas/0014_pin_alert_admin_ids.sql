-- 0014_pin_alert_admin_ids.sql
-- Follow-up to 0013 (found by a column-privilege check, 2026-11-09): `authenticated` holds UPDATE on the new
-- columns alerts.acknowledged_by / resolved_by, and the 0010 guard trigger did not pin them, so a student
-- cancelling their own alert could have written an arbitrary admin id there. Pin both for signed-in
-- non-admins, exactly like acknowledged_at / resolved_at. Admins and service_role (auth.uid() is null) are
-- unchanged. Everything else in the function is the 0010 body.
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
    new.acknowledged_by = old.acknowledged_by;
    new.resolved_by     = old.resolved_by;
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
