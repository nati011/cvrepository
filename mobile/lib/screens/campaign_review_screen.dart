import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/campaign_feed_provider.dart';
import 'package:cv_exec_feed/providers/campaigns_provider.dart';
import 'package:cv_exec_feed/providers/reactions_provider.dart';
import 'package:cv_exec_feed/screens/feed_screen.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/utils/reaction_actions.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CampaignReviewScreen extends ConsumerWidget {
  final String campaignId;
  const CampaignReviewScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(campaignsProvider);
    final feedAsync = ref.watch(campaignFeedProvider(campaignId));
    final statsAsync = ref.watch(campaignStatsProvider(campaignId));

    return Scaffold(
      appBar: AppBar(
        title: jobsAsync.when(
          data: (jobs) {
            final job = jobs.where((j) => j.id == campaignId).firstOrNull;
            return Text(job?.title.isNotEmpty == true ? job!.title : 'Review');
          },
          loading: () => const Text('Review'),
          error: (_, __) => const Text('Review'),
        ),
      ),
      body: feedAsync.when(
        loading: () => const LoadingView(label: 'Loading candidates…'),
        error: (e, _) => StateView(
          icon: Icons.wifi_off,
          title: 'Could not load candidates',
          subtitle: '$e',
        ),
        data: (ranked) {
          if (ranked.isEmpty) {
            return const StateView(
              icon: Icons.people_outline,
              title: 'No ranked candidates',
              subtitle: 'Rank CVs against this role to start reviewing.',
            );
          }

          final progress = statsAsync.valueOrNull;
          final reviewed = progress?.reviewedCount ?? 0;
          final total = progress?.rankedCount ?? ranked.length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(campaignFeedProvider(campaignId));
              ref.invalidate(campaignStatsProvider(campaignId));
              await ref.read(reactionsProvider.notifier).refresh();
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: ranked.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$reviewed / $total reviewed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  );
                }
                final entry = ranked[index - 1];
                return _ReviewCard(
                  item: entry.item,
                  rank: entry.rank,
                  campaignId: campaignId,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  final FeedItem item;
  final int rank;
  final String campaignId;

  const _ReviewCard({
    required this.item,
    required this.rank,
    required this.campaignId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selected = watchReactionAction(
      ref,
      item,
      jobId: campaignId,
    );

    return Card(
      child: InkWell(
        onTap: () => showCandidateDetails(context, item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      '#$rank',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
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
                  LiTag(
                    label: '${item.score}%',
                    color: AppTheme.scoreColor(item.score),
                  ),
                ],
              ),
              if (item.tldr.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  item.tldr,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.4),
                ),
              ],
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: LiActionButton(
                      filledIcon: Icons.thumb_up_rounded,
                      outlineIcon: Icons.thumb_up_outlined,
                      label: 'Shortlist',
                      color: AppTheme.green,
                      active: selected == 'shortlist',
                      onTap: () => handleReaction(
                        ref,
                        context,
                        item: item,
                        action: 'shortlist',
                        verb: 'Shortlisted',
                        jobId: campaignId,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LiActionButton(
                      filledIcon: Icons.block_rounded,
                      outlineIcon: Icons.block_outlined,
                      label: 'Pass',
                      color: AppTheme.danger,
                      active: selected == 'pass',
                      onTap: () => handleReaction(
                        ref,
                        context,
                        item: item,
                        action: 'pass',
                        verb: 'Passed',
                        jobId: campaignId,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Details',
                    onPressed: () => showCandidateDetails(context, item),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
