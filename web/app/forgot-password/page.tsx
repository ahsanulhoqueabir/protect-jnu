"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import Link from "next/link";
import { forgotPasswordSchema } from "@/schema/auth.schema";
import {
  AuthCard,
  ErrorNote,
  Field,
  primaryButton,
  readEnvelope,
} from "@/components/auth/auth-ui";

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const parsed = forgotPasswordSchema.safeParse({ email });
    if (!parsed.success) {
      setError(parsed.error.issues[0].message);
      return;
    }
    setBusy(true);
    try {
      const res = await fetch("/api/auth/forgot-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parsed.data),
      });
      const body = await readEnvelope(res);
      if (!body.success) {
        const wait = body.data?.retry_after_seconds;
        setError(
          typeof wait === "number"
            ? `${body.error ?? "Please wait."} (try again in ${wait}s)`
            : (body.error ?? "Request failed."),
        );
        return;
      }
      router.push(
        `/reset-password?email=${encodeURIComponent(parsed.data.email)}`,
      );
    } catch {
      setError("Could not reach the server.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <AuthCard
      title="Forgot password"
      subtitle="We will email a 6-digit code to your university address."
    >
      <form onSubmit={onSubmit} className="space-y-5" noValidate>
        <Field
          id="email"
          label="University email"
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <ErrorNote message={error} />
        <button type="submit" disabled={busy} className={primaryButton}>
          {busy ? "Sending…" : "Send code"}
        </button>
      </form>
      <p className="mt-6 text-center text-sm">
        <Link
          href="/login"
          className="font-medium text-[#1F3A5F] underline-offset-2 hover:underline dark:text-zinc-200"
        >
          Back to sign in
        </Link>
      </p>
    </AuthCard>
  );
}
