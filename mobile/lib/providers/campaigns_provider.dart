import 'package:cv_exec_feed/data/repository_providers.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/feed_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final campaignStatusFilterProvider = StateProvider<String?>((ref) => null);

class CampaignsNotifier extends AsyncNotifier<List<Job>> {
  @override
  Future<List<Job>> build() async {
    final filter = ref.watch(campaignStatusFilterProvider);
    return ref.read(campaignsRepositoryProvider).list(status: filter);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final filter = ref.read(campaignStatusFilterProvider);
      return ref.read(campaignsRepositoryProvider).list(status: filter);
    });
  }

  Future<Job> createCampaign(Job job) async {
    final created = await ref.read(campaignsRepositoryProvider).create(job);
    await refresh();
    ref.invalidate(campaignRankStatusProvider(created.id));
    invalidateGlobalFeed(ref);
    await ref.read(feedProvider.notifier).refresh();
    return created;
  }

  Future<Job> deactivateCampaign(Job job, {String status = 'closed'}) async {
    final updated = await ref
        .read(campaignsRepositoryProvider)
        .updateStatus(job.id, status: status);
    await refresh();
    ref.invalidate(campaignRankStatusProvider(job.id));
    ref.invalidate(campaignStatsProvider(job.id));
    invalidateGlobalFeed(ref);
    ref.invalidate(activeCampaignsProvider);
    return updated;
  }

  Future<ImprovedJD> improveDescription({
    required String title,
    required String jdText,
    String instruction = '',
  }) =>
      ref.read(campaignsRepositoryProvider).improve(
            title: title,
            jdText: jdText,
            instruction: instruction,
          );
}

final activeCampaignsProvider = FutureProvider<List<Job>>((ref) async {
  return ref.read(campaignsRepositoryProvider).list(status: 'active');
});

final campaignsProvider = AsyncNotifierProvider<CampaignsNotifier, List<Job>>(
  CampaignsNotifier.new,
);

class CampaignRankStatusNotifier
    extends AutoDisposeFamilyAsyncNotifier<RankStatus, String> {
  @override
  Future<RankStatus> build(String campaignId) async {
    final status =
        await ref.read(campaignsRepositoryProvider).rankStatus(campaignId);
    if (status.isActive) {
      _schedulePoll(campaignId);
    }
    return status;
  }

  void _schedulePoll(String campaignId) {
    Future.delayed(const Duration(seconds: 3), () {
      if (!ref.exists(campaignRankStatusProvider(campaignId))) return;
      ref.invalidateSelf();
    });
  }

  Future<void> triggerRank(String campaignId) async {
    await ref.read(campaignsRepositoryProvider).triggerRank(campaignId);
    ref.invalidateSelf();
  }
}

final campaignRankStatusProvider = AutoDisposeAsyncNotifierProviderFamily<
    CampaignRankStatusNotifier, RankStatus, String>(
  CampaignRankStatusNotifier.new,
);

class CampaignStatsNotifier
    extends AutoDisposeFamilyAsyncNotifier<CampaignStats, String> {
  @override
  Future<CampaignStats> build(String campaignId) async {
    return ref.read(campaignsRepositoryProvider).stats(campaignId);
  }

  Future<void> refresh() async {
    final id = arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(campaignsRepositoryProvider).stats(id),
    );
  }
}

final campaignStatsProvider = AutoDisposeAsyncNotifierProviderFamily<
    CampaignStatsNotifier, CampaignStats, String>(
  CampaignStatsNotifier.new,
);
