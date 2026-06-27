import 'package:cv_exec_feed/data/providers.dart';
import 'package:cv_exec_feed/data/repository_providers.dart';
import 'package:cv_exec_feed/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _dismissedNoticesKey = 'dismissed_notice_signatures';

/// Whether the notifications bell should show as unread.
final notificationsReadProvider = StateProvider<bool>((ref) => false);

final notificationsProvider = FutureProvider<List<AppNotice>>((ref) async {
  final stats = await ref.read(statsRepositoryProvider).pipelineStats();
  return buildNotices(stats);
});

/// Signatures of notices dismissed by swipe (id → title at dismiss time).
class DismissedNoticesNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getStringList(_dismissedNoticesKey) ?? const [];
    final map = <String, String>{};
    for (final entry in raw) {
      final sep = entry.indexOf('\u0000');
      if (sep <= 0) continue;
      map[entry.substring(0, sep)] = entry.substring(sep + 1);
    }
    return map;
  }

  void dismiss(AppNotice notice) {
    final next = Map<String, String>.from(state)..[notice.id] = notice.title;
    _persist(next);
    state = next;
  }

  void _persist(Map<String, String> dismissed) {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = dismissed.entries
        .map((e) => '${e.key}\u0000${e.value}')
        .toList();
    prefs.setStringList(_dismissedNoticesKey, raw);
  }
}

final dismissedNoticesProvider =
    NotifierProvider<DismissedNoticesNotifier, Map<String, String>>(
  DismissedNoticesNotifier.new,
);

bool isNoticeDismissed(AppNotice notice, Map<String, String> dismissed) {
  return dismissed[notice.id] == notice.title;
}

List<AppNotice> visibleNotices(
  List<AppNotice> notices,
  Map<String, String> dismissed,
) {
  return notices.where((n) => !isNoticeDismissed(n, dismissed)).toList();
}

/// Pipeline notices minus ones the user swiped away.
final visibleNotificationsProvider = Provider<AsyncValue<List<AppNotice>>>((ref) {
  final noticesAsync = ref.watch(notificationsProvider);
  final dismissed = ref.watch(dismissedNoticesProvider);
  return noticesAsync.whenData((notices) => visibleNotices(notices, dismissed));
});
