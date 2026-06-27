import 'package:cv_exec_feed/data/repository_providers.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/feed_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JobDefinitionsNotifier extends AsyncNotifier<List<Job>> {
  @override
  Future<List<Job>> build() async {
    return ref.read(jobDefinitionsRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(jobDefinitionsRepositoryProvider).list(),
    );
  }

  Future<Job> createJob(Job job) async {
    final created = await ref.read(jobDefinitionsRepositoryProvider).create(job);
    await refresh();
    ref.invalidate(jobRankStatusProvider(created.id));
    invalidateGlobalFeed(ref);
    return created;
  }

  Future<Job> updateJob(Job job) async {
    final updated = await ref.read(jobDefinitionsRepositoryProvider).update(job);
    await refresh();
    ref.invalidate(jobRankStatusProvider(job.id));
    invalidateGlobalFeed(ref);
    return updated;
  }

  Future<void> deleteJob(String id) async {
    await ref.read(jobDefinitionsRepositoryProvider).delete(id);
    await refresh();
    ref.invalidate(jobRankStatusProvider(id));
    invalidateGlobalFeed(ref);
  }

  Future<ImprovedJD> improveDescription({
    required String title,
    required String jdText,
    String instruction = '',
  }) =>
      ref.read(jobDefinitionsRepositoryProvider).improve(
            title: title,
            jdText: jdText,
            instruction: instruction,
          );
}

final jobDefinitionsProvider =
    AsyncNotifierProvider<JobDefinitionsNotifier, List<Job>>(
  JobDefinitionsNotifier.new,
);

class JobRankStatusNotifier
    extends AutoDisposeFamilyAsyncNotifier<RankStatus, String> {
  @override
  Future<RankStatus> build(String jobId) async {
    final status =
        await ref.read(jobDefinitionsRepositoryProvider).rankStatus(jobId);
    if (status.isActive) {
      _schedulePoll(jobId);
    }
    return status;
  }

  void _schedulePoll(String jobId) {
    Future.delayed(const Duration(seconds: 3), () {
      if (!ref.exists(jobRankStatusProvider(jobId))) return;
      ref.invalidateSelf();
    });
  }

  Future<void> triggerRank(String jobId) async {
    await ref.read(jobDefinitionsRepositoryProvider).triggerRank(jobId);
    ref.invalidateSelf();
  }
}

final jobRankStatusProvider = AutoDisposeAsyncNotifierProviderFamily<
    JobRankStatusNotifier, RankStatus, String>(
  JobRankStatusNotifier.new,
);
