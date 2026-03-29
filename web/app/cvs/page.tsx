import { PageHeader } from "@/components/PageHeader";
import { CvsLibrary } from "./CvsLibrary";

export default function CVsPage() {
  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        eyebrow="Documents"
        title="Library"
        description="Browse CVs and open a document for details. Use Upload PDFs to add new files to the library."
      />
      <CvsLibrary />
    </div>
  );
}
