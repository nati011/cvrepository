import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/list_providers.dart';
import 'package:cv_exec_feed/providers/reactions_provider.dart';
import 'package:cv_exec_feed/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> handleReaction(
  WidgetRef ref,
  BuildContext context, {
  required FeedItem item,
  required String action,
  required String verb,
  String? jobId,
  bool global = false,
}) async {
  final effectiveJobId = global ? null : jobId;
  try {
    final result = await ref.read(reactionsProvider.notifier).toggleReaction(
          cvId: item.cvId,
          action: action,
          jobId: effectiveJobId,
          verb: verb,
        );
    if (result != null && context.mounted) {
      showActionSnackBar(context, '$result ${item.name}');
    }
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

String? watchReactionAction(
  WidgetRef ref,
  FeedItem item, {
  String? jobId,
  bool global = false,
}) {
  return ref.watch(reactionForCvProvider(ReactionLookup(
    cvId: item.cvId,
    jobId: global ? null : jobId,
  )));
}
