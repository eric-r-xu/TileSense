/// Defensive tile-safety ranking against a player who has declared riichi.
///
/// A simplified port of `EfficiencyLogging.evaluate_safety` / `is_suji` /
/// `safety_explanation` from the Vala client's `TileEfficiency.vala`. Ratings
/// run 0 (very dangerous) to 15 (genbutsu). No hidden-wall information is used;
/// only public discards and visible tiles.
library;

import 'tile.dart';

class SafetyRating {
  const SafetyRating(this.type, this.rating, this.label);
  final TileType type;

  /// 0..15. Higher is safer.
  final int rating;
  final String label;

  bool get isSafe => rating >= 15;
}

/// Rank each distinct tile type in [hand] for safety against the riichi player.
///
/// - [opponentDiscards]: the riichi player's own discard pond.
/// - [allDiscards]: every player's discards (genbutsu also covers tiles others
///   discarded after the declaration without being ronned).
/// - [visibleCounts34]: how many of each tile type are visible anywhere
///   (discards, melds, dora indicators, own hand) — length 34.
List<SafetyRating> rankSafety(
  List<Tile> hand, {
  required List<TileType> opponentDiscards,
  required List<TileType> allDiscards,
  required List<int> visibleCounts34,
}) {
  final seen = <TileType>{};
  final out = <SafetyRating>[];

  final genbutsu = {...opponentDiscards, ...allDiscards};

  for (final tile in hand) {
    if (!seen.add(tile.type)) continue;
    out.add(_rate(tile.type, genbutsu, opponentDiscards, visibleCounts34));
  }
  out.sort((a, b) => b.rating.compareTo(a.rating));
  return out;
}

SafetyRating _rate(
  TileType t,
  Set<TileType> genbutsu,
  List<TileType> oppDiscards,
  List<int> visible,
) {
  if (genbutsu.contains(t)) {
    return SafetyRating(t, 15, 'genbutsu (in discards)');
  }

  if (t.isHonor) {
    final left = 4 - visible[t.index - 1];
    if (left <= 1) return SafetyRating(t, 13, 'honor, 1 live — cannot be shanpon');
    if (left == 2) return SafetyRating(t, 9, 'honor, 2 live');
    return SafetyRating(t, 6, 'honor, 3 live — shanpon/tanki risk');
  }

  final n = t.number;
  final suit = t.suit;
  final suji = oppDiscards.where((d) => d.suit == suit).map((d) => d.number).toSet();

  // Terminal suji (1/9 covered by 4/6 in the pond).
  if (n == 1 && suji.contains(4)) {
    return SafetyRating(t, 11, 'suji terminal (4 discarded)');
  }
  if (n == 9 && suji.contains(6)) {
    return SafetyRating(t, 11, 'suji terminal (6 discarded)');
  }

  if (n >= 4 && n <= 6) {
    final lowSuji = suji.contains(n - 3);
    final highSuji = suji.contains(n + 3);
    if (lowSuji && highSuji) {
      return SafetyRating(t, 12, 'double suji');
    }
    if (lowSuji || highSuji) {
      return SafetyRating(t, 7, 'half suji — still a kanchan/shanpon risk');
    }
    return SafetyRating(t, 2, 'non-suji middle tile');
  }

  // 2,3,7,8: suji covers the ryanmen but not penchan/kanchan/shanpon.
  final sujiPartner = (n == 2 || n == 3) ? n + 3 : n - 3;
  if (suji.contains(sujiPartner)) {
    return SafetyRating(t, 6, 'suji ($sujiPartner discarded) — penchan/kanchan risk');
  }

  // No-chance / one-chance: all four of an adjacent connector visible.
  if (_noChance(t, visible)) {
    return SafetyRating(t, 8, 'no-chance (blockers exhausted)');
  }

  return SafetyRating(t, 3, 'non-suji ${n <= 3 ? 'low' : 'high'} tile');
}

bool _noChance(TileType t, List<int> visible) {
  final n = t.number;
  final base = t.suit * 9;
  int cnt(int num) => (num >= 1 && num <= 9) ? visible[base + num - 1] : 0;

  // A ryanmen that would wait on t needs the two tiles on the far side.
  // If either connector pair is fully visible, that wait is dead.
  final lowDead = n - 2 >= 1 && cnt(n - 1) == 4;
  final highDead = n + 2 <= 9 && cnt(n + 1) == 4;
  return lowDead && highDead;
}
