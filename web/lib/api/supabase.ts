import { sb } from "@/config/env.config";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";

export type TypedSupabaseClient = SupabaseClient<Database>;

const clientOptions = {
  auth: { autoRefreshToken: false, persistSession: false },
};

let serverClient: TypedSupabaseClient | null = null;

/**
 * Service-role client (bypasses RLS). SERVICES ONLY — never import from routes.
 * Singleton. Never call `signIn*` on it: that would swap its service-role token
 * for the user's session. Use `createSupabaseAuthClient()` for that.
 */
export function getSupabaseServerClient(): TypedSupabaseClient {
  if (serverClient) return serverClient;

  if (!sb.url || !sb.secret) {
    throw new Error(
      "Supabase URL and Secret Key must be defined in environment variables",
    );
  }

  serverClient = createClient<Database>(sb.url, sb.secret, clientOptions);
  return serverClient;
}

/**
 * Per-request client that acts AS the caller (publishable key + the caller's validated access token),
 * so RLS and `auth.uid()` apply (D-028, chat). SERVICES ONLY. Never log the token.
 */
export function createSupabaseUserClient(accessToken: string): TypedSupabaseClient {
  if (!sb.url || !sb.publish) {
    throw new Error(
      "Supabase URL and Publishable Key must be defined in environment variables",
    );
  }
  return createClient<Database>(sb.url, sb.publish, {
    ...clientOptions,
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
}

/** Throwaway publishable-key client for end-user auth calls (e.g. signInWithPassword). */
export function createSupabaseAuthClient(): TypedSupabaseClient {
  if (!sb.url || !sb.publish) {
    throw new Error(
      "Supabase URL and Publishable Key must be defined in environment variables",
    );
  }
  return createClient<Database>(sb.url, sb.publish, clientOptions);
}
