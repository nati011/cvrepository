"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { TopSearchBar } from "@/components/TopSearchBar";

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
        d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5M9 11.25v1.5M12 9v3.75m3-6v6"
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

function IconPreferences({ className }: { className?: string }) {
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
        d="M10.343 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.132a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 010 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.132a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.132a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 010-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 01-.26-1.43l1.297-2.132a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z"
      />
      <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
  );
}

const navItems = [
  { href: "/", label: "Dashboard", Icon: IconDashboard },
  { href: "/cvs", label: "Library", Icon: IconFolder },
  { href: "/preferences", label: "Preferences", Icon: IconPreferences },
] as const;

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

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

  const sidebarInner = (
    <>
      <div className="flex h-16 shrink-0 items-center border-b border-slate-700/60 px-5">
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-white">CV Repository</p>
        </div>
      </div>

      <nav className="flex flex-1 flex-col gap-1 p-3" aria-label="Main">
        <p className="px-3 pb-2 pt-2 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
          Workspace
        </p>
        {navItems.map(({ href, label, Icon }) => {
          const active = isActive(href);
          return (
            <Link
              key={href}
              href={href}
              className={`group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                active
                  ? "bg-slate-800 text-white shadow-sm ring-1 ring-white/10"
                  : "text-slate-400 hover:bg-slate-800/80 hover:text-slate-100"
              }`}
            >
              <Icon
                className={`h-5 w-5 shrink-0 ${active ? "text-sky-400" : "text-slate-500 group-hover:text-slate-300"}`}
              />
              {label}
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-slate-700/60 p-4">
        <p className="text-[11px] leading-relaxed text-slate-500">
          CV repo @ 2026 - kifiya.com
        </p>
      </div>
    </>
  );

  return (
    <div className="flex min-h-screen bg-slate-100 dark:bg-slate-950">
      {mobileOpen && (
        <button
          type="button"
          aria-label="Close menu"
          className="fixed inset-0 z-40 bg-slate-950/60 backdrop-blur-sm md:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      <aside
        className={`fixed inset-y-0 left-0 z-50 flex w-[260px] flex-col border-r border-slate-700/50 bg-slate-900 shadow-2xl shadow-slate-950/50 transition-transform duration-200 ease-out md:static md:z-0 md:translate-x-0 md:shadow-none ${
          mobileOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="flex h-14 items-center justify-end border-b border-slate-700/60 px-3 md:hidden">
          <button
            type="button"
            aria-label="Close menu"
            className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white"
            onClick={() => setMobileOpen(false)}
          >
            <IconClose className="h-5 w-5" />
          </button>
        </div>
        <div className="flex min-h-0 flex-1 flex-col md:pt-0">{sidebarInner}</div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 border-b border-slate-200/80 bg-white/95 backdrop-blur-md dark:border-slate-800 dark:bg-slate-900/95">
          <div className="flex items-center gap-2 px-3 py-2.5 sm:gap-3 sm:px-4 sm:py-3 lg:px-6">
            <button
              type="button"
              aria-label="Open menu"
              className="shrink-0 rounded-lg p-2 text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800 md:hidden"
              onClick={() => setMobileOpen(true)}
            >
              <IconMenu className="h-5 w-5" />
            </button>
            <TopSearchBar />
          </div>
        </header>

        <main className="flex-1 overflow-auto">
          <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8 lg:py-10">{children}</div>
        </main>
      </div>
    </div>
  );
}
