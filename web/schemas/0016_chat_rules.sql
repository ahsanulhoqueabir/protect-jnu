-- 0016_chat_rules.sql  (Phase 6, D-072). Run manually in the SQL editor; then verify by MCP query.

-- 1. Body: non-empty after trim, at most 1000 characters.
--    NOT VALID so any old test rows are not scanned; new rows are checked.
alter table public.messages
  add constraint messages_body_length
  check (char_length(btrim(body)) between 1 and 1000) not valid;

-- 2. Thread is read-only once the alert is resolved or cancelled (admins too).
drop policy if exists "admins insert messages on any thread" on public.messages;
create policy "admins insert messages on any thread" on public.messages
  for insert to authenticated
  with check (
    (select public.is_admin())
    and sender_id = (select auth.uid())
    and exists (
      select 1 from public.alerts a
      where a.id = messages.alert_id
        and a.status in ('active', 'acknowledged')
    )
  );

-- 3. Mark read: only the OTHER party's messages (never your own), only on a
--    thread you can see. Column grant (read_at only) is from 0008.
drop policy if exists "students mark read on own threads" on public.messages;
drop policy if exists "admins update all messages"        on public.messages;
create policy "mark other party messages read" on public.messages
  for update to authenticated
  using (
    sender_id <> (select auth.uid())
    and exists (
      select 1 from public.alerts a
      where a.id = messages.alert_id
        and (a.user_id = (select auth.uid()) or (select public.is_admin()))
    )
  )
  with check (
    sender_id <> (select auth.uid())
    and exists (
      select 1 from public.alerts a
      where a.id = messages.alert_id
        and (a.user_id = (select auth.uid()) or (select public.is_admin()))
    )
  );

-- 4. One conversation per alert: last message + unread count.
--    SECURITY INVOKER, so RLS decides which alerts/messages the caller sees.
--    Admin unread = unread messages sent by the student (alert owner);
--    student unread = unread messages sent by anyone else (admins).
create or replace function public.chat_conversations()
returns table (
  alert_id uuid,
  last_body text,
  last_sent_at timestamptz,
  last_sender_id uuid,
  unread_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select a.id,
         lm.body,
         lm.sent_at,
         lm.sender_id,
         (select count(*) from public.messages m
           where m.alert_id = a.id
             and m.read_at is null
             and case when (select public.is_admin())
                      then m.sender_id = a.user_id
                      else m.sender_id <> a.user_id end)
  from public.alerts a
  join lateral (
    select m.body, m.sent_at, m.sender_id
    from public.messages m
    where m.alert_id = a.id
    order by m.sent_at desc
    limit 1
  ) lm on true
  order by lm.sent_at desc;
$$;

revoke all on function public.chat_conversations() from public, anon;
grant execute on function public.chat_conversations() to authenticated;
