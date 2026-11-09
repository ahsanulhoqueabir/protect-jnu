import { z } from "zod";

/** D-072: 1 to 1000 characters after trimming (same rule as DB CHECK messages_body_length). */
export const MESSAGE_MAX = 1000;

export const messageBodySchema = z.object({
  body: z.string().trim().min(1).max(MESSAGE_MAX),
});

/** Reconnect catch-up: only messages newer than this timestamp. */
export const messagesQuerySchema = z.object({
  since: z.iso.datetime({ offset: true }).optional(),
});
