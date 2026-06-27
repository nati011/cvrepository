"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import { StatusBadge } from "@/components/StatusBadge";
import { FETCH_LIMIT, buildDashboardModel, type DashboardModel } from "@/lib/cvStats";
import { normalizePipelineStats, type CVListResponse, type PipelineStats } from "@/lib/types";

const SEGMENT_COLORS = {
  pending: "#94a3b8",
  processing: "#EB7D23",
  done: "#10b981",
  failed: "#f43f5e",
} as const;

type Segment = { key: keyof typeof SEGMENT_COLORS; label: string; value: number };

function StackedBar({ segments }: { segments: Segment[] }) {
  const total = segments.reduce((s, x) => s + x.value, 0);
  return (
    <div className="mt-3 flex h-2 w-full overflow-hidden rounded-full bg-slate-100">
      {total === 0 ? null : (
        segments.map((s) =>
          s.value === 0 ? null : (
            <div
              key={s.key}
              style={{ width: `${(s.value / total) * 100}%`, backgroundColor: SEGMENT_COLORS[s.key] }}
              title={`${s.label}: ${s.value}`}
            />
          ),
        )
      )}
    </div>
  );
}

function Breakdown({ segments }: { segments: Segment[] }) {
  return (
    <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1.5">
      {segments.map((s) => (
        <span key={s.key} className="inline-flex items-center gap-1.5 text-[12px] text-slate-600">
          <span className="h-2 w-2 rounded-full" style={{ backgroundColor: SEGMENT_COLORS[s.key] }} />
          {s.label}
          <span className="font-semibold tabular-nums text-slate-900">{s.value}</span>
        </span>
      ))}
    </div>
  );
}

function StageCard({
  step,
  title,
  subtitle,
  headline,
  headlineLabel,
  segments,
  Icon,
}: {
  step: number;
  title: string;
  subtitle: string;
  headline: number;
  headlineLabel: string;
  segments: Segment[];
  Icon: ({ className }: { className?: string }) => React.ReactNode;
}) {
  return (
    <div className="relative rounded-xl border border-slate-200/90 bg-white p-5 shadow-card">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-brand-primary/10 text-brand-primary">
            <Icon className="h-4 w-4" />
          </span>
          <div>
            <p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400">Step {step}</p>
            <p className="text-sm font-semibold text-brand-primary">{title}</p>
          </div>
        </div>
      </div>
      <p className="mt-4 text-2xl font-semibold tabular-nums tracking-tight text-brand-primary">
        {headline.toLocaleString()}
        <span className="ml-1.5 text-[11px] font-medium text-slate-400">{headlineLabel}</span>
      </p>
      <p className="mt-0.5 text-[11px] text-slate-500">{subtitle}</p>
      <StackedBar segments={segments} />
      <Breakdown segments={segments} />
    </div>
  );
}

export function PipelineClient() {
  const [stats, setStats] = useState<PipelineStats | null>(null);
  const [model, setModel] = useState<DashboardModel | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const [pRes, cRes] = await Promise.all([
        fetch("/api/pipeline", { cache: "no-store" }),
        fetch(`/api/cvs?limit=${FETCH_LIMIT}&offset=0`, { cache: "no-store" }),
      ]);
      const pJson = (await pRes.json()) as PipelineStats & { error?: string };
      const cJson = (await cRes.json()) as CVListResponse & { error?: string };
      if (!pRes.ok) {
        setErr(pJson.error ?? `Failed to load pipeline (${pRes.status})`);
        return;
      }
      setStats(normalizePipelineStats(pJson));
      if (cRes.ok) setModel(buildDashboardModel(cJson));
    } catch {
      setErr("Network error while loading the pipeline");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const inFlight = useMemo(() => {
    if (!stats) return 0;
    return (
      stats.extraction.pending +
      stats.extraction.processing +
      stats.profile.pending +
      stats.profile.processing +
      stats.ranking.pending +
      stats.ranking.processing
    );
  }, [stats]);

  useEffect(() => {
    if (inFlight > 0) {
      const t = setInterval(() => void load(), 4000);
      return () => clearInterval(t);
    }
  }, [inFlight, load]);

  const pieData = useMemo(() => {
    if (!stats) return [];
    const e = stats.extraction;
    return [
      { name: "Search-ready", value: e.ready, color: "#02404F" },
      { name: "In pipeline", value: e.pending + e.processing, color: "#EB7D23" },
      { name: "Parse failed", value: e.failed, color: "#f43f5e" },
    ].filter((d) => d.value > 0);
  }, [stats]);

  const parseRate = useMemo(() => {
    if (!stats) return null;
    const done = stats.extraction.ready + stats.extraction.failed;
    if (done === 0) return null;
    return Math.round((stats.extraction.ready / done) * 1000) / 10;
  }, [stats]);

  if (loading) {
    return (
      <div className="flex min-h-[240px] items-center justify-center rounded-xl border border-dashed border-slate-200 bg-slate-50/50 text-sm text-slate-500">
        Loading pipeline…
      </div>
    );
  }

  if (err) {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-4 text-sm text-red-800">
        {err}
        <button type="button" onClick={() => void load()} className="ml-2 font-medium underline">
          Retry
        </button>
      </div>
    );
  }

  if (!stats) return null;

  return (
    <div className="flex flex-col gap-8">
      <div className="flex flex-wrap items-center gap-3 rounded-xl border border-slate-200/90 bg-white px-5 py-3 text-sm shadow-card">
        <span className="inline-flex items-center gap-2">
          <span className={`h-2.5 w-2.5 rounded-full ${inFlight > 0 ? "animate-pulse bg-brand-secondary" : "bg-emerald-500"}`} />
          <span className="font-medium text-brand-primary">
            {inFlight > 0 ? `${inFlight.toLocaleString()} item(s) processing` : "Pipeline idle — all caught up"}
          </span>
        </span>
        <span className="text-slate-400">·</span>
        <span className="text-slate-500">
          {stats.total_cvs.toLocaleString()} CVs · {stats.jobs.toLocaleString()} jobs ·{" "}
          {stats.campaigns.toLocaleString()} campaigns
        </span>
        <button
          type="button"
          onClick={() => void load()}
          className="ml-auto rounded-lg border border-slate-200 px-3 py-1.5 text-[13px] font-medium text-slate-600 hover:bg-slate-50"
        >
          Refresh
        </button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StageCard
          step={1}
          title="Ingestion"
          subtitle="PDFs uploaded into the repository"
          Icon={IconUpload}
          headline={stats.total_cvs}
          headlineLabel="ingested"
          segments={[
            { key: "pending", label: "Queued", value: stats.extraction.pending },
            { key: "processing", label: "Active", value: stats.extraction.processing },
            { key: "done", label: "Stored", value: stats.extraction.ready + stats.extraction.failed },
          ]}
        />
        <StageCard
          step={2}
          title="Text extraction"
          subtitle="Parsing résumé text for search & AI"
          Icon={IconText}
          headline={stats.extraction.ready}
          headlineLabel="extracted"
          segments={[
            { key: "pending", label: "Pending", value: stats.extraction.pending },
            { key: "processing", label: "Processing", value: stats.extraction.processing },
            { key: "done", label: "Ready", value: stats.extraction.ready },
            { key: "failed", label: "Failed", value: stats.extraction.failed },
          ]}
        />
        <StageCard
          step={3}
          title="Profile extraction"
          subtitle="AI structures skills & experience"
          Icon={IconProfile}
          headline={stats.profile.ready}
          headlineLabel="profiled"
          segments={[
            { key: "pending", label: "Pending", value: stats.profile.pending },
            { key: "processing", label: "Processing", value: stats.profile.processing },
            { key: "done", label: "Ready", value: stats.profile.ready },
            { key: "failed", label: "Failed", value: stats.profile.failed },
          ]}
        />
        <StageCard
          step={4}
          title="Ranking"
          subtitle="Scoring candidates against jobs"
          Icon={IconRank}
          headline={stats.ranking.done}
          headlineLabel="ranked"
          segments={[
            { key: "pending", label: "Pending", value: stats.ranking.pending },
            { key: "processing", label: "Processing", value: stats.ranking.processing },
            { key: "done", label: "Done", value: stats.ranking.done },
            { key: "failed", label: "Failed", value: stats.ranking.failed },
          ]}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card lg:col-span-2">
          <h2 className="text-sm font-semibold text-brand-primary">Parse quality</h2>
          <p className="mt-1 text-xs text-slate-500">
            Among finished extraction jobs (ready + failed), share that extracted text successfully for search.
          </p>
          <div className="mt-6 flex flex-wrap items-end gap-6">
            <div>
              <p className="text-3xl font-semibold tabular-nums text-brand-primary">
                {parseRate == null ? "—" : `${parseRate}%`}
              </p>
              <p className="mt-1 text-xs text-slate-500">Parse success rate</p>
            </div>
            <div className="flex flex-wrap gap-4 text-sm">
              <div>
                <span className="text-slate-500">Ready </span>
                <span className="font-semibold text-emerald-600">{stats.extraction.ready}</span>
              </div>
              <div>
                <span className="text-slate-500">Failed </span>
                <span className="font-semibold text-rose-600">{stats.extraction.failed}</span>
              </div>
              <div>
                <span className="text-slate-500">Queued / running </span>
                <span className="font-semibold text-brand-secondary">
                  {stats.extraction.pending + stats.extraction.processing}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card">
          <h2 className="text-sm font-semibold text-brand-primary">Pipeline health</h2>
          <p className="mt-1 text-[11px] text-slate-500">Extraction distribution today</p>
          <div className="mt-2 h-[200px] w-full">
            {pieData.length === 0 ? (
              <p className="flex h-full items-center justify-center text-sm text-slate-500">
                No documents yet.
              </p>
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={pieData} dataKey="value" nameKey="name" cx="50%" cy="45%" innerRadius={44} outerRadius={70} paddingAngle={2}>
                    {pieData.map((entry) => (
                      <Cell key={entry.name} fill={entry.color} stroke="transparent" />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend verticalAlign="bottom" wrapperStyle={{ fontSize: "11px" }} />
                </PieChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      </div>

      <div className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card">
        <div className="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 className="text-sm font-semibold text-brand-primary">Recent activity</h2>
            <p className="text-[11px] text-slate-500">Latest documents moving through the pipeline</p>
          </div>
          <Link href="/cvs" className="text-sm font-medium text-brand-secondary hover:text-brand-secondary/80">
            View all →
          </Link>
        </div>
        {!model || model.recent.length === 0 ? (
          <p className="mt-6 text-sm text-slate-500">No CVs yet.</p>
        ) : (
          <ul className="mt-4 divide-y divide-slate-100">
            {model.recent.map((cv) => (
              <li key={cv.id} className="flex flex-col gap-2 py-3 first:pt-0 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <Link
                    href={`/cvs/${cv.id}`}
                    className="font-medium text-brand-primary hover:text-brand-primary/80"
                  >
                    {cv.title || cv.original_filename}
                  </Link>
                  <p className="truncate text-xs text-slate-500">{cv.original_filename}</p>
                </div>
                <div className="flex shrink-0 items-center gap-3">
                  <StatusBadge status={cv.status} />
                  <span className="text-xs text-slate-400 tabular-nums">{new Date(cv.created_at).toLocaleString()}</span>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

function IconUpload({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
    </svg>
  );
}

function IconText({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
    </svg>
  );
}

function IconProfile({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
    </svg>
  );
}

function IconRank({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
    </svg>
  );
}
