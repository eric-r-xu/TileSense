/// Hong Kong defence: public-information risk estimates only. With no
/// furiten, a tile an opponent discarded earlier can still win their hand, so
/// nothing here is ever rated as certainly safe.
library;

import '../safety.dart';
import '../tile.dart';

/// Rank each distinct tile type in [hand] by estimated risk against an
/// opponent with an exposed hand. Honours get safer as copies become visible,
/// terminals sit in the middle, and middle suit tiles are the most dangerous.
List<SafetyRating> rankHongKongSafety(
  List<Tile> hand, {
  required List<int> visibleCounts34,
}) {
  final types = hand.map((t) => t.type).where((t) => t.isPlayingTile).toSet();
  final result = <SafetyRating>[];
  for (final t in types) {
    final left = (4 - visibleCounts34[t.index - 1]).clamp(0, 4);
    // Even a fourth visible honour may complete Thirteen Orphans, so the top
    // rating stays short of the 15 that means "cannot deal in".
    final rating = t.isHonor
        ? (left == 0
            ? 14
            : left == 1
                ? 11
                : 6)
        : t.isTerminal
            ? 5
            : 3;
    result.add(SafetyRating(
        t,
        rating,
        t.isHonor
            ? 'Honor, $left unseen; special-hand risk remains'
            : t.isTerminal
                ? 'Terminal; sequence and pair risk'
                : 'Suit tile; sequence and pair risk'));
  }
  result.sort((a, b) => b.rating.compareTo(a.rating));
  return result;
}
