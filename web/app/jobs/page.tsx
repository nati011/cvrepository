import { JobsClient } from "@/components/JobsClient";

export const metadata = {
  title: "Job management",
  description: "Create and manage reusable job definitions for CV ranking.",
};

export default function JobsPage() {
  return (
    <div className="flex flex-col gap-8">
      <JobsClient />
    </div>
  );
}
