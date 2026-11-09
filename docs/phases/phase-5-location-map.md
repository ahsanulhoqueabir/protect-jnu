# Phase 5 — Live Location & Leaflet Map

## Objectives
Continuous location sharing during an active alert and live map for admins.

## Requirements covered
FR-LOC-1…4, NFR-3, 4, 5, 7; PRD §5.3, 7.3.

## Prerequisites
Phase 4 complete. Q-013 (test phones). Ask user: exact interval within 5–10s, trail length ("short trail": how many points/minutes), foreground notification text, tile source details (public OSM tile URL policy) — do not choose.

## Components
Flutter: `features/location` — Android foreground service (verify current plugin options, D-023), location stream, local queue (persistent store; choice OPEN), connectivity watcher, flush logic, stop on resolve/cancel (listen to alert status).
Web: `components/map/LiveMap` (Leaflet, client-only), marker, polyline trail, last-update label, OSM attribution, tile error fallback, Realtime subscription to `locations` filtered by alert.

## Steps
1. Android manifest: location + foreground service permissions/types (verify against Android 8–14+ requirements and Flutter plugin docs).
2. Implement service start on alert creation; persistent notification.
3. Emit points at chosen interval; insert into `locations` with device timestamp (`recorded_at`).
4. Offline queue: persist points, send in order on reconnect, dedupe, bounded size (ask limit).
5. Stop service when alert status becomes resolved/cancelled or student cancels; verify service really stops.
6. Web map: init Leaflet with OSM tiles, attribution, marker moves on new points, trail polyline of last N points, "updated Xs ago".
7. Initial load fetches recent points then subscribes; handles out-of-order inserts by `recorded_at`.
8. Tile failure → visible "map tiles unavailable" state; marker data still shown as coordinates.
9. Place map in Alert Details page.

## Dependencies / integrations
Leaflet (+ react-leaflet if approved — OPEN), OSM tiles, Supabase Realtime.

## Database / API
`locations` insert (student, own active alert only) and select (own + admins). Consider index on (`alert_id`, `recorded_at`).

## Testing & validation
- Device: airplane-mode toggle mid-alert → queued points arrive after reconnect, ordered.
- Screen off / app backgrounded 10+ min keeps updating (test on ≥2 brands if available).
- Service stops after resolve (check notification gone, no more inserts via MCP).
- Student B cannot read/insert student A locations (RLS).
- Map shows attribution; simulated tile block shows fallback.

## Completion criteria
- [ ] Moving marker + trail + timestamp verified live
- [ ] Offline queue verified
- [ ] Stop-on-end verified
- [ ] Attribution + fallback verified
- [ ] PROGRESS updated; user confirmed

## Out of scope
Geofencing, history replay UI beyond trail.
