-- Phase 5: a location point is identified by its alert and device timestamp, so a batch that
-- the phone re-sends after a lost response is ignored instead of stored twice.
-- Clients insert with ON CONFLICT DO NOTHING (PostgREST: Prefer resolution=ignore-duplicates).

-- Remove existing duplicates first (keep the earliest row) so the constraint can be created.
delete from public.locations a
using public.locations b
where a.alert_id = b.alert_id
  and a.recorded_at = b.recorded_at
  and a.id > b.id;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'locations_alert_recorded_at_key' and conrelid = 'public.locations'::regclass
  ) then
    alter table public.locations
      add constraint locations_alert_recorded_at_key unique (alert_id, recorded_at);
  end if;
end $$;
