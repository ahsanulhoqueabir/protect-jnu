# Phase 4 — SOS Flow & Live Alerts List

## Objectives
Student triggers SOS; alert appears on dashboard in real time; admins acknowledge/resolve; student sees status.

## Requirements covered
FR-SOS-1…4, NFR-1; screens: Home, Active Alert (status part); Live Alerts List, Alert Details (without map/chat), Alert History, Users (basic).

## Prerequisites
Phase 3 complete. D-022 (cancel status) closed. Q-013 device availability. Ask user: audible alert sound asset/behavior, and what student details appear on the alert card.

## Components
Flutter: `features/sos` (hold-2s button, 5s cancellation countdown, cancel), `features/alert` (status watcher via Realtime).
Web: live alerts list (Realtime subscription), notification sound/visual (browser autoplay rules: needs user interaction — handle), alert detail page with student info + emergency contacts, acknowledge/resolve actions, history list, users list.

## Steps
1. Get initial location one-shot at SOS send; request location permission at SOS time (PRD: collect only after SOS). Handle denied → ask user for required behavior (OPEN).
2. Implement hold-to-activate (2s) with visual progress, then 5s cancel window; cancel aborts without creating an alert (confirm: alert created after window ends).
3. Create alert (`status=active`) + first location. Define whether via server API or direct RLS insert (follow D-004; document in api-contract).
4. Prevent duplicate active alerts per student (confirm rule with user).
5. Student Active Alert screen shows current status via Realtime.
6. Web alerts list subscribed to `alerts` changes; new alert → toast + sound; fall back to refetch/polling on disconnect.
7. Alert detail: student name/ID/email/phone, emergency contacts, timestamps.
8. Admin actions: acknowledge → resolve (server-validated transitions; record timestamps/admin id — column additions need approval from Phase 1 schema).
9. Alert History + Users pages (filters/pagination: ask, D-024).
10. Measure latency SOS → dashboard (target ≈3s).

## Dependencies / integrations
Flutter location + permission packages (D-023), Supabase Realtime, shadcn/ui components.

## Database / API
`alerts`, `locations`, `profiles`, `emergency_contacts`; RLS per Phase 1; Realtime publication.

## Testing & validation
- Unit: hold timer and cancel window logic.
- Two students send SOS; each sees only own alert; admin sees both.
- Status transitions enforced (cannot go resolved→active).
- Latency measurement noted in PROGRESS.
- Accidental trigger test (short press does nothing).

## Completion criteria
- [ ] End-to-end SOS → dashboard → acknowledge → resolve → student sees status
- [ ] Notification works
- [ ] RLS verified for alerts
- [ ] Latency recorded
- [ ] PROGRESS updated; user confirmed

## Out of scope
Continuous location, map, chat.
