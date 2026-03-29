"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useState } from "react";
import type { SearchResponse } from "@/lib/types";

function SearchResultsInner() {
  const searchParams = useSearchParams();
  const q = searchParams.get("q")?.trim() ?? "";

  const [res, setRes] = useState<SearchResponse | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const run = useCallback(async (query: string) => {
    setErr(null);
    setBusy(true);
    try {
      const params = new URLSearchParams({ q: query });
      const r = await fetch(`/api/search?${params}`, { cache: "no-store" });
      const j = (await r.json()) as SearchResponse & { error?: string };
      if (!r.ok) {
        setErr(j.error ?? `Search failed (${r.status})`);
        setRes(null);
        return;
      }
      setRes(j);
    } catch {
      setErr("Network error");
      setRes(null);
    } finally {
      setBusy(false);
    }
  }, []);

  useEffect(() => {
    if (!q) {
      setRes(null);
      setErr(null);
      return;
    }
    void run(q);
  }, [q, run]);

  if (!q) {
    return (
      <p className="rounded-xl border border-dashed border-slate-200 bg-slate-50/80 px-5 py-8 text-center text-sm text-slate-600 dark:border-slate-700 dark:bg-slate-900/40 dark:text-slate-400">
        Use the <strong className="font-medium text-slate-800 dark:text-slate-200">search bar</strong> at the
        top to query titles, filenames, and extracted CV text.
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      {busy && (
        <p className="text-sm text-slate-500 dark:text-slate-400">Searching…</p>
      )}

      {err && (
        <p className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-900/50 dark:bg-red-950/40 dark:text-red-200">
          {err}
        </p>
      )}

      {res && !busy && (
        <div className="overflow-hidden rounded-xl border border-slate-200/90 bg-white shadow-card dark:border-slate-800 dark:bg-slate-900">
          {res.hits.length === 0 ? (
            <p className="p-6 text-sm text-slate-500 dark:text-slate-400">
              No results for &ldquo;{res.query}&rdquo;.
            </p>
          ) : (
            <ul className="divide-y divide-slate-100 dark:divide-slate-800">
              {res.hits.map((h) => (
                <li
                  key={h.id}
                  className="px-6 py-4 transition hover:bg-slate-50/80 dark:hover:bg-slate-800/50"
                >
                  <Link
                    href={`/cvs/${h.id}`}
                    className="font-medium text-sky-700 hover:text-sky-600 dark:text-sky-400 dark:hover:text-sky-300"
                  >
                    {h.title || h.original_filename}
                  </Link>
                  <p className="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                    {h.original_filename}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}

export function SearchClient() {
  return (
    <Suspense
      fallback={
        <p className="text-sm text-slate-500 dark:text-slate-400">Loading search…</p>
      }
    >
      <SearchResultsInner />
    </Suspense>
  );
}
