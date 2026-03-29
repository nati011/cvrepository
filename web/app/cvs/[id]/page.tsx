import Link from "next/link";
import { notFound } from "next/navigation";
import { DeleteCVButton } from "@/components/DeleteCVButton";
import { StatusBadge } from "@/components/StatusBadge";
import { backendBase } from "@/lib/backend";
import type { CV } from "@/lib/types";

export const dynamic = "force-dynamic";

type PageProps = { params: Promise<{ id: string }> };

export default async function CVDetailPage({ params }: PageProps) {
  const { id } = await params;
  let res: Response;
  try {
    res = await fetch(`${backendBase()}/v1/cvs/${id}`, { cache: "no-store" });
  } catch {
    throw new Error("Failed to reach API (check API_URL)");
  }
  if (res.status === 404) {
    notFound();
  }
  if (!res.ok) {
    throw new Error(`API error ${res.status}`);
  }
  const cv = (await res.json()) as CV;

  return (
    <div className="flex flex-col gap-8">
      <nav className="text-sm" aria-label="Breadcrumb">
        <ol className="flex flex-wrap items-center gap-2 text-slate-500 dark:text-slate-400">
          <li>
            <Link
              href="/cvs"
              className="font-medium text-sky-700 hover:text-sky-600 dark:text-sky-400 dark:hover:text-sky-300"
            >
              Library
            </Link>
          </li>
          <li aria-hidden className="text-slate-300 dark:text-slate-600">
            /
          </li>
          <li className="truncate text-slate-700 dark:text-slate-300">
            {cv.title || cv.original_filename}
          </li>
        </ol>
      </nav>

      <div className="flex flex-col gap-6 border-b border-slate-200/90 pb-8 dark:border-slate-800 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <p className="text-xs font-semibold uppercase tracking-widest text-sky-600 dark:text-sky-400">
            Document
          </p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-slate-900 dark:text-white sm:text-3xl">
            {cv.title || cv.original_filename}
          </h1>
          <p className="mt-2 text-sm text-slate-500 dark:text-slate-400">{cv.original_filename}</p>
          <div className="mt-4 flex flex-wrap items-center gap-3 text-sm text-slate-600 dark:text-slate-400">
            <StatusBadge status={cv.status} />
            <span className="text-slate-300 dark:text-slate-600">·</span>
            <span>{(cv.size_bytes / 1024).toFixed(1)} KB</span>
            <span className="text-slate-300 dark:text-slate-600">·</span>
            <span className="font-mono text-xs text-slate-500">{cv.sha256.slice(0, 12)}…</span>
          </div>
        </div>
        <DeleteCVButton id={cv.id} />
      </div>

      {cv.parse_error && (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800 dark:border-red-900/50 dark:bg-red-950/30 dark:text-red-200">
          <strong className="font-semibold">Parse error:</strong> {cv.parse_error}
        </div>
      )}

      <section className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card dark:border-slate-800 dark:bg-slate-900">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-xs font-semibold uppercase tracking-widest text-slate-500 dark:text-slate-400">
            Preview
          </h2>
          <a
            href={`/api/cvs/${id}/file`}
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm font-medium text-sky-700 hover:text-sky-600 dark:text-sky-400 dark:hover:text-sky-300"
          >
            Open in new tab
          </a>
        </div>
        <iframe
          title={cv.title || cv.original_filename}
          src={`/api/cvs/${id}/file`}
          className="mt-4 h-[min(80vh,900px)] w-full rounded-lg border border-slate-200 dark:border-slate-700"
        />
      </section>
    </div>
  );
}
