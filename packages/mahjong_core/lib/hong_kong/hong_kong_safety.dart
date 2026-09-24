/// Hong Kong defence: public-information risk estimates only. With no
/// furiten, a tile an opponent discarded earlier can still win their hand, so
/// nothing here is ever rated as certainly safe.
library;

import '../meld.dart';
import '../safety.dart';
import '../tile.dart';

/// Rank each distinct tile type in [hand] by estimated risk against an
/// opponent with an exposed hand. Honours get safer as copies become visible,
/// terminals sit in the middle, and middle suit tiles are the most dangerous.
///
/// Given the threat's exposed [threatMelds] and [threatDiscards], it also
/// reads their hand. Two or more exposed suited sets all in one suit point at
/// a flush, which makes the other suits far safer and that suit the most
/// dangerous. A tile they threw away themselves is rated far safer: measured
/// against the bots, a threat won on a tile it had discarded 4.4% of the time
/// where chance alone gives 29%. With no furiten it can still win them the
/// hand, so it is never rated certainly safe. Both empty, the ratings are the
/// plain by-type ones.
List<SafetyRating> rankHongKongSafety(
  List<Tile> hand, {
  required List<int> visibleCounts34,
  List<Meld> threatMelds = const [],
  List<TileType> threatDiscards = const [],
}) {
  final exposedSuits = {
    for (final m in threatMelds)
      if (!m.concealed && m.low.isSuit) m.low.suit
  };
  final suitedSets =
      threatMelds.where((m) => !m.concealed && m.low.isSuit).length;
  final flushSuit =
      exposedSuits.length == 1 && suitedSets >= 2 ? exposedSuits.single : null;
  final discarded = threatDiscards.toSet();
  final types = hand.map((t) => t.type).where((t) => t.isPlayingTile).toSet();
  final result = <SafetyRating>[];
  for (final t in types) {
    final left = (4 - visibleCounts34[t.index - 1]).clamp(0, 4);
    // Even a fourth visible honour may complete Thirteen Orphans, so the top
    // rating stays short of the 15 that means "cannot deal in".
    var rating = t.isHonor
        ? (left == 0
            ? 14
            : left == 1
                ? 11
                : 6)
        : t.isTerminal
            ? 5
            : 3;
    var label = t.isHonor
        ? 'Honor, $left unseen; special-hand risk remains'
        : t.isTerminal
            ? 'Terminal; sequence and pair risk'
            : 'Suit tile; sequence and pair risk';
    if (flushSuit != null && t.isSuit) {
      if (t.suit == flushSuit) {
        rating = rating < 1 ? rating : 1;
        label = 'In the suit their exposed sets are collecting';
      } else {
        rating = rating > 12 ? rating : 12;
        label = 'Off the suit their exposed sets are collecting';
      }
    }
    if (discarded.contains(t)) {
      rating = rating > 12 ? rating : 12;
      label = '$label; they discarded it themselves';
    }
    result.add(SafetyRating(t, rating, label));
  }
  result.sort((a, b) => b.rating.compareTo(a.rating));
  return result;
}
