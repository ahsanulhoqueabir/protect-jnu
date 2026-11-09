import type { LocationPoint } from "@/types/alert.types";

/** Short trail on the live map (D-066). */
export const TRAIL_POINTS = 20;

/** Merge by id, order by device time (handles out-of-order inserts), keep the newest N. */
export function mergePoints(current: LocationPoint[], incoming: LocationPoint[]): LocationPoint[] {
  const byId = new Map(current.map((p) => [p.id, p]));
  for (const p of incoming) byId.set(p.id, p);
  return [...byId.values()]
    .sort((a, b) => Date.parse(a.recorded_at) - Date.parse(b.recorded_at))
    .slice(-TRAIL_POINTS);
}
