/// Shanten and acceptance for a Fuzhou hand, where the Gold tiles are wild.
///
/// The calculator in `efficiency_calc.dart` knows nothing of wilds, so the
/// hand is split first: natural tiles go through its search, each Gold tile
/// takes one step off the result, and drawing another Gold counts as an
/// improving draw whenever the hand is not already complete.
library;

import '../efficiency_calc.dart';
import '../tile.dart';
import 'fuzhou_hand_parse.dart';

/// One discard from a hand and where it leaves the rest.
class FuzhouLine {
  FuzhouLine({
    required this.discard,
    required this.shanten,
    required this.ukeire,
    required this.accepts,
  });

  final TileType discard;

  /// Shanten after the discard (0 = ready).
  final int shanten;

  /// Live tiles that bring the hand a step closer, Gold included.
  final int ukeire;

  /// The tile types among them.
  final List<TileType> accepts;
}

class FuzhouEfficiency {
  static final _calc = TileEfficiencyCalculator();

  /// Shanten of [hand] (the concealed tiles, 16 - 3 per call between draws,
  /// or one more after a draw) with [openMelds] calls made.
  static int shanten(List<Tile> hand,
      {required int openMelds, required Set<TileType> gold}) {
    final s = splitGold(hand, gold);
    return _shantenOf(s.counts, s.wilds, openMelds);
  }

  static int _shantenOf(List<int> counts34, int wilds, int openMelds) =>
      _calc.wildShanten(trainerCountsFromTypeCounts(counts34),
          openMelds: openMelds, wilds: wilds);

  /// Tiles that would lower the shanten of [hand] (between draws), and how many
  /// are live. [live34] counts the unseen copies of each natural type;
  /// [goldLeft] is how many Gold tiles are still unseen.
  static ({int count, List<TileType> tiles}) acceptance(List<Tile> hand,
      {required int openMelds,
      required Set<TileType> gold,
      required List<int> live34,
      required int goldLeft}) {
    final s = splitGold(hand, gold);
    return _accept(s.counts, s.wilds, openMelds, gold, live34, goldLeft);
  }

  static ({int count, List<TileType> tiles}) _accept(
      List<int> counts,
      int wilds,
      int openMelds,
      Set<TileType> gold,
      List<int> live34,
      int goldLeft) {
    final base = _shantenOf(counts, wilds, openMelds);
    var count = 0;
    final tiles = <TileType>[];
    if (base > -1) {
      for (var i = 0; i < 27; i++) {
        final type = typeFrom34(i);
        if (gold.contains(type) || live34[i] <= 0) continue;
        counts[i]++;
        if (_shantenOf(counts, wilds, openMelds) < base) {
          count += live34[i];
          tiles.add(type);
        }
        counts[i]--;
      }
      if (goldLeft > 0 && _shantenOf(counts, wilds + 1, openMelds) < base) {
        count += goldLeft;
        tiles.addAll(gold.where((t) => t.isPlayingTile));
      }
    }
    return (count: count, tiles: tiles);
  }

  /// Every distinct discard from [hand] (a full hand after a draw), with the
  /// shanten and acceptance it leaves.
  static List<FuzhouLine> lines(List<Tile> hand,
      {required int openMelds,
      required Set<TileType> gold,
      required List<int> live34,
      required int goldLeft}) {
    final out = <FuzhouLine>[];
    final seen = <TileType>{};
    for (final tile in hand) {
      if (!seen.add(tile.type)) continue;
      final rest = [...hand]..remove(tile);
      final s = splitGold(rest, gold);
      final accept = _accept(s.counts, s.wilds, openMelds, gold, live34, goldLeft);
      out.add(FuzhouLine(
        discard: tile.type,
        shanten: _shantenOf(s.counts, s.wilds, openMelds),
        ukeire: accept.count,
        accepts: accept.tiles,
      ));
    }
    return out;
  }

  /// The lowest shanten any discard from [hand] reaches.
  static int bestAfterDiscard(List<Tile> hand,
      {required int openMelds, required Set<TileType> gold}) {
    var best = 99;
    final seen = <TileType>{};
    for (final tile in hand) {
      if (!seen.add(tile.type)) continue;
      final s = splitGold([...hand]..remove(tile), gold);
      final v = _shantenOf(s.counts, s.wilds, openMelds);
      if (v < best) best = v;
    }
    return best;
  }
}
