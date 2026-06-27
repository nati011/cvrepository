import 'package:cv_exec_feed/data/repository_providers.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/app_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsNotifier extends AsyncNotifier<List<ExecStat>> {
  @override
  Future<List<ExecStat>> build() async {
    return ref.read(statsRepositoryProvider).leaderboard();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(statsRepositoryProvider).leaderboard(),
    );
  }
}

final statsProvider = AsyncNotifierProvider<StatsNotifier, List<ExecStat>>(
  StatsNotifier.new,
);

final pipelineStatsProvider = FutureProvider<PipelineStats>((ref) async {
  return ref.read(statsRepositoryProvider).pipelineStats();
});

final jobProgressProvider =
    FutureProvider.autoDispose.family<JobProgress?, String>((ref, jobId) async {
  final execId = ref.watch(execIdProvider);
  final res = await ref.read(statsRepositoryProvider).stats(
        jobId: jobId,
        execId: execId,
      );
  return res.progress;
});
