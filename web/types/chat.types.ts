import type { Database } from "@/types/database.types";

export type MessageRow = Database["public"]["Tables"]["messages"]["Row"];

/** One chat message as shown to an admin; sender name per D-021. */
export type ChatMessage = Pick<MessageRow, "id" | "sender_id" | "body" | "sent_at" | "read_at"> & {
  sender_name: string | null;
  from_student: boolean;
};

/** One conversation (= one alert) with its last message and unread count. */
export type Conversation = {
  alert_id: string;
  last_body: string;
  last_sent_at: string;
  last_sender_id: string;
  unread_count: number;
  student: { full_name: string; student_id: string } | null;
  status: Database["public"]["Enums"]["alert_status"] | null;
};
