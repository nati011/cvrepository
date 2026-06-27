"use client";

import { useRouter } from "next/navigation";

export function ProfileActions() {
  const router = useRouter();

  function logout() {
    if (typeof window !== "undefined") {
      if (!window.confirm("Log out of the CV Repository?")) return;
      try {
        window.localStorage.clear();
      } catch {
        // ignore storage errors
      }
      router.push("/");
      router.refresh();
    }
  }

  return (
    <div className="flex flex-wrap gap-3">
      <button
        type="button"
        onClick={logout}
        className="inline-flex items-center gap-1.5 rounded-lg border border-rose-200 bg-white px-4 py-2 text-[13px] font-semibold text-rose-600 hover:bg-rose-50"
      >
        <LogoutIcon className="h-4 w-4" />
        Log out
      </button>
    </div>
  );
}

function LogoutIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"
      />
    </svg>
  );
}
