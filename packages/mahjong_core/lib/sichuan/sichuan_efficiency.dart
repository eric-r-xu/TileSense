/// Shanten and acceptance under Sichuan's hand shapes: the ordinary search,
/// with seven pairs allowed to use four identical tiles as two pairs and no
/// thirteen orphans. Void-suit tiles are the caller's to leave out: a hand
/// holding its voided suit cannot win, so the guide and the bots count the
/// rest of the hand.
library;

import '../efficiency_calc.dart';

class SichuanEfficiencyCalculator extends TileEfficiencyCalculator {
  SichuanEfficiencyCalculator() : super(sichuan: true);
}

/// [counts] (a 38-slot trainer array) with the tiles of [voidSuit] (0 man,
/// 1 pin, 2 sou) removed.
List<int> withoutVoidSuit(List<int> counts, int? voidSuit) {
  if (voidSuit == null) return counts;
  final out = List<int>.of(counts);
  for (var n = 1; n <= 9; n++) {
    out[voidSuit * 10 + n] = 0;
  }
  return out;
}
