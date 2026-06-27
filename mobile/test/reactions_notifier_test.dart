import 'package:cv_exec_feed/data/api_client.dart';
import 'package:cv_exec_feed/data/repositories/reactions_repository.dart';
import 'package:cv_exec_feed/data/repository_providers.dart';
import 'package:cv_exec_feed/data/providers.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/reactions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReactionsRepository extends ReactionsRepository {
  FakeReactionsRepository() : super(ApiClient(baseUrl: 'http://test'));

  final List<Reaction> store = [];
  int nextId = 1;

  @override
  Future<ReactionResult> add({
    required String cvId,
    required String action,
    String? jobId,
    required String execId,
  }) async {
    final id = 'r-${nextId++}';
    store.add(Reaction(
      id: id,
      cvId: cvId,
      jobId: jobId,
      execId: execId,
      action: action,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ));
    return ReactionResult(id: id, action: action);
  }

  @override
  Future<void> remove({required String id, required String execId}) async {
    store.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<Reaction>> list({
    required String execId,
    String? jobId,
    String? action,
  }) async {
    return store
        .where((r) => r.execId == execId)
        .where((r) => jobId == null || r.jobId == jobId)
        .where((r) => action == null || r.action == action)
        .toList();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'exec_id': 'test-exec'});
  });

  test('ReactionsNotifier hydrates and toggles campaign shortlist', () async {
    final prefs = await SharedPreferences.getInstance();
    final fakeRepo = FakeReactionsRepository();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reactionsRepositoryProvider.overrideWith((ref) => fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    fakeRepo.store.add(Reaction(
      id: 'r-0',
      cvId: 'cv-1',
      jobId: 'job-1',
      execId: 'test-exec',
      action: 'shortlist',
      createdAt: '2026-01-01T00:00:00Z',
    ));

    await container.read(reactionsProvider.future);
    final notifier = container.read(reactionsProvider.notifier);
    expect(notifier.actionFor('cv-1', jobId: 'job-1'), 'shortlist');

    await notifier.toggleReaction(
      cvId: 'cv-2',
      action: 'star',
      jobId: 'job-1',
      verb: 'Starred',
    );
    expect(notifier.actionFor('cv-2', jobId: 'job-1'), 'star');
    expect(fakeRepo.store.where((r) => r.cvId == 'cv-2').length, 1);

    await notifier.toggleReaction(
      cvId: 'cv-2',
      action: 'star',
      jobId: 'job-1',
      verb: 'Starred',
    );
    expect(notifier.actionFor('cv-2', jobId: 'job-1'), isNull);
  });

  test('Global like does not collide with campaign shortlist', () async {
    final prefs = await SharedPreferences.getInstance();
    final fakeRepo = FakeReactionsRepository();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reactionsRepositoryProvider.overrideWith((ref) => fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(reactionsProvider.future);
    final notifier = container.read(reactionsProvider.notifier);

    await notifier.toggleReaction(
      cvId: 'cv-1',
      action: 'like',
      jobId: null,
      verb: 'Liked',
    );
    await notifier.toggleReaction(
      cvId: 'cv-1',
      action: 'shortlist',
      jobId: 'job-1',
      verb: 'Shortlisted',
    );

    expect(notifier.actionFor('cv-1', jobId: null), 'like');
    expect(notifier.actionFor('cv-1', jobId: 'job-1'), 'shortlist');
  });

  test('ReactionsNotifier persists pass reactions for campaigns', () async {
    final prefs = await SharedPreferences.getInstance();
    final fakeRepo = FakeReactionsRepository();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reactionsRepositoryProvider.overrideWith((ref) => fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(reactionsProvider.future);

    await container.read(reactionsProvider.notifier).toggleReaction(
          cvId: 'cv-9',
          action: 'pass',
          jobId: 'job-1',
          verb: 'Passed',
        );

    expect(
      fakeRepo.store.any(
          (r) => r.cvId == 'cv-9' && r.action == 'pass' && r.jobId == 'job-1'),
      isTrue,
    );
  });
}
