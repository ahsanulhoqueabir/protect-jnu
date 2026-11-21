# Phase 10 — Admin Features in the Mobile App

## Objectives
Bring every capability of the Next.js admin dashboard into the Flutter app for accounts with
`profiles.role = 'admin'`, without changing what a normal user (`role = 'user'`) sees or does.
The web dashboard stays (D-082).

## Requirements covered
User request 2026-11-21 (scope change, recorded as D-078). PRD 4 (roles), 5.2 (admin acknowledge/
resolve), 5.3 (live map), 5.4 (conversations, unread counts), 5.6 (reports, chart, CSV), 6.2
(dashboard screens), 7.6 and 8 (authorize every admin request). PRD 3.2 push-notification
non-goal amended by D-081.

## Prerequisites
Phases 0–9 completed (Phase 9 marked completed by the user, 2026-11-21, D-083).

## Decisions (user answers 2026-11-21)
| ID | Decision |
|---|---|
| D-078 | Admin features are added to the mobile app. An admin keeps every normal-user feature and gets extra admin screens. Normal users see no change |
| D-079 | Map: `flutter_map` with OpenStreetMap tiles (+ its `latlong2` dependency). No Google Maps. OSM attribution shown |
| D-080 | Reports: `fl_chart` for the monthly bar chart; CSV is downloaded from the existing export route and shared through `share_plus` |
| D-081 | Notifications: system notifications with sound and vibration through `flutter_local_notifications`, raised from the live Realtime connection while the app process runs (foreground or recently backgrounded), plus in-app haptics and banners. Remote push that wakes a killed app (FCM) needs a Firebase project and a server-side sender; it is NOT built in this phase and is tracked as B-022 |
| D-082 | Admins also must add 2 emergency contacts (same gate as students). The web dashboard is kept |
| D-083 | Phase 9 is completed (user statement); this work is Phase 10 |

## Design
- **Role check (client):** `isAdminProvider` reads `role` from `authProvider` (already returned by
  `/api/auth/login` and `/api/auth/me`). Routes under `/admin` are refused by `resolveRedirect` for
  non-admins (sent to Home). An extra **Admin** tab appears in the bottom bar only for admins.
- **Role check (server, authoritative):** every admin call goes to the existing `/api/admin/*`
  routes with `Authorization: Bearer <access token>`; `withAdmin` re-reads the role on every
  request and answers 403 `not_admin` otherwise. RLS (`is_admin()`) protects Realtime. No backend or
  database change is needed.
- **Live updates:** Supabase Realtime `postgres_changes` on `alerts`, `messages` and `locations`
  (RLS lets admins read all) trigger a refetch through the admin API; a polling fallback
  (as the dashboard: 30 s while connected) covers dropped sockets.
- **Bug fixed first:** the student queries for "my open alert" and "my contacts" relied on RLS
  only. RLS lets an admin read every row, so an admin would have seen another student's alert as
  their own. Both now also filter by the signed-in user id.

## Screens (`app/lib/features/admin/`)
| Dashboard page | Mobile screen | API |
|---|---|---|
| Live alerts (toast + beep) | Admin tab → Live: open alerts, live, new-alert notification + vibration | `GET /api/admin/alerts?status=open` |
| Alert detail (map, student, contacts, timeline, actions, chat) | Alert detail: student card (tap to call), contacts, timeline with acting admin, Acknowledge / Resolve, live map, chat button | `GET /api/admin/alerts/:id`, `PATCH …/status`, `GET …/locations` |
| Chat panel | Admin chat: history, live updates, send, mark read, read-only after close | `GET/POST/PATCH /api/admin/alerts/:id/messages` |
| Conversations | Conversations: last message, unread badge, live | `GET /api/admin/conversations` |
| History | History: status filter, 20 per page | `GET /api/admin/alerts?status=&page=` |
| Users | Users: 20 per page, role, verified flag | `GET /api/admin/users?page=` |
| Reports | Reports: year picker, bar chart, table, Share CSV | `GET /api/admin/reports`, `/export` |

## Notifications
| Who | Event | Notification |
|---|---|---|
| Admin | New alert (INSERT, status active) | "New SOS alert" with sound + vibration; in-app banner |
| Admin | New student message on any thread | "New message from <student>" |
| Student | Own alert acknowledged / resolved | "Your alert was acknowledged/resolved" |
| Student | New admin message while the chat screen is closed | "New message from the admin team" |
Android 13+ asks for the notification permission at the first sign-in. The Phase 5 location
notification is unchanged.

## Gradle changes (from the flutter_local_notifications 23.0.3 README)
`compileSdk = 37` (Flutter's default is 36), core library desugaring enabled with
`desugar_jdk_libs:2.1.4`, AGP 9.1.0 -> 9.1.1. Not built in this session: the agent's environment
cannot download the Android SDK. The README also mentions an optional `androidx.window` dependency
for reported crashes on Android 12L+; not added (no evidence it is needed).

## Testing & validation
- `dart run scripts/check.dart` (format, analyze 0 issues, all tests).
- Router tests: admin reaches `/admin/*`; normal user is redirected; Admin tab only for admins.
- Repository tests with a fake Dio adapter for every admin endpoint (shapes from api-contract 6).
- Widget tests for each admin screen; existing student tests stay green (no workflow change).
- Regression test: an admin's "open alert" and "contacts" queries are scoped to their own id.
- Manual (user, on the phone): sign in as admin and as student; SOS from the student phone
  shows on the admin phone with notification; acknowledge/resolve; map; chat both ways; reports
  and CSV share.

## Completion criteria
- [x] All dashboard capabilities available in the app for admins (code + widget tests, 2026-11-21)
- [x] Normal-user experience unchanged (all 92 earlier tests pass unchanged; role tests added)
- [~] Non-admin refused on client routes (router tests) and by the server (existing `withAdmin`; repository test of the 403 envelope; not re-run against the live API in this session)
- [~] Notifications with sound/vibration for the listed events (bridge tests with a fake notifier; NOT seen on a phone)
- [~] Checks pass (`dart run scripts/check.dart`: 126 tests, 0 issues); APK build and manual phone run NOT done (B-023)

## Out of scope
FCM remote push (B-022), admin promotion from the app (stays SQL-only, PRD 5.1), editing users.
