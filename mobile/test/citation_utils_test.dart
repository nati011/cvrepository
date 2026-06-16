import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/utils/citation_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Citation cite(String cvId, String claim) =>
      Citation(cvId: cvId, claim: claim, quote: '');

  test('groups citations by candidate preserving order', () {
    final groups = groupCitationsByCandidate([
      cite('a', 'claim 1'),
      cite('b', 'claim 2'),
      cite('a', 'claim 3'),
      cite('c', 'claim 4'),
      cite('b', 'claim 5'),
    ]);

    expect(groups.length, 3);
    expect(groups[0].map((c) => c.claim).toList(), ['claim 1', 'claim 3']);
    expect(groups[1].map((c) => c.claim).toList(), ['claim 2', 'claim 5']);
    expect(groups[2].map((c) => c.claim).toList(), ['claim 4']);
  });

  test('returns empty list for no citations', () {
    expect(groupCitationsByCandidate([]), isEmpty);
  });
}
