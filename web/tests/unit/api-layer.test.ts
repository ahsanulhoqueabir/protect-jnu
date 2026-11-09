import { NextRequest } from "next/server";
import { describe, expect, it } from "vitest";
import { ERROR_STATUS, statusForCode } from "@/lib/api/error-codes";
import { failFromService, ok, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { loginSchema, registerSchema } from "@/schema/auth.schema";

function jsonRequest(body: unknown) {
  return new NextRequest("http://localhost/api/test", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

describe("error codes (docs/api-contract.md)", () => {
  it("maps every documented code to its status", () => {
    expect(statusForCode("validation_failed")).toBe(422);
    expect(statusForCode("email_domain_not_allowed")).toBe(422);
    expect(statusForCode("email_taken")).toBe(409);
    expect(statusForCode("student_id_taken")).toBe(409);
    expect(statusForCode("otp_invalid")).toBe(400);
    expect(statusForCode("otp_expired")).toBe(400);
    expect(statusForCode("otp_attempts_exceeded")).toBe(400);
    expect(statusForCode("otp_not_found")).toBe(400);
    expect(statusForCode("otp_resend_cooldown")).toBe(429);
    expect(statusForCode("otp_send_limit")).toBe(429);
    expect(statusForCode("email_delivery_failed")).toBe(502);
    expect(statusForCode("invalid_credentials")).toBe(401);
    expect(statusForCode("invalid_refresh_token")).toBe(401);
    expect(statusForCode("invalid_token")).toBe(401);
    expect(statusForCode("email_not_verified")).toBe(403);
    expect(statusForCode("not_admin")).toBe(403);
  });

  it("falls back to 500 for unknown or missing codes", () => {
    expect(statusForCode("nope")).toBe(500);
    expect(statusForCode(undefined)).toBe(500);
    expect(ERROR_STATUS.internal_error).toBe(500);
  });
});

describe("response envelope", () => {
  it("success is { success: true, data }", async () => {
    const res = ok({ data: { a: 1 }, statusCode: 201 });
    expect(res.status).toBe(201);
    expect(await res.json()).toEqual({ success: true, data: { a: 1 } });
  });

  it("failFromService adds the code, status and safe data", async () => {
    const res = failFromService({
      success: false,
      error: "Please wait before requesting another code.",
      code: "otp_resend_cooldown",
      data: { retry_after_seconds: 42 },
    });
    expect(res.status).toBe(429);
    expect(await res.json()).toEqual({
      success: false,
      error: "Please wait before requesting another code.",
      code: "otp_resend_cooldown",
      data: { retry_after_seconds: 42 },
    });
  });

  it("a failure without a code becomes 500 internal_error", async () => {
    const res = failFromService({ success: false, error: "boom" });
    expect(res.status).toBe(500);
    expect((await res.json()).code).toBe("internal_error");
  });

  it("unexpected() never echoes error text", async () => {
    const res = unexpected();
    expect(res.status).toBe(500);
    expect(await res.json()).toEqual({
      success: false,
      error: "An unexpected error occurred",
      code: "internal_error",
    });
  });
});

describe("parseBody", () => {
  it("returns the parsed, normalised body", async () => {
    const parsed = await parseBody(
      jsonRequest({ email: " A@JNU.AC.BD ", password: "x" }),
      loginSchema,
    );
    expect(parsed.ok).toBe(true);
    if (parsed.ok) expect(parsed.data.email).toBe("a@jnu.ac.bd");
  });

  it("rejects invalid JSON with 400 validation_failed", async () => {
    const parsed = await parseBody(jsonRequest("{not json"), loginSchema);
    expect(parsed.ok).toBe(false);
    if (!parsed.ok) {
      expect(parsed.response.status).toBe(400);
      expect((await parsed.response.json()).code).toBe("validation_failed");
    }
  });

  it("a non-university email is 422 email_domain_not_allowed", async () => {
    const parsed = await parseBody(
      jsonRequest({ email: "x@gmail.com", password: "x" }),
      loginSchema,
    );
    expect(parsed.ok).toBe(false);
    if (!parsed.ok) {
      expect(parsed.response.status).toBe(422);
      const body = await parsed.response.json();
      expect(body.code).toBe("email_domain_not_allowed");
      expect(body.error).toBe("Use your @jnu.ac.bd university email");
    }
  });

  it("other validation problems are 422 validation_failed with per-field details", async () => {
    const parsed = await parseBody(
      jsonRequest({
        full_name: "A",
        student_id: "nope",
        email: "a@jnu.ac.bd",
        password: "password123",
      }),
      registerSchema,
    );
    expect(parsed.ok).toBe(false);
    if (!parsed.ok) {
      expect(parsed.response.status).toBe(422);
      const body = await parsed.response.json();
      expect(body.code).toBe("validation_failed");
      const paths = body.data.map((d: { path: string }) => d.path);
      expect(paths).toContain("student_id");
      expect(paths).toContain("password");
    }
  });

  it("validation details never echo the submitted password", async () => {
    const parsed = await parseBody(
      jsonRequest({ full_name: "A", student_id: "x", email: "a@jnu.ac.bd", password: "password123" }),
      registerSchema,
    );
    expect(parsed.ok).toBe(false);
    if (!parsed.ok) {
      expect(JSON.stringify(await parsed.response.json())).not.toContain("password123");
    }
  });
});
