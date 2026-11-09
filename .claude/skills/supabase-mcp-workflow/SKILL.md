---
name: supabase-mcp-workflow
description: Use for any database work (schema, migrations, RLS, Realtime, queries, verification) in this project via the Supabase MCP server.
---

# Supabase MCP Workflow

Full doc: `docs/05-supabase-mcp-workflow.md`. Summary:

1. List the MCP's available tools first; use only tools that exist. Don't assume names.
2. Inspect before changing (tables, policies, migrations).
3. Schema changes = named migrations through MCP; also save SQL to `web/schemas/NNNN_*.sql`.
4. Verify after each migration (RLS enabled, policies, constraints); run advisors if available.
5. Never run destructive SQL or touch a production project without explicit user confirmation.
6. Never write MCP tokens / service-role keys / JWT secrets anywhere in the repo or chat.
7. MCP is dev-only; app code uses Supabase SDK/server integration.
8. Schema/columns not in the approved schema doc require user approval first (`clarify-before-assuming`).
9. RLS must be tested with student A, student B, admin, anon; save results.
