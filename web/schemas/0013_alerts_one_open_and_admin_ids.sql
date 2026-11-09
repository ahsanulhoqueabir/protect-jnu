-- 0013_alerts_one_open_and_admin_ids.sql
-- D-060: one open alert (active or acknowledged) per student, enforced in the database.
-- D-061/D-063: record which admin acknowledged / resolved an alert.
-- User approved 2026-11-09, including deleting the 44 old test alerts (student.a / student.b seed accounts;
-- locations and messages cascade).

delete from public.alerts;

alter table public.alerts
  add column if not exists acknowledged_by uuid references public.profiles(id) on delete set null,
  add column if not exists resolved_by uuid references public.profiles(id) on delete set null;

create unique index if not exists alerts_one_open_per_user
  on public.alerts (user_id)
  where status in ('active', 'acknowledged');
