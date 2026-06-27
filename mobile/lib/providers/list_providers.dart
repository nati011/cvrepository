import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/feed_provider.dart';
import 'package:cv_exec_feed/providers/reactions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isGlobalReaction(Reaction r) =>
    r.jobId == null || r.jobId!.isEmpty;

int _compareReactionDate(Reaction a, Reaction b) {
  final da = DateTime.tryParse(a.createdAt);
  final db = DateTime.tryParse(b.createdAt);
  if (da != null && db != null) return db.compareTo(da);
  return b.createdAt.compareTo(a.createdAt);
}

final likedCandidatesProvider = Provider<List<ListEntry>>((ref) {
  final reactions = ref.watch(reactionsProvider).valueOrNull;
  if (reactions == null) return const [];
  final lookup = ref.watch(candidateLookupProvider);
  final entries = <ListEntry>[];
  for (final r in reactions.byKey.values) {
    if (r.action != 'like' || !_isGlobalReaction(r)) continue;
    final item = lookup[r.cvId];
    if (item != null) entries.add(ListEntry(item: item, reaction: r));
  }
  entries.sort((a, b) => _compareReactionDate(a.reaction, b.reaction));
  return entries;
});

final starredCandidatesProvider = Provider<List<ListEntry>>((ref) {
  final reactions = ref.watch(reactionsProvider).valueOrNull;
  if (reactions == null) return const [];
  final lookup = ref.watch(candidateLookupProvider);
  final entries = <ListEntry>[];
  for (final r in reactions.byKey.values) {
    if (r.action != 'star' || !_isGlobalReaction(r)) continue;
    final item = lookup[r.cvId];
    if (item != null) entries.add(ListEntry(item: item, reaction: r));
  }
  entries.sort((a, b) => _compareReactionDate(a.reaction, b.reaction));
  return entries;
});

final reactionForCvProvider =
    Provider.family<String?, ReactionLookup>((ref, lookup) {
  final reactions = ref.watch(reactionsProvider).valueOrNull;
  if (reactions == null) return null;
  final key = ReactionKey.of(lookup.cvId, lookup.jobId);
  return reactions.byKey[key]?.action;
});

class ReactionLookup {
  final String cvId;
  final String? jobId;

  const ReactionLookup({required this.cvId, this.jobId});

  @override
  bool operator ==(Object other) =>
      other is ReactionLookup && other.cvId == cvId && other.jobId == jobId;

  @override
  int get hashCode => Object.hash(cvId, jobId);
}
