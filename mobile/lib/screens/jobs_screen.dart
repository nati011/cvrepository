import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/job_definitions_provider.dart';
import 'package:cv_exec_feed/screens/job_detail_screen.dart';
import 'package:cv_exec_feed/screens/job_editor.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/utils/snackbar.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobDefinitionsProvider);

    return Scaffold(
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(jobDefinitionsProvider.notifier).refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  StateView(
                    icon: Icons.work_outline,
                    title: 'No jobs yet',
                    subtitle:
                        'Create a reusable role definition to rank candidates against it.',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(jobDefinitionsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _JobCard(job: jobs[index]);
              },
            ),
          );
        },
        loading: () => const LoadingView(label: 'Loading jobs…'),
        error: (e, _) => StateView(
          icon: Icons.wifi_off,
          title: 'Could not load jobs',
          subtitle: '$e',
          action: LiButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: () =>
                ref.read(jobDefinitionsProvider.notifier).refresh(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openJobEditor(context),
        backgroundColor: AppTheme.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New job'),
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  final Job job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rankAsync = ref.watch(jobRankStatusProvider(job.id));

    return LiCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JobDetailScreen(jobId: job.id),
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
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    openJobEditor(context, job: job);
                  } else if (value == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete job?'),
                        content: Text(
                          '“${job.title.isEmpty ? 'Untitled role' : job.title}” will be removed permanently.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    try {
                      await ref
                          .read(jobDefinitionsProvider.notifier)
                          .deleteJob(job.id);
                      if (context.mounted) {
                        showAppSnackBar(context, 'Job deleted');
                      }
                    } catch (e) {
                      if (context.mounted) showErrorSnackBar(context, e);
                    }
                  } else if (value == 'rank') {
                    try {
                      await ref
                          .read(jobRankStatusProvider(job.id).notifier)
                          .triggerRank(job.id);
                      if (context.mounted) {
                        showAppSnackBar(context, 'Ranking queued');
                      }
                    } catch (e) {
                      if (context.mounted) showErrorSnackBar(context, e);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'rank', child: Text('Rank CVs')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (job.createdAt.isNotEmpty) ...[
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
