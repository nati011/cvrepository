import type { Metadata } from "next";
import { DashboardClient } from "@/components/DashboardClient";
import { PageHeader } from "@/components/PageHeader";

export const metadata: Metadata = {
  title: "Dashboard",
  description:
    "CV library metrics: ingest volume, parse pipeline, search-ready documents, and storage.",
};

export default function DashboardPage() {
  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        eyebrow="Operations"
        title="Dashboard"
        description="Live snapshot of your CV repository: ingest trends, parsing pipeline, search readiness, and PDF storage."
      />
      <DashboardClient />
    </div>
  );
}
