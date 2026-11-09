import { z } from "zod";

/**
 * Shared auth schemas — imported by BOTH client forms and API routes.
 * Never redefine these rules elsewhere.
 */
export const loginSchema = z.object({
  email: z.string().trim().toLowerCase().pipe(z.email("Enter a valid email")),
  password: z.string().min(1, "Password is required"),
});

export const signUpSchema = z.object({
  name: z.string().trim().min(1, "Name is required").max(100),
  email: z.string().trim().toLowerCase().pipe(z.email("Enter a valid email")),
  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(72, "Password must be at most 72 characters"),
  username: z
    .string()
    .trim()
    .regex(/^[a-z0-9_]{3,30}$/i, "3–30 letters, numbers or underscores")
    .optional(),
});
