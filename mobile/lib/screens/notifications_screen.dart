import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/app_provider.dart';
import 'package:cv_exec_feed/providers/notifications_provider.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void openNotificationsScreen(BuildContext context, WidgetRef ref) {
  ref.read(notificationsReadProvider.notifier).state = true;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
  );
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(visibleNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(notificationsProvider),
          ),
        ],
      ),
      body: noticesAsync.when(
        loading: () => const LoadingView(label: 'Loading notifications…'),
        error: (e, _) => StateView(
          icon: Icons.wifi_off,
          title: 'Could not load notifications',
          subtitle: '$e',
          action: LiButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: () => ref.invalidate(notificationsProvider),
          ),
        ),
        data: (notices) {
          if (notices.isEmpty) {
            return const StateView(
              icon: Icons.notifications_none_outlined,
              title: "You're all caught up",
              subtitle: 'No pipeline updates right now.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: notices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _DismissibleNoticeTile(notice: notices[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _DismissibleNoticeTile extends ConsumerWidget {
  final AppNotice notice;

  const _DismissibleNoticeTile({required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('${notice.id}:${notice.title}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(dismissedNoticesProvider.notifier).dismiss(notice);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: _NoticeTile(notice: notice),
    );
  }
}

class _NoticeTile extends ConsumerWidget {
  final AppNotice notice;

  const _NoticeTile({required this.notice});

  Color _toneColor(NoticeTone tone) => switch (tone) {
        NoticeTone.success => AppTheme.green,
        NoticeTone.warning => AppTheme.danger,
        NoticeTone.progress => AppTheme.blue,
        NoticeTone.info => AppTheme.blue,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = _toneColor(notice.tone);

    return LiCard(
      padding: const EdgeInsets.all(14),
      onTap: notice.tabIndex == null
          ? null
          : () {
              Navigator.pop(context);
              ref.read(appProvider.notifier).setTab(notice.tabIndex!);
            },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  notice.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
