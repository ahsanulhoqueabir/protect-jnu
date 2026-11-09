import type { ReactNode, InputHTMLAttributes } from "react";

/** Shared look for the admin auth pages. Primary colour #1F3A5F (D-053); restyle here only. */
export function AuthCard({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
}) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4 dark:bg-black">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <p className="mb-2 text-xs font-semibold uppercase tracking-widest text-[#1F3A5F] dark:text-zinc-300">
            Protect JnU&apos;ins · Admin
          </p>
          <h1 className="text-2xl font-semibold tracking-tight text-zinc-900 dark:text-white">
            {title}
          </h1>
          {subtitle && (
            <p className="mt-1.5 text-sm text-zinc-500 dark:text-zinc-400">
              {subtitle}
            </p>
          )}
        </div>
        {children}
      </div>
    </div>
  );
}

export function Field({
  label,
  id,
  ...props
}: { label: string; id: string } & InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div>
      <label
        htmlFor={id}
        className="mb-1.5 block text-sm font-medium text-zinc-700 dark:text-zinc-300"
      >
        {label}
      </label>
      <input
        id={id}
        {...props}
        className="block w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 placeholder-zinc-400 outline-none transition-colors focus:border-[#1F3A5F] focus:ring-2 focus:ring-[#1F3A5F]/20 dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
      />
    </div>
  );
}

export function ErrorNote({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <p
      role="alert"
      className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600 dark:bg-red-950/40 dark:text-red-400"
    >
      {message}
    </p>
  );
}

export function InfoNote({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <p className="rounded-lg bg-blue-50 px-3 py-2 text-sm text-[#1F3A5F] dark:bg-blue-950/40 dark:text-blue-200">
      {message}
    </p>
  );
}

export const primaryButton =
  "w-full rounded-lg bg-[#1F3A5F] px-4 py-2.5 text-sm font-medium text-white transition-opacity hover:opacity-90 disabled:opacity-60";

/** Reads `{ error, code, data }` from our API envelope without throwing. */
export async function readEnvelope(res: Response): Promise<{
  success: boolean;
  error?: string;
  code?: string;
  data?: Record<string, unknown>;
}> {
  try {
    return await res.json();
  } catch {
    return { success: false, error: "Unexpected response from the server." };
  }
}
