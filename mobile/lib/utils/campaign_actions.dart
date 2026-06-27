import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/campaigns_provider.dart';
import 'package:cv_exec_feed/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool> confirmDeactivateCampaign(
  BuildContext context,
  WidgetRef ref,
  Job job,
) async {
  if (!job.canDeactivate) return false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Deactivate campaign?'),
      content: Text(
        '“${job.title.isEmpty ? 'Untitled role' : job.title}” will be closed and '
        'removed from the active feed. Title and description cannot be changed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Deactivate'),
        ),
      ],
    ),
  );

  if (ok != true || !context.mounted) return false;

  try {
    await ref.read(campaignsProvider.notifier).deactivateCampaign(job);
    if (context.mounted) {
      showAppSnackBar(context, 'Campaign deactivated');
    }
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return false;
  }
}
