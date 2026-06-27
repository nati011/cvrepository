"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { Job, JobsResponse } from "@/lib/types";

type SortKey = "title" | "created_at";
type SortDir = "asc" | "desc";

const PAGE_SIZES = [5, 10, 25, 50] as const;

export function JobsClient() {
  const [jobs, setJobs] = useState<Job[]>([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const [query, setQuery] = useState("");
  const [sortKey, setSortKey] = useState<SortKey>("created_at");
  const [sortDir, setSortDir] = useState<SortDir>("desc");
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState<number>(10);
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const loadJobs = useCallback(async () => {
    try {
      const res = await fetch("/api/jobs", { cache: "no-store" });
      const data = (await res.json()) as JobsResponse & { error?: string };
      if (!res.ok) {
        setErr(data.error ?? `Failed to load jobs (${res.status})`);
        return;
      }
      setJobs(data.items);
    } catch {
      setErr("Network error while loading jobs");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadJobs();
  }, [loadJobs]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return jobs;
    return jobs.filter(
      (j) => j.title.toLowerCase().includes(q) || j.jd_text.toLowerCase().includes(q),
    );
  }, [jobs, query]);

  const sorted = useMemo(() => {
    const arr = [...filtered];
    arr.sort((a, b) => {
      let cmp = 0;
      if (sortKey === "title") cmp = (a.title || "").localeCompare(b.title || "");
      else cmp = +new Date(a.created_at) - +new Date(b.created_at);
      return sortDir === "asc" ? cmp : -cmp;
    });
    return arr;
  }, [filtered, sortKey, sortDir]);

  const total = sorted.length;
  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  const safePage = Math.min(page, pageCount - 1);
  const pageItems = useMemo(
    () => sorted.slice(safePage * pageSize, safePage * pageSize + pageSize),
    [sorted, safePage, pageSize],
  );

  useEffect(() => {
    if (page > pageCount - 1) setPage(Math.max(0, pageCount - 1));
  }, [page, pageCount]);

  async function remove(job: Job) {
    if (
      typeof window !== "undefined" &&
      !window.confirm(`Delete “${job.title || "Untitled role"}”? This cannot be undone.`)
    ) {
      return;
    }
    setDeletingId(job.id);
    setErr(null);
    setMsg(null);
    try {
      const res = await fetch(`/api/jobs/${job.id}`, { method: "DELETE" });
      if (!res.ok) {
        const data = (await res.json()) as { error?: string };
        setErr(data.error ?? `Delete failed (${res.status})`);
        return;
      }
      setSelected((prev) => {
        const next = new Set(prev);
        next.delete(job.id);
        return next;
      });
      await loadJobs();
      setMsg("Job deleted.");
    } catch {
      setErr("Network error while deleting");
    } finally {
      setDeletingId(null);
    }
  }

  function toggleSort(key: SortKey) {
    if (sortKey === key) setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    else {
      setSortKey(key);
      setSortDir(key === "title" ? "asc" : "desc");
    }
    setPage(0);
  }

  const pageIds = pageItems.map((j) => j.id);
  const allOnPageSelected = pageIds.length > 0 && pageIds.every((id) => selected.has(id));
  const rangeStart = total === 0 ? 0 : safePage * pageSize + 1;
  const rangeEnd = Math.min(total, safePage * pageSize + pageSize);

  return (
    <div className="flex flex-col gap-4">
      {(msg || err) && (
        <div className="flex items-center gap-2 text-sm">
          {msg && <span className="text-emerald-600">{msg}</span>}
          {err && <span className="text-rose-600">{err}</span>}
        </div>
      )}

      <div className="rounded-xl border border-slate-200 bg-white shadow-card">
        <div className="flex flex-col gap-3 border-b border-slate-200 px-5 py-3 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-sm font-semibold text-brand-primary">Job definitions</h2>
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
            <input
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setPage(0);
              }}
              placeholder="Search jobs…"
              className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-[13px] outline-none focus:border-brand-secondary sm:w-56"
            />
            <Link
              href="/jobs/new"
              className="inline-flex shrink-0 items-center justify-center rounded-lg bg-brand-primary px-4 py-2 text-[13px] font-semibold text-white hover:bg-brand-primary/90"
            >
              New job
            </Link>
          </div>
        </div>

        {selected.size > 0 && (
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-200 bg-brand-secondary/5 px-5 py-2.5">
            <span className="text-[13px] font-medium text-brand-primary">{selected.size} selected</span>
            <button
              type="button"
              onClick={() => setSelected(new Set())}
              className="rounded-lg px-3 py-1.5 text-[13px] font-medium text-slate-600 hover:bg-white"
            >
              Clear
            </button>
          </div>
        )}

        {loading ? (
          <p className="px-5 py-6 text-sm text-slate-500">Loading jobs…</p>
        ) : jobs.length === 0 ? (
          <div className="px-5 py-10 text-center">
            <p className="text-sm text-slate-500">No job definitions yet.</p>
            <Link
              href="/jobs/new"
              className="mt-3 inline-block rounded-lg bg-brand-primary px-4 py-2 text-[13px] font-semibold text-white"
            >
              Create your first job
            </Link>
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-left text-[13px]">
                <thead>
                  <tr className="border-b border-slate-200 text-[11px] uppercase tracking-wide text-slate-500">
                    <th className="w-10 px-5 py-2.5">
                      <input
                        type="checkbox"
                        checked={allOnPageSelected}
                        onChange={() => {
                          setSelected((prev) => {
                            const next = new Set(prev);
                            if (allOnPageSelected) pageIds.forEach((id) => next.delete(id));
                            else pageIds.forEach((id) => next.add(id));
                            return next;
                          });
                        }}
                        className="h-4 w-4 rounded border-slate-300"
                      />
                    </th>
                    <th className="px-3 py-2.5 font-semibold">
                      <button type="button" onClick={() => toggleSort("title")} className="uppercase">
                        Title {sortKey === "title" ? (sortDir === "asc" ? "▲" : "▼") : ""}
                      </button>
                    </th>
                    <th className="px-3 py-2.5 font-semibold">
                      <button type="button" onClick={() => toggleSort("created_at")} className="uppercase">
                        Created {sortKey === "created_at" ? (sortDir === "asc" ? "▲" : "▼") : ""}
                      </button>
                    </th>
                    <th className="px-5 py-2.5 text-right font-semibold">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {pageItems.map((j) => (
                    <tr key={j.id} className="hover:bg-slate-50">
                      <td className="px-5 py-3">
                        <input
                          type="checkbox"
                          checked={selected.has(j.id)}
                          onChange={() => {
                            setSelected((prev) => {
                              const next = new Set(prev);
                              if (next.has(j.id)) next.delete(j.id);
                              else next.add(j.id);
                              return next;
                            });
                          }}
                          className="h-4 w-4 rounded border-slate-300"
                        />
                      </td>
                      <td className="px-3 py-3">
                        <Link href={`/jobs/${j.id}`} className="font-medium text-brand-primary hover:underline">
                          {j.title || "Untitled role"}
                        </Link>
                      </td>
                      <td className="whitespace-nowrap px-3 py-3 text-slate-500">
                        {new Date(j.created_at).toLocaleDateString()}
                      </td>
                      <td className="px-5 py-3">
                        <div className="flex justify-end gap-2">
                          <Link
                            href={`/jobs/${j.id}/edit`}
                            className="rounded-lg border border-slate-200 px-3 py-1.5 text-[13px] font-medium text-slate-700 hover:bg-slate-50"
                          >
                            Edit
                          </Link>
                          <button
                            type="button"
                            onClick={() => void remove(j)}
                            disabled={deletingId === j.id}
                            className="rounded-lg border border-rose-200 px-3 py-1.5 text-[13px] font-medium text-rose-700 hover:bg-rose-50 disabled:opacity-50"
                          >
                            {deletingId === j.id ? "…" : "Delete"}
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-200 px-5 py-3 text-[12px] text-slate-500">
              <span>
                Showing {rangeStart}–{rangeEnd} of {total}
              </span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  disabled={safePage === 0}
                  onClick={() => setPage((p) => p - 1)}
                  className="rounded border px-2 py-1 disabled:opacity-40"
                >
                  Prev
                </button>
                <span>
                  Page {safePage + 1} / {pageCount}
                </span>
                <button
                  type="button"
                  disabled={safePage >= pageCount - 1}
                  onClick={() => setPage((p) => p + 1)}
                  className="rounded border px-2 py-1 disabled:opacity-40"
                >
                  Next
                </button>
                <select
                  value={pageSize}
                  onChange={(e) => {
                    setPageSize(Number(e.target.value));
                    setPage(0);
                  }}
                  className="rounded border px-1 py-1"
                >
                  {PAGE_SIZES.map((n) => (
                    <option key={n} value={n}>
                      {n} rows
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
