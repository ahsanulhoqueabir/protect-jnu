import type { NextRequest } from "next/server";
import type { z } from "zod";
import { fail } from "@/lib/api/api-response";
import { EMAIL_DOMAIN_MESSAGE } from "@/schema/auth.schema";

type ParseResult<T> =
  | { ok: true; data: T }
  | { ok: false; response: ReturnType<typeof fail> };

/**
 * Parse + validate a JSON body with a shared Zod schema (from `schema/`).
 * Failures are 422 `validation_failed`, or `email_domain_not_allowed` when the email is not
 * a university address (jnu.ac.bd or a subdomain). Issue details never include the submitted values.
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
    return {
      ok: false,
      response: fail({
        error: "Invalid JSON body",
        code: "validation_failed",
        statusCode: 400,
      }),
    };
  }

  const result = schema.safeParse(body);
  if (!result.success) {
    const domainIssue = result.error.issues.find(
      (i) => i.message === EMAIL_DOMAIN_MESSAGE,
    );
    return {
      ok: false,
      response: fail({
        error: domainIssue?.message ?? result.error.issues[0]?.message ?? "Invalid request",
        code: domainIssue ? "email_domain_not_allowed" : "validation_failed",
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
