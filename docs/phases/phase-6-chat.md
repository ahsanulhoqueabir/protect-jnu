# Phase 6 — Real-Time Chat

## Objectives
One chat thread per alert shared by student and admin team, real time, with unread counts.

## Requirements covered
FR-CHAT-1, 2; screens: Chat (Flutter), Conversations + chat panel in Alert Details (web).

## Prerequisites
Phase 4 complete. D-021 answered (multi-admin semantics, sender display). Ask: message length limit, whether chat remains after alert resolved (read-only?), notification behavior for new messages on the student side.

## Components
Flutter `features/chat`: message list, composer, Realtime subscription, mark-as-read.
Web: Conversations page (list with unread counts), chat panel in Alert Details.

## Steps
1. Confirm `messages` schema (`alert_id`, `sender_id`, `body`, `sent_at`, `read_at`) and RLS: student only on own alert; admins on any.
2. Send message (insert) from both sides; validate non-empty/length server-side or via constraint.
3. Subscribe to inserts filtered by `alert_id`; load history ordered by `sent_at`; dedupe optimistic inserts.
4. Mark read: when recipient views thread, set `read_at` on the other party's messages (RLS must allow only this column/rows appropriately — design with user).
5. Conversations list: per alert last message + unread count for admins; Realtime updates.
6. Handle reconnects (refetch since last seen).

## Dependencies / integrations
Supabase Realtime.

## Database / API
`messages`; possibly a view/RPC for unread counts (ask before adding).

## Testing & validation
- Two students + admin: isolation verified.
- Messages arrive <~2s both directions; ordering by timestamp.
- Unread counts increment/decrement correctly.
- Offline send behavior documented (ask expected behavior).

## Completion criteria
- [ ] Bidirectional realtime chat on device + dashboard
- [ ] Unread counts correct
- [ ] RLS matrix for messages passes
- [ ] PROGRESS updated; user confirmed

## Out of scope
Attachments, push notifications, typing indicators.
