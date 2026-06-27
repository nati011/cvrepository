"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import type { Job, RankStatus } from "@/lib/types";

export function JobDetailClient({ jobId }: { jobId: string }) {
  const router = useRouter();
  const [job, setJob] = useState<Job | null>(null);
  const [rankStatus, setRankStatus] = useState<RankStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [ranking, setRanking] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [jRes, rRes] = await Promise.all([
        fetch(`/api/jobs/${jobId}`, { cache: "no-store" }),
        fetch(`/api/jobs/${jobId}/rank`, { cache: "no-store" }),
      ]);
      const jData = (await jRes.json()) as Job & { error?: string };
      if (!jRes.ok) {
        setErr(jData.error ?? "Failed to load job");
        return;
      }
      setJob(jData);
      if (rRes.ok) {
        setRankStatus((await rRes.json()) as RankStatus);
      }
    } catch {
      setErr("Network error");
    } finally {
      setLoading(false);
    }
  }, [jobId]);

  useEffect(() => {
    void load();
  }, [load]);

  async function triggerRank() {
    setRanking(true);
    setMsg(null);
    try {
      const res = await fetch(`/api/jobs/${jobId}/rank`, { method: "POST" });
      const data = (await res.json()) as { queued?: number; error?: string };
      if (!res.ok) {
        setErr(data.error ?? "Re-rank failed");
        return;
      }
      setMsg(`Queued ${data.queued ?? 0} ranking tasks.`);
      await load();
    } catch {
      setErr("Network error while triggering rank");
    } finally {
      setRanking(false);
    }
  }

  async function remove() {
    if (
      typeof window !== "undefined" &&
      !window.confirm(`Delete “${job?.title || "Untitled role"}”? This cannot be undone.`)
    ) {
      return;
    }
    setDeleting(true);
    setErr(null);
    try {
      const res = await fetch(`/api/jobs/${jobId}`, { method: "DELETE" });
      if (!res.ok) {
        const data = (await res.json()) as { error?: string };
        setErr(data.error ?? "Delete failed");
        return;
      }
      router.push("/jobs");
      router.refresh();
    } catch {
      setErr("Network error while deleting");
    } finally {
      setDeleting(false);
    }
  }

  if (loading) {
    return <p className="text-sm text-slate-500">Loading job…</p>;
  }
  if (err || !job) {
    return <p className="text-sm text-rose-600">{err ?? "Job not found"}</p>;
  }

  const rankTotal =
    (rankStatus?.pending ?? 0) +
    (rankStatus?.processing ?? 0) +
    (rankStatus?.done ?? 0) +
    (rankStatus?.failed ?? 0);
  const rankDone = rankStatus?.done ?? 0;
  const rankPct = rankTotal > 0 ? Math.round((rankDone / rankTotal) * 100) : 0;

  return (
    <div className="flex flex-col gap-6">
      <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-card">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-bold text-brand-primary">{job.title || "Untitled role"}</h2>
            <p className="mt-1 text-[12px] text-slate-500">
              Reusable role definition used for CV ranking
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Link
              href={`/jobs/${jobId}/edit`}
              className="rounded-lg border border-slate-200 px-3 py-1.5 text-[13px] font-medium text-slate-700 hover:bg-slate-50"
            >
              Edit
            </Link>
            <button
              type="button"
              onClick={() => void triggerRank()}
              disabled={ranking}
              className="rounded-lg bg-brand-secondary px-3 py-1.5 text-[13px] font-semibold text-white hover:bg-brand-secondary/90 disabled:opacity-50"
            >
              {ranking ? "Queuing…" : "Rank CVs"}
            </button>
            <button
              type="button"
              onClick={() => void remove()}
              disabled={deleting}
              className="rounded-lg border border-rose-200 px-3 py-1.5 text-[13px] font-medium text-rose-700 hover:bg-rose-50 disabled:opacity-50"
            >
              {deleting ? "Deleting…" : "Delete"}
            </button>
          </div>
        </div>
        {msg && <p className="mt-3 text-sm text-emerald-600">{msg}</p>}
      </div>

      {rankStatus && rankTotal > 0 && (
        <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-card">
          <div className="flex items-center justify-between text-[13px]">
            <span className="font-medium text-brand-primary">Ranking progress</span>
            <span className="text-slate-500">
              {rankPct}% ({rankDone}/{rankTotal})
            </span>
          </div>
          <div className="mt-2 h-2 overflow-hidden rounded-full bg-slate-100">
            <div className="h-full rounded-full bg-brand-secondary transition-all" style={{ width: `${rankPct}%` }} />
          </div>
          <div className="mt-2 flex flex-wrap gap-3 text-[12px] text-slate-500">
            <span>Pending: {rankStatus.pending}</span>
            <span>Processing: {rankStatus.processing}</span>
            <span>Failed: {rankStatus.failed}</span>
          </div>
        </div>
      )}

      <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-card">
        <h3 className="text-sm font-semibold text-brand-primary">Job description</h3>
        <pre className="mt-3 whitespace-pre-wrap font-sans text-[13px] leading-relaxed text-slate-700">
          {job.jd_text}
        </pre>
      </div>
    </div>
  );
}
