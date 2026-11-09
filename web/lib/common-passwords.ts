/**
 * Small denylist of very common passwords (D-015: "reject very common passwords if feasible").
 * Only entries of 8+ characters matter because shorter passwords are already rejected by length.
 * Supabase's leaked-password protection (HaveIBeenPwned) is a separate, broader dashboard setting.
 */
const COMMON = new Set([
  "password",
  "password1",
  "password12",
  "password123",
  "passw0rd",
  "p@ssw0rd",
  "12345678",
  "123456789",
  "1234567890",
  "11111111",
  "00000000",
  "88888888",
  "87654321",
  "qwertyui",
  "qwerty123",
  "qwertyuiop",
  "abc12345",
  "abcd1234",
  "abcdefgh",
  "iloveyou",
  "letmein1",
  "welcome1",
  "welcome123",
  "admin123",
  "administrator",
  "changeme",
  "monkey123",
  "dragon123",
  "football",
  "baseball",
  "superman",
  "trustno1",
  "sunshine",
  "princess",
  "whatever",
  "jnu12345",
  "jagannath",
  "jagannath123",
  "bangladesh",
  "bangladesh123",
]);

export function isCommonPassword(password: string): boolean {
  return COMMON.has(password.toLowerCase());
}
