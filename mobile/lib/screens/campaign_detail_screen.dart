import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/campaign_feed_provider.dart';
import 'package:cv_exec_feed/providers/jobs_provider.dart';
import 'package:cv_exec_feed/screens/campaign_review_screen.dart';
import 'package:cv_exec_feed/screens/feed_screen.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/utils/campaign_actions.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CampaignDetailScreen extends ConsumerStatefulWidget {
  final String campaignId;
  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  ConsumerState<CampaignDetailScreen> createState() =>
      _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  int _candidateTab = 0;

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider);
    final statsAsync = ref.watch(campaignStatsProvider(widget.campaignId));
    final candidatesAsync =
        ref.watch(campaignFeedProvider(widget.campaignId));
    final reviewed = ref.watch(campaignReviewedProvider(widget.campaignId));
    final shortlisted =
        ref.watch(campaignShortlistedProvider(widget.campaignId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign'),
        actions: [
          if (jobsAsync.valueOrNull
                  ?.where((j) => j.id == widget.campaignId)
                  .firstOrNull
                  ?.canDeactivate ??
              false)
            IconButton(
              icon: const Icon(Icons.block_outlined),
              tooltip: 'Deactivate',
              onPressed: () async {
                final job = jobsAsync.valueOrNull
                    ?.where((j) => j.id == widget.campaignId)
                    .firstOrNull;
                if (job != null && context.mounted) {
                  final ok =
                      await confirmDeactivateCampaign(context, ref, job);
                  if (ok && context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: jobsAsync.when(
        loading: () => const LoadingView(label: 'Loading…'),
        error: (e, _) => StateView(
          icon: Icons.wifi_off,
          title: 'Could not load campaign',
          subtitle: '$e',
        ),
        data: (jobs) {
          final job = jobs.where((j) => j.id == widget.campaignId).firstOrNull;
          if (job == null) {
            return const StateView(
              icon: Icons.campaign_outlined,
              title: 'Campaign not found',
            );
          }

          final allCandidates =
              ref.watch(campaignCandidatesProvider(widget.campaignId));
          final tabCandidates = switch (_candidateTab) {
            1 => reviewed,
            2 => shortlisted,
            _ => allCandidates,
          };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                job.title.isEmpty ? 'Untitled role' : job.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _StatusChip(status: job.status),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  job.isDeactivated
                      ? 'This campaign is deactivated. Title and description are read-only.'
                      : 'Title and description are locked after creation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (job.metadataSubtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  job.metadataSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              _MetadataBlock(job: job),
              const SizedBox(height: 16),
              statsAsync.when(
                data: (st) => _StatsGrid(stats: st),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              LiButton(
                label: 'Review candidates',
                icon: Icons.fact_check_outlined,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CampaignReviewScreen(
                        campaignId: widget.campaignId,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Candidates',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CandidateTabChip(
                      label: 'All ranked (${allCandidates.length})',
                      selected: _candidateTab == 0,
                      onTap: () => setState(() => _candidateTab = 0),
                    ),
                    const SizedBox(width: 8),
                    _CandidateTabChip(
                      label: 'Reviewed (${reviewed.length})',
                      selected: _candidateTab == 1,
                      onTap: () => setState(() => _candidateTab = 1),
                    ),
                    const SizedBox(width: 8),
                    _CandidateTabChip(
                      label: 'Shortlisted (${shortlisted.length})',
                      selected: _candidateTab == 2,
                      onTap: () => setState(() => _candidateTab = 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              candidatesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (_) {
                  if (tabCandidates.isEmpty) {
                    return StateView(
                      icon: Icons.people_outline,
                      title: _candidateTab == 2
                          ? 'No shortlisted candidates'
                          : _candidateTab == 1
                              ? 'No reviewed candidates yet'
                              : 'No ranked candidates',
                      subtitle: _candidateTab == 0
                          ? 'Rank CVs against this role to see candidates here.'
                          : 'Review candidates to shortlist or pass on them.',
                    );
                  }
                  return Column(
                    children: [
                      for (final c in tabCandidates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CandidateRow(candidate: c),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Job description',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(job.jdText),
            ],
          );
        },
      ),
    );
  }
}

class _MetadataBlock extends ConsumerWidget {
  final Job job;
  const _MetadataBlock({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankAsync = ref.watch(rankStatusProvider(job.id));
    final scheme = Theme.of(context).colorScheme;
    final lines = <String>[];
    if (job.hiringManager.isNotEmpty) {
      lines.add('Hiring manager: ${job.hiringManager}');
    }
    if (job.headcount != null) lines.add('Headcount: ${job.headcount}');
    if (job.startDate != null && job.startDate!.isNotEmpty) {
      lines.add('Start: ${job.startDate}');
    }
    if (job.endDate != null && job.endDate!.isNotEmpty) {
      lines.add('End: ${job.endDate}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        rankAsync.when(
          data: (st) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LiTag(
              label: st.isActive
                  ? 'Ranking… ${st.done}/${st.total}'
                  : '${st.done} ranked',
              color: AppTheme.peacock,
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        if (job.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: job.tags.map((t) => LiTag(label: t)).toList(),
          ),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              line,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }
}

class _CandidateTabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CandidateTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiFilterChip(
      label: label,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final CampaignCandidate candidate;
  const _CandidateRow({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = candidate.item;
    final reaction = candidate.reactionAction;

    return LiCard(
      onTap: () => showCandidateDetails(context, item),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#${candidate.rank}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          LiAvatar(initials: item.initials, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (item.experience.isNotEmpty)
                  Text(
                    item.experience.first.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          if (reaction != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ReactionBadge(action: reaction),
            ),
          LiTag(
            label: '${item.score}%',
            color: AppTheme.scoreColor(item.score),
          ),
        ],
      ),
    );
  }
}

class _ReactionBadge extends StatelessWidget {
  final String action;
  const _ReactionBadge({required this.action});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (action) {
      'shortlist' => (Icons.thumb_up_rounded, AppTheme.green, 'Shortlisted'),
      'pass' => (Icons.block_rounded, AppTheme.danger, 'Passed'),
      'star' => (Icons.star_rounded, AppTheme.gold, 'Starred'),
      _ => (Icons.check_circle_outline, AppTheme.blue, 'Reviewed'),
    };
    return Tooltip(
      message: label,
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final CampaignStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatTile(label: 'Ranked', value: '${stats.rankedCount}'),
        _StatTile(label: 'Reviewed', value: '${stats.reviewedCount}'),
        _StatTile(label: 'Shortlisted', value: '${stats.shortlist}'),
        _StatTile(label: 'Passed', value: '${stats.pass}'),
        if (stats.avgScore != null)
          _StatTile(label: 'Avg score', value: stats.avgScore!.toStringAsFixed(1)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return LiTag(label: status, color: AppTheme.peacock);
  }
}
