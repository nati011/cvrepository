import 'package:cv_exec_feed/data/repository_providers.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/feed_provider.dart';
import 'package:cv_exec_feed/providers/campaigns_provider.dart';
import 'package:cv_exec_feed/providers/reactions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RankedFeedItem {
  final FeedItem item;
  final int rank;

  const RankedFeedItem({required this.item, required this.rank});
}

final campaignFeedProvider = FutureProvider.autoDispose
    .family<List<RankedFeedItem>, String>((ref, campaignId) async {
  final repo = ref.read(feedRepositoryProvider);
  final campaigns = await ref.watch(campaignsProvider.future);
  final campaign = campaigns.where((j) => j.id == campaignId).firstOrNull;
  if (campaign == null) return const [];

  final page = await repo.campaignFeed(campaignId, limit: feedPageSize);
  return [
    for (var i = 0; i < page.items.length; i++)
      RankedFeedItem(
        item: page.items[i].withJob(jobId: campaign.id, jobTitle: campaign.title),
        rank: i + 1,
      ),
  ];
});

final campaignCandidatesProvider = Provider.autoDispose
    .family<List<CampaignCandidate>, String>((ref, campaignId) {
  final feed = ref.watch(campaignFeedProvider(campaignId)).valueOrNull ?? [];
  final reactions = ref.watch(reactionsProvider).valueOrNull;

  return feed
      .map((entry) {
        final key = ReactionKey.of(entry.item.cvId, campaignId);
        final action = reactions?.byKey[key]?.action;
        return CampaignCandidate(
          item: entry.item,
          rank: entry.rank,
          reactionAction: action,
        );
      })
      .toList();
});

final campaignReviewedProvider = Provider.autoDispose
    .family<List<CampaignCandidate>, String>((ref, campaignId) {
  return ref
      .watch(campaignCandidatesProvider(campaignId))
      .where((c) => c.isReviewed)
      .toList();
});

final campaignShortlistedProvider = Provider.autoDispose
    .family<List<CampaignCandidate>, String>((ref, campaignId) {
  return ref
      .watch(campaignCandidatesProvider(campaignId))
      .where((c) => c.isShortlisted)
      .toList();
});
