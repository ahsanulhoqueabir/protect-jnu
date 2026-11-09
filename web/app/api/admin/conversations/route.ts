import { failFromService, ok } from "@/lib/api/api-response";
import { withAdmin } from "@/lib/api/auth-middleware";
import { ChatService } from "@/services/chat.service";

/** GET /api/admin/conversations — last message + unread count per alert, newest first. */
export const GET = withAdmin(async ({ accessToken }) => {
  const result = await ChatService.conversations(accessToken);
  if (!result.success) return failFromService(result);
  return ok({ data: result.data });
});
