import { PageHeader } from "@/components/PageHeader";
import { CvsUploadClient } from "./CvsUploadClient";

export default function CvsUploadPage() {
  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Upload CVs"
        description="Add PDF files to the library. A background worker parses each file with Tika and indexes it for search."
      />
      <CvsUploadClient />
    </div>
  );
}
