import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/stats_provider.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: statsAsync.when(
        data: (stats) {
          if (stats.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(statsProvider.notifier).refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  StateView(
                    icon: Icons.emoji_events_outlined,
                    title: 'No activity yet',
                    subtitle:
                        'Like or star candidates in the Feed to climb the leaderboard.',
                  ),
                ],
              ),
            );
          }

          final totalReviews = stats.fold<int>(0, (a, b) => a + b.totalReviews);
          final totalLikes = stats.fold<int>(0, (a, b) => a + b.likes);
          final totalStars = stats.fold<int>(0, (a, b) => a + b.stars);

          return RefreshIndicator(
            onRefresh: () => ref.read(statsProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _SummaryTile(
                            label: 'Total',
                            value: totalReviews,
                            icon: Icons.fact_check_outlined,
                            color: AppTheme.peacock)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _SummaryTile(
                            label: 'Likes',
                            value: totalLikes,
                            icon: Icons.thumb_up_rounded,
                            color: AppTheme.green)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _SummaryTile(
                            label: 'Stars',
                            value: totalStars,
                            icon: Icons.star_rounded,
                            color: AppTheme.orange)),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionLabel(
                    icon: Icons.leaderboard_outlined, label: 'Leaderboard'),
                const SizedBox(height: 10),
                ...stats.asMap().entries.map(
                      (e) => _LeaderCard(rank: e.key + 1, stat: e.value),
                    ),
              ],
            ),
          );
        },
        loading: () => const LoadingView(label: 'Loading stats…'),
        error: (e, _) => StateView(
          icon: Icons.wifi_off,
          title: 'Could not load stats',
          subtitle: '$e',
          action: LiButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: () => ref.read(statsProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LiCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text('$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  )),
        ],
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final int rank;
  final ExecStat stat;

  const _LeaderCard({required this.rank, required this.stat});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                _RankMedal(rank: rank),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stat.execId,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                LiTag(label: '🔥 ${stat.streakDays}d', color: AppTheme.gold),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(label: 'Total', value: stat.totalReviews),
                _divider(scheme),
                _Metric(label: 'Likes', value: stat.likes),
                _divider(scheme),
                _Metric(label: 'Stars', value: stat.stars),
                _divider(scheme),
                _Metric(label: 'Shortlists', value: stat.shortlists),
                _divider(scheme),
                _Metric(label: 'Passes', value: stat.passes),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme scheme) => Container(
        width: 1,
        height: 28,
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      );
}

class _RankMedal extends StatelessWidget {
  final int rank;
  const _RankMedal({required this.rank});

  @override
  Widget build(BuildContext context) {
    const medals = {
      1: Color(0xFFFACC15),
      2: Color(0xFF94A3B8),
      3: Color(0xFFB45309)
    };
    final color = medals[rank];
    if (color != null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.2),
        child: Text('$rank',
            style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }
}
