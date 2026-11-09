"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import Link from "next/link";
import { loginSchema } from "@/schema/auth.schema";
import {
  AuthCard,
  ErrorNote,
  Field,
  primaryButton,
  readEnvelope,
} from "@/components/auth/auth-ui";

export default function AdminLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const parsed = loginSchema.safeParse({ email, password });
    if (!parsed.success) {
      setError(parsed.error.issues[0].message);
      return;
    }
    setBusy(true);
    try {
      const res = await fetch("/api/admin/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parsed.data),
      });
      const body = await readEnvelope(res);
      if (!body.success) {
        setError(body.error ?? "Sign in failed.");
        return;
      }
      router.replace("/admin");
      router.refresh();
    } catch {
      setError("Could not reach the server.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <AuthCard title="Admin sign in" subtitle="Administrators only.">
      <form onSubmit={onSubmit} className="space-y-5" noValidate>
        <Field
          id="email"
          label="University email"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <Field
          id="password"
          label="Password"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <ErrorNote message={error} />
        <button type="submit" disabled={busy} className={primaryButton}>
          {busy ? "Signing in…" : "Sign in"}
        </button>
      </form>
      <p className="mt-6 text-center text-sm text-zinc-500 dark:text-zinc-400">
        <Link
          href="/forgot-password"
          className="font-medium text-[#1F3A5F] underline-offset-2 hover:underline dark:text-zinc-200"
        >
          Forgot password?
        </Link>
      </p>
    </AuthCard>
  );
}
