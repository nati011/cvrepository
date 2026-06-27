import { JobEditor } from "@/components/JobEditor";

type Props = { params: Promise<{ id: string }> };

export default async function EditJobPage({ params }: Props) {
  const { id } = await params;
  return (
    <div className="flex flex-col gap-8">
      <JobEditor jobId={id} />
    </div>
  );
}
