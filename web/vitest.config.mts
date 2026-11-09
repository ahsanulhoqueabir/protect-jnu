import path from "node:path";
import { loadEnv } from "vite";
import { defineConfig } from "vitest/config";

/**
 * Unit tests (tests/unit) need no network. Integration tests (tests/integration) call the real
 * Supabase dev project through the service role and need migration 0011 applied; they mock the
 * email provider so no email is ever sent.
 * Env: mode "dev" makes Vite read `.env` and `.env.local` (it skips `.env.local` in mode "test").
 */
export default defineConfig(({ mode }) => ({
  resolve: {
    alias: { "@": path.resolve(__dirname, ".") },
  },
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
    testTimeout: 30_000,
    hookTimeout: 60_000,
    env: loadEnv(mode === "test" ? "dev" : mode, process.cwd(), ""),
  },
}));
