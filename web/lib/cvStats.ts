import type { CV, CVListResponse, CVStatus } from "./types";

export const FETCH_LIMIT = 2000;

function pad2(n: number) {
  return String(n).padStart(2, "0");
}

function localDayKey(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

function localDayKeyFromISO(iso: string): string {
  return localDayKey(new Date(iso));
}

export function lastNDaysLocal(n: number): string[] {
  const out: string[] = [];
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    out.push(localDayKey(d));
  }
  return out;
}

export function shortDayLabel(yyyyMmDd: string): string {
  const [y, m, day] = yyyyMmDd.split("-").map(Number);
  const d = new Date(y, (m ?? 1) - 1, day ?? 1);
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export function uploadsPerDay(
  items: CV[],
  daysBack: number,
): { key: string; label: string; uploads: number }[] {
  const keys = lastNDaysLocal(daysBack);
  const counts = new Map<string, number>();
  for (const k of keys) counts.set(k, 0);
  for (const cv of items) {
    const day = localDayKeyFromISO(cv.created_at);
    if (counts.has(day)) {
      counts.set(day, (counts.get(day) ?? 0) + 1);
    }
  }
  return keys.map((key) => ({
    key,
    label: shortDayLabel(key),
    uploads: counts.get(key) ?? 0,
  }));
}

export function countByStatus(items: CV[]): Record<CVStatus, number> {
  const init: Record<CVStatus, number> = {
    pending: 0,
    processing: 0,
    ready: 0,
    failed: 0,
  };
  for (const cv of items) {
    init[cv.status] += 1;
  }
  return init;
}

export function totalBytes(items: CV[]): number {
  return items.reduce((s, c) => s + c.size_bytes, 0);
}

export function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(2)} MB`;
}

export function parseSuccessRate(status: Record<CVStatus, number>): number | null {
  const done = status.ready + status.failed;
  if (done === 0) return null;
  return Math.round((status.ready / done) * 1000) / 10;
}

export type DashboardModel = {
  response: CVListResponse;
  status: Record<CVStatus, number>;
  pipeline: number;
  storageBytes: number;
  storagePartial: boolean;
  parseRate: number | null;
  uploadsSeries: { key: string; label: string; uploads: number }[];
  recent: CV[];
};

export function buildDashboardModel(data: CVListResponse): DashboardModel {
  const items = data.items;
  const status = countByStatus(items);
  const pipeline = status.pending + status.processing;
  const storageBytes = totalBytes(items);
  const storagePartial = data.total > items.length;
  return {
    response: data,
    status,
    pipeline,
    storageBytes,
    storagePartial,
    parseRate: parseSuccessRate(status),
    uploadsSeries: uploadsPerDay(items, 14),
    recent: [...items].sort((a, b) => +new Date(b.created_at) - +new Date(a.created_at)).slice(0, 6),
  };
}
