import 'package:cv_exec_feed/data/repository_providers.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/campaigns_provider.dart';
import 'package:cv_exec_feed/providers/job_definitions_provider.dart';
import 'package:cv_exec_feed/providers/reactions_provider.dart';
import 'package:cv_exec_feed/providers/stats_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const feedPageSize = 50;

class FeedPageState {
  final List<FeedItem> items;
  final int total;
  final bool loadingMore;
  final bool hasMore;

  const FeedPageState({
    this.items = const [],
    this.total = 0,
    this.loadingMore = false,
    this.hasMore = false,
  });

  FeedPageState copyWith({
    List<FeedItem>? items,
    int? total,
    bool? loadingMore,
    bool? hasMore,
  }) {
    return FeedPageState(
      items: items ?? this.items,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class FeedNotifier extends AsyncNotifier<FeedPageState> {
  @override
  Future<FeedPageState> build() async {
    ref.watch(jobDefinitionsProvider);
    ref.watch(campaignsProvider);
    return _loadInitial();
  }

  Future<FeedPageState> _loadInitial() async {
    final items = await ref.read(globalFeedProvider.future);
    return FeedPageState(items: items, total: items.length, hasMore: false);
  }

  Future<void> refresh() async {
    invalidateGlobalFeed(ref);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadInitial);
  }

  Future<void> loadMore() async {
    // Global feed is loaded in full; nothing to paginate.
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedPageState>(
  FeedNotifier.new,
);

final globalFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final repo = ref.read(feedRepositoryProvider);
  final jobs = await ref.watch(jobDefinitionsProvider.future);
  final campaigns = await ref.watch(activeCampaignsProvider.future);

  final roleSources = <({String id, String title, RoleKind kind})>[
    ...jobs.map(
      (job) => (id: job.id, title: job.title, kind: RoleKind.job),
    ),
    ...campaigns.map(
      (campaign) => (id: campaign.id, title: campaign.title, kind: RoleKind.campaign),
    ),
  ];
  if (roleSources.isEmpty) return [];

  final perRole = await Future.wait(roleSources.map((role) async {
    try {
      final page = role.kind == RoleKind.job
          ? await repo.jobFeed(role.id, limit: feedPageSize)
          : await repo.campaignFeed(role.id, limit: feedPageSize);
      return [
        for (final it in page.items)
          (
            item: it.withJob(jobId: role.id, jobTitle: role.title),
            kind: role.kind,
          ),
      ];
    } catch (_) {
      return <({FeedItem item, RoleKind kind})>[];
    }
  }));

  final best = <String, FeedItem>{};
  final rolesByCv = <String, List<RoleMatch>>{};
  for (final entry in perRole.expand((e) => e)) {
    final item = entry.item;
    rolesByCv.putIfAbsent(item.cvId, () => []).add(
          RoleMatch(
            jobId: item.jobId,
            jobTitle: item.jobTitle,
            score: item.score,
            kind: entry.kind,
          ),
        );
    final existing = best[item.cvId];
    if (existing == null || item.score > existing.score) {
      best[item.cvId] = item;
    }
  }
  final merged = best.entries
      .map((e) => e.value.withRoleMatches(rolesByCv[e.key] ?? const []))
      .toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  return merged;
});

final candidateLookupProvider = Provider<Map<String, FeedItem>>((ref) {
  final feed = ref.watch(globalFeedProvider).valueOrNull ?? const [];
  final page = ref.watch(feedProvider).valueOrNull?.items ?? const [];
  final map = <String, FeedItem>{};
  for (final item in feed) {
    map[item.cvId] = item;
  }
  for (final item in page) {
    map[item.cvId] = item;
  }
  return map;
});

final feedSearchProvider = StateProvider<String>((ref) => '');

final searchResultsProvider =
    FutureProvider.autoDispose<List<SearchHit>>((ref) async {
  final q = ref.watch(feedSearchProvider).trim();
  if (q.length < 2) return const <SearchHit>[];
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future.delayed(const Duration(milliseconds: 300));
  if (disposed) return const <SearchHit>[];
  return ref.read(feedRepositoryProvider).search(q);
});

final fitFilterProvider = StateProvider<int>((ref) => 0);

const fitFilterLabels = ['All', 'Strong', 'Solid', 'Emerging'];

bool matchesFeedQuery(FeedItem item, String q) {
  if (q.isEmpty) return true;
  final haystack = [
    item.name,
    item.jobTitle,
    ...item.roleMatches.map((r) => r.jobTitle),
    item.tldr,
    ...item.skills,
  ].join(' ').toLowerCase();
  return haystack.contains(q);
}

bool matchesFitFilter(FeedItem item, int fit) {
  switch (fit) {
    case 1:
      return item.score >= 80;
    case 2:
      return item.score >= 60 && item.score < 80;
    case 3:
      return item.score < 60;
    default:
      return true;
  }
}

void invalidateGlobalFeed(Ref ref) {
  ref.invalidate(globalFeedProvider);
  ref.invalidate(jobDefinitionsProvider);
  ref.invalidate(activeCampaignsProvider);
}

/// Looks up a ranked candidate by CV id, refreshing cached feeds when needed.
Future<FeedItem?> resolveCandidate(WidgetRef ref, String cvId) async {
  final cached = ref.read(candidateLookupProvider)[cvId];
  if (cached != null) return cached;

  ref.invalidate(globalFeedProvider);
  ref.invalidate(jobDefinitionsProvider);
  ref.invalidate(activeCampaignsProvider);
  await ref.read(feedProvider.notifier).refresh();

  final refreshed = ref.read(candidateLookupProvider)[cvId];
  if (refreshed != null) return refreshed;

  final repo = ref.read(feedRepositoryProvider);
  final jobs = await ref.read(jobDefinitionsRepositoryProvider).list();
  final campaigns =
      await ref.read(campaignsRepositoryProvider).list(status: 'active');
  FeedItem? best;
  final roles = <RoleMatch>[];
  for (final job in jobs) {
    try {
      final page = await repo.jobFeed(job.id, limit: feedPageSize);
      for (final item in page.items) {
        if (item.cvId != cvId) continue;
        final tagged = item.withJob(jobId: job.id, jobTitle: job.title);
        roles.add(RoleMatch(
          jobId: job.id,
          jobTitle: job.title,
          score: tagged.score,
          kind: RoleKind.job,
        ));
        if (best == null || tagged.score > best.score) {
          best = tagged;
        }
      }
    } catch (_) {
      // Skip jobs we cannot load.
    }
  }
  for (final campaign in campaigns) {
    try {
      final page = await repo.campaignFeed(campaign.id, limit: feedPageSize);
      for (final item in page.items) {
        if (item.cvId != cvId) continue;
        final tagged =
            item.withJob(jobId: campaign.id, jobTitle: campaign.title);
        roles.add(RoleMatch(
          jobId: campaign.id,
          jobTitle: campaign.title,
          score: tagged.score,
          kind: RoleKind.campaign,
        ));
        if (best == null || tagged.score > best.score) {
          best = tagged;
        }
      }
    } catch (_) {
      // Skip campaigns we cannot load.
    }
  }
  if (best != null) return best.withRoleMatches(roles);

  return ref.read(feedRepositoryProvider).getCandidate(cvId);
}

Future<void> refreshFeedBundle(WidgetRef ref) async {
  ref.invalidate(globalFeedProvider);
  await Future.wait([
    ref.read(feedProvider.notifier).refresh(),
    ref.read(reactionsProvider.notifier).refresh(),
    ref.read(statsProvider.notifier).refresh(),
    ref.read(campaignsProvider.notifier).refresh(),
    ref.read(jobDefinitionsProvider.notifier).refresh(),
  ]);
}

/// Polls the pipeline while extraction, profiling, or ranking is in flight.
class FeedPipelineWatcher extends Notifier<void> {
  var _cancelled = false;

  @override
  void build() {
    ref.onDispose(() => _cancelled = true);
    _poll();
  }

  Future<void> _poll() async {
    while (!_cancelled) {
      await Future.delayed(const Duration(seconds: 4));
      if (_cancelled) return;
      try {
        final stats = await ref.read(statsRepositoryProvider).pipelineStats();
        final busy = stats.extraction.pending +
                stats.extraction.processing +
                stats.profile.pending +
                stats.profile.processing +
                stats.ranking.pending +
                stats.ranking.processing >
            0;
        if (busy) {
          invalidateGlobalFeed(ref);
          ref.invalidateSelf();
        }
      } catch (_) {
        // Ignore transient API errors while polling.
      }
    }
  }
}

final feedPipelineWatcherProvider =
    NotifierProvider<FeedPipelineWatcher, void>(FeedPipelineWatcher.new);
