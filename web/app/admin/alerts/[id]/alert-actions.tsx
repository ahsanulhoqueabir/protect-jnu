"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import type { AlertStatus } from "@/types/alert.types";

export function AlertActions({ id, status }: { id: string; status: AlertStatus }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const action =
    status === "active"
      ? { key: "acknowledge", label: "Acknowledge" }
      : status === "acknowledged"
        ? { key: "resolve", label: "Mark resolved" }
        : null;
  if (!action) return null;

  async function run(key: string) {
    setBusy(true);
    setError(null);
    const res = await fetch(`/api/admin/alerts/${id}/status`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ action: key }),
    });
    setBusy(false);
    if (res.status === 401) return window.location.reload();
    if (!res.ok) {
      setError((await res.json()).error ?? "Could not update the alert.");
    }
    router.refresh(); // also shows the new state if another admin got there first
  }

  return (
    <div className="mt-4">
      <button
        type="button"
        disabled={busy}
        onClick={() => run(action.key)}
        className="rounded bg-[#1F3A5F] px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
      >
        {busy ? "Saving…" : action.label}
      </button>
      {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
    </div>
  );
}
