import { z } from "zod";
import { isCommonPassword } from "@/lib/common-passwords";

/**
 * Shared auth schemas — imported by BOTH client forms and API routes (docs/api-contract.md).
 * Never redefine these rules elsewhere. Same rules as the Flutter app and the DB constraints.
 */

/** Exact message used to detect a domain failure and return `email_domain_not_allowed`. */
export const EMAIL_DOMAIN_MESSAGE =
  "Use your Jagannath University email (ending in jnu.ac.bd)";

/**
 * `name@jnu.ac.bd` or `name@<dept>[.<more>].jnu.ac.bd` (D-052). Each label is letters, digits and
 * hyphens, not starting or ending with a hyphen, so `jnu.ac.bd.evil.com`, `xjnu.ac.bd`,
 * `.jnu.ac.bd` and `a@b@jnu.ac.bd` are all rejected. Same pattern as the DB constraint (0012).
 */
const UNIVERSITY_EMAIL =
  /^[^@\s]+@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)*jnu\.ac\.bd$/;

/** Trimmed, lowercased, valid, on `jnu.ac.bd` or one of its subdomains (PRD 5.1, FR-AUTH-2). */
const emailField = z
  .string()
  .trim()
  .toLowerCase()
  .pipe(z.email("Enter a valid email"))
  .refine((value) => UNIVERSITY_EMAIL.test(value), EMAIL_DOMAIN_MESSAGE);

/** `B` + 9 digits (D-020). Trimmed and uppercased before the check. */
const studentIdField = z
  .string()
  .trim()
  .toUpperCase()
  .regex(/^B[0-9]{9}$/, "Student ID looks like B210305040");

/** 8-64 characters, no composition rules, not a very common password (D-015). */
const newPasswordField = z
  .string()
  .min(8, "Password must be at least 8 characters")
  .max(64, "Password must be at most 64 characters")
  .refine((value) => !isCommonPassword(value), "Choose a less common password");

const codeField = z
  .string()
  .trim()
  .regex(/^[0-9]{6}$/, "Enter the 6-digit code");

export const otpPurposeSchema = z.enum(["email_verification", "password_reset"]);

export const registerSchema = z.object({
  full_name: z.string().trim().min(1, "Name is required").max(100),
  student_id: studentIdField,
  email: emailField,
  password: newPasswordField,
});

export const verifyOtpSchema = z.object({
  email: emailField,
  code: codeField,
  purpose: z.literal("email_verification"),
});

export const resendOtpSchema = z.object({
  email: emailField,
  purpose: otpPurposeSchema,
});

export const loginSchema = z.object({
  email: emailField,
  password: z.string().min(1, "Password is required"),
});

export const refreshSchema = z.object({
  refresh_token: z.string().min(1, "Refresh token is required"),
});

export const forgotPasswordSchema = z.object({
  email: emailField,
});

export const resetPasswordSchema = z.object({
  email: emailField,
  code: codeField,
  new_password: newPasswordField,
});
