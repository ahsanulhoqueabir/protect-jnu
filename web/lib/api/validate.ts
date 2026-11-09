import type { NextRequest } from "next/server";
import type { z } from "zod";
import { fail } from "@/lib/api/api-response";

type ParseResult<T> =
  | { ok: true; data: T }
  | { ok: false; response: ReturnType<typeof fail> };

/**
 * Parse + validate a JSON body with a shared Zod schema (from `schema/`).
 * @example
 * const parsed = await parseBody(request, loginSchema);
 * if (!parsed.ok) return parsed.response;
 */
export async function parseBody<S extends z.ZodType>(
  request: NextRequest,
  schema: S,
): Promise<ParseResult<z.infer<S>>> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return { ok: false, response: fail({ error: "Invalid JSON body" }) };
  }

  const result = schema.safeParse(body);
  if (!result.success) {
    return {
      ok: false,
      response: fail({
        error: result.error.issues[0]?.message ?? "Invalid request",
        data: result.error.issues.map((i) => ({
          path: i.path.join("."),
          message: i.message,
        })),
        statusCode: 422,
      }),
    };
  }
  return { ok: true, data: result.data };
}
