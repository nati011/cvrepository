import 'package:cv_exec_feed/data/repository_providers.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/app_provider.dart';
import 'package:cv_exec_feed/providers/campaign_feed_provider.dart';
import 'package:cv_exec_feed/providers/campaigns_provider.dart';
import 'package:cv_exec_feed/providers/stats_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReactionsState {
  final Map<ReactionKey, Reaction> byKey;
  final Map<String, Reaction> byCvId;
  final Set<String> pending;

  const ReactionsState({
    this.byKey = const {},
    this.byCvId = const {},
    this.pending = const {},
  });

  factory ReactionsState.fromItems(List<Reaction> items) {
    final byKey = <ReactionKey, Reaction>{};
    final byCvId = <String, Reaction>{};
    for (final r in items) {
      byKey[r.key] = r;
      byCvId[r.cvId] = r;
    }
    return ReactionsState(byKey: byKey, byCvId: byCvId);
  }

  ReactionsState copyWith({
    Map<ReactionKey, Reaction>? byKey,
    Map<String, Reaction>? byCvId,
    Set<String>? pending,
  }) {
    return ReactionsState(
      byKey: byKey ?? this.byKey,
      byCvId: byCvId ?? this.byCvId,
      pending: pending ?? this.pending,
    );
  }
}

class ReactionsNotifier extends AsyncNotifier<ReactionsState> {
  @override
  Future<ReactionsState> build() async {
    final execId = ref.watch(execIdProvider);
    final items =
        await ref.read(reactionsRepositoryProvider).list(execId: execId);
    return ReactionsState.fromItems(items);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final execId = ref.read(execIdProvider);
      final items =
          await ref.read(reactionsRepositoryProvider).list(execId: execId);
      return ReactionsState.fromItems(items);
    });
  }

  String? actionFor(String cvId, {String? jobId}) {
    final current = state.valueOrNull;
    if (current == null) return null;
    final key = ReactionKey.of(cvId, jobId);
    return current.byKey[key]?.action;
  }

  Future<String?> toggleReaction({
    required String cvId,
    required String action,
    String? jobId,
    required String verb,
  }) async {
    final current = state.valueOrNull ?? ReactionsState();
    final execId = ref.read(execIdProvider);
    final key = ReactionKey.of(cvId, jobId);
    final existing = current.byKey[key];

    if (existing?.action == action) {
      await clearReaction(cvId: cvId, jobId: jobId);
      return null;
    }

    final optimistic = Reaction(
      id: existing?.id ?? 'pending',
      cvId: cvId,
      jobId: jobId,
      execId: execId,
      action: action,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    final nextByKey = Map<ReactionKey, Reaction>.from(current.byKey)
      ..[key] = optimistic;
    final nextByCv = _byCvIdFromKeys(nextByKey);
    final nextPending = Set<String>.from(current.pending)..add(cvId);

    state = AsyncData(current.copyWith(
      byKey: nextByKey,
      byCvId: nextByCv,
      pending: nextPending,
    ));

    try {
      final result = await ref.read(reactionsRepositoryProvider).add(
            cvId: cvId,
            action: action,
            jobId: jobId,
            execId: execId,
          );
      final saved = Reaction(
        id: result.id,
        cvId: cvId,
        jobId: jobId,
        execId: execId,
        action: result.action,
        createdAt: optimistic.createdAt,
      );
      final done = state.valueOrNull ?? current;
      final doneByKey = Map<ReactionKey, Reaction>.from(done.byKey)
        ..[key] = saved;
      final doneByCv = _byCvIdFromKeys(doneByKey);
      final donePending = Set<String>.from(done.pending)..remove(cvId);
      state = AsyncData(done.copyWith(
        byKey: doneByKey,
        byCvId: doneByCv,
        pending: donePending,
      ));
      ref.invalidate(statsProvider);
      if (jobId != null && jobId.isNotEmpty) {
        ref.invalidate(jobProgressProvider(jobId));
        ref.invalidate(campaignStatsProvider(jobId));
        ref.invalidate(campaignFeedProvider(jobId));
      }
      return verb;
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> clearReaction({
    required String cvId,
    String? jobId,
  }) async {
    final current = state.valueOrNull ?? ReactionsState();
    final execId = ref.read(execIdProvider);
    final key = ReactionKey.of(cvId, jobId);
    final existing = current.byKey[key];
    if (existing == null) return;

    final nextByKey = Map<ReactionKey, Reaction>.from(current.byKey)
      ..remove(key);
    final nextByCv = _byCvIdFromKeys(nextByKey);
    final nextPending = Set<String>.from(current.pending)..add(cvId);
    state = AsyncData(current.copyWith(
      byKey: nextByKey,
      byCvId: nextByCv,
      pending: nextPending,
    ));

    if (existing.id == 'pending') {
      nextPending.remove(cvId);
      return;
    }

    try {
      await ref.read(reactionsRepositoryProvider).remove(
            id: existing.id,
            execId: execId,
          );
      final done = state.valueOrNull ?? current;
      final donePending = Set<String>.from(done.pending)..remove(cvId);
      state = AsyncData(done.copyWith(pending: donePending));
      ref.invalidate(statsProvider);
      if (jobId != null && jobId.isNotEmpty) {
        ref.invalidate(jobProgressProvider(jobId));
        ref.invalidate(campaignStatsProvider(jobId));
        ref.invalidate(campaignFeedProvider(jobId));
      }
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final reactionsProvider =
    AsyncNotifierProvider<ReactionsNotifier, ReactionsState>(
  ReactionsNotifier.new,
);

Map<String, Reaction> _byCvIdFromKeys(Map<ReactionKey, Reaction> byKey) {
  return {for (final r in byKey.values) r.cvId: r};
}
