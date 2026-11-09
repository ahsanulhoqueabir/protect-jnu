import type { z } from "zod";
import type { loginSchema, signUpSchema } from "@/schema/auth.schema";
import type { Profile, PublicProfile } from "@/types/profile.types";

/** Request payloads — inferred from the shared Zod schemas. */
export type LoginParams = z.infer<typeof loginSchema>;
export type SignUpParams = z.infer<typeof signUpSchema>;

/** Claims stored in the API JWT. */
export type JwtPayload = Pick<Profile, "email" | "role"> & {
  /** `profiles.id` */
  profile: Profile["id"];
};

/** User shape exposed to the client. */
export type AuthUser = PublicProfile;

/** Response `data` of login and signup. */
export type AuthSession = { user: AuthUser; token: string };
