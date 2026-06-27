"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function DeleteCVButton({ id }: { id: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function onDelete() {
    if (!confirm("Delete this CV permanently?")) return;
    setBusy(true);
    try {
      const res = await fetch(`/api/cvs/${encodeURIComponent(id)}`, {
        method: "DELETE",
        cache: "no-store",
      });
      if (res.ok) {
        router.push("/cvs");
        router.refresh();
        return;
      }
      const j = await res.json().catch(() => ({}));
      alert(typeof j.error === "string" ? j.error : `Delete failed (${res.status})`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <button
      type="button"
      onClick={() => void onDelete()}
      disabled={busy}
      className="rounded-lg border border-red-200 bg-white px-4 py-2 text-sm font-medium text-red-700 shadow-sm transition hover:bg-red-50 disabled:opacity-50"
    >
      {busy ? "Deleting…" : "Delete"}
    </button>
  );
}
