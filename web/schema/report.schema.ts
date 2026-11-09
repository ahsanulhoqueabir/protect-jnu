import { z } from "zod";

/** `year` defaults to the current year in the service when omitted. */
export const reportQuerySchema = z.object({
  year: z.coerce.number().int().min(2000).max(2100).optional(),
});
