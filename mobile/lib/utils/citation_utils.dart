import 'package:cv_exec_feed/models.dart';

/// Groups citations by candidate while preserving first-seen order.
List<List<Citation>> groupCitationsByCandidate(List<Citation> cites) {
  final groups = <List<Citation>>[];
  final indexByCvId = <String, int>{};
  for (final cite in cites) {
    final existing = indexByCvId[cite.cvId];
    if (existing != null) {
      groups[existing].add(cite);
    } else {
      indexByCvId[cite.cvId] = groups.length;
      groups.add([cite]);
    }
  }
  return groups;
}
