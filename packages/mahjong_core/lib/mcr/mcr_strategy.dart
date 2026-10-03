/// Conservative pattern potential for unfinished hands, not a scoring result.
library;

import '../meld.dart';
import '../tile.dart';

/// How much of a qualifying pattern the tiles already support (0..1).
/// Used only before ready; completed waits always go through the scorer.
double mcrPatternPotential(List<Tile> hand, List<Meld> melds,
    {required Wind seatWind, required Wind roundWind}) {
  final tiles = [...hand.map((t) => t.type), ...melds.expand((m) => m.types)];
  if (tiles.isEmpty) return 0;
  double share(bool Function(TileType) p) =>
      tiles.where(p).length / tiles.length;
  var best = melds.every((m) => m.concealed) ? 0.55 : 0.2;
  void take(double v) {
    if (v > best) best = v;
  }

  for (var suit = 0; suit < 3; suit++) {
    if (melds.every((m) => m.types.every((t) => t.suit == suit)))
      take(share((t) => t.suit == suit));
    if (melds.every((m) => m.types.every((t) => t.suit == suit || t.isHonor))) {
      take(share((t) => t.suit == suit || t.isHonor) * 0.9);
    }
  }
  if (melds.every((m) => m.isTripletLike)) {
    final counts = toCounts34(hand);
    final paired = counts.fold<int>(0, (n, c) => n + (c >= 2 ? c : 0));
    take((paired + melds.length * 3) / (hand.length + melds.length * 3));
  }
  if (melds.every((m) => m.types.every((t) => t.isSuit && t.number >= 6)))
    take(share((t) => t.isSuit && t.number >= 6));
  if (melds.every((m) => m.types.every((t) => t.isSuit && t.number <= 4)))
    take(share((t) => t.isSuit && t.number <= 4));
  final fixed = melds.fold<int>(
      0,
      (n, m) =>
          n +
          (m.isTripletLike
              ? (m.low.isDragon ? 2 : 0) +
                  (m.low == seatWind.tile ? 2 : 0) +
                  (m.low == roundWind.tile ? 2 : 0)
              : 0) +
          (m.isKan ? (m.concealed ? 2 : 1) : 0));
  take((fixed / 8).clamp(0, 1).toDouble());
  // Chows in all three suits can pursue the 8-point mixed triple chow.
  for (var low = 1; low <= 7; low++) {
    if (melds.where((m) => m.isSequence).every((m) => m.low.number == low)) {
      final hits = tiles
          .where((t) => t.isSuit && t.number >= low && t.number <= low + 2)
          .length;
      take((hits / 9).clamp(0, 1).toDouble() * 0.9);
    }
  }
  return best.clamp(0, 1).toDouble();
}
