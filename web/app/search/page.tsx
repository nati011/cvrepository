import { PageHeader } from "@/components/PageHeader";
import { SearchClient } from "@/components/SearchClient";

export default function SearchPage() {
  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Search"
        description="Results for your query from the top search bar — titles, filenames, and extracted CV text."
      />
      <SearchClient />
    </div>
  );
}
