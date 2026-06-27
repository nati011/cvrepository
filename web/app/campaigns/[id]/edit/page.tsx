import { redirect } from "next/navigation";

type Props = { params: Promise<{ id: string }> };

export default async function EditCampaignRedirect({ params }: Props) {
  const { id } = await params;
  redirect(`/campaigns/${id}`);
}
