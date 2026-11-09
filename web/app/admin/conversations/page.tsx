import { cookies } from "next/headers";
import { ACCESS_COOKIE } from "@/lib/api/admin-session";
import { ChatService } from "@/services/chat.service";
import { ConversationList } from "./conversation-list";

export const dynamic = "force-dynamic";

export default async function ConversationsPage() {
  // The layout has already verified this token belongs to an admin.
  const token = (await cookies()).get(ACCESS_COOKIE)?.value ?? "";
  const list = await ChatService.conversations(token);
  return (
    <ConversationList
      initial={list.success ? list.data : []}
      accessToken={token}
      supabaseUrl={process.env.NEXT_PUBLIC_SUPABASE_URL!}
      publishableKey={process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!}
    />
  );
}
