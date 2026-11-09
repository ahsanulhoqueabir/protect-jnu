import { NextResponse } from "next/server";
import { statusForCode } from "@/lib/api/error-codes";
import type { ServiceFailure } from "@/types/generic.types";

interface SuccessResponseOptions {
  data?: unknown;
  message?: string;
  statusCode?: number;
}

interface ErrorResponseOptions {
  error: string;
  /** Machine-readable code (see `lib/api/error-codes.ts`). */
  code?: string;
  data?: unknown;
  statusCode?: number;
}

/**
 * Success response utility
 * @example ok({ data: { id: "123" }, message: "Created successfully" })
 * @example ok({ data: result, statusCode: 201 })
 */
export function ok(options: SuccessResponseOptions) {
  const { data, message, statusCode = 200 } = options;
  const response: Record<string, unknown> = {
    success: true,
  };
  if (message) response.message = message;
  if (data !== undefined) response.data = data;
  return NextResponse.json(response, { status: statusCode });
}

/**
 * Error response utility
 * @example fail({ error: "Invalid request" })
 * @example fail({ error: "Unauthorized", code: "invalid_token", statusCode: 401 })
 * @example fail({ error: "Not found", data: { details: "..." }, statusCode: 404 })
 */
export function fail(options: ErrorResponseOptions) {
  const { error, code, data, statusCode = 400 } = options;
  const response: Record<string, unknown> = {
    success: false,
    error,
  };
  if (code) response.code = code;
  if (data !== undefined) response.data = data;
  return NextResponse.json(response, { status: statusCode });
}

/** 500 for an unexpected throw. Never echoes the error text (it can contain internals). */
export function unexpected() {
  return fail({
    error: "An unexpected error occurred",
    code: "internal_error",
    statusCode: 500,
  });
}

/** Map a service failure (message + optional code/data) to an HTTP error response. */
export function failFromService(result: ServiceFailure) {
  return fail({
    error: result.error,
    code: result.code ?? "internal_error",
    data: result.data,
    statusCode: statusForCode(result.code),
  });
}
