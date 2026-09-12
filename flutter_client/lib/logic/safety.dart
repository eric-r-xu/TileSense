/// Public-information risk estimates. Discards confer no immunity in HK.
library;

import 'tile.dart';

class SafetyRating {
  const SafetyRating(this.type, this.rating, this.label);
  final TileType type;
  final int rating;
  final String label;
  bool get isSafe => rating >= 15;
}

List<SafetyRating> rankSafety(
  List<Tile> hand, {
  required List<TileType> opponentDiscards,
  required List<TileType> passedDiscardsAfterRiichi,
  required List<int> visibleCounts34,
}) {
  final types = hand.map((t) => t.type).where((t) => t.isPlayingTile).toSet();
  final result = <SafetyRating>[];
  for (final t in types) {
    final left = (4 - visibleCounts34[t.index - 1]).clamp(0, 4);
    // Even a fourth visible honor may complete Thirteen Orphans. No tile is
    // certified safe by this heuristic, and previously passed tiles can win.
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
