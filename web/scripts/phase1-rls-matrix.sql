-- phase1-rls-matrix.sql — Phase 1 RLS test matrix (student A, student B, admin, anon).
-- Run through the Supabase MCP execute_sql (or the SQL editor) as the project owner.
-- Creates 3 throwaway users directly in auth.users (no Auth API, no email can be sent),
-- exercises every policy and grant under `set local role`, then ends with a deliberate
-- RAISE EXCEPTION so the WHOLE transaction rolls back. Results are in the error message:
-- RLS_MATRIX_RESULT {"total":N,"failed":N,"failures":[...],"passes":[...]}
do $do$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  adm uuid := gen_random_uuid();
  a1 uuid; a2 uuid; b1 uuid;
  n_prof bigint;
  res jsonb;
begin
  create temp table results (
    seq serial, name text, expect_state text, expect_n bigint, ge boolean, state text, n bigint
  );

  create function pg_temp.run(
    p_name text, p_role text, p_sub uuid, p_sql text,
    p_state text default 'ok', p_n bigint default null, p_ge boolean default false
  ) returns void language plpgsql as $fn$
  declare v_state text := 'ok'; v_n bigint;
  begin
    perform set_config('request.jwt.claims',
      case when p_sub is null then '' else jsonb_build_object('sub', p_sub, 'role', p_role)::text end, true);
    execute format('set local role %I', p_role);
    begin
      execute p_sql;
      get diagnostics v_n = row_count;
    exception when others then
      v_state := sqlstate; v_n := null;
    end;
    reset role;
    perform set_config('request.jwt.claims', '', true);
    insert into pg_temp.results (name, expect_state, expect_n, ge, state, n)
      values (p_name, p_state, p_n, p_ge, v_state, v_n);
  end $fn$;

  -- Setup as the owner (profiles are created by the on_auth_user_created trigger).
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (a,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rls-a@jnu.ac.bd',
     '{"full_name":"Matrix A","student_id":"B900000001"}', now(), now()),
    (b,   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rls-b@jnu.ac.bd',
     '{"full_name":"Matrix B","student_id":"B900000002"}', now(), now()),
    (adm, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rls-admin@jnu.ac.bd',
     '{"full_name":"Matrix Admin","student_id":"B900000003"}', now(), now());
  update public.profiles set role = 'admin' where id = adm;
  insert into public.alerts (user_id) values (a) returning id into a1;
  insert into public.alerts (user_id) values (a) returning id into a2;
  insert into public.alerts (user_id) values (b) returning id into b1;
  select count(*) into n_prof from public.profiles;

  -- ===== profiles =====
  perform pg_temp.run('P1 A reads profiles: only own',            'authenticated', a, 'select * from public.profiles', 'ok', 1);
  perform pg_temp.run('P2 A reads B profile: none',               'authenticated', a, format('select * from public.profiles where id = %L', b), 'ok', 0);
  perform pg_temp.run('P3 admin reads all profiles',              'authenticated', adm, 'select * from public.profiles', 'ok', n_prof);
  perform pg_temp.run('P4 anon reads profiles: denied',           'anon', null, 'select * from public.profiles', '42501');
  perform pg_temp.run('P5 A updates own full_name',               'authenticated', a, format('update public.profiles set full_name = %L where id = %L', 'Matrix A2', a), 'ok', 1);
  perform pg_temp.run('P6 A updates own student_id: denied',      'authenticated', a, format('update public.profiles set student_id = %L where id = %L', 'B900000009', a), '42501');
  perform pg_temp.run('P7 A promotes self to admin: denied',      'authenticated', a, format('update public.profiles set role = %L where id = %L', 'admin', a), '42501');
  perform pg_temp.run('P8 A sets own email_verified_at: denied',  'authenticated', a, format('update public.profiles set email_verified_at = now() where id = %L', a), '42501');
  perform pg_temp.run('P9 A updates B full_name: 0 rows',         'authenticated', a, format('update public.profiles set full_name = %L where id = %L', 'x', b), 'ok', 0);
  perform pg_temp.run('P10 A deletes own profile: denied',        'authenticated', a, format('delete from public.profiles where id = %L', a), '42501');
  perform pg_temp.run('P11 admin updates A phone',                'authenticated', adm, format('update public.profiles set phone = %L where id = %L', '01712345678', a), 'ok', 1);
  perform pg_temp.run('P12 A sets invalid phone: check',          'authenticated', a, format('update public.profiles set phone = %L where id = %L', 'abc', a), '23514');

  -- ===== emergency_contacts =====
  perform pg_temp.run('C1 A inserts contact 1',                   'authenticated', a, format('insert into public.emergency_contacts (user_id, name, phone) values (%L, %L, %L)', a, 'c1', '01711111111'), 'ok', 1);
  perform pg_temp.run('C2 A inserts contact 2',                   'authenticated', a, format('insert into public.emergency_contacts (user_id, name, phone) values (%L, %L, %L)', a, 'c2', '01722222222'), 'ok', 1);
  perform pg_temp.run('C3 A inserts contact 3',                   'authenticated', a, format('insert into public.emergency_contacts (user_id, name, phone) values (%L, %L, %L)', a, 'c3', '+8801733333333'), 'ok', 1);
  perform pg_temp.run('C4 A inserts 4th contact: cap check',      'authenticated', a, format('insert into public.emergency_contacts (user_id, name, phone) values (%L, %L, %L)', a, 'c4', '01744444444'), '23514');
  perform pg_temp.run('C5 A inserts contact for B: denied',       'authenticated', a, format('insert into public.emergency_contacts (user_id, name, phone) values (%L, %L, %L)', b, 'x', '01755555555'), '42501');
  perform pg_temp.run('C6 B reads A contacts: none',              'authenticated', b, format('select * from public.emergency_contacts where user_id = %L', a), 'ok', 0);
  perform pg_temp.run('C7 admin reads A contacts: 3',             'authenticated', adm, format('select * from public.emergency_contacts where user_id = %L', a), 'ok', 3);
  perform pg_temp.run('C8 A deletes own contact',                 'authenticated', a, format('delete from public.emergency_contacts where user_id = %L and name = %L', a, 'c3'), 'ok', 1);
  perform pg_temp.run('C9 A inserts contact with bad phone',      'authenticated', a, format('insert into public.emergency_contacts (user_id, name, phone) values (%L, %L, %L)', a, 'bad', '12'), '23514');
  perform pg_temp.run('C10 B deletes A contact: 0 rows',          'authenticated', b, format('delete from public.emergency_contacts where user_id = %L', a), 'ok', 0);

  -- ===== alerts =====
  perform pg_temp.run('A1 A raises alert (own, coords)',          'authenticated', a, format('insert into public.alerts (user_id, first_latitude, first_longitude) values (%L, 23.7, 90.4)', a), 'ok', 1);
  perform pg_temp.run('A2 A raises alert with status resolved',   'authenticated', a, format('insert into public.alerts (user_id, status) values (%L, %L)', a, 'resolved'), '42501');
  perform pg_temp.run('A3 A raises alert for B: denied',          'authenticated', a, format('insert into public.alerts (user_id) values (%L)', b), '42501');
  perform pg_temp.run('A4 B reads A alerts: none',                'authenticated', b, format('select * from public.alerts where user_id = %L', a), 'ok', 0);
  perform pg_temp.run('A5 admin reads all alerts',                'authenticated', adm, 'select * from public.alerts', 'ok', 4, true);
  perform pg_temp.run('A6 A updates B alert: 0 rows',             'authenticated', a, format('update public.alerts set status = %L where id = %L', 'cancelled', b1), 'ok', 0);
  perform pg_temp.run('A7 A cancels own alert with forged timestamps', 'authenticated', a,
    format('update public.alerts set status = %L, acknowledged_at = now(), resolved_at = now() where id = %L', 'cancelled', a1), 'ok', 1);
  insert into pg_temp.results (name, expect_state, expect_n, state, n)
    select 'A7b forged acknowledged_at/resolved_at were pinned, cancelled_at set by trigger', 'ok', null,
           case when acknowledged_at is null and resolved_at is null and cancelled_at is not null then 'ok' else 'FAIL' end, 1
    from public.alerts where id = a1;
  perform pg_temp.run('A8 A acknowledges own alert: denied',      'authenticated', a, format('update public.alerts set status = %L where id = %L', 'acknowledged', a2), '42501');
  perform pg_temp.run('A9 A edits coords without cancelling: denied', 'authenticated', a, format('update public.alerts set first_latitude = 1 where id = %L', a2), '42501');
  perform pg_temp.run('A10 admin acknowledges A alert',           'authenticated', adm, format('update public.alerts set status = %L where id = %L', 'acknowledged', a2), 'ok', 1);
  insert into pg_temp.results (name, expect_state, expect_n, state, n)
    select 'A10b acknowledged_at set by trigger', 'ok', null, case when acknowledged_at is not null then 'ok' else 'FAIL' end, 1
    from public.alerts where id = a2;
  perform pg_temp.run('A11 admin deletes alert: denied',          'authenticated', adm, format('delete from public.alerts where id = %L', a2), '42501');
  perform pg_temp.run('A12 A deletes own alert: denied',          'authenticated', a, format('delete from public.alerts where id = %L', a2), '42501');
  perform pg_temp.run('A13 anon reads alerts: denied',            'anon', null, 'select * from public.alerts', '42501');

  -- ===== locations =====
  perform pg_temp.run('L1 A adds location to own open alert',     'authenticated', a, format('insert into public.locations (alert_id, user_id, latitude, longitude) values (%L, %L, 23.7, 90.4)', a2, a), 'ok', 1);
  perform pg_temp.run('L2 A adds location to B alert: denied',    'authenticated', a, format('insert into public.locations (alert_id, user_id, latitude, longitude) values (%L, %L, 1, 1)', b1, a), '42501');
  perform pg_temp.run('L3 A adds location to cancelled alert',    'authenticated', a, format('insert into public.locations (alert_id, user_id, latitude, longitude) values (%L, %L, 1, 1)', a1, a), '42501');
  perform pg_temp.run('L4 A adds location as user B: denied',     'authenticated', a, format('insert into public.locations (alert_id, user_id, latitude, longitude) values (%L, %L, 1, 1)', a2, b), '42501');
  perform pg_temp.run('L5 B reads A locations: none',             'authenticated', b, format('select * from public.locations where alert_id = %L', a2), 'ok', 0);
  perform pg_temp.run('L6 admin reads A locations',               'authenticated', adm, format('select * from public.locations where alert_id = %L', a2), 'ok', 1, true);
  perform pg_temp.run('L7 A deletes location: denied',            'authenticated', a, format('delete from public.locations where alert_id = %L', a2), '42501');
  perform pg_temp.run('L8 A updates location: denied',            'authenticated', a, format('update public.locations set latitude = 0 where alert_id = %L', a2), '42501');

  -- ===== messages =====
  perform pg_temp.run('M1 A posts on own acknowledged alert',     'authenticated', a, format('insert into public.messages (alert_id, sender_id, body) values (%L, %L, %L)', a2, a, 'help'), 'ok', 1);
  perform pg_temp.run('M2 A posts with forged read_at: denied',   'authenticated', a, format('insert into public.messages (alert_id, sender_id, body, read_at) values (%L, %L, %L, now())', a2, a, 'x'), '42501');
  perform pg_temp.run('M3 A posts as sender B: denied',           'authenticated', a, format('insert into public.messages (alert_id, sender_id, body) values (%L, %L, %L)', a2, b, 'x'), '42501');
  perform pg_temp.run('M4 B posts on A thread: denied',           'authenticated', b, format('insert into public.messages (alert_id, sender_id, body) values (%L, %L, %L)', a2, b, 'x'), '42501');
  perform pg_temp.run('M5 admin posts on A thread as self',       'authenticated', adm, format('insert into public.messages (alert_id, sender_id, body) values (%L, %L, %L)', a2, adm, 'on our way'), 'ok', 1);
  perform pg_temp.run('M6 admin posts as sender A: denied',       'authenticated', adm, format('insert into public.messages (alert_id, sender_id, body) values (%L, %L, %L)', a2, a, 'spoof'), '42501');
  perform pg_temp.run('M7 A posts on cancelled alert: denied',    'authenticated', a, format('insert into public.messages (alert_id, sender_id, body) values (%L, %L, %L)', a1, a, 'x'), '42501');
  perform pg_temp.run('M8 A edits message body: denied',          'authenticated', a, format('update public.messages set body = %L where alert_id = %L', 'edited', a2), '42501');
  perform pg_temp.run('M9 A marks thread messages read',          'authenticated', a, format('update public.messages set read_at = now() where alert_id = %L', a2), 'ok', 2);
  perform pg_temp.run('M10 B reads A thread: none',               'authenticated', b, format('select * from public.messages where alert_id = %L', a2), 'ok', 0);
  perform pg_temp.run('M11 A deletes message: denied',            'authenticated', a, format('delete from public.messages where alert_id = %L', a2), '42501');
  perform pg_temp.run('M12 B marks A thread read: 0 rows',        'authenticated', b, format('update public.messages set read_at = now() where alert_id = %L', a2), 'ok', 0);
  perform pg_temp.run('M13 A reads own thread',                   'authenticated', a, format('select * from public.messages where alert_id = %L', a2), 'ok', 2);
  perform pg_temp.run('M14 admin reads A thread',                 'authenticated', adm, format('select * from public.messages where alert_id = %L', a2), 'ok', 2);

  -- ===== OTP tables and helper functions =====
  perform pg_temp.run('O1 A reads otp_codes: denied',             'authenticated', a, 'select * from public.otp_codes', '42501');
  perform pg_temp.run('O2 A inserts otp_codes: denied',           'authenticated', a, format('insert into public.otp_codes (user_id, purpose, code_hash, expires_at) values (%L, %L, %L, now())', a, 'email_verification', 'h'), '42501');
  perform pg_temp.run('O3 anon reads otp_send_events: denied',    'anon', null, 'select * from public.otp_send_events', '42501');
  perform pg_temp.run('O4 admin reads otp_codes: denied',         'authenticated', adm, 'select * from public.otp_codes', '42501');
  perform pg_temp.run('O5 A reads otp_send_events: denied',       'authenticated', a, 'select * from public.otp_send_events', '42501');
  perform pg_temp.run('F1 anon calls is_admin(): denied',         'anon', null, 'select public.is_admin()', '42501');
  perform pg_temp.run('F2 A calls is_admin()',                    'authenticated', a, 'select public.is_admin()', 'ok', 1);
  perform pg_temp.run('F3 A calls handle_new_user() as RPC: denied', 'authenticated', a, 'select public.handle_new_user()', '42501');

  -- ===== domain / format constraints (as owner, direct inserts) =====
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x@gmail.com',
            '{"full_name":"X","student_id":"B900000004"}', now(), now());
    insert into pg_temp.results (name, expect_state, state) values ('D1 non-jnu email rejected', 'check_violation', 'ok');
  exception when check_violation then
    insert into pg_temp.results (name, expect_state, state) values ('D1 non-jnu email rejected', 'check_violation', 'check_violation');
  end;
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'y@jnu.ac.bd',
            '{"full_name":"Y","student_id":"X123"}', now(), now());
    insert into pg_temp.results (name, expect_state, state) values ('D2 bad student_id rejected', 'check_violation', 'ok');
  exception when check_violation then
    insert into pg_temp.results (name, expect_state, state) values ('D2 bad student_id rejected', 'check_violation', 'check_violation');
  end;
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'z@jnu.ac.bd',
            '{"full_name":"Z","student_id":"B900000001"}', now(), now());
    insert into pg_temp.results (name, expect_state, state) values ('D3 duplicate student_id rejected', 'unique_violation', 'ok');
  exception when unique_violation then
    insert into pg_temp.results (name, expect_state, state) values ('D3 duplicate student_id rejected', 'unique_violation', 'unique_violation');
  end;

  with r as (
    select *, (state = expect_state and (expect_n is null or (case when ge then n >= expect_n else n = expect_n end))) as pass
    from pg_temp.results
  )
  select jsonb_build_object(
    'total', count(*),
    'failed', count(*) filter (where not pass),
    'failures', coalesce(jsonb_agg(jsonb_build_object('case', name, 'expect', expect_state, 'expect_n', expect_n, 'got', state, 'n', n) order by seq) filter (where not pass), '[]'::jsonb),
    'passes', coalesce(jsonb_agg(name order by seq) filter (where pass), '[]'::jsonb)
  ) into res from r;

  raise exception 'RLS_MATRIX_RESULT %', res;
end
$do$;
