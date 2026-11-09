# schemas/ — SQL migration history

Numbered, append-only, idempotent SQL (`NNNN_description.sql`). Apply in order via the
Supabase SQL editor or `supabase db push`. After any change, update `types/database.types.ts`.

(Zod validation schemas live in `schema/` — singular. SQL lives here — plural.)

## Status as of 2026-11-09 (Phase 1)
- `0001`–`0003` come from the template and describe an older `profiles` shape (`"user"`, `name`, `username`). They are stale and were never applied to the live DB. Left in place because this folder is append-only. **Do not run them.**
- `0000_baseline_applied_2026-11-08.sql` is documentation of what was already applied. **Do not run it.**
- `0004`+ are the real history. Apply order in the live DB: 0004 and 0005 via MCP; 0006 manually; 0007 via MCP; 0008 manually; 0009 and 0010 pending.
- `admin-provisioning.md` is a runbook, not a migration.
