import { describe, expect, it } from "vitest";
import { mergePoints, TRAIL_POINTS } from "@/lib/map/merge-points";
import type { LocationPoint } from "@/types/alert.types";

const pt = (id: string, sec: number): LocationPoint => ({
  id,
  latitude: 23.7,
  longitude: 90.4,
  accuracy: null,
  recorded_at: new Date(Date.UTC(2026, 10, 9, 12, 0, sec)).toISOString(),
});

describe("mergePoints", () => {
  it("orders by recorded_at even when points arrive out of order", () => {
    const out = mergePoints([pt("a", 10), pt("c", 30)], [pt("b", 20)]);
    expect(out.map((p) => p.id)).toEqual(["a", "b", "c"]);
  });
  it("ignores a point it already has", () => {
    const out = mergePoints([pt("a", 10)], [pt("a", 10), pt("a", 10)]);
    expect(out).toHaveLength(1);
  });
  it("keeps only the newest 20", () => {
    const many = Array.from({ length: 30 }, (_, i) => pt(`p${i}`, i));
    const out = mergePoints([], many);
    expect(out).toHaveLength(TRAIL_POINTS);
    expect(out[0].id).toBe("p10");
    expect(out.at(-1)!.id).toBe("p29");
  });
  it("a late older point does not replace the newest marker position", () => {
    const out = mergePoints([pt("b", 20)], [pt("a", 5)]);
    expect(out.at(-1)!.id).toBe("b");
  });
});
