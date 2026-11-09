export interface SystemFields {
  id: string;
  created_at: string;
  updated_at: string;
  status: Status;
}

export const STATUS = {
  DRAFT: "DRAFT",
  PENDING: "PENDING",
  ACTIVE: "ACTIVE",
  DELETED: "DELETED",
  COMPLETED: "COMPLETED",
  CANCELLED: "CANCELLED",
  DECLINED: "DECLINED",
  IN_PROGRESS: "IN_PROGRESS",
  EXPIRED: "EXPIRED",
  PAUSED: "PAUSED",
  DELIVERED: "DELIVERED",
  REVIEW: "REVIEW",
  REVISION: "REVISION",
  ACCEPTED: "ACCEPTED",
  APPROVED: "APPROVED",
  SUSPENDED: "SUSPENDED",
} as const;

export type Status = (typeof STATUS)[keyof typeof STATUS];

export type RecordContext =
  | Record<string, string>
  | Promise<Record<string, string>>;

/** A failed service call. `code` is a machine code from `lib/api/error-codes.ts`; `data` is safe to return. */
export type ServiceFailure = {
  success: false;
  error: string;
  code?: string;
  data?: Record<string, unknown>;
};

export type ServiceResult<T = unknown> =
  | { success: true; data: T }
  | ServiceFailure;

export type QueryParams = Record<string, unknown>;
export type QueryFilter = Record<string, unknown>;
