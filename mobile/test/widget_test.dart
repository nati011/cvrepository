import 'package:cv_exec_feed/data/providers.dart';
import 'package:cv_exec_feed/main.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/campaigns_provider.dart';
import 'package:cv_exec_feed/providers/feed_provider.dart';
import 'package:cv_exec_feed/providers/job_definitions_provider.dart';
import 'package:cv_exec_feed/providers/notifications_provider.dart';
import 'package:cv_exec_feed/providers/reactions_provider.dart';
import 'package:cv_exec_feed/providers/stats_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestCampaignsNotifier extends CampaignsNotifier {
  @override
  Future<List<Job>> build() async => const [];
}

class _TestJobDefinitionsNotifier extends JobDefinitionsNotifier {
  @override
  Future<List<Job>> build() async => const [];
}

class _TestFeedNotifier extends FeedNotifier {
  @override
  Future<FeedPageState> build() async => const FeedPageState();
}

class _TestReactionsNotifier extends ReactionsNotifier {
  @override
  Future<ReactionsState> build() async => const ReactionsState();
}

class _TestPipelineWatcher extends FeedPipelineWatcher {
  @override
  void build() {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'exec_id': 'test-exec'});
  });

  testWidgets('App boots and shows the navigation shell', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          campaignsProvider.overrideWith(_TestCampaignsNotifier.new),
          jobDefinitionsProvider.overrideWith(_TestJobDefinitionsNotifier.new),
          feedProvider.overrideWith(_TestFeedNotifier.new),
          globalFeedProvider.overrideWith((ref) async => const []),
          activeCampaignsProvider.overrideWith((ref) async => const []),
          candidateLookupProvider.overrideWith((ref) => const {}),
          reactionsProvider.overrideWith(_TestReactionsNotifier.new),
          feedPipelineWatcherProvider.overrideWith(_TestPipelineWatcher.new),
          notificationsProvider.overrideWith(
            (ref) async => const <AppNotice>[],
          ),
          pipelineStatsProvider.overrideWith(
            (ref) async => const PipelineStats(
              totalCvs: 0,
              extraction: StageCounts(),
              profile: StageCounts(),
              ranking: RankCounts(),
              jobs: 0,
              campaigns: 0,
            ),
          ),
        ],
        child: const CVExecFeedApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Feed'), findsWidgets);
    expect(find.text('Jobs'), findsWidgets);
    expect(find.text('Campaigns'), findsWidgets);
    expect(find.text('Lists'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
  });
}
