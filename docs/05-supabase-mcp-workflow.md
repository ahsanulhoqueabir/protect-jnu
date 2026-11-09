# Supabase MCP Workflow

Supabase MCP is a **development-time** tool (PRD §7.2). The deployed apps never use MCP.

## Rules
1. Before any DB work: use MCP to list tables/extensions/migrations and read the current state. Never assume what exists.
2. All schema changes are **migrations** (named, one logical change each), applied through MCP — not ad-hoc SQL edits to the live schema.
3. Every applied migration's SQL is also saved to `web/schemas/NNNN_<name>.sql` (template numbering, append-only, idempotent; see `web/.claude/skills/new-migration`) so the repo reproduces the DB.
4. After each migration: run MCP verification queries (tables exist, RLS enabled, policies listed, constraints present) and record the result in PROGRESS.md.
5. Run MCP's security/performance advisors (if the connected MCP exposes them — verify tool list) after schema/RLS changes; fix or log findings.
6. Prefer a **development** Supabase project/branch. Confirm with the user before any destructive statement (DROP, TRUNCATE, DELETE without WHERE) or any change to a production project.
7. Generate/refresh TypeScript types from the schema via MCP (if available) into `web/types/database.types.ts`. Flutter models are hand-written from the documented schema; keep them in sync.
8. Never paste MCP tokens, service-role keys, or JWT secrets into files, docs, chat, or commits. Use `.env.local` (web, gitignored) only.
9. Seed/test data for RLS tests must be clearly marked and removable; do not seed real student data.

## Per-phase DB workflow
| Phase | MCP use |
|---|---|
| 1 | Inspect empty project → migrations for tables, enums, indexes, constraints, RLS, realtime publication → verify → RLS tests with 2 students + 1 admin |
| 2 | Migrations for OTP/reset/rate-limit tables (if not in 1) → verify no client policies |
| 3 | Verify rows after auth flows (hashes only, no plaintext) |
| 4–6 | Verify alert/location/message inserts, Realtime publication membership, RLS under each role |
| 8 | Test report queries/views against seeded alerts |
| 9 | Final advisor run, policy audit |

## Tool names
Exact MCP tool names are **not assumed** here. At Phase 0/1, list the connected MCP's tools and record them below.

Recorded 2026-11-09 (tool names as exposed in the agent session as `mcp__supabase__*`; read-only proof of connectivity: `get_project_url`, `list_tables`):
- Schema/data: `list_tables`, `list_extensions`, `list_migrations`, `apply_migration`, `execute_sql`, `generate_typescript_types`
- Diagnostics: `get_advisors`, `query_logs`, `search_docs`
- Project: `get_project_url`, `get_publishable_keys` (returns keys: never paste into docs or logs)
- Edge functions: `list_edge_functions`, `get_edge_function`, `deploy_edge_function`, `create_edge_function_secret` (not used by this project; server code lives in `web/`)
- Branching: `create_branch`, `list_branches`, `merge_branch`, `rebase_branch`, `reset_branch`, `delete_branch`
- Notebooks/feedback: `list_notebooks`, `get_notebook`, `submit_feedback`, `delete_feedback`
- Project ref: `bthjjlpylvauiolwrdfn` (development, disposable data per user 2026-11-09).

## RLS test protocol
Create student A, student B, admin. For each table and operation (select/insert/update/delete) assert expected allow/deny for A, B, admin, and anonymous. Save the matrix to `docs/phases/phase-1-rls-test-matrix.md` with pass/fail.
