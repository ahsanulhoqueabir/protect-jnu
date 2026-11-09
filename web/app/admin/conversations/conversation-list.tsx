"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@supabase/supabase-js";
import { StatusBadge, formatTime } from "@/components/admin/alert-ui";
import type { Conversation } from "@/types/chat.types";

const POLL_MS = 5000;
const SLOW_POLL_MS = 30000;

/** Conversations with unread counts. Realtime `messages` events trigger a refetch; polled as a fallback. */
export function ConversationList({
  initial,
  accessToken,
  supabaseUrl,
  publishableKey,
}: {
  initial: Conversation[];
  accessToken: string;
  supabaseUrl: string;
  publishableKey: string;
}) {
  const [items, setItems] = useState(initial);
  const [live, setLive] = useState(false);

  const refetch = useCallback(async () => {
    const res = await fetch("/api/admin/conversations", { cache: "no-store" });
    if (res.status === 401) {
      window.location.reload();
      return;
    }
    if (res.ok) setItems((await res.json()).data as Conversation[]);
  }, []);

  useEffect(() => {
    const client = createClient(supabaseUrl, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    client.realtime.setAuth(accessToken);
    const channel = client
      .channel("admin-conversations")
      .on("postgres_changes", { event: "*", schema: "public", table: "messages" }, () => void refetch())
      .subscribe((status) => {
        const up = status === "SUBSCRIBED";
        setLive(up);
        if (up) void refetch();
      });
    return () => {
      void client.removeChannel(channel);
    };
  }, [accessToken, supabaseUrl, publishableKey, refetch]);

  useEffect(() => {
    const t = setInterval(() => void refetch(), live ? SLOW_POLL_MS : POLL_MS);
    return () => clearInterval(t);
  }, [live, refetch]);

  return (
    <div>
      <h1 className="text-xl font-semibold text-zinc-900">Conversations</h1>
      <p className="mb-4 mt-1 text-xs text-zinc-500">
        {live ? "● Live" : "○ Reconnecting, refreshing every 5 s"}
      </p>
      {items.length === 0 ? (
        <p className="rounded border bg-white p-6 text-sm text-zinc-500">No conversations yet.</p>
      ) : (
        <ul className="space-y-2">
          {items.map((c) => (
            <li key={c.alert_id}>
              <Link
                href={`/admin/alerts/${c.alert_id}`}
                className="flex items-center justify-between rounded border bg-white p-4 hover:bg-zinc-50"
              >
                <span className="min-w-0">
                  <span className="block font-medium text-zinc-900">
                    {c.student?.full_name ?? "Student"}{" "}
                    <span className="text-xs font-normal text-zinc-500">{c.student?.student_id}</span>
                  </span>
                  <span className="block truncate text-sm text-zinc-600">{c.last_body}</span>
                  <span className="text-xs text-zinc-400">{formatTime(c.last_sent_at)}</span>
                </span>
                <span className="ml-4 flex items-center gap-3">
                  {c.status && <StatusBadge status={c.status} />}
                  {c.unread_count > 0 && (
                    <span
                      className="rounded-full bg-red-600 px-2 py-0.5 text-xs font-semibold text-white"
                      aria-label={`${c.unread_count} unread`}
                    >
                      {c.unread_count}
                    </span>
                  )}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
