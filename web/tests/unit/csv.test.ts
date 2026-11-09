import { describe, expect, it } from "vitest";
import { csvCell, toCsv } from "@/lib/csv";

describe("csv", () => {
  it("guards formula injection", () => {
    for (const s of ["=1+1", "+1", "-1", "@SUM(A1)", "\tx"]) expect(csvCell(s).startsWith("'") || csvCell(s).startsWith('"\'')).toBe(true);
  });
  it("leaves numbers (including negatives) alone", () => {
    expect(csvCell(-3)).toBe("-3");
  });
  it("quotes commas, quotes and newlines", () => {
    expect(csvCell('a,"b"')).toBe('"a,""b"""');
    expect(csvCell("a\nb")).toBe('"a\nb"');
  });
  it("builds rows with CRLF", () => {
    expect(toCsv(["a", "b"], [[1, 2]])).toBe("a,b\r\n1,2\r\n");
  });
});
