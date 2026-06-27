import Link from "next/link";
import { JobDetailClient } from "@/components/JobDetailClient";

type Props = { params: Promise<{ id: string }> };

export default async function JobDetailPage({ params }: Props) {
  const { id } = await params;
  return (
    <div className="flex flex-col gap-8">
      <div className="flex justify-end">
        <Link href="/jobs" className="text-sm font-medium text-slate-500 hover:text-brand-secondary">
          ← All jobs
        </Link>
      </div>
      <JobDetailClient jobId={id} />
    </div>
  );
}
