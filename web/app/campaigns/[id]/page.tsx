import Link from "next/link";
import { CampaignDetailClient } from "@/components/CampaignDetailClient";

type Props = { params: Promise<{ id: string }> };

export default async function CampaignDetailPage({ params }: Props) {
  const { id } = await params;
  return (
    <div className="flex flex-col gap-8">
      <div className="flex justify-end">
        <Link href="/campaigns" className="text-sm font-medium text-slate-500 hover:text-brand-secondary">
          ← All campaigns
        </Link>
      </div>
      <CampaignDetailClient campaignId={id} />
    </div>
  );
}
