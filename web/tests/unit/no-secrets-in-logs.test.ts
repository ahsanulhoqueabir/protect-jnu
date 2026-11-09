import { readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

/**
 * Source scan for the rule "never log OTPs, reset tokens, hashes, API keys, passwords or raw
 * provider responses" (CLAUDE.md rule 8, PRD 7.4). It checks every `console.*` call in the
 * server code: no argument may mention a sensitive identifier. It is a guard, not a proof;
 * the runtime tests in email.test.ts check the real log output of the Brevo client.
 */
const ROOTS = ["services", "lib", "app/api"];
const SENSITIVE =
  /\b(code|codeHash|code_hash|stored_hash|hash|password|new_password|token|access_token|refresh_token|apiKey|api-key|secret|session|otp)\b/i;

function walk(dir: string): string[] {
  const out: string[] = [];
  for (const name of readdirSync(dir)) {
    const full = path.join(dir, name);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else if (/\.(ts|tsx)$/.test(name)) out.push(full);
  }
  return out;
}

/** Text of each console.* call, from `console.` to the matching close paren. */
function consoleCalls(source: string): string[] {
  const calls: string[] = [];
  const re = /console\.(log|info|warn|error|debug)\(/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(source))) {
    let depth = 1;
    let i = re.lastIndex;
    while (i < source.length && depth > 0) {
      if (source[i] === "(") depth++;
      else if (source[i] === ")") depth--;
      i++;
    }
    calls.push(source.slice(m.index, i));
  }
  return calls;
}

/** Property access like `error?.code` or `err.code` is the DB/auth error code, not an OTP. */
function withoutErrorCodeAccess(call: string): string {
  return call
    .replace(/\b\w+\??\.code\b/g, "ERRCODE")
    .replace(/"[^"]*"/g, '""'); // static message text is fine
}

describe("no secrets in logs", () => {
  const files = ROOTS.flatMap((r) => walk(path.join(process.cwd(), r)));

  it("finds the server source to scan", () => {
    expect(files.length).toBeGreaterThan(10);
  });

  it("no console call mentions a code, hash, password, token, key or session", () => {
    const offenders: string[] = [];
    for (const file of files) {
      const source = readFileSync(file, "utf8");
      for (const call of consoleCalls(source)) {
        if (SENSITIVE.test(withoutErrorCodeAccess(call))) {
          offenders.push(`${path.relative(process.cwd(), file)}: ${call.replace(/\s+/g, " ")}`);
        }
      }
    }
    expect(offenders).toEqual([]);
  });

  it("the scanner itself flags a leaking call (self-test)", () => {
    const leaky = `console.error("failed", { code, hash: codeHash })`;
    expect(SENSITIVE.test(withoutErrorCodeAccess(leaky))).toBe(true);
    const safe = `console.error("otp_issue failed", { dbCode: error?.code })`;
    expect(SENSITIVE.test(withoutErrorCodeAccess(safe))).toBe(false);
  });
});
