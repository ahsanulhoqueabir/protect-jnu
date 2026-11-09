import { beforeAll, describe, expect, it, vi } from "vitest";

const SECRET = "a".repeat(64);

type OtpModule = typeof import("@/lib/otp");
let otp: OtpModule;

beforeAll(async () => {
  process.env.OTP_HASH_SECRET = SECRET;
  vi.resetModules();
  otp = await import("@/lib/otp");
});

describe("generateOtpCode", () => {
  it("always returns exactly 6 digits, keeping leading zeros", () => {
    const seen = new Set<string>();
    for (let i = 0; i < 5000; i++) {
      const code = otp.generateOtpCode();
      expect(code).toMatch(/^[0-9]{6}$/);
      seen.add(code);
    }
    // Not a constant or tiny range: 5000 draws from 1,000,000 values should be almost all distinct.
    expect(seen.size).toBeGreaterThan(4900);
  });

  it("produces codes across the whole range, including a leading zero", () => {
    let leadingZero = false;
    let high = false;
    for (let i = 0; i < 5000 && !(leadingZero && high); i++) {
      const code = otp.generateOtpCode();
      if (code.startsWith("0")) leadingZero = true;
      if (code.startsWith("9")) high = true;
    }
    expect(leadingZero).toBe(true);
    expect(high).toBe(true);
  });
});

describe("hashOtp", () => {
  const user = "11111111-1111-1111-1111-111111111111";

  it("is a 64-char hex HMAC and never contains the code", () => {
    const hash = otp.hashOtp(user, "email_verification", "123456");
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
    expect(hash).not.toContain("123456");
  });

  it("is deterministic for the same inputs", () => {
    expect(otp.hashOtp(user, "email_verification", "123456")).toBe(
      otp.hashOtp(user, "email_verification", "123456"),
    );
  });

  it("changes with the code, the user and the purpose", () => {
    const base = otp.hashOtp(user, "email_verification", "123456");
    expect(otp.hashOtp(user, "email_verification", "123457")).not.toBe(base);
    expect(
      otp.hashOtp("22222222-2222-2222-2222-222222222222", "email_verification", "123456"),
    ).not.toBe(base);
    expect(otp.hashOtp(user, "password_reset", "123456")).not.toBe(base);
  });

  it("depends on the server secret (a leaked table alone is not enough)", async () => {
    const withA = otp.hashOtp(user, "email_verification", "123456");
    process.env.OTP_HASH_SECRET = "b".repeat(64);
    vi.resetModules();
    const other = await import("@/lib/otp");
    expect(other.hashOtp(user, "email_verification", "123456")).not.toBe(withA);
    process.env.OTP_HASH_SECRET = SECRET;
    vi.resetModules();
    otp = await import("@/lib/otp");
  });

  it("refuses to hash without a strong secret", async () => {
    process.env.OTP_HASH_SECRET = "short";
    vi.resetModules();
    const weak = await import("@/lib/otp");
    expect(() => weak.hashOtp(user, "email_verification", "123456")).toThrow(
      /OTP_HASH_SECRET/,
    );
    process.env.OTP_HASH_SECRET = SECRET;
    vi.resetModules();
    otp = await import("@/lib/otp");
  });
});

describe("hashesEqual", () => {
  it("is true only for identical digests", () => {
    const a = "ab".repeat(32);
    expect(otp.hashesEqual(a, a)).toBe(true);
    expect(otp.hashesEqual(a, "cd".repeat(32))).toBe(false);
  });

  it("is false for different lengths, empty input or non-hex input", () => {
    const a = "ab".repeat(32);
    expect(otp.hashesEqual(a, "ab".repeat(31))).toBe(false);
    expect(otp.hashesEqual("", "")).toBe(false);
    expect(otp.hashesEqual("zz", "zz")).toBe(false);
  });
});
