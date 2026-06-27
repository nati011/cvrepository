import { PipelineClient } from "@/components/PipelineClient";

export const metadata = {
  title: "Data pipeline",
  description: "Track CVs through ingestion, text extraction, profile extraction, and ranking.",
};

export default function PipelinePage() {
  return (
    <div className="flex flex-col gap-8">
      <PipelineClient />
    </div>
  );
}
