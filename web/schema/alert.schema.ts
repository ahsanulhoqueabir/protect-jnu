import { z } from "zod";

/** Admin alert actions (PRD: acknowledged, then resolved). */
export const alertActionSchema = z.object({
  action: z.enum(["acknowledge", "resolve"]),
});

/** `open` = active + acknowledged (the live list). Lists are 20 per page, newest first (D-024). */
export const alertListQuerySchema = z.object({
  status: z
    .enum(["open", "all", "active", "acknowledged", "resolved", "cancelled"])
    .default("open"),
  page: z.coerce.number().int().min(1).max(10_000).default(1),
});

export const pageQuerySchema = z.object({
  page: z.coerce.number().int().min(1).max(10_000).default(1),
});

export const uuidSchema = z.uuid();
