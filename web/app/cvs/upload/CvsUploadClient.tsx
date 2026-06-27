"use client";

import { useRouter } from "next/navigation";
import { UploadForm } from "@/components/UploadForm";

export function CvsUploadClient() {
  const router = useRouter();

  return (
    <section className="rounded-xl border border-slate-200/90 bg-white p-6 shadow-card">
      <h2 className="text-xs font-semibold uppercase tracking-widest text-slate-500">
        Upload
      </h2>
      <p className="mt-1 text-sm text-slate-600">
        Accepted format: PDF. You can select multiple files at once. Each upload is stored and queued for parsing automatically.
      </p>
      <div className="mt-5">
        <UploadForm
          onUploaded={() => {
            router.push("/cvs");
          }}
        />
      </div>
    </section>
  );
}
