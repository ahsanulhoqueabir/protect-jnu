import type { ServiceResult } from "@/types/generic.types";

/** Service-layer result helpers. Services never throw to routes; they return these. */
export function success<T>(data: T): ServiceResult<T> {
  return { success: true, data };
}

export function failure<T = never>(
  message: string,
  extra?: { code?: string; data?: Record<string, unknown> },
): ServiceResult<T> {
  return { success: false, error: message, ...extra };
}

export function toMessage(err: unknown): string {
  return err instanceof Error && err.message
    ? err.message
    : "An unknown error occurred";
}
