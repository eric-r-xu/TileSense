import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/tile.dart';

/// Holds the guide's defensive judgement to account across a wide spread of
/// random tables, rather than the handful of hands the other tests pin down.
///
/// There is no fold switch any more: the recommendation is simply the best
/// expected value, and folding has to fall out of the numbers on its own. That
/// only works while a discard is charged both for its own danger and for the
/// turns choosing it commits you to. These are the properties that would break
/// first if either charge went wrong.
void main() {
  const trials = 600;

  ({
    int positions,
    int hadGenbutsu,
    int tookGenbutsu,
    int notSafest,
    int worstSafetyGap,
  }) sweep() {
    final rng = Random(12345);
    var positions = 0;
    var hadGenbutsu = 0;
    var tookGenbutsu = 0;
    var notSafest = 0;
    var worstSafetyGap = 0;

    for (var trial = 0; trial < trials; trial++) {
      final bag = <TileType>[
        for (var i = 0; i < 34; i++)
          for (var c = 0; c < 4; c++) typeFrom34(i),
      ]..shuffle(rng);
      var k = 0;
      final hand = [for (var i = 0; i < 14; i++) Tile(i, bag[k++])];
      final pond = [for (var i = 0; i < 4 + rng.nextInt(8); i++) bag[k++]];
      final dora = [bag[k++]];
      final wall = 8 + rng.nextInt(60);

      final visible = List<int>.filled(34, 0);
      for (final t in hand) {
        visible[t.type.index - 1]++;
      }
      for (final t in [...pond, ...dora]) {
        visible[t.index - 1]++;
      }

      final report = EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: visible,
        canRiichi: true,
        defenseHand: hand,
        opponentRiichi: true,
        opponentIsDealer: rng.nextBool(),
        opponentDiscards: pond,
        valueContext: EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: wall,
          doraIndicators: dora,
        ),
      );
      // Before tenpai, behind a live riichi: where the switch used to fire.
      if (report.lines.isEmpty ||
          !report.defending ||
          report.currentShanten <= 0) {
        continue;
      }
      positions++;

      final reco = report.lines.firstWhere((l) => l.recommended);
      final recoRating = reco.safety?.rating ?? 0;
      final safest = report.lines
          .map((l) => l.safety?.rating ?? 0)
          .reduce((a, b) => a > b ? a : b);

      if (safest >= 15) {
        hadGenbutsu++;
        if (recoRating >= 15) tookGenbutsu++;
      }
      if (recoRating < safest) {
        notSafest++;
        worstSafetyGap = max(worstSafetyGap, safest - recoRating);
      }
    }
    return (
      positions: positions,
      hadGenbutsu: hadGenbutsu,
      tookGenbutsu: tookGenbutsu,
      notSafest: notSafest,
      worstSafetyGap: worstSafetyGap,
    );
  }

  test('a perfectly safe tile is taken when the hand is not worth pushing', () {
    final r = sweep();
    expect(r.positions, greaterThan(400), reason: 'need a real sample');
    expect(r.hadGenbutsu, greaterThan(300));

    // Randomly dealt hands are cheap, so behind a riichi almost all of them
    // should be folded. This is not a law that genbutsu is always right — a big
    // enough hand should push — it is a guard against the guide failing to fold
    // when it plainly should. Measured at 513/513 when this was written.
    final tookRate = r.tookGenbutsu / r.hadGenbutsu;
    expect(tookRate, greaterThan(0.95),
        reason: 'only took the genbutsu in '
            '${(tookRate * 100).toStringAsFixed(1)}% of positions that had one');
  });

  test('the recommendation never gives up much safety', () {
    final r = sweep();
    // Measured: the safest tile in 589 of 600. Ten of the eleven give up 1 to
    // 3 points, between near-identical tiles in hands with nothing safe at all.
    // The eleventh gives up 6, and is the shape of call this bound exists to
    // allow rather than forbid: a lone honour rated at a 3% deal-in, cut to
    // keep a live 2-shanten hand, where the genbutsu alternative dismantles
    // the shape and leaves a 1.4% chance of ever winning.
    expect(r.notSafest / r.positions, lessThan(0.02),
        reason: '${r.notSafest} of ${r.positions} were not the safest tile');
    expect(r.worstSafetyGap, lessThanOrEqualTo(6),
        reason: 'gave up ${r.worstSafetyGap} points of safety rating — that is '
            'a fold being overruled, not a close call');
  });
}
