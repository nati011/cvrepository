"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  Legend,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { StatusBadge } from "@/components/StatusBadge";
import {
  FETCH_LIMIT,
  buildDashboardModel,
  formatBytes,
  type DashboardModel,
} from "@/lib/cvStats";
import type { CVListResponse } from "@/lib/types";

const PIE_COLORS = {
  ready: "#10b981",
  queue: "#0ea5e9",
  failed: "#f43f5e",
} as const;

function StatCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <div className="rounded-xl border border-slate-200/90 bg-white p-5 shadow-card dark:border-slate-800 dark:bg-slate-900">
      <p className="text-xs font-semibold uppercase tracking-widest text-slate-500 dark:text-slate-400">
        {label}
      </p>
      <p className="mt-2 text-2xl font-semibold tabular-nums tracking-tight text-slate-900 dark:text-white">
        {value}
      </p>
      {hint && <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">{hint}</p>}
    </div>
  );
}

function ChartCard({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card dark:border-slate-800 dark:bg-slate-900">
      <h2 className="text-sm font-semibold text-slate-900 dark:text-white">{title}</h2>
      {subtitle && <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">{subtitle}</p>}
      <div className="mt-4 h-[260px] w-full">{children}</div>
    </div>
  );
}

export function DashboardClient() {
  const [model, setModel] = useState<DashboardModel | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const res = await fetch(`/api/cvs?limit=${FETCH_LIMIT}&offset=0`, { cache: "no-store" });
      const j = (await res.json()) as CVListResponse & { error?: string };
      if (!res.ok) {
        setErr(j.error ?? `Failed to load (${res.status})`);
        setModel(null);
        return;
      }
      setModel(buildDashboardModel(j));
    } catch {
      setErr("Network error");
      setModel(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!model) return;
    const { status } = model;
    if (status.pending > 0 || status.processing > 0) {
      const t = setInterval(() => void load(), 4000);
      return () => clearInterval(t);
    }
  }, [model, load]);

  const pieData = useMemo(() => {
    if (!model) return [];
    const { status } = model;
    return [
      { name: "Search-ready", value: status.ready, color: PIE_COLORS.ready },
      { name: "In pipeline", value: status.pending + status.processing, color: PIE_COLORS.queue },
      { name: "Parse failed", value: status.failed, color: PIE_COLORS.failed },
    ].filter((d) => d.value > 0);
  }, [model]);

  if (loading) {
    return (
      <div className="flex min-h-[240px] items-center justify-center rounded-xl border border-dashed border-slate-200 bg-slate-50/50 text-sm text-slate-500 dark:border-slate-800 dark:bg-slate-900/30 dark:text-slate-400">
        Loading dashboard…
      </div>
    );
  }

  if (err) {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-4 text-sm text-red-800 dark:border-red-900/50 dark:bg-red-950/30 dark:text-red-200">
        {err}
        <button type="button" onClick={() => void load()} className="ml-2 font-medium underline">
          Retry
        </button>
      </div>
    );
  }

  if (!model) return null;

  const { response, status, pipeline, storageBytes, storagePartial, parseRate, uploadsSeries, recent } =
    model;
  const total = response.total;
  const loaded = response.items.length;
  const indexedPct =
    total === 0 ? null : Math.round((status.ready / total) * 1000) / 10;

  return (
    <div className="flex flex-col gap-10">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="CVs in library"
          value={String(total)}
          hint={
            loaded < total
              ? `Showing latest ${loaded} for charts & storage sum`
              : "PDF résumés on record"
          }
        />
        <StatCard
          label="Search-ready"
          value={String(status.ready)}
          hint={
            indexedPct != null
              ? `${indexedPct}% of library indexed (Meilisearch)`
              : "Indexed for keyword search"
          }
        />
        <StatCard
          label="Pipeline"
          value={String(pipeline)}
          hint="Tika parse pending or in progress"
        />
        <StatCard
          label="Storage (PDFs)"
          value={formatBytes(storageBytes)}
          hint={storagePartial ? `Sum of ${loaded} most recent rows` : "Total uploaded bytes"}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-5">
        <div className="lg:col-span-3">
          <ChartCard
            title="Uploads (14 days)"
            subtitle="New CVs added per day (local date)"
          >
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={uploadsSeries} margin={{ top: 8, right: 8, left: -8, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" className="dark:stroke-slate-700" />
                <XAxis dataKey="label" tick={{ fontSize: 11 }} stroke="#64748b" interval="preserveStartEnd" />
                <YAxis allowDecimals={false} tick={{ fontSize: 11 }} stroke="#64748b" width={32} />
                <Tooltip
                  contentStyle={{
                    borderRadius: "8px",
                    border: "1px solid rgb(226 232 240)",
                    fontSize: "12px",
                  }}
                  labelFormatter={(_, payload) => {
                    const p = payload?.[0]?.payload as { key?: string } | undefined;
                    return p?.key ?? "";
                  }}
                />
                <Bar dataKey="uploads" fill="#0ea5e9" radius={[4, 4, 0, 0]} name="Uploads" />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>

        <div className="lg:col-span-2">
          <ChartCard title="Pipeline health" subtitle="How CVs are distributed today">
            {pieData.length === 0 ? (
              <p className="flex h-full items-center justify-center text-sm text-slate-500 dark:text-slate-400">
                No documents yet.
              </p>
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={pieData}
                    dataKey="value"
                    nameKey="name"
                    cx="50%"
                    cy="42%"
                    innerRadius={52}
                    outerRadius={80}
                    paddingAngle={2}
                  >
                    {pieData.map((entry) => (
                      <Cell key={entry.name} fill={entry.color} stroke="transparent" />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend verticalAlign="bottom" wrapperStyle={{ fontSize: "12px" }} />
                </PieChart>
              </ResponsiveContainer>
            )}
          </ChartCard>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card dark:border-slate-800 dark:bg-slate-900 lg:col-span-2">
          <h2 className="text-sm font-semibold text-slate-900 dark:text-white">Parse quality</h2>
          <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">
            Among finished jobs (ready + failed), share that extracted text successfully for search.
          </p>
          <div className="mt-6 flex flex-wrap items-end gap-6">
            <div>
              <p className="text-4xl font-semibold tabular-nums text-slate-900 dark:text-white">
                {parseRate == null ? "—" : `${parseRate}%`}
              </p>
              <p className="mt-1 text-xs text-slate-500 dark:text-slate-400">Parse success rate</p>
            </div>
            <div className="flex flex-wrap gap-4 text-sm">
              <div>
                <span className="text-slate-500 dark:text-slate-400">Ready </span>
                <span className="font-semibold text-emerald-600 dark:text-emerald-400">{status.ready}</span>
              </div>
              <div>
                <span className="text-slate-500 dark:text-slate-400">Failed </span>
                <span className="font-semibold text-rose-600 dark:text-rose-400">{status.failed}</span>
              </div>
              <div>
                <span className="text-slate-500 dark:text-slate-400">Queued / running </span>
                <span className="font-semibold text-sky-600 dark:text-sky-400">{pipeline}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="flex flex-col justify-between rounded-xl border border-slate-200/90 bg-gradient-to-br from-slate-900 to-slate-800 p-6 text-white shadow-card dark:border-slate-700">
          <div>
            <h2 className="text-sm font-semibold">Quick actions</h2>
            <p className="mt-2 text-xs text-slate-300">
              Upload new PDFs or search across extracted résumé text.
            </p>
          </div>
          <div className="mt-6 flex flex-col gap-2">
            <Link
              href="/cvs"
              className="rounded-lg bg-white px-4 py-2.5 text-center text-sm font-semibold text-slate-900 hover:bg-slate-100"
            >
              Open library
            </Link>
            <Link
              href="/search"
              className="rounded-lg border border-slate-600 px-4 py-2.5 text-center text-sm font-medium text-white hover:bg-slate-800"
            >
              Search CVs
            </Link>
          </div>
        </div>
      </div>

      <div className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card dark:border-slate-800 dark:bg-slate-900">
        <div className="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 className="text-sm font-semibold text-slate-900 dark:text-white">Recent CVs</h2>
            <p className="text-xs text-slate-500 dark:text-slate-400">Latest uploads by ingest time</p>
          </div>
          <Link href="/cvs" className="text-sm font-medium text-sky-600 hover:text-sky-500 dark:text-sky-400">
            View all →
          </Link>
        </div>
        {recent.length === 0 ? (
          <p className="mt-6 text-sm text-slate-500 dark:text-slate-400">
            No CVs yet.{" "}
            <Link href="/cvs" className="font-medium text-sky-600 dark:text-sky-400">
              Upload a PDF
            </Link>{" "}
            to see it here.
          </p>
        ) : (
          <ul className="mt-4 divide-y divide-slate-100 dark:divide-slate-800">
            {recent.map((cv) => (
              <li
                key={cv.id}
                className="flex flex-col gap-2 py-3 first:pt-0 sm:flex-row sm:items-center sm:justify-between"
              >
                <div className="min-w-0">
                  <Link
                    href={`/cvs/${cv.id}`}
                    className="font-medium text-sky-700 hover:text-sky-600 dark:text-sky-400 dark:hover:text-sky-300"
                  >
                    {cv.title || cv.original_filename}
                  </Link>
                  <p className="truncate text-xs text-slate-500 dark:text-slate-400">
                    {cv.original_filename} · {formatBytes(cv.size_bytes)}
                  </p>
                </div>
                <div className="flex shrink-0 items-center gap-3">
                  <StatusBadge status={cv.status} />
                  <span className="text-xs text-slate-400 tabular-nums">
                    {new Date(cv.created_at).toLocaleString()}
                  </span>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
