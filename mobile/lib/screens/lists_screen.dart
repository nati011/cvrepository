import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/list_providers.dart';
import 'package:cv_exec_feed/providers/reactions_provider.dart';
import 'package:cv_exec_feed/screens/feed_screen.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/utils/reaction_actions.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  int _segment = 0;
  bool _dashboardExpanded = false;

  @override
  Widget build(BuildContext context) {
    final liked = ref.watch(likedCandidatesProvider);
    final starred = ref.watch(starredCandidatesProvider);
    final items = _segment == 0 ? liked : starred;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _MyScoreDashboard(
            liked: liked,
            starred: starred,
            expanded: _dashboardExpanded,
            onToggle: () =>
                setState(() => _dashboardExpanded = !_dashboardExpanded),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiFilterChip(
                  label: 'Liked (${liked.length})',
                  icon: Icons.thumb_up_outlined,
                  color: AppTheme.blue,
                  selected: _segment == 0,
                  onTap: () => setState(() => _segment = 0),
                ),
                const SizedBox(width: 8),
                LiFilterChip(
                  label: 'Starred (${starred.length})',
                  icon: Icons.star_outline_rounded,
                  color: AppTheme.gold,
                  selected: _segment == 1,
                  onTap: () => setState(() => _segment = 1),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? RefreshIndicator(
                  onRefresh: () =>
                      ref.read(reactionsProvider.notifier).refresh(),
                  child: ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      StateView(
                        icon: _segment == 0
                            ? Icons.thumb_up_off_alt
                            : Icons.star_outline_rounded,
                        title: _segment == 0
                            ? 'No liked candidates'
                            : 'No starred candidates',
                        subtitle: _segment == 0
                            ? 'Like candidates in the Feed to track ones you enjoy.'
                            : 'Star candidates you want to revisit later.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(reactionsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = items[index];
                      return _ListCandidateCard(
                        entry: entry,
                        segment: _segment,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _MyScoreDashboard extends StatelessWidget {
  final List<ListEntry> liked;
  final List<ListEntry> starred;
  final bool expanded;
  final VoidCallback onToggle;

  const _MyScoreDashboard({
    required this.liked,
    required this.starred,
    required this.expanded,
    required this.onToggle,
  });

  int get _total => liked.length + starred.length;

  int? get _avgMatch {
    final all = [...liked, ...starred];
    if (all.isEmpty) return null;
    final sum = all.fold<int>(0, (a, b) => a + b.item.score);
    return (sum / all.length).round();
  }

  int? get _topMatch {
    final all = [...liked, ...starred];
    if (all.isEmpty) return null;
    return all.map((e) => e.item.score).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = _total == 0
        ? 'Like or star candidates in the Feed to build your score.'
        : '${liked.length} liked · ${starred.length} starred';

    return LiCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      size: 18,
                      color: AppTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Score',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DashMetric(
                          label: 'Liked',
                          value: '${liked.length}',
                          color: AppTheme.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DashMetric(
                          label: 'Starred',
                          value: '${starred.length}',
                          color: AppTheme.gold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DashMetric(
                          label: 'Avg match',
                          value: _avgMatch == null ? '—' : '$_avgMatch%',
                          color: AppTheme.peacock,
                        ),
                      ),
                    ],
                  ),
                  if (_topMatch != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: LiTag(
                        label: 'Top match $_topMatch%',
                        color: AppTheme.scoreColor(_topMatch!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _DashMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DashMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ListCandidateCard extends ConsumerWidget {
  final ListEntry entry;
  final int segment;
  const _ListCandidateCard({required this.entry, required this.segment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final item = entry.item;
    final action = segment == 0 ? 'like' : 'star';
    final verb = segment == 0 ? 'Liked' : 'Starred';
    final label = segment == 0 ? 'Liked' : 'Starred';
    final dateLabel = formatFeedDate(entry.reaction.createdAt);

    return LiCard(
      onTap: () => showCandidateDetails(context, item),
      child: Row(
        children: [
          LiAvatar(initials: item.initials, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (item.jobTitle.isNotEmpty)
                  Text(
                    item.jobTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                Text(
                  '${item.score}% match',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.scoreColor(item.score),
                  ),
                ),
                if (dateLabel.isNotEmpty)
                  Text(
                    '$label · $dateLabel',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => handleReaction(
              ref,
              context,
              item: item,
              action: action,
              verb: verb,
              global: true,
            ),
            icon: Icon(
              segment == 0 ? Icons.thumb_up_rounded : Icons.star_rounded,
              color: segment == 0 ? AppTheme.blue : AppTheme.gold,
            ),
          ),
        ],
      ),
    );
  }
}
