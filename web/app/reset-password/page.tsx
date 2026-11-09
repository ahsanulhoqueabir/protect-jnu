"use client";

import { Suspense, useState, type FormEvent } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { resetPasswordSchema } from "@/schema/auth.schema";
import {
  AuthCard,
  ErrorNote,
  Field,
  InfoNote,
  primaryButton,
  readEnvelope,
} from "@/components/auth/auth-ui";

function ResetForm() {
  const params = useSearchParams();
  const [email, setEmail] = useState(params.get("email") ?? "");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const parsed = resetPasswordSchema.safeParse({
      email,
      code,
      new_password: password,
    });
    if (!parsed.success) {
      setError(parsed.error.issues[0].message);
      return;
    }
    setBusy(true);
    try {
      const res = await fetch("/api/auth/reset-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parsed.data),
      });
      const body = await readEnvelope(res);
      if (!body.success) {
        const left = body.data?.attempts_remaining;
        setError(
          typeof left === "number"
            ? `${body.error ?? "Wrong code."} (${left} attempts left)`
            : (body.error ?? "Reset failed."),
        );
        return;
      }
      setDone(true);
    } catch {
      setError("Could not reach the server.");
    } finally {
      setBusy(false);
    }
  }

  if (done) {
    return (
      <AuthCard title="Password changed">
        <InfoNote message="Your password was changed and all other sessions were signed out." />
        <p className="mt-6 text-center text-sm">
          <Link
            href="/login"
            className="font-medium text-[#1F3A5F] underline-offset-2 hover:underline dark:text-zinc-200"
          >
            Sign in
          </Link>
        </p>
      </AuthCard>
    );
  }

  return (
    <AuthCard
      title="Reset password"
      subtitle="Enter the code from your email and a new password."
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
        <Field
          id="code"
          label="6-digit code"
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={6}
          value={code}
          onChange={(e) => setCode(e.target.value)}
        />
        <Field
          id="new-password"
          label="New password"
          type="password"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <ErrorNote message={error} />
        <button type="submit" disabled={busy} className={primaryButton}>
          {busy ? "Saving…" : "Change password"}
        </button>
      </form>
      <p className="mt-6 text-center text-sm">
        <Link
          href="/forgot-password"
          className="font-medium text-[#1F3A5F] underline-offset-2 hover:underline dark:text-zinc-200"
        >
          Send a new code
        </Link>
      </p>
    </AuthCard>
  );
}

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={null}>
      <ResetForm />
    </Suspense>
  );
}
