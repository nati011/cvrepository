import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/feed_provider.dart';
import 'package:cv_exec_feed/providers/stats_provider.dart';
import 'package:cv_exec_feed/screens/campaign_detail_screen.dart';
import 'package:cv_exec_feed/screens/cv_viewer_screen.dart';
import 'package:cv_exec_feed/screens/job_detail_screen.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/utils/reaction_actions.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _feedMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatFeedDate(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null || raw.isEmpty) return '';
  return '${_feedMonths[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Opens the candidate detail sheet. Shared by the feed and chat screens.
void showCandidateDetails(BuildContext context, FeedItem item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => _CandidateSheet(item: item),
  );
}

void openJobDetail(BuildContext context, String jobId) {
  if (jobId.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => JobDetailScreen(jobId: jobId),
    ),
  );
}

void openRoleMatch(BuildContext context, RoleMatch role) {
  if (role.jobId.isEmpty) return;
  if (role.kind == RoleKind.campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampaignDetailScreen(campaignId: role.jobId),
      ),
    );
    return;
  }
  openJobDetail(context, role.jobId);
}

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final query = ref.watch(feedSearchProvider).trim().toLowerCase();
    final fit = ref.watch(fitFilterProvider);

    // 2+ chars => switch the body to a real global search (backend /v1/search),
    // mirroring the web top search bar. Filters/feed return when the box clears.
    final searching = query.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: _FitFilters(fit: fit),
          ),
        Expanded(
          child: searching
              ? _SearchResults(query: query)
              : feedAsync.when(
            data: (page) {
              final items = page.items;
              // Rank against the full list, then apply filters so positions stay stable.
              final ranked = [
                for (var i = 0; i < items.length; i++)
                  (item: items[i], rank: i + 1),
              ];
              final visible = ranked.where((r) {
                if (!matchesFeedQuery(r.item, query)) return false;
                if (!matchesFitFilter(r.item, fit)) return false;
                return true;
              }).toList();

              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => refreshFeedBundle(ref),
                  child: ListView(
                    children: const [
                      SizedBox(height: 120),
                      _FeedEmptyState(),
                    ],
                  ),
                );
              }
              if (visible.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: 100),
                    StateView(
                      icon: Icons.search_off_rounded,
                      title: query.isNotEmpty
                          ? 'No candidates match “$query”'
                          : 'No candidates in this filter',
                      subtitle: 'Try a different match level or search term.',
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                onRefresh: () => refreshFeedBundle(ref),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollEndNotification &&
                        n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                      ref.read(feedProvider.notifier).loadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: visible.length + (page.loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index >= visible.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final entry = visible[index];
                    return _FeedCard(
                      item: entry.item,
                      rank: entry.rank,
                    );
                  },
                ),
                ),
              );
            },
            loading: () => const LoadingView(label: 'Ranking candidates…'),
            error: (e, _) => StateView(
              icon: Icons.wifi_off,
              title: 'Could not load the feed',
              subtitle: '$e',
              action: LiButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: () => refreshFeedBundle(ref),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Contextual empty feed message based on pipeline state.
class _FeedEmptyState extends ConsumerWidget {
  const _FeedEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(pipelineStatsProvider).valueOrNull;
    if (stats == null) {
      return const StateView(
        icon: Icons.inbox_outlined,
        title: 'No ranked candidates yet',
        subtitle: 'Upload CVs and create an active campaign to see matches here.',
      );
    }

    final rankingBusy =
        stats.ranking.pending + stats.ranking.processing > 0;
    final profilingBusy =
        stats.profile.pending + stats.profile.processing > 0;
    final extractingBusy =
        stats.extraction.pending + stats.extraction.processing > 0;

    if (extractingBusy || profilingBusy || rankingBusy) {
      return const StateView(
        icon: Icons.hourglass_top_rounded,
        title: 'Processing CVs…',
        subtitle: 'Ranking will appear here once extraction and scoring finish.',
      );
    }

    if (stats.jobs == 0 && stats.totalCvs > 0) {
      return const StateView(
        icon: Icons.campaign_outlined,
        title: 'No active campaigns',
        subtitle:
            'After a data reset, create a campaign so uploaded CVs can be ranked into the feed.',
      );
    }

    if (stats.totalCvs == 0) {
      return const StateView(
        icon: Icons.upload_file_outlined,
        title: 'No CVs uploaded yet',
        subtitle: 'Upload CVs on the web library, then rank them against a campaign.',
      );
    }

    return const StateView(
      icon: Icons.inbox_outlined,
      title: 'No ranked candidates yet',
      subtitle: 'Pull to refresh, or trigger ranking from the campaign screen.',
    );
  }
}

/// Global search results — hits the backend `/v1/search` endpoint (the same
/// API behind the web top search bar) and lists matching CVs. Tapping a result
/// that's already ranked in the feed opens its full candidate profile.
class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchResultsProvider);
    final lookup = ref.watch(candidateLookupProvider);
    final scheme = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const LoadingView(label: 'Searching all CVs…'),
      error: (e, _) => StateView(
        icon: Icons.wifi_off,
        title: 'Search failed',
        subtitle: '$e',
        action: LiButton(
          label: 'Retry',
          icon: Icons.refresh,
          onPressed: () => ref.invalidate(searchResultsProvider),
        ),
      ),
      data: (hits) {
        if (hits.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 100),
              StateView(
                icon: Icons.search_off_rounded,
                title: 'No CVs match “$query”',
                subtitle:
                    'Try different keywords — skills, titles, or filenames.',
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: hits.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Text(
                  '${hits.length} result${hits.length == 1 ? '' : 's'} for “$query”',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              );
            }
            final hit = hits[index - 1];
            final candidate = lookup[hit.id];
            final inFeed = candidate != null;
            return LiCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onTap: () {
                if (candidate != null) {
                  showCandidateDetails(context, candidate);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('“${hit.label}” isn’t ranked against a role yet.'),
                    ),
                  );
                }
              },
              child: LiEntityTile(
                initials: hit.initials,
                title: hit.label,
                subtitle: hit.originalFilename.isNotEmpty
                    ? hit.originalFilename
                    : 'CV document',
                trailing: inFeed
                    ? Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant)
                    : Text(
                        'CV',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Match-level filter chips: All, Strong, Solid, Emerging.
class _FitFilters extends ConsumerWidget {
  final int fit;

  const _FitFilters({required this.fit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiFilterBar(
      labels: fitFilterLabels,
      selectedIndex: fit,
      onSelected: (i) => ref.read(fitFilterProvider.notifier).state = i,
    );
  }
}

class _FeedCard extends ConsumerStatefulWidget {
  final FeedItem item;
  final int rank;

  const _FeedCard({
    required this.item,
    required this.rank,
  });

  @override
  ConsumerState<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends ConsumerState<_FeedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  FeedItem get item => widget.item;

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = watchReactionAction(ref, item, global: true);

    return Card(
      child: InkWell(
        onTap: () => _showDetails(context),
        onDoubleTap: () => _react('like', 'Liked'),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostHeader(
                    item: item,
                    rank: widget.rank,
                  ),
                  if (item.subscores.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SubscoreRow(subscores: item.subscores),
                  ],
                  if (item.tldr.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      item.tldr,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.4),
                    ),
                  ],
                  if (item.skills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.skills
                          .take(6)
                          .map((s) => _HashtagChip(label: s))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _RoleMatchesList(item: item),
                  Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 4),
                  _ReactionBar(
                    selected: selected,
                    onReact: (action, verb) => _react(action, verb),
                    onDetail: () => _showDetails(context),
                  ),
                ],
              ),
            ),
            _HeartBurst(controller: _burst),
          ],
        ),
      ),
    );
  }

  Future<void> _react(String action, String verb) async {
    if (action == 'like' &&
        watchReactionAction(ref, item, global: true) != 'like') {
      _burst.forward(from: 0);
    }
    await handleReaction(
      ref,
      context,
      item: item,
      action: action,
      verb: verb,
      global: true,
    );
  }

  void _showDetails(BuildContext context) => showCandidateDetails(context, item);
}

class _PostHeader extends StatelessWidget {
  final FeedItem item;
  final int rank;
  const _PostHeader({
    required this.item,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headline = item.experience.isNotEmpty
        ? [item.experience.first.title, item.experience.first.company]
            .where((s) => s.isNotEmpty)
            .join('  ·  ')
        : (item.totalYears > 0 ? '${item.totalYears}y experience' : 'Candidate');
    final dateLabel = formatFeedDate(item.scoredAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(initials: item.initials, rank: rank),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 1),
              Text(
                [
                  if (dateLabel.isNotEmpty) dateLabel,
                  'Ranked #$rank',
                ].join(' · '),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        ScoreBadge(score: item.score),
      ],
    );
  }
}

/// Role match breakdown for each active campaign the candidate was scored against.
class _RoleMatchesList extends StatelessWidget {
  final FeedItem item;
  const _RoleMatchesList({required this.item});

  @override
  Widget build(BuildContext context) {
    final roles = item.displayRoles;
    if (roles.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Role matches',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
        ),
        const SizedBox(height: 8),
        ...roles.map((role) => _RoleMatchRow(role: role)),
      ],
    );
  }
}

class _RoleMatchRow extends StatelessWidget {
  final RoleMatch role;
  const _RoleMatchRow({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.scoreColor(role.score);
    final isStrong = role.score >= 80;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: role.jobId.isEmpty
              ? null
              : () => openRoleMatch(context, role),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _titleCase(role.jobTitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                  ),
                ),
                if (isStrong) ...[
                  Icon(Icons.star_rounded, size: 14, color: AppTheme.gold),
                  const SizedBox(width: 4),
                ],
                Text(
                  '${role.score}%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (role.jobId.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Big translucent heart that pops on double-tap, Instagram-style.
class _HeartBurst extends StatelessWidget {
  final AnimationController controller;
  const _HeartBurst({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isDismissed) return const SizedBox.shrink();
          final t = controller.value;
          final scale = 0.6 + (t < 0.4 ? t / 0.4 : 1) * 0.7;
          final opacity = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Icon(
                Icons.thumb_up_rounded,
                size: 88,
                color: AppTheme.peacock,
                shadows: [
                  Shadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final int rank;
  const _Avatar({required this.initials, required this.rank});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LiAvatar(initials: initials, size: 48),
        if (rank > 0)
          Positioned(
            top: -6,
            left: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: rank <= 3 ? AppTheme.gold : scheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.surface, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: rank <= 3 ? Colors.white : scheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Social-style hashtag chip for skills (e.g. #golang).
class _HashtagChip extends StatelessWidget {
  final String label;
  const _HashtagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tag = label.replaceAll(RegExp(r'\s+'), '');
    return Text(
      '#$tag',
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: scheme.primary,
      ),
    );
  }
}

class _SubscoreRow extends StatelessWidget {
  final Map<String, int> subscores;
  const _SubscoreRow({required this.subscores});

  static const _allowed = {'skills', 'seniority', 'domain'};

  @override
  Widget build(BuildContext context) {
    final entries = subscores.entries
        .where((e) => _allowed.contains(e.key.toLowerCase()))
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          Expanded(child: _SubscoreBar(label: entries[i].key, value: entries[i].value)),
          if (i != entries.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SubscoreBar extends StatelessWidget {
  final String label;
  final int value;
  const _SubscoreBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppTheme.scoreColor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0, 100) / 100,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text('$value', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// Feed action row: Like, Star, and a chevron to open details.
class _ReactionBar extends StatelessWidget {
  final String? selected;
  final void Function(String action, String verb) onReact;
  final VoidCallback onDetail;

  const _ReactionBar({
    required this.selected,
    required this.onReact,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: LiActionButton(
            filledIcon: Icons.thumb_up_rounded,
            outlineIcon: Icons.thumb_up_outlined,
            label: 'Like',
            color: AppTheme.blue,
            active: selected == 'like',
            onTap: () => onReact('like', 'Liked'),
          ),
        ),
        Expanded(
          child: LiActionButton(
            filledIcon: Icons.star_rounded,
            outlineIcon: Icons.star_outline_rounded,
            label: 'Star',
            color: AppTheme.gold,
            active: selected == 'star',
            onTap: () => onReact('star', 'Starred'),
          ),
        ),
        IconButton(
          tooltip: 'Details',
          onPressed: onDetail,
          icon: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CandidateSheet extends ConsumerWidget {
  final FeedItem item;
  const _CandidateSheet({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              _ProfileHeader(item: item),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item.tldr.isNotEmpty)
                      _ProfileSectionCard(
                        icon: Icons.summarize_outlined,
                        title: 'Overview',
                        child: Text(
                          item.tldr,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(height: 1.5),
                        ),
                      ),
                    if (item.displayRoles.isNotEmpty)
                      _ProfileSectionCard(
                        icon: Icons.work_outline,
                        title: 'Role matches',
                        child: Column(
                          children: [
                            for (var i = 0; i < item.displayRoles.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.45),
                                ),
                              _ProfileRoleMatchRow(role: item.displayRoles[i]),
                            ],
                          ],
                        ),
                      ),
                    if (_hasAtAGlance(item))
                      _ProfileSectionCard(
                        icon: Icons.person_outline,
                        title: 'At a glance',
                        child: _AtAGlanceBody(item: item),
                      ),
                    if (item.subscores.isNotEmpty)
                      _ProfileSectionCard(
                        icon: Icons.analytics_outlined,
                        title: 'Fit breakdown',
                        child: _SubscoreRow(subscores: item.subscores),
                      ),
                    if (item.strengths.isNotEmpty)
                      _ProfileSectionCard(
                        icon: Icons.thumb_up_outlined,
                        title: 'Strengths',
                        accent: AppTheme.green,
                        child: _ProfileBulletList(
                          items: item.strengths,
                          accent: AppTheme.green,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                    if (item.gaps.isNotEmpty)
                      _ProfileSectionCard(
                        icon: Icons.help_outline,
                        title: 'Gaps',
                        accent: AppTheme.gold,
                        child: _ProfileBulletList(
                          items: item.gaps,
                          accent: AppTheme.gold,
                          icon: Icons.info_outline,
                        ),
                      ),
                    if (item.redFlags.isNotEmpty)
                      _ProfileSectionCard(
                        icon: Icons.flag_outlined,
                        title: 'Red flags',
                        accent: AppTheme.danger,
                        child: _ProfileBulletList(
                          items: item.redFlags,
                          accent: AppTheme.danger,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                    if (item.experience.isNotEmpty)
                      _ProfileSectionCard(
                        icon: Icons.work_history_outlined,
                        title: 'Experience',
                        child: Builder(
                          builder: (context) {
                            final experiences = item.experience.take(8).toList();
                            return Column(
                              children: [
                                for (var i = 0; i < experiences.length; i++)
                                  _ExperienceTile(
                                    exp: experiences[i],
                                    isLast: i == experiences.length - 1,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    if (item.evidence.isNotEmpty)
                      _ProfileSectionCard(
                        icon: Icons.format_quote,
                        title: 'Evidence',
                        child: Column(
                          children: item.evidence
                              .map((e) => _EvidenceTile(evidence: e))
                              .toList(),
                        ),
                      ),
                    if (item.suggestedQuestions.isNotEmpty)
                      _ProfileSectionCard(
                        icon: Icons.quiz_outlined,
                        title: 'Suggested questions',
                        accent: Theme.of(context).colorScheme.primary,
                        child: _ProfileBulletList(
                          items: item.suggestedQuestions,
                          accent: Theme.of(context).colorScheme.primary,
                          icon: Icons.chat_bubble_outline,
                          numbered: true,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _hasAtAGlance(FeedItem item) =>
    item.location.isNotEmpty ||
    item.contact.isNotEmpty ||
    item.totalYears > 0 ||
    item.skills.isNotEmpty;

class _ProfileSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? accent;
  final Widget child;

  const _ProfileSectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(icon: icon, label: title, color: accent),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfileRoleMatchRow extends StatelessWidget {
  final RoleMatch role;
  const _ProfileRoleMatchRow({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.scoreColor(role.score);
    final isStrong = role.score >= 80;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: role.jobId.isEmpty
            ? null
            : () => openRoleMatch(context, role),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _titleCase(role.jobTitle),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (isStrong) ...[
                const Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
                const SizedBox(width: 4),
              ],
              Text(
                '${role.score}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (role.jobId.isNotEmpty) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AtAGlanceBody extends StatelessWidget {
  final FeedItem item;
  const _AtAGlanceBody({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.totalYears > 0)
          _MetaRow(
            icon: Icons.schedule_outlined,
            label: '${item.totalYears} years experience',
          ),
        if (item.location.isNotEmpty)
          _MetaRow(icon: Icons.location_on_outlined, label: item.location),
        if (item.contact.isNotEmpty)
          _MetaRow(icon: Icons.mail_outline, label: item.contact),
        if (item.skills.isNotEmpty) ...[
          if (item.totalYears > 0 ||
              item.location.isNotEmpty ||
              item.contact.isNotEmpty)
            const SizedBox(height: 12),
          Text(
            'Skills',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: item.skills
                .take(12)
                .map((s) => LiTag(label: s, color: scheme.primary))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBulletList extends StatelessWidget {
  final List<String> items;
  final Color accent;
  final IconData icon;
  final bool numbered;

  const _ProfileBulletList({
    required this.items,
    required this.accent,
    required this.icon,
    this.numbered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.14)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (numbered)
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    )
                  else
                    Icon(icon, size: 17, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i],
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// LinkedIn-style profile header: brand cover banner, large overlapping
/// avatar, name/headline, pill action buttons, and a "Match level" bar.
class _ProfileHeader extends ConsumerWidget {
  final FeedItem item;
  const _ProfileHeader({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selected = watchReactionAction(ref, item, global: true);

    final headline = item.experience.isNotEmpty
        ? [item.experience.first.title, item.experience.first.company]
            .where((s) => s.isNotEmpty)
            .join('  ·  ')
        : (item.jobTitle.isNotEmpty
            ? 'Candidate · ${_titleCase(item.jobTitle)}'
            : 'Candidate');
    final meta = item.totalYears > 0 ? '${item.totalYears}y experience' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover banner + overlapping avatar.
        SizedBox(
          height: 132,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 92,
                decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 40,
                      bottom: -40,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: _MatchChip(score: item.score),
              ),
              Positioned(
                left: 20,
                top: 92 - 44,
                child: LiAvatar(initials: item.initials, size: 80, ring: true),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(headline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.3,
                      )),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(meta,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: LiButton(
                      label: selected == 'like' ? 'Liked' : 'Like',
                      icon: selected == 'like'
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_up_outlined,
                      expand: true,
                      onPressed: () => handleReaction(
                          ref, context,
                          item: item, action: 'like', verb: 'Liked', global: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiButton(
                      label: selected == 'star' ? 'Starred' : 'Star',
                      icon: selected == 'star'
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      variant: LiButtonVariant.secondary,
                      color: AppTheme.gold,
                      expand: true,
                      onPressed: () => handleReaction(
                          ref, context,
                          item: item, action: 'star', verb: 'Starred', global: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LiButton(
                label: 'View original CV',
                icon: Icons.picture_as_pdf_outlined,
                variant: LiButtonVariant.secondary,
                expand: true,
                onPressed: () => openOriginalCv(
                  context,
                  cvId: item.cvId,
                  title: item.fileName.isNotEmpty ? item.fileName : item.name,
                ),
              ),
              const SizedBox(height: 18),
              _MatchLevel(score: item.score),
              const SizedBox(height: 4),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Translucent "% match" chip shown on the cover banner.
class _MatchChip extends StatelessWidget {
  final int score;
  const _MatchChip({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: AppTheme.scoreColor(score), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$score% match',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink)),
        ],
      ),
    );
  }
}

/// Large profile avatar with a white ring, overlapping the cover banner.
/// "Match level" segmented bar, mirroring LinkedIn's "Profile level: Advanced".
class _MatchLevel extends StatelessWidget {
  final int score;
  const _MatchLevel({required this.score});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppTheme.scoreColor(score);
    final filled = (score / 20).round().clamp(1, 5);
    final label = score >= 80
        ? 'Strong'
        : score >= 60
            ? 'Solid'
            : 'Emerging';
    return Row(
      children: [
        Text('Match level: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                )),
        Text(label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < 5; i++) ...[
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < filled
                          ? color
                          : scheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (i != 4) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        if (score >= 80) ...[
          const SizedBox(width: 8),
          Icon(Icons.star_rounded, size: 18, color: color),
        ],
      ],
    );
  }
}

class _ExperienceTile extends StatelessWidget {
  final Experience exp;
  final bool isLast;
  const _ExperienceTile({required this.exp, this.isLast = true});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exp.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (exp.company.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      exp.company,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  if (exp.range.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      exp.range,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  final Evidence evidence;
  const _EvidenceTile({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  evidence.claim,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (evidence.quote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '“${evidence.quote}”',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
