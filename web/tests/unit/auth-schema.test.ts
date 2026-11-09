import { describe, expect, it } from "vitest";
import {
  EMAIL_DOMAIN_MESSAGE,
  forgotPasswordSchema,
  loginSchema,
  registerSchema,
  resendOtpSchema,
  resetPasswordSchema,
  verifyOtpSchema,
} from "@/schema/auth.schema";

const valid = {
  full_name: "Ayesha Rahman",
  student_id: "B210305040",
  email: "ayesha@jnu.ac.bd",
  password: "correct horse battery",
};

function messages(result: { success: boolean; error?: { issues: { message: string }[] } }) {
  return result.error?.issues.map((i) => i.message) ?? [];
}

describe("university email (FR-AUTH-2)", () => {
  it("accepts a @jnu.ac.bd address and normalises case and whitespace", () => {
    const r = registerSchema.safeParse({ ...valid, email: "  Ayesha@JNU.AC.BD " });
    expect(r.success).toBe(true);
    expect(r.data?.email).toBe("ayesha@jnu.ac.bd");
  });

  it.each([
    "x@gmail.com",
    "x@jnu.ac.bd.evil.com",
    "x@evil.com@jnu.ac.bd",
    "x@sub.jnu.ac.bd",
    "x@jnu.ac.bdx",
    "x@mail.jnu.ac.bd",
    "x@jnu.edu.bd",
    "@jnu.ac.bd",
  ])("rejects %s", (email) => {
    const r = registerSchema.safeParse({ ...valid, email });
    expect(r.success).toBe(false);
  });

  it("reports the domain message for a valid non-university email", () => {
    const r = registerSchema.safeParse({ ...valid, email: "x@gmail.com" });
    expect(messages(r)).toContain(EMAIL_DOMAIN_MESSAGE);
  });

  it("applies the same rule on every route that takes an email", () => {
    const bad = "x@gmail.com";
    expect(loginSchema.safeParse({ email: bad, password: "x" }).success).toBe(false);
    expect(forgotPasswordSchema.safeParse({ email: bad }).success).toBe(false);
    expect(
      resendOtpSchema.safeParse({ email: bad, purpose: "password_reset" }).success,
    ).toBe(false);
    expect(
      verifyOtpSchema.safeParse({
        email: bad,
        code: "123456",
        purpose: "email_verification",
      }).success,
    ).toBe(false);
    expect(
      resetPasswordSchema.safeParse({
        email: bad,
        code: "123456",
        new_password: "correct horse battery",
      }).success,
    ).toBe(false);
  });
});

describe("student ID (D-020)", () => {
  it("trims and uppercases before checking", () => {
    const r = registerSchema.safeParse({ ...valid, student_id: " b210305040 " });
    expect(r.success).toBe(true);
    expect(r.data?.student_id).toBe("B210305040");
  });

  it.each(["B21030504", "B2103050400", "A210305040", "B21030504X", "", "210305040"])(
    "rejects %j",
    (student_id) => {
      expect(registerSchema.safeParse({ ...valid, student_id }).success).toBe(false);
    },
  );
});

describe("password policy (D-015)", () => {
  it("accepts 8 to 64 characters with no composition rules", () => {
    expect(registerSchema.safeParse({ ...valid, password: "alllowercase" }).success).toBe(true);
    expect(registerSchema.safeParse({ ...valid, password: "x".repeat(8) + "!q" }).success).toBe(true);
    expect(registerSchema.safeParse({ ...valid, password: "q".repeat(64) }).success).toBe(true);
  });

  it("rejects too short and too long", () => {
    expect(registerSchema.safeParse({ ...valid, password: "short7!" }).success).toBe(false);
    expect(registerSchema.safeParse({ ...valid, password: "q".repeat(65) }).success).toBe(false);
  });

  it("rejects very common passwords, case-insensitively", () => {
    for (const password of ["password123", "PASSWORD123", "12345678", "iloveyou"]) {
      expect(registerSchema.safeParse({ ...valid, password }).success).toBe(false);
    }
  });

  it("applies to the new password on reset too", () => {
    const base = { email: valid.email, code: "123456" };
    expect(resetPasswordSchema.safeParse({ ...base, new_password: "password123" }).success).toBe(false);
    expect(resetPasswordSchema.safeParse({ ...base, new_password: "tiny" }).success).toBe(false);
    expect(resetPasswordSchema.safeParse({ ...base, new_password: "a fine new password" }).success).toBe(true);
  });
});

describe("code and purpose", () => {
  const base = { email: valid.email, purpose: "email_verification" as const };

  it("requires exactly six digits and trims whitespace", () => {
    expect(verifyOtpSchema.safeParse({ ...base, code: " 123456 " }).data?.code).toBe("123456");
    for (const code of ["12345", "1234567", "12345a", "", "12 456"]) {
      expect(verifyOtpSchema.safeParse({ ...base, code }).success).toBe(false);
    }
  });

  it("verify-otp accepts only the email_verification purpose", () => {
    expect(
      verifyOtpSchema.safeParse({ ...base, code: "123456", purpose: "password_reset" }).success,
    ).toBe(false);
  });

  it("resend-otp accepts the two known purposes only", () => {
    expect(resendOtpSchema.safeParse({ email: valid.email, purpose: "password_reset" }).success).toBe(true);
    expect(resendOtpSchema.safeParse({ email: valid.email, purpose: "other" }).success).toBe(false);
  });
});

describe("full name", () => {
  it("is required and capped at 100 characters", () => {
    expect(registerSchema.safeParse({ ...valid, full_name: "   " }).success).toBe(false);
    expect(registerSchema.safeParse({ ...valid, full_name: "n".repeat(101) }).success).toBe(false);
    expect(registerSchema.safeParse({ ...valid, full_name: "n".repeat(100) }).success).toBe(true);
  });
});
