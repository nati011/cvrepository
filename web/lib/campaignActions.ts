import type { Campaign, CampaignStatus } from "@/lib/types";

export function canDeactivate(status: CampaignStatus): boolean {
  return status === "draft" || status === "active" || status === "paused";
}

export async function deactivateCampaign(
  campaign: Campaign,
  status: CampaignStatus = "closed",
): Promise<{ ok: true; campaign: Campaign } | { ok: false; error: string }> {
  const res = await fetch(`/api/campaigns/${campaign.id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json; charset=utf-8" },
    body: JSON.stringify({ status }),
  });
  const data = (await res.json()) as Campaign & { error?: string };
  if (!res.ok) {
    return { ok: false, error: data.error ?? `Deactivate failed (${res.status})` };
  }
  return { ok: true, campaign: data };
}
