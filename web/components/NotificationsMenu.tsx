"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { normalizePipelineStats, type PipelineStats } from "@/lib/types";

type NoticeTone = "info" | "success" | "progress" | "warning";

type Notice = {
  id: string;
  tone: NoticeTone;
  title: string;
  detail: string;
  href: string;
};

const TONE_DOT: Record<NoticeTone, string> = {
  info: "bg-brand-secondary",
  success: "bg-emerald-500",
  progress: "bg-brand-secondary",
  warning: "bg-rose-500",
};

function buildNotices(s: PipelineStats): Notice[] {
  const out: Notice[] = [];
  const ranking = s.ranking;
  const inFlight =
    s.extraction.pending +
    s.extraction.processing +
    s.profile.pending +
    s.profile.processing +
    ranking.pending +
    ranking.processing;

  if (inFlight > 0) {
    out.push({
      id: "in-flight",
      tone: "progress",
      title: `${inFlight.toLocaleString()} item${inFlight === 1 ? "" : "s"} processing`,
      detail: "Extraction, profiling, and ranking are running in the background.",
      href: "/pipeline",
    });
  }
  if (ranking.done > 0) {
    out.push({
      id: "ranked",
      tone: "success",
      title: `${ranking.done.toLocaleString()} candidate${ranking.done === 1 ? "" : "s"} ranked`,
      detail: `Scored across ${(s.jobs + s.campaigns).toLocaleString()} role${s.jobs + s.campaigns === 1 ? "" : "s"}. Review in the mobile app.`,
      href: "/campaigns",
    });
  }
  if (s.extraction.ready > 0) {
    out.push({
      id: "search-ready",
      tone: "info",
      title: `${s.extraction.ready.toLocaleString()} CV${s.extraction.ready === 1 ? "" : "s"} search-ready`,
      detail: "Extracted résumé text is indexed and searchable.",
      href: "/search",
    });
  }
  const failed = s.extraction.failed + s.profile.failed;
  if (failed > 0) {
    out.push({
      id: "failed",
      tone: "warning",
      title: `${failed.toLocaleString()} document${failed === 1 ? "" : "s"} need attention`,
      detail: "Some files failed to parse or profile. Check the pipeline.",
      href: "/pipeline",
    });
  }
  return out;
}

function IconBell({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"
      />
    </svg>
  );
}

export function NotificationsMenu() {
  const [open, setOpen] = useState(false);
  const [notices, setNotices] = useState<Notice[]>([]);
  const [read, setRead] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  const load = useCallback(async () => {
    try {
      const res = await fetch("/api/pipeline", { cache: "no-store" });
      if (!res.ok) return;
      const stats = normalizePipelineStats((await res.json()) as PipelineStats);
      const next = buildNotices(stats);
      setNotices((prev) => {
        const sig = (list: Notice[]) => list.map((n) => `${n.id}:${n.title}`).join("|");
        if (sig(prev) !== sig(next)) setRead(false);
        return next;
      });
    } catch {
      // header notifications are best-effort; ignore network errors
    }
  }, []);

  useEffect(() => {
    void load();
    const t = setInterval(() => void load(), 30000);
    return () => clearInterval(t);
  }, [load]);

  useEffect(() => {
    if (!open) return;
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onClick);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const unread = read ? 0 : notices.length;

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        aria-label="Notifications"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        className="relative rounded-full p-2 text-brand-primary hover:bg-brand-primary/5"
      >
        <IconBell className="h-5 w-5" />
        {unread > 0 && (
          <span className="absolute right-1.5 top-1.5 grid h-2 w-2 place-items-center rounded-full bg-brand-secondary ring-2 ring-white" />
        )}
      </button>

      {open && (
        <div
          role="menu"
          className="absolute right-0 z-50 mt-2 w-80 overflow-hidden rounded-xl border border-slate-200 bg-white shadow-lg ring-1 ring-black/5"
        >
          <div className="flex items-center justify-between border-b border-slate-100 px-4 py-3">
            <p className="text-sm font-semibold text-brand-primary">
              Notifications
              {unread > 0 && (
                <span className="ml-2 rounded-full bg-brand-secondary/15 px-2 py-0.5 text-[11px] font-semibold text-brand-secondary">
                  {unread} new
                </span>
              )}
            </p>
            {notices.length > 0 && unread > 0 && (
              <button
                type="button"
                onClick={() => setRead(true)}
                className="text-[12px] font-medium text-brand-secondary hover:text-brand-secondary/80"
              >
                Mark all read
              </button>
            )}
          </div>

          {notices.length === 0 ? (
            <div className="px-4 py-8 text-center text-sm text-slate-500">
              You&apos;re all caught up.
            </div>
          ) : (
            <ul className="max-h-80 divide-y divide-slate-100 overflow-auto">
              {notices.map((n) => (
                <li key={n.id}>
                  <Link
                    href={n.href}
                    onClick={() => setOpen(false)}
                    className="flex gap-3 px-4 py-3 transition-colors hover:bg-slate-50"
                  >
                    <span className={`mt-1.5 h-2 w-2 shrink-0 rounded-full ${TONE_DOT[n.tone]}`} />
                    <div className="min-w-0">
                      <p className="text-[13px] font-medium text-slate-900">{n.title}</p>
                      <p className="mt-0.5 text-[12px] leading-snug text-slate-500">{n.detail}</p>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}

          <Link
            href="/pipeline"
            onClick={() => setOpen(false)}
            className="block border-t border-slate-100 px-4 py-2.5 text-center text-[12px] font-semibold text-brand-secondary hover:bg-slate-50"
          >
            View data pipeline →
          </Link>
        </div>
      )}
    </div>
  );
}
