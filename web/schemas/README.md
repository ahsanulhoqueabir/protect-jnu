# schemas/ — SQL migration history

Numbered, append-only, idempotent SQL (`NNNN_description.sql`). Apply in order via the
Supabase SQL editor or `supabase db push`. After any change, update `types/database.types.ts`.

(Zod validation schemas live in `schema/` — singular. SQL lives here — plural.)
