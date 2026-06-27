import type { CVStatus } from "@/lib/types";

const styles: Record<CVStatus, string> = {
  pending:
    "bg-amber-100 text-amber-900",
  processing:
    "bg-brand-primary/10 text-brand-primary",
  ready: "bg-emerald-100 text-emerald-900",
  failed: "bg-red-100 text-red-900",
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
