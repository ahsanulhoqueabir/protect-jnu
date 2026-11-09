"use client";

import { useRouter } from "next/navigation";

export function LogoutButton() {
  const router = useRouter();
  async function logout() {
    try {
      await fetch("/api/admin/session", { method: "DELETE" });
    } finally {
      router.replace("/login");
      router.refresh();
    }
  }
  return (
    <button
      onClick={logout}
      className="rounded-md border border-white/40 px-3 py-1 hover:bg-white/10"
    >
      Sign out
    </button>
  );
}
