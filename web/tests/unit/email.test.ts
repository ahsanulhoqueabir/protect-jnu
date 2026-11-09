import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { renderOtpEmail } from "@/lib/email/otp-email";

describe("renderOtpEmail (approved design, D-049)", () => {
  const base = { name: "Ayesha", code: "482913", ttlMinutes: 10 };

  it("verification email contains the code, heading and expiry", () => {
    const { subject, html } = renderOtpEmail({ ...base, purpose: "email_verification" });
    expect(html).toContain("482913");
    expect(html).toContain("Verify your university email");
    expect(html).toContain("<strong>10 minutes</strong>");
    expect(html).toContain("Hi Ayesha");
    expect(html).toContain("Never share this code");
    expect(subject).toBe("Your Protect JnU'ins verification code");
  });

  it("reset email has its own heading and subject", () => {
    const { subject, html } = renderOtpEmail({ ...base, purpose: "password_reset" });
    expect(html).toContain("Reset your password");
    expect(html).toContain("Ignore this email and your password stays the same");
    expect(subject).toBe("Reset your Protect JnU'ins password");
  });

  it("never puts the code in the subject line", () => {
    for (const purpose of ["email_verification", "password_reset"] as const) {
      expect(renderOtpEmail({ ...base, purpose }).subject).not.toContain("482913");
    }
  });

  it("escapes the recipient name so it cannot inject markup", () => {
    const { html } = renderOtpEmail({
      ...base,
      purpose: "email_verification",
      name: `<script>alert("x")</script> & 'q'`,
    });
    expect(html).not.toContain("<script>");
    expect(html).toContain("&lt;script&gt;");
    expect(html).toContain("&amp;");
    expect(html).toContain("&#39;q&#39;");
  });

  it("falls back to a neutral greeting for an empty name", () => {
    const { html } = renderOtpEmail({ ...base, purpose: "email_verification", name: "   " });
    expect(html).toContain("Hi there");
  });

  it("refuses anything that is not a 6-digit code", () => {
    for (const code of ["12345", "1234567", "12345a", "<b>1234", ""]) {
      expect(() =>
        renderOtpEmail({ ...base, purpose: "email_verification", code }),
      ).toThrow();
    }
  });

  it("uses inline styles and no remote images or scripts", () => {
    const { html } = renderOtpEmail({ ...base, purpose: "email_verification" });
    expect(html).not.toMatch(/<img/i);
    expect(html).not.toMatch(/<script/i);
    expect(html).not.toMatch(/<link/i);
    expect(html).toContain('style="');
  });
});

describe("EmailService.sendOtp (Brevo)", () => {
  const API_KEY = "xkeysib-test-key-0000000000000000";
  const params = {
    to: "ayesha@jnu.ac.bd",
    name: "Ayesha",
    purpose: "email_verification" as const,
    code: "482913",
    ttlMinutes: 10,
  };

  type Service = typeof import("@/services/email.service");
  let EmailService: Service["EmailService"];
  let fetchMock: ReturnType<typeof vi.fn>;
  let errorSpy: ReturnType<typeof vi.spyOn>;

  async function load(env: Record<string, string | undefined>) {
    for (const [k, v] of Object.entries(env)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
    vi.resetModules();
    EmailService = (await import("@/services/email.service")).EmailService;
  }

  beforeEach(async () => {
    fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
    errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    await load({
      BREVO_API_KEY: API_KEY,
      BREVO_SENDER_EMAIL: "no-reply@example.test",
      BREVO_SENDER_NAME: "Protect JnU",
    });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    errorSpy.mockRestore();
  });

  const loggedText = () => JSON.stringify(errorSpy.mock.calls);

  it("calls the verified endpoint with the api-key header and an HTML-only body", async () => {
    fetchMock.mockResolvedValue(new Response("{}", { status: 201 }));
    const result = await EmailService.sendOtp(params);

    expect(result.success).toBe(true);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe("https://api.brevo.com/v3/smtp/email");
    expect(init.method).toBe("POST");
    const headers = init.headers as Record<string, string>;
    expect(headers["api-key"]).toBe(API_KEY);
    expect(headers["content-type"]).toBe("application/json");

    const body = JSON.parse(init.body as string);
    expect(body.sender).toEqual({ name: "Protect JnU", email: "no-reply@example.test" });
    expect(body.to).toEqual([{ email: "ayesha@jnu.ac.bd" }]);
    expect(body.htmlContent).toContain("482913");
    expect(body).not.toHaveProperty("textContent"); // D-049: one body type per request
    expect(body.subject).not.toContain("482913");
  });

  it.each([400, 401, 403, 429, 500, 502])(
    "treats HTTP %i as not sent and does not leak the response",
    async (status) => {
      fetchMock.mockResolvedValue(
        new Response(JSON.stringify({ code: "secret_provider_detail" }), { status }),
      );
      const result = await EmailService.sendOtp(params);

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.code).toBe("email_delivery_failed");
        expect(result.error).not.toContain("secret_provider_detail");
      }
      const logs = loggedText();
      expect(logs).not.toContain("secret_provider_detail");
      expect(logs).not.toContain("482913");
      expect(logs).not.toContain(API_KEY);
    },
  );

  it("treats a 200 or 202 as not sent (only 201 is documented success)", async () => {
    for (const status of [200, 202]) {
      fetchMock.mockResolvedValue(new Response("{}", { status }));
      expect((await EmailService.sendOtp(params)).success).toBe(false);
    }
  });

  it("treats a network error or timeout as not sent", async () => {
    fetchMock.mockRejectedValue(new TypeError("fetch failed: " + API_KEY));
    const result = await EmailService.sendOtp(params);
    expect(result.success).toBe(false);
    const logs = loggedText();
    expect(logs).not.toContain(API_KEY);
    expect(logs).not.toContain("482913");
  });

  it("fails without calling Brevo when it is not configured", async () => {
    await load({ BREVO_API_KEY: "", BREVO_SENDER_EMAIL: "", BREVO_SENDER_NAME: "" });
    const result = await EmailService.sendOtp(params);
    expect(result.success).toBe(false);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
