"use client";

import Link from "next/link";
import { CVTable } from "@/components/CVTable";

export function CvsLibrary() {
  return (
    <div className="flex flex-col gap-8">
      <section className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card dark:border-slate-800 dark:bg-slate-900">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="min-w-0">
            <h2 className="text-xs font-semibold uppercase tracking-widest text-slate-500 dark:text-slate-400">
              All CVs
            </h2>
            <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Recent uploads and processing status. The list refreshes while jobs are running.
            </p>
          </div>
          <Link
            href="/cvs/upload"
            className="shrink-0 rounded-lg bg-slate-900 px-4 py-2.5 text-center text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 dark:bg-sky-600 dark:hover:bg-sky-500"
          >
            Upload PDFs
          </Link>
        </div>
        <div className="mt-5">
          <CVTable />
        </div>
      </section>
    </div>
  );
}
