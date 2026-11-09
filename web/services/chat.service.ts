import { failure, success, toMessage } from "@/lib/service-result";
import { createSupabaseUserClient } from "@/lib/api/supabase";
import type { ServiceResult } from "@/types/generic.types";
import type { ChatMessage, Conversation } from "@/types/chat.types";

/** History page size (never unbounded). The newest N are returned, oldest first. */
export const HISTORY_LIMIT = 200;

const GENERIC = "Something went wrong. Please try again.";

/**
 * Chat for admins (D-072). Every call runs as the admin through their own access token, so RLS decides:
 * admins read all threads, send only on active/acknowledged alerts, and mark only the OTHER party's
 * messages as read (migration 0016).
 */
export class ChatService {
  /** Conversations (last message + unread count), newest first, with student name and alert status. */
  static async conversations(accessToken: string): Promise<ServiceResult<Conversation[]>> {
    try {
      const db = createSupabaseUserClient(accessToken);
      const { data, error } = await db.rpc("chat_conversations");
      if (error) throw new Error(error.message);
      const rows = data ?? [];
      if (rows.length === 0) return success([]);

      const ids = rows.map((r) => r.alert_id);
      const { data: alerts, error: alertError } = await db
        .from("alerts")
        .select("id,status,student:profiles!alerts_user_id_fkey(full_name,student_id)")
        .in("id", ids);
      if (alertError) throw new Error(alertError.message);
      const byId = new Map((alerts ?? []).map((a) => [a.id, a]));

      return success(
        rows.map((r) => {
          const a = byId.get(r.alert_id);
          return {
            ...r,
            student: a?.student ?? null,
            status: a?.status ?? null,
          };
        }),
      );
    } catch (err) {
      console.error("chat conversations error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /** Thread history, oldest first. `since` returns only newer messages (reconnect catch-up). */
  static async history(
    accessToken: string,
    alertId: string,
    since?: string,
  ): Promise<ServiceResult<ChatMessage[]>> {
    try {
      const db = createSupabaseUserClient(accessToken);
      const { data: alert, error: alertError } = await db
        .from("alerts")
        .select("user_id")
        .eq("id", alertId)
        .maybeSingle();
      if (alertError) throw new Error(alertError.message);
      if (!alert) return failure("Alert not found.", { code: "alert_not_found" });

      let q = db
        .from("messages")
        .select("id,sender_id,body,sent_at,read_at,sender:profiles!messages_sender_id_fkey(full_name)")
        .eq("alert_id", alertId)
        .order("sent_at", { ascending: false })
        .limit(HISTORY_LIMIT);
      if (since) q = q.gt("sent_at", since);
      const { data, error } = await q;
      if (error) throw new Error(error.message);

      return success(
        (data ?? []).reverse().map((m) => ({
          id: m.id,
          sender_id: m.sender_id,
          body: m.body,
          sent_at: m.sent_at,
          read_at: m.read_at,
          sender_name: m.sender?.full_name ?? null,
          from_student: m.sender_id === alert.user_id,
        })),
      );
    } catch (err) {
      console.error("chat history error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  static async send(
    accessToken: string,
    adminId: string,
    alertId: string,
    body: string,
  ): Promise<ServiceResult<{ id: string; sent_at: string }>> {
    try {
      const db = createSupabaseUserClient(accessToken);
      const { data, error } = await db
        .from("messages")
        .insert({ alert_id: alertId, sender_id: adminId, body })
        .select("id,sent_at")
        .single();
      if (error) {
        // RLS refusal (42501): alert missing, or already resolved/cancelled -> thread is read-only.
        if (error.code === "42501") {
          return failure("This conversation is closed or does not exist.", {
            code: "chat_closed",
          });
        }
        if (error.code === "23514") {
          return failure("Message must be 1 to 1000 characters.", { code: "validation_failed" });
        }
        throw new Error(error.message);
      }
      return success(data);
    } catch (err) {
      console.error("chat send error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /** Mark the student's unread messages on this thread as read (D-021: any admin opening clears it). */
  static async markRead(
    accessToken: string,
    adminId: string,
    alertId: string,
  ): Promise<ServiceResult<{ updated: number }>> {
    try {
      const { data, error } = await createSupabaseUserClient(accessToken)
        .from("messages")
        .update({ read_at: new Date().toISOString() })
        .eq("alert_id", alertId)
        .is("read_at", null)
        .neq("sender_id", adminId)
        .select("id");
      if (error) throw new Error(error.message);
      return success({ updated: data?.length ?? 0 });
    } catch (err) {
      console.error("chat mark read error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }
}
