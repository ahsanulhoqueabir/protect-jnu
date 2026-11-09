import { describe, expect, it } from "vitest";
import { mergeMessages } from "@/components/chat/chat-panel";
import type { ChatMessage } from "@/types/chat.types";

const m = (id: string, sec: number, extra: Partial<ChatMessage> = {}): ChatMessage => ({
  id,
  sender_id: "s",
  body: id,
  sent_at: new Date(Date.UTC(2026, 10, 9, 12, 0, sec)).toISOString(),
  read_at: null,
  sender_name: null,
  from_student: true,
  ...extra,
});

describe("mergeMessages", () => {
  it("dedupes by id and orders by sent_at", () => {
    const out = mergeMessages([m("a", 1), m("c", 3)], [m("b", 2), m("c", 3)]);
    expect(out.map((x) => x.id)).toEqual(["a", "b", "c"]);
  });
  it("a late older message lands in order", () => {
    expect(mergeMessages([m("b", 2)], [m("a", 1)]).map((x) => x.id)).toEqual(["a", "b"]);
  });
  it("keeps newer field values for the same id", () => {
    const out = mergeMessages([m("a", 1)], [m("a", 1, { read_at: "2026-11-09T12:00:09.000Z" })]);
    expect(out[0].read_at).not.toBeNull();
  });
});
