"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { formatBytes } from "@/lib/cvStats";
import type { CV, CVListResponse } from "@/lib/types";
import { StatusBadge } from "./StatusBadge";

const PAGE_SIZE = 10;

const ROW_GRID =
  "grid grid-cols-1 gap-3 border-b border-slate-100 px-4 py-4 last:border-b-0 md:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)_minmax(0,5rem)_auto] md:items-center md:gap-4 md:px-5";

function needsPoll(items: CV[]) {
  return items.some((c) => c.status === "pending" || c.status === "processing");
}

function formatCvDate(iso: string) {
  return new Date(iso).toLocaleString();
}

export function CVTable({ reloadKey = 0 }: { reloadKey?: number }) {
  const [page, setPage] = useState(0);
  const [data, setData] = useState<CVListResponse | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [fetching, setFetching] = useState(true);

  const load = useCallback(async () => {
    setFetching(true);
    const offset = page * PAGE_SIZE;
    try {
      const res = await fetch(
        `/api/cvs?limit=${PAGE_SIZE}&offset=${offset}`,
        { cache: "no-store" },
      );
      const j = (await res.json()) as CVListResponse & { error?: string };
      if (!res.ok) {
        setErr(j.error ?? `Failed to load (${res.status})`);
        return;
      }
      if (j.total > 0 && j.items.length === 0 && offset >= j.total) {
        setPage(Math.max(0, Math.ceil(j.total / PAGE_SIZE) - 1));
        return;
      }
      setErr(null);
      setData(j);
    } catch {
      setErr("Network error");
    } finally {
      setFetching(false);
    }
  }, [page]);

  useEffect(() => {
    void load();
  }, [load, reloadKey]);

  useEffect(() => {
    if (data === null) return;
    const maxPage = Math.max(0, Math.ceil(data.total / PAGE_SIZE) - 1);
    if (page > maxPage) setPage(maxPage);
  }, [data, page]);

  useEffect(() => {
    if (!data || !needsPoll(data.items)) return;
    const t = setInterval(() => void load(), 2500);
    return () => clearInterval(t);
  }, [data, load]);

  if (err) {
    return (
      <p className="text-sm text-red-600">
        {err}
        <button type="button" onClick={() => void load()} className="ml-2 font-medium underline">
          Retry
        </button>
      </p>
    );
  }

  if (!data) {
    return <p className="text-sm text-slate-500">Loading…</p>;
  }

  if (data.total === 0) {
    return (
      <p className="rounded-lg border border-dashed border-slate-200 bg-slate-50/50 px-4 py-8 text-center text-sm text-slate-500">
        No CVs yet.{" "}
        <Link href="/cvs/upload" className="font-medium text-brand-secondary hover:text-brand-secondary/80">
          Upload PDFs
        </Link>{" "}
        to add documents.
      </p>
    );
  }

  const totalPages = Math.max(1, Math.ceil(data.total / PAGE_SIZE));
  const from = data.items.length ? page * PAGE_SIZE + 1 : 0;
  const to = page * PAGE_SIZE + data.items.length;

  return (
    <div
      className={`overflow-hidden rounded-lg border border-slate-200 transition-opacity ${
        fetching ? "opacity-70" : "opacity-100"
      }`}
    >
      <div className="hidden border-b border-slate-200 bg-slate-50/90 px-5 py-2.5 text-xs font-semibold uppercase tracking-wide text-slate-500 md:grid md:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)_minmax(0,5rem)_auto] md:gap-4">
        <div>Document</div>
        <div>Uploaded</div>
        <div>Updated</div>
        <div>Size</div>
        <div className="text-right">Status</div>
      </div>

      <ul className="divide-y divide-slate-100 bg-white" role="list">
        {data.items.map((c) => (
          <li key={c.id} className={ROW_GRID}>
            <div className="min-w-0 md:col-span-1">
              <Link
                href={`/cvs/${c.id}`}
                className="font-medium text-brand-primary hover:text-brand-primary/80"
              >
                {c.title || c.original_filename}
              </Link>
              <p className="mt-0.5 truncate text-xs text-slate-500">
                {c.original_filename}
              </p>
            </div>
            <div>
              <p className="text-[11px] font-medium uppercase tracking-wide text-slate-400 md:hidden">
                Uploaded
              </p>
              <p className="text-sm tabular-nums text-slate-700">
                {formatCvDate(c.created_at)}
              </p>
            </div>
            <div>
              <p className="text-[11px] font-medium uppercase tracking-wide text-slate-400 md:hidden">
                Updated
              </p>
              <p className="text-sm tabular-nums text-slate-600">
                {formatCvDate(c.updated_at)}
              </p>
            </div>
            <div>
              <p className="text-[11px] font-medium uppercase tracking-wide text-slate-400 md:hidden">
                Size
              </p>
              <p className="text-sm tabular-nums text-slate-600">
                {formatBytes(c.size_bytes)}
              </p>
            </div>
            <div className="flex flex-col gap-1 md:items-end">
              <p className="text-[11px] font-medium uppercase tracking-wide text-slate-400 md:hidden">
                Status
              </p>
              <StatusBadge status={c.status} />
            </div>
          </li>
        ))}
      </ul>

      <div className="flex flex-col gap-3 border-t border-slate-200 bg-slate-50/50 px-4 py-3 sm:flex-row sm:items-center sm:justify-between sm:px-5">
        <p className="text-xs text-slate-500">
          Showing{" "}
          <span className="font-medium tabular-nums text-slate-700">
            {from}–{to}
          </span>{" "}
          of{" "}
          <span className="font-medium tabular-nums text-slate-700">
            {data.total}
          </span>
          <span className="text-slate-400"> · Page </span>
          <span className="font-medium tabular-nums text-slate-700">
            {page + 1}
          </span>
          <span className="text-slate-400"> / {totalPages}</span>
        </p>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            disabled={page <= 0 || fetching}
            onClick={() => setPage((p) => Math.max(0, p - 1))}
            className="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40"
          >
            Previous
          </button>
          <button
            type="button"
            disabled={page >= totalPages - 1 || fetching}
            onClick={() => setPage((p) => p + 1)}
            className="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40"
          >
            Next
          </button>
        </div>
      </div>
    </div>
  );
}
