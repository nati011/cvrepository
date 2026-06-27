"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { Campaign, CampaignStats, CampaignStatus, CampaignsResponse } from "@/lib/types";
import { StatusBadge } from "@/components/CampaignDetailClient";
import { canDeactivate, deactivateCampaign } from "@/lib/campaignActions";

type SortKey = "title" | "created_at" | "client";
type SortDir = "asc" | "desc";

const PAGE_SIZES = [5, 10, 25, 50] as const;
const STATUS_FILTERS: Array<CampaignStatus | "all"> = ["all", "draft", "active", "paused", "closed", "archived"];

export function CampaignsClient() {
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [statsMap, setStatsMap] = useState<Record<string, CampaignStats>>({});
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [deactivatingId, setDeactivatingId] = useState<string | null>(null);

  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<CampaignStatus | "all">("all");
  const [sortKey, setSortKey] = useState<SortKey>("created_at");
  const [sortDir, setSortDir] = useState<SortDir>("desc");
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState<number>(10);
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const loadCampaigns = useCallback(async () => {
    try {
      const qs = statusFilter !== "all" ? `?status=${statusFilter}` : "";
      const res = await fetch(`/api/campaigns${qs}`, { cache: "no-store" });
      const data = (await res.json()) as CampaignsResponse & { error?: string };
      if (!res.ok) {
        setErr(data.error ?? `Failed to load campaigns (${res.status})`);
        return;
      }
      setCampaigns(data.items);
    } catch {
      setErr("Network error while loading campaigns");
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => {
    void loadCampaigns();
  }, [loadCampaigns]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return campaigns;
    return campaigns.filter(
      (c) =>
        c.title.toLowerCase().includes(q) ||
        c.client.toLowerCase().includes(q) ||
        c.jd_text.toLowerCase().includes(q) ||
        c.tags.some((t) => t.toLowerCase().includes(q)),
    );
  }, [campaigns, query]);

  const sorted = useMemo(() => {
    const arr = [...filtered];
    arr.sort((a, b) => {
      let cmp = 0;
      if (sortKey === "title") cmp = (a.title || "").localeCompare(b.title || "");
      else if (sortKey === "client") cmp = (a.client || "").localeCompare(b.client || "");
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

  useEffect(() => {
    let cancelled = false;
    async function loadStats() {
      const entries = await Promise.all(
        pageItems.map(async (c) => {
          try {
            const res = await fetch(`/api/campaigns/${c.id}/stats`, { cache: "no-store" });
            if (!res.ok) return [c.id, null] as const;
            const data = (await res.json()) as CampaignStats;
            return [c.id, data] as const;
          } catch {
            return [c.id, null] as const;
          }
        }),
      );
      if (cancelled) return;
      const next: Record<string, CampaignStats> = {};
      for (const [id, st] of entries) {
        if (st) next[id] = st;
      }
      setStatsMap((prev) => ({ ...prev, ...next }));
    }
    if (pageItems.length > 0) void loadStats();
    return () => {
      cancelled = true;
    };
  }, [pageItems]);

  async function deactivate(campaign: Campaign) {
    if (!canDeactivate(campaign.status)) return;
    if (
      typeof window !== "undefined" &&
      !window.confirm(
        `Deactivate “${campaign.title || "Untitled role"}”? Title and description will stay unchanged.`,
      )
    ) {
      return;
    }
    setDeactivatingId(campaign.id);
    setErr(null);
    setMsg(null);
    try {
      const result = await deactivateCampaign(campaign);
      if (!result.ok) {
        setErr(result.error);
        return;
      }
      setSelected((prev) => {
        const next = new Set(prev);
        next.delete(campaign.id);
        return next;
      });
      await loadCampaigns();
      setMsg("Campaign deactivated.");
    } catch {
      setErr("Network error while deactivating");
    } finally {
      setDeactivatingId(null);
    }
  }

  function toggleSort(key: SortKey) {
    if (sortKey === key) setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    else {
      setSortKey(key);
      setSortDir(key === "title" || key === "client" ? "asc" : "desc");
    }
    setPage(0);
  }

  const pageIds = pageItems.map((c) => c.id);
  const allOnPageSelected = pageIds.length > 0 && pageIds.every((id) => selected.has(id));
  const someOnPageSelected = pageIds.some((id) => selected.has(id));
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
          <h2 className="text-sm font-semibold text-brand-primary">Campaigns</h2>
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value as CampaignStatus | "all");
                setPage(0);
              }}
              className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-[13px] outline-none focus:border-brand-secondary"
            >
              {STATUS_FILTERS.map((s) => (
                <option key={s} value={s}>
                  {s === "all" ? "Open" : s.charAt(0).toUpperCase() + s.slice(1)}
                </option>
              ))}
            </select>
            <input
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setPage(0);
              }}
              placeholder="Search campaigns…"
              className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-[13px] outline-none focus:border-brand-secondary sm:w-56"
            />
            <Link
              href="/campaigns/new"
              className="inline-flex shrink-0 items-center justify-center rounded-lg bg-brand-primary px-4 py-2 text-[13px] font-semibold text-white hover:bg-brand-primary/90"
            >
              New campaign
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
          <p className="px-5 py-6 text-sm text-slate-500">Loading campaigns…</p>
        ) : campaigns.length === 0 ? (
          <div className="px-5 py-10 text-center">
            <p className="text-sm text-slate-500">No campaigns yet.</p>
            <Link href="/campaigns/new" className="mt-3 inline-block rounded-lg bg-brand-primary px-4 py-2 text-[13px] font-semibold text-white">
              Create your first campaign
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
                      <button type="button" onClick={() => toggleSort("client")} className="uppercase">
                        Client {sortKey === "client" ? (sortDir === "asc" ? "▲" : "▼") : ""}
                      </button>
                    </th>
                    <th className="px-3 py-2.5 font-semibold">Status</th>
                    <th className="px-3 py-2.5 font-semibold">Ranked</th>
                    <th className="px-3 py-2.5 font-semibold">Shortlisted</th>
                    <th className="px-3 py-2.5 font-semibold">
                      <button type="button" onClick={() => toggleSort("created_at")} className="uppercase">
                        Created {sortKey === "created_at" ? (sortDir === "asc" ? "▲" : "▼") : ""}
                      </button>
                    </th>
                    <th className="px-5 py-2.5 text-right font-semibold">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {pageItems.map((c) => {
                    const st = statsMap[c.id];
                    return (
                      <tr key={c.id} className="hover:bg-slate-50">
                        <td className="px-5 py-3">
                          <input
                            type="checkbox"
                            checked={selected.has(c.id)}
                            onChange={() => {
                              setSelected((prev) => {
                                const next = new Set(prev);
                                if (next.has(c.id)) next.delete(c.id);
                                else next.add(c.id);
                                return next;
                              });
                            }}
                            className="h-4 w-4 rounded border-slate-300"
                          />
                        </td>
                        <td className="px-3 py-3">
                          <Link href={`/campaigns/${c.id}`} className="font-medium text-brand-primary hover:underline">
                            {c.title || "Untitled role"}
                          </Link>
                        </td>
                        <td className="px-3 py-3 text-slate-600">{c.client || "—"}</td>
                        <td className="px-3 py-3">
                          <StatusBadge status={c.status} />
                        </td>
                        <td className="px-3 py-3 text-slate-600">{st?.ranked_count ?? "…"}</td>
                        <td className="px-3 py-3 text-slate-600">{st?.reactions.shortlist ?? "…"}</td>
                        <td className="whitespace-nowrap px-3 py-3 text-slate-500">
                          {new Date(c.created_at).toLocaleDateString()}
                        </td>
                        <td className="px-5 py-3">
                          <div className="flex justify-end gap-2">
                            {canDeactivate(c.status) && (
                              <button
                                type="button"
                                onClick={() => void deactivate(c)}
                                disabled={deactivatingId === c.id}
                                className="rounded-lg border border-amber-200 px-3 py-1.5 text-[13px] font-medium text-amber-800 hover:bg-amber-50 disabled:opacity-50"
                              >
                                {deactivatingId === c.id ? "…" : "Deactivate"}
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-200 px-5 py-3 text-[12px] text-slate-500">
              <span>
                Showing {rangeStart}–{rangeEnd} of {total}
              </span>
              <div className="flex items-center gap-2">
                <button type="button" disabled={safePage === 0} onClick={() => setPage((p) => p - 1)} className="rounded border px-2 py-1 disabled:opacity-40">
                  Prev
                </button>
                <span>
                  Page {safePage + 1} / {pageCount}
                </span>
                <button type="button" disabled={safePage >= pageCount - 1} onClick={() => setPage((p) => p + 1)} className="rounded border px-2 py-1 disabled:opacity-40">
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
