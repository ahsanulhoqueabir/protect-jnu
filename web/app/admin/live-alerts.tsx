"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { createClient } from "@supabase/supabase-js";
import { StatusBadge, formatTime } from "@/components/admin/alert-ui";
import type { AlertListItem, AlertPage } from "@/types/alert.types";

const POLL_MS = 5000;
/** Safety net while the socket claims to be up (one run in 11 missed an event in testing). */
const SLOW_POLL_MS = 30000;

type Toast = { id: number; text: string };

/**
 * Live alerts (D-028, D-062). Realtime `alerts` changes (RLS: admin reads all) trigger a refetch of the
 * list through our admin API; while the socket is down the list is polled every 5 s. The short-lived
 * access token is used for Realtime only; the refresh token stays httpOnly. Beep needs one click first
 * (browser autoplay rules).
 */
export function LiveAlerts({
  initial,
  accessToken,
  supabaseUrl,
  publishableKey,
}: {
  initial: AlertListItem[];
  accessToken: string;
  supabaseUrl: string;
  publishableKey: string;
}) {
  const [items, setItems] = useState(initial);
  const [live, setLive] = useState(false);
  const [soundOn, setSoundOn] = useState(false);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const audio = useRef<AudioContext | null>(null);
  const known = useRef(new Set(initial.map((a) => a.id)));
  const soundRef = useRef(false);

  const beep = useCallback(() => {
    const ctx = audio.current;
    if (!ctx || !soundRef.current) return;
    for (const [i, freq] of [880, 660, 880].entries()) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.frequency.value = freq;
      gain.gain.value = 0.2;
      osc.connect(gain).connect(ctx.destination);
      const t = ctx.currentTime + i * 0.25;
      osc.start(t);
      osc.stop(t + 0.18);
    }
  }, []);

  const refetch = useCallback(async () => {
    const res = await fetch("/api/admin/alerts?status=open", { cache: "no-store" });
    if (res.status === 401) {
      window.location.reload(); // the proxy refreshes the cookie or sends us to /login
      return;
    }
    if (!res.ok) return;
    const page = (await res.json()).data as AlertPage;
    const fresh = page.items.filter((a) => !known.current.has(a.id));
    fresh.forEach((a) => known.current.add(a.id));
    setItems(page.items);
    if (fresh.length > 0) {
      beep();
      const added = fresh.map((a) => ({
        id: Date.now() + Math.random(),
        text: `New SOS: ${a.student.full_name} (${a.student.student_id})`,
      }));
      setToasts((t) => [...t, ...added]);
      added.forEach((n) =>
        setTimeout(() => setToasts((t) => t.filter((x) => x.id !== n.id)), 10000),
      );
    }
  }, [beep]);

  useEffect(() => {
    const client = createClient(supabaseUrl, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    client.realtime.setAuth(accessToken);
    const channel = client
      .channel("admin-alerts")
      .on("postgres_changes", { event: "*", schema: "public", table: "alerts" }, () => {
        void refetch();
      })
      .subscribe((status) => {
        const up = status === "SUBSCRIBED";
        setLive(up);
        if (up) void refetch(); // catch anything missed while connecting
      });
    return () => {
      void client.removeChannel(channel);
    };
  }, [accessToken, supabaseUrl, publishableKey, refetch]);

  // Fallback: poll every 5 s while the socket is not up, every 30 s while it is.
  useEffect(() => {
    const timer = setInterval(() => void refetch(), live ? SLOW_POLL_MS : POLL_MS);
    return () => clearInterval(timer);
  }, [live, refetch]);

  function enableSound() {
    audio.current ??= new AudioContext();
    void audio.current.resume();
    soundRef.current = true;
    setSoundOn(true);
    beep();
  }

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-zinc-900">Live alerts</h1>
          <p className="mt-1 text-xs text-zinc-500">
            {live ? "● Live" : "○ Reconnecting, refreshing every 5 s"}
          </p>
        </div>
        <button
          type="button"
          onClick={enableSound}
          disabled={soundOn}
          className="rounded border px-3 py-1.5 text-sm hover:bg-zinc-100 disabled:opacity-60"
        >
          {soundOn ? "Sound on" : "Enable sound"}
        </button>
      </div>

      <div className="fixed right-4 top-16 z-10 flex flex-col gap-2" role="status">
        {toasts.map((t) => (
          <div key={t.id} className="rounded bg-red-600 px-4 py-2 text-sm text-white shadow">
            {t.text}
          </div>
        ))}
      </div>

      {items.length === 0 ? (
        <p className="rounded border bg-white p-6 text-sm text-zinc-500">No open alerts.</p>
      ) : (
        <ul className="space-y-2">
          {items.map((a) => (
            <li key={a.id}>
              <Link
                href={`/admin/alerts/${a.id}`}
                className={`flex items-center justify-between rounded border bg-white p-4 hover:bg-zinc-50 ${
                  a.status === "active" ? "border-red-400 ring-1 ring-red-200" : ""
                }`}
              >
                <span>
                  <span className="block font-medium text-zinc-900">{a.student.full_name}</span>
                  <span className="text-xs text-zinc-500">
                    {a.student.student_id} · {formatTime(a.started_at)}
                  </span>
                </span>
                <StatusBadge status={a.status} />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
