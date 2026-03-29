import type { CVStatus } from "@/lib/types";

const styles: Record<CVStatus, string> = {
  pending:
    "bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200",
  processing:
    "bg-sky-100 text-sky-900 dark:bg-sky-950 dark:text-sky-200",
  ready: "bg-emerald-100 text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200",
  failed: "bg-red-100 text-red-900 dark:bg-red-950 dark:text-red-200",
};

export function StatusBadge({ status }: { status: CVStatus }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${styles[status]}`}
    >
      {status}
    </span>
  );
}
