"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import type { SearchResponse } from "@/lib/types";

const MIN_CHARS = 2;
const DEBOUNCE_MS = 300;

function IconSearch({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.5}
      aria-hidden
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
      />
    </svg>
  );
}

function TopSearchBarInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [query, setQuery] = useState("");
  const [hits, setHits] = useState<SearchResponse["hits"]>([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [focused, setFocused] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    setQuery(searchParams.get("q") ?? "");
  }, [searchParams]);

  useEffect(() => {
    abortRef.current?.abort();
    const q = query.trim();
    if (q.length < MIN_CHARS) {
      setHits([]);
      setErr(null);
      setLoading(false);
      return;
    }

    const timer = setTimeout(() => {
      const ac = new AbortController();
      abortRef.current = ac;
      setLoading(true);
      setErr(null);
      const params = new URLSearchParams({ q });
      fetch(`/api/search?${params}`, { cache: "no-store", signal: ac.signal })
        .then(async (r) => {
          const j = (await r.json()) as SearchResponse & { error?: string };
          if (ac.signal.aborted) return;
          if (!r.ok) {
            setErr(j.error ?? `Search failed (${r.status})`);
            setHits([]);
            return;
          }
          setHits(j.hits);
        })
        .catch((e: Error) => {
          if (e.name === "AbortError" || ac.signal.aborted) return;
          setErr("Network error");
          setHits([]);
        })
        .finally(() => {
          if (!ac.signal.aborted) setLoading(false);
        });
    }, DEBOUNCE_MS);

    return () => {
      clearTimeout(timer);
      abortRef.current?.abort();
    };
  }, [query]);

  useEffect(() => {
    function onDocMouseDown(e: MouseEvent) {
      if (!wrapRef.current?.contains(e.target as Node)) {
        setFocused(false);
      }
    }
    document.addEventListener("mousedown", onDocMouseDown);
    return () => document.removeEventListener("mousedown", onDocMouseDown);
  }, []);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") setFocused(false);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const showPanel = focused && query.trim().length >= MIN_CHARS;
  const qTrim = query.trim();

  const goFullSearch = useCallback(() => {
    setFocused(false);
    router.push(qTrim ? `/search?q=${encodeURIComponent(qTrim)}` : "/search");
  }, [qTrim, router]);

  return (
    <div ref={wrapRef} className="relative min-w-0 w-full max-w-md">
      <form
        role="search"
        className="relative"
        onSubmit={(e) => {
          e.preventDefault();
          goFullSearch();
        }}
      >
        <label htmlFor="top-search" className="sr-only">
          Search CVs
        </label>
        <IconSearch className="pointer-events-none absolute left-3 top-1/2 z-10 h-4 w-4 -translate-y-1/2 text-slate-400" />
        <input
          id="top-search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onFocus={() => setFocused(true)}
          placeholder="Search CVs (skills, titles, filenames…)"
          autoComplete="off"
          aria-controls="top-search-results"
          className="w-full rounded-lg border border-slate-200 bg-slate-50/90 py-2 pl-9 pr-3 text-sm text-slate-900 shadow-sm outline-none ring-brand-secondary/20 placeholder:text-slate-400 focus:border-brand-secondary focus:bg-white focus:ring-2"
        />
      </form>

      {showPanel && (
        <div
          id="top-search-results"
          role="listbox"
          className="absolute left-0 right-0 top-[calc(100%+6px)] z-50 max-h-80 overflow-y-auto rounded-lg border border-slate-200 bg-white py-1 shadow-lg"
        >
          {loading && (
            <p className="px-3 py-2.5 text-sm text-slate-500">Searching…</p>
          )}
          {!loading && err && (
            <p className="px-3 py-2.5 text-sm text-red-600">{err}</p>
          )}
          {!loading && !err && hits.length === 0 && (
            <p className="px-3 py-2.5 text-sm text-slate-500">
              No matches. Try other keywords or press Enter for the full search page.
            </p>
          )}
          {!loading &&
            !err &&
            hits.map((h) => (
              <Link
                key={h.id}
                href={`/cvs/${h.id}`}
                role="option"
                className="block px-3 py-2.5 text-sm hover:bg-slate-50"
                onClick={() => setFocused(false)}
              >
                <span className="font-medium text-brand-primary">
                  {h.title || h.original_filename}
                </span>
                <span className="mt-0.5 block truncate text-xs text-slate-500">
                  {h.original_filename}
                </span>
              </Link>
            ))}
          {!loading && !err && hits.length > 0 && (
            <button
              type="button"
              className="w-full border-t border-slate-100 px-3 py-2 text-left text-xs font-medium text-brand-secondary hover:bg-slate-50"
              onClick={() => goFullSearch()}
            >
              View all results on search page →
            </button>
          )}
        </div>
      )}
    </div>
  );
}

export function TopSearchBarFallback() {
  return (
    <div className="min-w-0 w-full max-w-md opacity-60">
      <div className="h-9 w-full rounded-lg bg-slate-100" />
    </div>
  );
}

export function TopSearchBar() {
  return (
    <Suspense fallback={<TopSearchBarFallback />}>
      <TopSearchBarInner />
    </Suspense>
  );
}
