# Phase 8 — Support Reports & CSV Export

## Objectives
Admin Reports page: students supported and alerts handled by month/year, bar chart, CSV export.

## Requirements covered
FR-REP-1…3; PRD §5.6.

## Prerequisites
Phase 4 complete (alerts with acknowledged/resolved timestamps). Ask: timezone for month boundaries (e.g. Asia/Dhaka?), which timestamp assigns an alert to a period (acknowledged vs resolved vs started), CSV columns, chart library (shadcn charts/Recharts — confirm).

## Components
Web: `/admin/reports` page, filters (month, year), bar chart (monthly), summary cards, CSV export (server route, admin-authorized).

## Steps
1. Define metrics precisely with user: "alerts handled" = acknowledged or resolved; "students supported" = distinct students per period (PRD 5.6). Write definitions in this doc.
2. Implement SQL/aggregation derived from `alerts` (view or RPC only if approved; no duplicate tracking tables).
3. Reports API route/server action with admin check.
4. Filters + monthly bar chart for chosen year.
5. CSV export endpoint; escape fields; protect against CSV/formula injection (prefix risky cells); admin-only.
6. Test on seeded data via MCP (clearly marked, removable).

## Dependencies / integrations
Chart library, Supabase.

## Database / API
Reads `alerts` (+ `profiles`). Possible view/RPC — requires approval and a migration via MCP.

## Testing & validation
- Seed alerts across months; compare UI numbers with manual SQL via MCP.
- Same student with 3 alerts → 1 supported, 3 alerts.
- Period boundary cases (month end, timezone).
- CSV opens in spreadsheet; non-admin gets 401/403.

## Completion criteria
- [ ] Numbers match SQL verification
- [ ] Filters, chart, CSV work
- [ ] Admin-only enforced
- [ ] PROGRESS updated; user confirmed

## Out of scope
PDF reports, scheduled emails.
