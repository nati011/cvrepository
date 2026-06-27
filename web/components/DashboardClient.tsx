"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
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
import { normalizePipelineStats, type CVListResponse, type PipelineStats } from "@/lib/types";

function StatCard({
  label,
  value,
  hint,
  href,
  linkLabel = "View entries",
  Icon,
}: {
  label: string;
  value: string;
  hint?: string;
  href?: string;
  linkLabel?: string;
  Icon?: ({ className }: { className?: string }) => React.ReactNode;
}) {
  return (
    <div className="rounded-xl border border-slate-200/90 bg-white p-5 shadow-card transition-shadow hover:shadow-md">
      <div className="flex items-start justify-between gap-3">
        <p className="text-[13px] font-medium text-slate-500">
          {label}
        </p>
        {Icon && (
          <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-brand-primary/10 text-brand-primary">
            <Icon className="h-4 w-4" />
          </span>
        )}
      </div>
      <p className="mt-3 text-2xl font-semibold tabular-nums tracking-tight text-brand-primary">
        {value}
      </p>
      {hint && <p className="mt-1 text-[11px] text-slate-500">{hint}</p>}
      {href && (
        <Link
          href={href}
          className="mt-3 inline-flex items-center gap-1 text-[11px] font-semibold text-brand-secondary hover:text-brand-secondary/80"
        >
          {linkLabel} →
        </Link>
      )}
    </div>
  );
}

function IconLibrary({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
    </svg>
  );
}

function IconSearchReady({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
  );
}

function IconPipeline({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
  );
}

function IconStorage({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path strokeLinecap="round" strokeLinejoin="round" d="M5.25 14.25h13.5m-13.5 0a3 3 0 01-3-3V7.5a3 3 0 013-3h13.5a3 3 0 013 3v3.75a3 3 0 01-3 3m-16.5 0v2.25A2.25 2.25 0 005.25 18.75h13.5a2.25 2.25 0 002.25-2.25V14.25" />
    </svg>
  );
}

function IconCampaign({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5M9 11.25v.008M15 11.25v.008"
      />
    </svg>
  );
}

function IconJobs({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M20.25 14.15v4.075c0 1.313-.875 2.475-2.163 2.638-2.005.254-4.05.387-6.087.387-2.037 0-4.082-.133-6.087-.387C4.625 20.7 3.75 19.538 3.75 18.225V14.15M20.25 14.15c.41-.211.71-.59.806-1.057L21.75 8.4M20.25 14.15a2.25 2.25 0 01-.806.243 41.34 41.34 0 01-7.444.657 41.34 41.34 0 01-7.444-.657 2.25 2.25 0 01-.806-.243M3.75 14.15c-.41-.211-.71-.59-.806-1.057L2.25 8.4m0 0a2.25 2.25 0 01.806-1.302 41.34 41.34 0 0118.888 0 2.25 2.25 0 01.806 1.302m-19.5 0h19.5M15 11.25v.008M9 11.25v.008M12 3.75V6m-3.75 0h7.5a1.5 1.5 0 011.5 1.5"
      />
    </svg>
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
    <div className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card">
      <h2 className="text-sm font-semibold text-brand-primary">{title}</h2>
      {subtitle && <p className="mt-1 text-[11px] text-slate-500">{subtitle}</p>}
      <div className="mt-4 h-[260px] w-full">{children}</div>
    </div>
  );
}

export function DashboardClient() {
  const [model, setModel] = useState<DashboardModel | null>(null);
  const [jobCount, setJobCount] = useState<number | null>(null);
  const [campaignCount, setCampaignCount] = useState<number | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const [cRes, pRes] = await Promise.all([
        fetch(`/api/cvs?limit=${FETCH_LIMIT}&offset=0`, { cache: "no-store" }),
        fetch("/api/pipeline", { cache: "no-store" }),
      ]);
      const j = (await cRes.json()) as CVListResponse & { error?: string };
      if (!cRes.ok) {
        setErr(j.error ?? `Failed to load (${cRes.status})`);
        setModel(null);
        return;
      }
      setModel(buildDashboardModel(j));
      if (pRes.ok) {
        const p = normalizePipelineStats((await pRes.json()) as PipelineStats);
        setJobCount(p.jobs);
        setCampaignCount(p.campaigns);
      }
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

  if (loading) {
    return (
      <div className="flex min-h-[240px] items-center justify-center rounded-xl border border-dashed border-slate-200 bg-slate-50/50 text-sm text-slate-500">
        Loading dashboard…
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

  if (!model) return null;

  const { response, status, pipeline, storageBytes, storagePartial, uploadsSeries, recent } = model;
  const total = response.total;
  const loaded = response.items.length;
  const indexedPct =
    total === 0 ? null : Math.round((status.ready / total) * 1000) / 10;

  return (
    <div className="flex flex-col gap-10">
      <section className="overflow-hidden rounded-2xl border border-slate-200/90 bg-gradient-to-r from-brand-primary to-brand-primary/85 p-6 text-white shadow-card sm:p-8">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="text-xs font-medium text-white/70">Welcome back</p>
            <h2 className="font-display mt-1 text-xl font-semibold tracking-tight sm:text-2xl">
              CV Repository overview
            </h2>
            <p className="mt-2 max-w-xl text-[13px] text-white/75">
              Live snapshot of ingest trends, parsing pipeline, search readiness, and storage across your
              résumé library.
            </p>
          </div>
          <div className="flex gap-2">
            <Link href="/cvs/upload" className="btn-cta-primary px-3.5 py-2 text-[13px]">
              Upload CVs
            </Link>
            <Link href="/jobs" className="btn-cta-on-brand px-3.5 py-2 text-[13px]">
              Manage jobs
            </Link>
            <Link href="/campaigns" className="btn-cta-on-brand px-3.5 py-2 text-[13px]">
              Manage campaigns
            </Link>
          </div>
        </div>
      </section>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <StatCard
          label="CVs in library"
          value={String(total)}
          Icon={IconLibrary}
          href="/cvs"
          linkLabel="Open library"
          hint={
            loaded < total
              ? `Showing latest ${loaded} for charts & storage sum`
              : "PDF résumés on record"
          }
        />
        <StatCard
          label="Search-ready"
          value={String(status.ready)}
          Icon={IconSearchReady}
          href="/search"
          linkLabel="Search CVs"
          hint={
            indexedPct != null
              ? `${indexedPct}% of library indexed (Meilisearch)`
              : "Indexed for keyword search"
          }
        />
        <StatCard
          label="Jobs"
          value={jobCount == null ? "—" : String(jobCount)}
          Icon={IconJobs}
          href="/jobs"
          linkLabel="Manage jobs"
          hint="Reusable role definitions"
        />
        <StatCard
          label="Campaigns"
          value={campaignCount == null ? "—" : String(campaignCount)}
          Icon={IconCampaign}
          href="/campaigns"
          linkLabel="Manage campaigns"
          hint="Active hiring initiatives"
        />
        <StatCard
          label="Pipeline"
          value={String(pipeline)}
          Icon={IconPipeline}
          href="/pipeline"
          linkLabel="View pipeline"
          hint="Extraction, profiling & ranking in progress"
        />
        <StatCard
          label="Storage (PDFs)"
          value={formatBytes(storageBytes)}
          Icon={IconStorage}
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
                <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
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
                <Bar dataKey="uploads" fill="#EB7D23" radius={[4, 4, 0, 0]} name="Uploads" />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>

        <div className="flex flex-col justify-between rounded-xl border border-slate-200/90 bg-gradient-to-br from-brand-primary to-brand-primary/80 p-6 text-white shadow-card lg:col-span-2">
          <div>
            <h2 className="text-sm font-semibold">Quick actions</h2>
            <p className="mt-2 text-[11px] text-white/75">
              Upload new PDFs, search résumé text, or watch documents move through the pipeline.
            </p>
          </div>
          <div className="mt-6 flex flex-col gap-2">
            <Link href="/jobs" className="btn-cta-primary px-4 py-2.5 text-center text-sm">
              Manage jobs
            </Link>
            <Link href="/cvs/upload" className="btn-cta-on-brand px-4 py-2.5 text-center text-sm">
              Upload CVs
            </Link>
            <Link href="/pipeline" className="btn-cta-on-brand px-4 py-2.5 text-center text-sm">
              View data pipeline
            </Link>
            <Link href="/search" className="btn-cta-on-brand px-4 py-2.5 text-center text-sm">
              Search CVs
            </Link>
          </div>
        </div>
      </div>

      <div className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card">
        <div className="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 className="text-sm font-semibold text-brand-primary">Recent CVs</h2>
            <p className="text-[11px] text-slate-500">Latest uploads by ingest time</p>
          </div>
          <Link href="/cvs" className="text-sm font-medium text-brand-secondary hover:text-brand-secondary/80">
            View all →
          </Link>
        </div>
        {recent.length === 0 ? (
          <p className="mt-6 text-sm text-slate-500">
            No CVs yet.{" "}
            <Link href="/cvs" className="font-medium text-brand-secondary">
              Upload a PDF
            </Link>{" "}
            to see it here.
          </p>
        ) : (
          <ul className="mt-4 divide-y divide-slate-100">
            {recent.map((cv) => (
              <li
                key={cv.id}
                className="flex flex-col gap-2 py-3 first:pt-0 sm:flex-row sm:items-center sm:justify-between"
              >
                <div className="min-w-0">
                  <Link
                    href={`/cvs/${cv.id}`}
                    className="font-medium text-brand-primary hover:text-brand-primary/80"
                  >
                    {cv.title || cv.original_filename}
                  </Link>
                  <p className="truncate text-xs text-slate-500">
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
