import type { Metadata } from "next";
import { DashboardClient } from "@/components/DashboardClient";

export const metadata: Metadata = {
  title: "Dashboard",
  description:
    "CV library metrics: ingest volume, parse pipeline, search-ready documents, and storage.",
};

export default function DashboardPage() {
  return <DashboardClient />;
}
