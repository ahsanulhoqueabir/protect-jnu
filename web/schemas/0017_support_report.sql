-- 0017_support_report.sql  (Phase 8, D-076). Run manually in the SQL editor; then verify by MCP query.
-- Monthly support report for one year. Read-only; admins only.
--  * period of an alert = month of coalesce(acknowledged_at, resolved_at) in Asia/Dhaka
--  * alerts_handled     = alerts with such a timestamp (cancelled-before-handling alerts have none)
--  * students_supported = distinct students among those alerts, once per month
-- Always returns 12 rows (months with no activity are 0).

create or replace function public.support_report(p_year integer)
returns table (year integer, month integer, alerts_handled bigint, students_supported bigint)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if not (select public.is_admin()) then
    raise exception 'admin only' using errcode = '42501';
  end if;
  if p_year is null or p_year < 2000 or p_year > 2100 then
    raise exception 'invalid year' using errcode = '22023';
  end if;

  return query
  with handled as (
    select
      a.user_id,
      extract(month from (coalesce(a.acknowledged_at, a.resolved_at) at time zone 'Asia/Dhaka'))::int as m
    from public.alerts a
    where coalesce(a.acknowledged_at, a.resolved_at) is not null
      and extract(year from (coalesce(a.acknowledged_at, a.resolved_at) at time zone 'Asia/Dhaka'))::int = p_year
  )
  select
    p_year,
    gs.m,
    count(h.user_id)::bigint,
    count(distinct h.user_id)::bigint
  from generate_series(1, 12) as gs(m)
  left join handled h on h.m = gs.m
  group by gs.m
  order by gs.m;
end;
$$;

revoke all on function public.support_report(integer) from public, anon;
grant execute on function public.support_report(integer) to authenticated;
