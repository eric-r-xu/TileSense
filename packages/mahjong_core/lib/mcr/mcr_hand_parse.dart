/// MCR special structures, isolated from the existing variants' parsers.
library;

import '../hand_parse.dart';
import '../meld.dart';
import '../tile.dart';

final List<List<int>> mcrKnittedSets = [
  for (final p in const [
    [0, 1, 2],
    [0, 2, 1],
    [1, 0, 2],
    [1, 2, 0],
    [2, 0, 1],
    [2, 1, 0]
  ])
    [
      for (var suit = 0; suit < 3; suit++)
        for (var n = p[suit]; n < 9; n += 3) suit * 9 + n
    ],
];

class McrShape {
  const McrShape(this.hand,
      {this.knitted = const [], this.honorsKnitted = false});
  final HandDecomposition hand;
  final List<int> knitted;
  final bool honorsKnitted;
}

List<McrShape> decomposeMcr(List<int> counts, {int openMelds = 0}) {
  if (counts.length != 34 ||
      counts.any((n) => n < 0 || n > 4) ||
      openMelds < 0 ||
      openMelds > 4 ||
      counts.fold<int>(0, (a, b) => a + b) != 14 - 3 * openMelds) return [];
  final out = [
    for (final d
        in decompose(counts, openMelds: openMelds, allArrangements: true))
      McrShape(d)
  ];
  if (openMelds == 0 &&
      counts.every((n) => n % 2 == 0) &&
      !out.any((s) => s.hand.sevenPairs)) {
    out.add(McrShape(HandDecomposition(melds: [
      for (var i = 0; i < 34; i++)
        for (var j = 0; j < counts[i] ~/ 2; j++)
          Meld(kind: MeldKind.pair, low: typeFrom34(i), concealed: true),
    ], pair: null, sevenPairs: true)));
  }
  for (final knit in mcrKnittedSets) {
    if (openMelds == 0 &&
        counts.every((n) => n <= 1) &&
        List.generate(27, (i) => i)
            .every((i) => counts[i] == 0 || knit.contains(i))) {
      out.add(McrShape(HandDecomposition(melds: const [], pair: null),
          knitted: knit, honorsKnitted: true));
    }
    if (openMelds <= 1 && knit.every((i) => counts[i] > 0)) {
      final rest = List<int>.of(counts);
      for (final i in knit) {
        rest[i]--;
      }
      for (final d in decompose(rest,
          openMelds: openMelds, totalMelds: 1, allArrangements: true)) {
        out.add(McrShape(d, knitted: knit));
      }
    }
  }
  return out;
}

bool isAgariMcr(List<int> counts, {int meldCount = 0}) =>
    decomposeMcr(counts, openMelds: meldCount).isNotEmpty;

List<TileType> waitTilesMcr(List<Tile> hand, {int openMelds = 0}) {
  final counts = toCounts34(hand);
  final out = <TileType>[];
  for (var i = 0; i < 34; i++) {
    if (counts[i] >= 4) continue;
    counts[i]++;
    if (isAgariMcr(counts, meldCount: openMelds)) out.add(typeFrom34(i));
    counts[i]--;
  }
  return out;
}

/// Exact distance to closed special forms, and knitted straight with <=1 meld.
/// [counts] does not include exposed melds or padding used by the trainer.
int mcrSpecialShanten(List<int> counts, {int openMelds = 0, int ceiling = 99}) {
  var best = ceiling;
  void take(int value) {
    if (value < best) best = value;
  }

  if (openMelds == 0) {
    take(6 - counts.fold<int>(0, (a, n) => a + n ~/ 2));
    const orphans = [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33];
    take(13 -
        orphans.where((i) => counts[i] > 0).length -
        (orphans.any((i) => counts[i] >= 2) ? 1 : 0));
    for (final knit in mcrKnittedSets) {
      take(13 -
          [...knit, 27, 28, 29, 30, 31, 32, 33]
              .where((i) => counts[i] > 0)
              .length);
    }
  }
  if (openMelds <= 1) {
    for (final knit in mcrKnittedSets) {
      final knitMissing = knit.where((i) => counts[i] == 0).length;
      if (knitMissing - 1 >= best) continue;
      final base = List<int>.filled(34, 0);
      for (final i in knit) {
        base[i]++;
      }
      // Maximize overlap with each legal knitted + meld + pair target.
      var missing = knitMissing;
      var overflow = 0;
      int deficit(int i) => base[i] > counts[i] ? base[i] - counts[i] : 0;
      void change(int i, int by) {
        missing -= deficit(i);
        if (base[i] > 4) overflow--;
        base[i] += by;
        if (base[i] > 4) overflow++;
        missing += deficit(i);
      }

      for (var pair = 0; pair < 34; pair++) {
        change(pair, 2);
        void assess() {
          if (overflow == 0) take(missing - 1);
        }

        if (openMelds == 1) {
          assess();
        } else {
          for (var m = 0; m < 34; m++) {
            change(m, 3);
            assess();
            change(m, -3);
            if (m < 27 && m % 9 <= 6) {
              for (var j = m; j < m + 3; j++) {
                change(j, 1);
              }
              assess();
              for (var j = m; j < m + 3; j++) {
                change(j, -1);
              }
            }
          }
        }
        change(pair, -2);
      }
    }
  }
  return best;
}
