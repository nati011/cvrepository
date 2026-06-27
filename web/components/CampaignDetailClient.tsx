"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import type { Campaign, CampaignStats, CampaignStatus } from "@/lib/types";
import { canDeactivate, deactivateCampaign } from "@/lib/campaignActions";

const STATUS_STYLES: Record<CampaignStatus, string> = {
  draft: "bg-slate-100 text-slate-700",
  active: "bg-emerald-100 text-emerald-800",
  paused: "bg-amber-100 text-amber-800",
  closed: "bg-slate-200 text-slate-600",
  archived: "bg-slate-100 text-slate-500",
};

export function StatusBadge({ status }: { status: CampaignStatus }) {
  return (
    <span className={`inline-flex rounded-full px-2 py-0.5 text-[11px] font-semibold capitalize ${STATUS_STYLES[status]}`}>
      {status}
    </span>
  );
}

export function CampaignDetailClient({ campaignId }: { campaignId: string }) {
  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [stats, setStats] = useState<CampaignStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [deactivating, setDeactivating] = useState(false);
  const [ranking, setRanking] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [cRes, sRes] = await Promise.all([
        fetch(`/api/campaigns/${campaignId}`, { cache: "no-store" }),
        fetch(`/api/campaigns/${campaignId}/stats`, { cache: "no-store" }),
      ]);
      const cData = (await cRes.json()) as Campaign & { error?: string };
      const sData = (await sRes.json()) as CampaignStats & { error?: string };
      if (!cRes.ok) {
        setErr(cData.error ?? "Failed to load campaign");
        return;
      }
      setCampaign(cData);
      if (sRes.ok) setStats(sData);
    } catch {
      setErr("Network error");
    } finally {
      setLoading(false);
    }
  }, [campaignId]);

  useEffect(() => {
    void load();
  }, [load]);

  async function deactivate() {
    if (!campaign || !canDeactivate(campaign.status)) return;
    if (
      typeof window !== "undefined" &&
      !window.confirm(
        `Deactivate “${campaign.title || "Untitled role"}”? Title and description will stay unchanged.`,
      )
    ) {
      return;
    }
    setDeactivating(true);
    setErr(null);
    setMsg(null);
    try {
      const result = await deactivateCampaign(campaign);
      if (!result.ok) {
        setErr(result.error);
        return;
      }
      setCampaign(result.campaign);
      setMsg("Campaign deactivated.");
      await load();
    } catch {
      setErr("Network error while deactivating");
    } finally {
      setDeactivating(false);
    }
  }

  async function triggerRank() {
    setRanking(true);
    setMsg(null);
    try {
      const res = await fetch(`/api/campaigns/${campaignId}/rank`, { method: "POST" });
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

  if (loading) {
    return <p className="text-sm text-slate-500">Loading campaign…</p>;
  }
  if (err || !campaign) {
    return <p className="text-sm text-rose-600">{err ?? "Campaign not found"}</p>;
  }

  const rankTotal =
    (stats?.rank_status.pending ?? 0) +
    (stats?.rank_status.processing ?? 0) +
    (stats?.rank_status.done ?? 0) +
    (stats?.rank_status.failed ?? 0);
  const rankDone = stats?.rank_status.done ?? 0;
  const rankPct = rankTotal > 0 ? Math.round((rankDone / rankTotal) * 100) : 0;
  const canRank = campaign.status === "draft" || campaign.status === "active" || campaign.status === "paused";

  return (
    <div className="flex flex-col gap-6">
      <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-card">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-lg font-bold text-brand-primary">{campaign.title || "Untitled role"}</h2>
              <StatusBadge status={campaign.status} />
            </div>
            <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-[13px] text-slate-600">
              {campaign.client && <span>Client: {campaign.client}</span>}
              {campaign.location && <span>Location: {campaign.location}</span>}
              {campaign.hiring_manager && <span>HM: {campaign.hiring_manager}</span>}
              {campaign.headcount != null && <span>Headcount: {campaign.headcount}</span>}
            </div>
            {(campaign.tags ?? []).length > 0 && (
              <div className="mt-2 flex flex-wrap gap-1">
                {campaign.tags.map((t) => (
                  <span key={t} className="rounded-full bg-slate-100 px-2 py-0.5 text-[11px] text-slate-600">
                    {t}
                  </span>
                ))}
              </div>
            )}
          </div>
          <div className="flex flex-wrap gap-2">
            {canDeactivate(campaign.status) && (
              <button
                type="button"
                onClick={() => void deactivate()}
                disabled={deactivating}
                className="rounded-lg border border-amber-200 px-3 py-1.5 text-[13px] font-medium text-amber-800 hover:bg-amber-50 disabled:opacity-50"
              >
                {deactivating ? "Deactivating…" : "Deactivate"}
              </button>
            )}
            {canRank && (
              <button
                type="button"
                onClick={() => void triggerRank()}
                disabled={ranking}
                className="rounded-lg bg-brand-secondary px-3 py-1.5 text-[13px] font-semibold text-white hover:bg-brand-secondary/90 disabled:opacity-50"
              >
                {ranking ? "Queuing…" : "Re-rank CVs"}
              </button>
            )}
          </div>
        </div>
        {msg && <p className="mt-3 text-sm text-emerald-600">{msg}</p>}
        {campaign.status !== "closed" && campaign.status !== "archived" ? (
          <p className="mt-3 text-[12px] text-slate-500">
            Title and job description are locked after creation.
          </p>
        ) : (
          <p className="mt-3 rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-[12px] text-slate-600">
            This campaign is deactivated. Title and description are read-only.
          </p>
        )}
      </div>

      {stats && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          <StatCard label="Ranked" value={stats.ranked_count} />
          <StatCard label="Reviewed" value={stats.reviewed_count} />
          <StatCard label="Shortlisted" value={stats.reactions.shortlist} />
          <StatCard label="Starred" value={stats.reactions.star} />
          <StatCard label="Avg score" value={stats.avg_score != null ? stats.avg_score.toFixed(1) : "—"} />
        </div>
      )}

      {stats && rankTotal > 0 && (
        <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-card">
          <div className="flex items-center justify-between text-[13px]">
            <span className="font-medium text-brand-primary">Ranking progress</span>
            <span className="text-slate-500">{rankPct}% ({rankDone}/{rankTotal})</span>
          </div>
          <div className="mt-2 h-2 overflow-hidden rounded-full bg-slate-100">
            <div className="h-full rounded-full bg-brand-secondary transition-all" style={{ width: `${rankPct}%` }} />
          </div>
          <div className="mt-2 flex flex-wrap gap-3 text-[12px] text-slate-500">
            <span>Pending: {stats.rank_status.pending}</span>
            <span>Processing: {stats.rank_status.processing}</span>
            <span>Failed: {stats.rank_status.failed}</span>
          </div>
        </div>
      )}

      <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-card">
        <h3 className="text-sm font-semibold text-brand-primary">Job description</h3>
        <pre className="mt-3 whitespace-pre-wrap font-sans text-[13px] leading-relaxed text-slate-700">
          {campaign.jd_text}
        </pre>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-card">
      <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-1 text-2xl font-bold text-brand-primary">{value}</p>
    </div>
  );
}
