"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { TopSearchBar } from "@/components/TopSearchBar";
import { NotificationsMenu } from "@/components/NotificationsMenu";

function IconDashboard({ className }: { className?: string }) {
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
        d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"
      />
    </svg>
  );
}

function IconBriefcase({ className }: { className?: string }) {
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
        d="M20.25 14.15v4.075c0 1.313-.875 2.475-2.163 2.638-2.005.254-4.05.387-6.087.387-2.037 0-4.082-.133-6.087-.387C4.625 20.7 3.75 19.538 3.75 18.225V14.15M20.25 14.15c.41-.211.71-.59.806-1.057L21.75 8.4M20.25 14.15a2.25 2.25 0 01-.806.243 41.34 41.34 0 01-7.444.657 41.34 41.34 0 01-7.444-.657 2.25 2.25 0 01-.806-.243M3.75 14.15c-.41-.211-.71-.59-.806-1.057L2.25 8.4m0 0a2.25 2.25 0 01.806-1.302 41.34 41.34 0 0118.888 0 2.25 2.25 0 01.806 1.302m-19.5 0h19.5M15 11.25v.008M9 11.25v.008M12 3.75V6m-3.75 0h7.5a1.5 1.5 0 011.5 1.5"
      />
    </svg>
  );
}

function IconFolder({ className }: { className?: string }) {
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
        d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-16.5 0a2.25 2.25 0 00-2.25 2.25v6A2.25 2.25 0 004.5 21h15a2.25 2.25 0 002.25-2.25v-6a2.25 2.25 0 00-2.25-2.25H5.25z"
      />
    </svg>
  );
}

function IconCampaign({ className }: { className?: string }) {
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
        d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5M9 11.25v.008M15 11.25v.008"
      />
    </svg>
  );
}

function IconMenu({ className }: { className?: string }) {
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
        d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
      />
    </svg>
  );
}

function IconClose({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.5}
      aria-hidden
    >
      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
    </svg>
  );
}

function IconPipeline({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5} aria-hidden>
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M3.75 6.75h16.5M6.75 12h10.5m-7.5 5.25h4.5"
      />
    </svg>
  );
}

const navItems = [
  { href: "/", label: "Dashboard", Icon: IconDashboard },
  { href: "/cvs", label: "Library", Icon: IconFolder },
  { href: "/jobs", label: "Jobs", Icon: IconBriefcase },
  { href: "/campaigns", label: "Campaigns", Icon: IconCampaign },
  { href: "/pipeline", label: "Pipeline", Icon: IconPipeline },
] as const;

const pageMeta: { match: (p: string) => boolean; title: string; subtitle: string }[] = [
  { match: (p) => p === "/", title: "Dashboard", subtitle: "CV Repository • Talent Review" },
  { match: (p) => p === "/cvs/upload", title: "Upload CVs", subtitle: "Add new résumé PDFs to the library" },
  { match: (p) => p.startsWith("/cvs"), title: "Library", subtitle: "All résumé documents on record" },
  { match: (p) => p.startsWith("/jobs"), title: "Job management", subtitle: "Reusable role definitions for CV ranking" },
  { match: (p) => p.startsWith("/campaigns"), title: "Campaign management", subtitle: "Operational hiring campaigns with lifecycle and analytics" },
  { match: (p) => p.startsWith("/pipeline"), title: "Data pipeline", subtitle: "Ingestion → extraction → profiling → ranking" },
  { match: (p) => p.startsWith("/search"), title: "Search", subtitle: "Find candidates across extracted CV text" },
  { match: (p) => p.startsWith("/profile"), title: "Profile", subtitle: "Your account & activity" },
];

function resolvePageMeta(pathname: string) {
  return (
    pageMeta.find((m) => m.match(pathname)) ?? {
      title: "CV Repository",
      subtitle: "Talent Review",
    }
  );
}

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(true);

  useEffect(() => {
    const stored = window.localStorage.getItem("sidebar-collapsed");
    if (stored === "0") setCollapsed(false);
  }, []);

  useEffect(() => {
    window.localStorage.setItem("sidebar-collapsed", collapsed ? "1" : "0");
  }, [collapsed]);

  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (!mobileOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setMobileOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [mobileOpen]);

  function isActive(href: string) {
    if (href === "/") return pathname === "/";
    return pathname === href || pathname.startsWith(`${href}/`);
  }

  // `c` controls collapse, but only applies at md+ so the mobile drawer always shows full labels.
  const c = collapsed;
  const sidebarInner = (
    <>
      <div
        className={`flex h-16 shrink-0 items-center gap-3 border-b border-white/10 px-5 ${
          c ? "md:justify-center md:px-2" : ""
        }`}
      >
        <Link
          href="/"
          className={`flex min-w-0 flex-1 items-center gap-2.5 ${c ? "md:hidden" : ""}`}
          aria-label="Kifiya CV Repository"
        >
          <Image
            src="/brand/kifiya-logo.png"
            alt="Kifiya"
            width={300}
            height={127}
            priority
            className="h-7 w-auto shrink-0 brightness-0 invert"
          />
          <span className="truncate border-l border-white/20 pl-2.5 text-[11px] leading-tight text-white/60">
            CV Repository
          </span>
        </Link>
        {c && (
          <Link href="/" aria-label="Kifiya CV Repository" className="hidden shrink-0 md:block">
            <Image
              src="/brand/kifiya-logo.png"
              alt="Kifiya"
              width={300}
              height={127}
              className="h-6 w-auto brightness-0 invert"
            />
          </Link>
        )}
      </div>

      <nav className={`flex flex-1 flex-col gap-1 p-3 ${c ? "md:items-center" : ""}`} aria-label="Main">
        {navItems.map(({ href, label, Icon }) => {
          const active = isActive(href);
          return (
            <Link
              key={href}
              href={href}
              title={c ? label : undefined}
              className={`group flex items-center gap-3 rounded-lg px-3 py-2 text-[13px] font-medium transition-colors ${
                c ? "md:h-10 md:w-10 md:justify-center md:p-0" : ""
              } ${
                active
                  ? "bg-brand-secondary text-white shadow-sm"
                  : "text-white/70 hover:bg-white/10 hover:text-white"
              }`}
            >
              <Icon
                className={`h-5 w-5 shrink-0 ${active ? "text-white" : "text-white/60 group-hover:text-white"}`}
              />
              <span className={c ? "md:hidden" : ""}>{label}</span>
            </Link>
          );
        })}
      </nav>

      <div className={`border-t border-white/10 p-4 ${c ? "md:hidden" : ""}`}>
        <p className="text-[11px] leading-relaxed text-white/40">CV repo © 2026 · kifiya.com</p>
      </div>
    </>
  );

  const meta = resolvePageMeta(pathname);

  return (
    <div className="flex min-h-screen bg-white">
      {mobileOpen && (
        <button
          type="button"
          aria-label="Close menu"
          className="fixed inset-0 z-40 bg-brand-dark/60 backdrop-blur-sm md:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      <aside
        className={`fixed inset-y-0 left-0 z-50 flex w-[260px] flex-col bg-brand-primary shadow-2xl shadow-brand-dark/50 transition-[transform,width] duration-200 ease-out md:sticky md:top-0 md:z-0 md:h-screen md:translate-x-0 md:shadow-none ${
          collapsed ? "md:w-[72px]" : "md:w-[260px]"
        } ${mobileOpen ? "translate-x-0" : "-translate-x-full"}`}
      >
        <div className="flex h-14 items-center justify-end border-b border-white/10 px-3 md:hidden">
          <button
            type="button"
            aria-label="Close menu"
            className="rounded-lg p-2 text-white/70 hover:bg-white/10 hover:text-white"
            onClick={() => setMobileOpen(false)}
          >
            <IconClose className="h-5 w-5" />
          </button>
        </div>
        <div className="flex min-h-0 flex-1 flex-col md:pt-0">{sidebarInner}</div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 border-b border-brand-primary/10 bg-white/95 backdrop-blur-md">
          <div className="flex items-center gap-3 px-2 py-2.5 sm:px-3 sm:py-3 lg:px-4">
            <button
              type="button"
              aria-label="Open menu"
              className="shrink-0 rounded-lg p-2 text-brand-primary hover:bg-brand-primary/5 md:hidden"
              onClick={() => setMobileOpen(true)}
            >
              <IconMenu className="h-5 w-5" />
            </button>

            <button
              type="button"
              aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
              title={collapsed ? "Expand sidebar" : "Collapse sidebar"}
              className="hidden shrink-0 rounded-lg p-2 text-brand-primary hover:bg-brand-primary/5 md:inline-flex"
              onClick={() => setCollapsed((v) => !v)}
            >
              <IconMenu className="h-5 w-5" />
            </button>

            <div className="hidden min-w-0 flex-1 lg:block">
              <h1 className="truncate font-display text-base font-semibold leading-tight text-brand-primary">
                {meta.title}
              </h1>
              <p className="truncate text-[11px] leading-tight text-brand-dark/60">
                {meta.subtitle}
              </p>
            </div>

            <div className="flex min-w-0 flex-1 justify-center">
              <TopSearchBar />
            </div>

            <div className="flex shrink-0 items-center gap-2 sm:gap-3">
              <NotificationsMenu />
              <Link
                href="/profile"
                aria-label="Open profile"
                className="flex items-center gap-2 rounded-full p-1 pr-2 transition-colors hover:bg-brand-primary/5"
              >
                <span className="grid h-9 w-9 place-items-center rounded-full bg-brand-primary text-xs font-semibold text-white ring-2 ring-brand-secondary/40">
                  TR
                </span>
                <div className="hidden leading-tight sm:block">
                  <p className="text-[13px] font-medium text-brand-dark">Talent Reviewer</p>
                  <p className="text-[11px] text-brand-dark/50">Kifiya · HUB</p>
                </div>
              </Link>
            </div>
          </div>
        </header>

        <main className="flex-1 overflow-auto">
          <div className="mx-auto max-w-7xl px-2 py-6 sm:px-3 lg:px-4 lg:py-8">{children}</div>
        </main>
      </div>
    </div>
  );
}
