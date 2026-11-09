"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { createClient } from "@supabase/supabase-js";
import { MESSAGE_MAX } from "@/schema/chat.schema";
import type { ChatMessage } from "@/types/chat.types";

const POLL_MS = 5000;
const SLOW_POLL_MS = 30000;

/** Merge by id (dedupes Realtime + refetch + own send), ordered by sent_at. */
export function mergeMessages(current: ChatMessage[], incoming: ChatMessage[]): ChatMessage[] {
  const map = new Map(current.map((m) => [m.id, m]));
  for (const m of incoming) map.set(m.id, { ...map.get(m.id), ...m });
  return [...map.values()].sort((a, b) => a.sent_at.localeCompare(b.sent_at));
}

/**
 * Chat panel for one alert (admin). History and sends go through our admin API (user-JWT, RLS);
 * Realtime INSERTs on `messages` (filtered by alert) add messages live; on (re)connect and by polling
 * the panel refetches what is newer than the last message seen. Read-only once the alert is closed (D-072).
 */
export function ChatPanel({
  alertId,
  open,
  initial,
  accessToken,
  supabaseUrl,
  publishableKey,
}: {
  alertId: string;
  open: boolean;
  initial: ChatMessage[];
  accessToken: string;
  supabaseUrl: string;
  publishableKey: string;
}) {
  const [messages, setMessages] = useState(initial);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [live, setLive] = useState(false);
  const [closed, setClosed] = useState(!open);
  const latest = useRef<string | undefined>(initial.at(-1)?.sent_at);
  const endRef = useRef<HTMLDivElement>(null);
  const base = `/api/admin/alerts/${alertId}/messages`;

  const markRead = useCallback(() => {
    void fetch(base, { method: "PATCH" });
  }, [base]);

  const refetch = useCallback(async () => {
    const q = latest.current ? `?since=${encodeURIComponent(latest.current)}` : "";
    const res = await fetch(base + q, { cache: "no-store" });
    if (res.status === 401) {
      window.location.reload();
      return;
    }
    if (!res.ok) return;
    const fresh = (await res.json()).data as ChatMessage[];
    if (fresh.length === 0) return;
    latest.current = fresh.at(-1)!.sent_at;
    setMessages((cur) => mergeMessages(cur, fresh));
    if (fresh.some((m) => m.from_student && !m.read_at)) markRead();
  }, [base, markRead]);

  useEffect(() => {
    markRead(); // opening the thread clears the unread count (D-021)
  }, [markRead]);

  useEffect(() => {
    const client = createClient(supabaseUrl, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    client.realtime.setAuth(accessToken);
    const channel = client
      .channel(`admin-chat-${alertId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "messages", filter: `alert_id=eq.${alertId}` },
        () => void refetch(),
      )
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "alerts", filter: `id=eq.${alertId}` },
        (p) => {
          const status = (p.new as { status?: string }).status;
          if (status === "resolved" || status === "cancelled") setClosed(true);
        },
      )
      .subscribe((status) => {
        const up = status === "SUBSCRIBED";
        setLive(up);
        if (up) void refetch(); // catch up on anything missed while connecting
      });
    return () => {
      void client.removeChannel(channel);
    };
  }, [alertId, accessToken, supabaseUrl, publishableKey, refetch]);

  useEffect(() => {
    const t = setInterval(() => void refetch(), live ? SLOW_POLL_MS : POLL_MS);
    return () => clearInterval(t);
  }, [live, refetch]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ block: "end" });
  }, [messages.length]);

  async function send(e: React.FormEvent) {
    e.preventDefault();
    const body = text.trim();
    if (!body || sending) return;
    setSending(true);
    setError(null);
    try {
      const res = await fetch(base, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ body }),
      });
      if (res.ok) {
        setText("");
        await refetch();
      } else {
        const j = await res.json().catch(() => ({}));
        if (j.code === "chat_closed") setClosed(true);
        setError(j.error ?? "Could not send. Try again.");
      }
    } catch {
      setError("Network problem. Message not sent.");
    } finally {
      setSending(false);
    }
  }

  return (
    <div>
      <p className="mb-2 text-xs text-zinc-500">
        {closed ? "Read-only: this alert is closed." : live ? "● Live" : "○ Reconnecting, refreshing every 5 s"}
      </p>
      <div className="max-h-96 space-y-2 overflow-y-auto rounded border bg-zinc-50 p-3" role="log">
        {messages.length === 0 && <p className="text-sm text-zinc-500">No messages yet.</p>}
        {messages.map((m) => (
          <div key={m.id} className={`flex ${m.from_student ? "justify-start" : "justify-end"}`}>
            <div
              className={`max-w-[75%] rounded px-3 py-2 text-sm ${
                m.from_student ? "bg-white border" : "bg-[#1F3A5F] text-white"
              }`}
            >
              <div className="mb-0.5 text-[11px] opacity-70">
                {m.from_student ? "Student" : (m.sender_name ?? "Admin")} ·{" "}
                {new Date(m.sent_at).toLocaleTimeString()}
              </div>
              <div className="whitespace-pre-wrap break-words">{m.body}</div>
            </div>
          </div>
        ))}
        <div ref={endRef} />
      </div>
      {!closed && (
        <form onSubmit={send} className="mt-3 flex gap-2">
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            maxLength={MESSAGE_MAX}
            placeholder="Reply to the student"
            className="flex-1 rounded border px-3 py-2 text-sm"
            aria-label="Message"
          />
          <button
            type="submit"
            disabled={sending || text.trim().length === 0}
            className="rounded bg-[#1F3A5F] px-4 py-2 text-sm text-white disabled:opacity-50"
          >
            Send
          </button>
        </form>
      )}
      {error && <p className="mt-2 text-xs text-red-600">{error}</p>}
    </div>
  );
}
