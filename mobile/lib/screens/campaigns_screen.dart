import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/screens/campaign_review_screen.dart';
import 'package:cv_exec_feed/providers/campaigns_provider.dart';
import 'package:cv_exec_feed/screens/campaign_detail_screen.dart';
import 'package:cv_exec_feed/screens/campaign_editor.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/utils/campaign_actions.dart';
import 'package:cv_exec_feed/utils/snackbar.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _statusFilters = <({String? value, String label})>[
  (value: null, label: 'Open'),
  (value: 'active', label: 'Active'),
  (value: 'draft', label: 'Draft'),
  (value: 'paused', label: 'Paused'),
  (value: 'closed', label: 'Closed'),
  (value: 'archived', label: 'Archived'),
];

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(campaignsProvider);
    final statusFilter = ref.watch(campaignStatusFilterProvider);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final f = _statusFilters[index];
                final selected = statusFilter == f.value;
                return LiFilterChip(
                  label: f.label,
                  selected: selected,
                  onTap: () {
                    ref.read(campaignStatusFilterProvider.notifier).state =
                        f.value;
                    ref.invalidate(campaignsProvider);
                  },
                );
              },
            ),
          ),
          Expanded(
            child: jobsAsync.when(
              data: (jobs) {
                if (jobs.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.read(campaignsProvider.notifier).refresh(),
                    child: ListView(
                      children: const [
                        SizedBox(height: 120),
                        StateView(
                          icon: Icons.campaign_outlined,
                          title: 'No campaigns yet',
                          subtitle:
                              'Create a role to start ranking candidates against it.',
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(campaignsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      return _CampaignCard(job: job);
                    },
                  ),
                );
              },
              loading: () => const LoadingView(label: 'Loading campaigns…'),
              error: (e, _) => StateView(
                icon: Icons.wifi_off,
                title: 'Could not load campaigns',
                subtitle: '$e',
                action: LiButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () => ref.read(campaignsProvider.notifier).refresh(),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openCampaignEditor(context),
        backgroundColor: AppTheme.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New campaign'),
      ),
    );
  }
}

class _CampaignCard extends ConsumerWidget {
  final Job job;
  const _CampaignCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rankAsync = ref.watch(campaignRankStatusProvider(job.id));

    return LiCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CampaignDetailScreen(campaignId: job.id),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title.isEmpty ? 'Untitled role' : job.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              LiTag(label: job.status, color: _statusColor(job.status)),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'review') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CampaignReviewScreen(campaignId: job.id),
                      ),
                    );
                  } else if (value == 'deactivate') {
                    await confirmDeactivateCampaign(context, ref, job);
                  } else if (value == 'rank') {
                    try {
                      await ref
                          .read(campaignRankStatusProvider(job.id).notifier)
                          .triggerRank(job.id);
                      if (context.mounted) {
                        showAppSnackBar(context, 'Ranking queued');
                      }
                    } catch (e) {
                      if (context.mounted) showErrorSnackBar(context, e);
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'review', child: Text('Review')),
                  if (job.canDeactivate)
                    const PopupMenuItem(
                      value: 'deactivate',
                      child: Text('Deactivate'),
                    ),
                  if (job.allowsManualRank)
                    const PopupMenuItem(value: 'rank', child: Text('Re-rank CVs')),
                ],
              ),
            ],
          ),
          if (job.metadataSubtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              job.metadataSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ] else if (job.createdAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Created ${_formatDate(job.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          rankAsync.when(
            data: (st) => _RankBadge(status: st),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.green;
      case 'draft':
        return AppTheme.orange;
      case 'paused':
        return AppTheme.peacock;
      default:
        return AppTheme.ink;
    }
  }

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _RankBadge extends StatelessWidget {
  final RankStatus status;
  const _RankBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status.isActive) {
      return LiTag(
        label:
            'Ranking… ${status.done}/${status.total} (${status.pending} pending)',
        color: AppTheme.peacock,
      );
    }
    if (status.failed > 0) {
      return LiTag(
        label: '${status.done} ranked · ${status.failed} failed',
        color: AppTheme.orange,
      );
    }
    return LiTag(
      label: '${status.done} candidates ranked',
      color: AppTheme.green,
    );
  }
}

