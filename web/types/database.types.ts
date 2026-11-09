/**
 * Supabase `Database` type — the single source of truth for table/view/RPC shapes.
 * Keep in sync with `schemas/*.sql`. Regenerate with:
 *   npx supabase gen types typescript --project-id <id> > types/database.types.ts
 * Domain types (`x.types.ts`) must derive from this file, never redeclare columns.
 */
export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          user: string;
          email: string;
          name: string;
          username: string | null;
          role: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user: string;
          email: string;
          name: string;
          username?: string | null;
          role?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user?: string;
          email?: string;
          name?: string;
          username?: string | null;
          role?: string;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      profiles_public: {
        Row: {
          id: string;
          email: string;
          name: string;
          username: string | null;
          role: string;
        };
        Relationships: [];
      };
    };
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
