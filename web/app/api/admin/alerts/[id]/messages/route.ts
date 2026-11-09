import { fail, failFromService, ok } from "@/lib/api/api-response";
import { withAdmin } from "@/lib/api/auth-middleware";
import { parseBody } from "@/lib/api/validate";
import { uuidSchema } from "@/schema/alert.schema";
import { messageBodySchema, messagesQuerySchema } from "@/schema/chat.schema";
import { ChatService } from "@/services/chat.service";

const notFound = () =>
  fail({ error: "Alert not found.", code: "alert_not_found", statusCode: 404 });

/** GET /api/admin/alerts/:id/messages[?since=ISO] — thread history, oldest first. */
export const GET = withAdmin(async ({ req, accessToken, params }) => {
  const id = uuidSchema.safeParse(params.id);
  if (!id.success) return notFound();
  const query = messagesQuerySchema.safeParse(Object.fromEntries(req.nextUrl.searchParams));
  if (!query.success) {
    return fail({ error: "Invalid query", code: "validation_failed", statusCode: 422 });
  }
  const result = await ChatService.history(accessToken, id.data, query.data.since);
  if (!result.success) return failFromService(result);
  return ok({ data: result.data });
});

/** POST /api/admin/alerts/:id/messages  body { body } — 409 chat_closed once resolved/cancelled. */
export const POST = withAdmin(async ({ req, user, accessToken, params }) => {
  const id = uuidSchema.safeParse(params.id);
  if (!id.success) return notFound();
  const parsed = await parseBody(req, messageBodySchema);
  if (!parsed.ok) return parsed.response;
  const result = await ChatService.send(accessToken, user.id, id.data, parsed.data.body);
  if (!result.success) return failFromService(result);
  return ok({ data: result.data, statusCode: 201 });
});

/** PATCH /api/admin/alerts/:id/messages — mark the student's messages read. */
export const PATCH = withAdmin(async ({ user, accessToken, params }) => {
  const id = uuidSchema.safeParse(params.id);
  if (!id.success) return notFound();
  const result = await ChatService.markRead(accessToken, user.id, id.data);
  if (!result.success) return failFromService(result);
  return ok({ data: result.data });
});
