"use client";

import { useState } from "react";

type BatchResultItem = {
  filename: string;
  id?: string;
  status?: string;
  error?: string;
};

type BatchResponse = {
  created?: number;
  failed?: number;
  results?: BatchResultItem[];
  error?: string;
};

export function UploadForm({ onUploaded }: { onUploaded?: () => void }) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [details, setDetails] = useState<BatchResultItem[] | null>(null);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setMessage(null);
    setDetails(null);
    const form = e.currentTarget;
    const input = form.elements.namedItem("files") as HTMLInputElement | null;
    const files = input?.files;
    if (!files?.length) {
      setMessage("Select at least one PDF.");
      return;
    }

    const fd = new FormData();
    for (let i = 0; i < files.length; i++) {
      fd.append("files", files[i]);
    }

    setBusy(true);
    try {
      const res = await fetch("/api/cvs/batch", { method: "POST", body: fd });
      const data = (await res.json().catch(() => ({}))) as BatchResponse;
      if (!res.ok) {
        setMessage(
          typeof data.error === "string" ? data.error : `Upload failed (${res.status})`,
        );
        return;
      }
      const created = data.created ?? 0;
      const failed = data.failed ?? 0;
      setMessage(`Imported ${created} CV(s)${failed ? `, ${failed} failed` : ""}.`);
      setDetails(data.results ?? null);
      form.reset();
      if (created > 0) {
        onUploaded?.();
      }
    } catch {
      setMessage("Network error");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-4 rounded-lg border border-slate-100 bg-slate-50/80 p-4">
      <div className="flex flex-col gap-1.5">
        <label htmlFor="files" className="text-sm font-medium text-slate-700">
          PDF files
        </label>
        <input
          id="files"
          name="files"
          type="file"
          accept="application/pdf,.pdf"
          multiple
          required
          className="text-sm text-slate-600 file:mr-3 file:rounded-lg file:border-0 file:bg-slate-200 file:px-3 file:py-2 file:text-sm file:font-medium file:text-slate-800 hover:file:bg-slate-300"
        />
        <p className="text-xs text-slate-500">
          Select one or more PDFs. Each file becomes a separate CV (title defaults to the filename).
        </p>
      </div>
      <button
        type="submit"
        disabled={busy}
        className="w-fit rounded-lg bg-brand-secondary px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-brand-secondary/90 disabled:opacity-50"
      >
        {busy ? "Uploading…" : "Upload documents"}
      </button>
      {message && (
        <p className="text-sm text-slate-700">{message}</p>
      )}
      {details && details.some((r) => r.error) && (
        <ul className="max-h-40 list-inside list-disc overflow-y-auto text-sm text-amber-800">
          {details
            .filter((r) => r.error)
            .map((r) => (
              <li key={`${r.filename}-${r.error}`}>
                <span className="font-medium">{r.filename}</span>: {r.error}
              </li>
            ))}
        </ul>
      )}
    </form>
  );
}
