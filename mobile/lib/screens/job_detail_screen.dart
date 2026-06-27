import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/job_definitions_provider.dart';
import 'package:cv_exec_feed/screens/job_editor.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/utils/snackbar.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JobDetailScreen extends ConsumerWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobDefinitionsProvider);
    final rankAsync = ref.watch(jobRankStatusProvider(jobId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () {
              final job = jobsAsync.valueOrNull
                  ?.where((j) => j.id == jobId)
                  .firstOrNull;
              if (job != null) openJobEditor(context, job: job);
            },
          ),
        ],
      ),
      body: jobsAsync.when(
        data: (jobs) {
          final job = jobs.where((j) => j.id == jobId).firstOrNull;
          if (job == null) {
            return const StateView(
              icon: Icons.work_off_outlined,
              title: 'Job not found',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                job.title.isEmpty ? 'Untitled role' : job.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reusable role definition for CV ranking',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              rankAsync.when(
                data: (st) => _RankBadge(status: st),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LiButton(
                      label: 'Rank CVs',
                      icon: Icons.sort,
                      onPressed: () async {
                        try {
                          await ref
                              .read(jobRankStatusProvider(jobId).notifier)
                              .triggerRank(jobId);
                          if (context.mounted) {
                            showAppSnackBar(context, 'Ranking queued');
                          }
                        } catch (e) {
                          if (context.mounted) showErrorSnackBar(context, e);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LiButton(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete job?'),
                            content: const Text(
                              'This role definition will be removed permanently.',
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
                              .deleteJob(jobId);
                          if (context.mounted) {
                            Navigator.pop(context);
                            showAppSnackBar(context, 'Job deleted');
                          }
                        } catch (e) {
                          if (context.mounted) showErrorSnackBar(context, e);
                        }
                      },
                    ),
                  ),
                ],
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
        loading: () => const LoadingView(label: 'Loading job…'),
        error: (e, _) => StateView(
          icon: Icons.wifi_off,
          title: 'Could not load job',
          subtitle: '$e',
        ),
      ),
    );
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
