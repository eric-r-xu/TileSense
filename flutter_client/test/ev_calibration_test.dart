import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_calc.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/tile.dart';

/// Guards the two properties the discard model is only useful if it has:
/// hands that are closer to home have to score higher, and the acceptance
/// figures the win estimator normalises against have to be the ones real play
/// actually produces.
///
/// Both are checked by simulating play rather than by hand-picking positions,
/// because the failures they exist to catch were invisible one hand at a time —
/// the ordering held on most hands and collapsed in aggregate.
void main() {
  /// A full wall, shuffled the same way every run.
  List<TileType> wallFor(Random rng) {
    final wall = <TileType>[
      for (var i = 0; i < 34; i++)
        for (var c = 0; c < 4; c++) typeFrom34(i),
    ];
    return wall..shuffle(rng);
  }

  test('typical acceptance by shanten is what play actually produces', () {
    // The divisor `_winProbabilityFromShanten` measures a hand's width
    // against. It has to be the real mean, not a plausible-looking guess: it
    // divides, so understating it hands every hand a scale above 1 and
    // compounds that over each step it has left. Understated at 3-shanten and
    // beyond, it flattened the win estimate until a 5-shanten hand scored like
    // a 1-shanten one.
    final expected = EfficiencyEngine.typicalUkeireByShanten;

    final rng = Random(7);
    final calc = TileEfficiencyCalculator();
    final total = List<double>.filled(expected.length, 0);
    final count = List<int>.filled(expected.length, 0);
    var judged = 0;

    for (var game = 0; game < 400; game++) {
      final wall = wallFor(rng);
      var next = 0;
      final tiles = <TileType>[for (var i = 0; i < 14; i++) wall[next++]];

      for (var turn = 0; turn < 14 && next < wall.length; turn++) {
        var id = 0;
        final hand = tiles.map((t) => Tile(id++, t)).toList();
        final seen = List<int>.filled(34, 0);
        for (final t in tiles) {
          seen[t.index - 1]++;
        }
        final remaining = trainerCountsFromTypeCounts(
          [for (var i = 0; i < 34; i++) 4 - seen[i]],
        );
        final lines = calc.calculate(toTrainerCounts(hand), remaining)
          ..sort((a, b) {
            final s = a.shanten.compareTo(b.shanten);
            return s != 0 ? s : b.ukeire.compareTo(a.ukeire);
          });
        if (lines.isEmpty) break;
        final best = lines.first;
        if (best.shanten >= 0 && best.shanten < expected.length) {
          total[best.shanten] += best.ukeire;
          count[best.shanten]++;
        }
        if (best.shanten <= 0) break;
        tiles.remove(best.discard);
        tiles.add(wall[next++]);
      }
    }

    for (var shanten = 0; shanten < expected.length; shanten++) {
      if (count[shanten] < 30) continue; // too few samples to judge
      judged++;
      final mean = total[shanten] / count[shanten];
      expect(
        mean,
        closeTo(expected[shanten], expected[shanten] * 0.15),
        reason: '$shanten-shanten hands average ${mean.toStringAsFixed(1)} '
            'acceptance over ${count[shanten]} positions, but the engine '
            'normalises against ${expected[shanten]}',
      );
    }
    expect(judged, greaterThanOrEqualTo(5),
        reason: 'the simulation reached enough distances to be worth trusting');
  });

  group('across simulated play', () {
    /// Every position a greedy player reaches over [games] hands, analysed with
    /// nothing threatening — no opponent riichi, so no line is carrying a
    /// safety discount and shape alone decides.
    List<EfficiencyReport> play({int games = 200, int seed = 999}) {
      final rng = Random(seed);
      final reports = <EfficiencyReport>[];

      for (var game = 0; game < games; game++) {
        final wall = wallFor(rng);
        var next = 0;
        final tiles = <TileType>[for (var i = 0; i < 14; i++) wall[next++]];
        final discarded = <TileType>[];
        final isDealer = rng.nextBool();

        for (var turn = 0; turn < 12 && next < wall.length; turn++) {
          var id = 0;
          final hand = tiles.map((t) => Tile(id++, t)).toList();
          final seen = List<int>.filled(34, 0);
          for (final t in [...tiles, ...discarded]) {
            seen[t.index - 1]++;
          }
          final report = EfficiencyEngine().analyze(
            hand: hand,
            visibleCounts34: seen,
            canRiichi: true,
            valueContext: EfficiencyValueContext(
              melds: const [],
              roundWind: Wind.east,
              seatWind: isDealer ? Wind.east : Wind.south,
              isDealer: isDealer,
              inRiichi: false,
              wallTilesRemaining: 70 - turn * 4,
              doraIndicators: const [],
            ),
          );
          reports.add(report);
          if (report.tenpai) break;
          final cut = report.lines.first.discard;
          tiles.remove(cut);
          discarded.add(cut);
          tiles.add(wall[next++]);
        }
      }
      return reports;
    }

    test('a strictly worse shape never scores higher', () {
      // The failure this exists for: the riichi deposit rode on reaching
      // tenpai while the payout rode on winning, so a hand was charged more
      // the closer to home it got, and a hopeless line could outscore a good
      // one purely by being too far away to owe anything.
      final offenders = <String>[];
      var pairs = 0;

      for (final report in play()) {
        for (final better in report.lines) {
          for (final worse in report.lines) {
            if (identical(better, worse)) continue;
            pairs++;
            if (worse.shanten <= better.shanten) continue;
            if (worse.ukeire > better.ukeire) continue;
            if (worse.expectedValue <= better.expectedValue + 1e-9) continue;
            offenders.add(
              '${worse.discard.code} (${worse.shanten}-shanten, '
              '${worse.ukeire} ukeire, ev ${worse.expectedValue.round()}) '
              'beat ${better.discard.code} (${better.shanten}-shanten, '
              '${better.ukeire} ukeire, ev ${better.expectedValue.round()})',
            );
          }
        }
      }

      expect(pairs, greaterThan(10000), reason: 'the sweep really ran');
      expect(offenders, isEmpty,
          reason: '${offenders.length} inversions, first few: '
              '${offenders.take(3).join('; ')}');
    });

    test('win probability falls with every step further from tenpai', () {
      // Not a property of any one hand — a wide 1-shanten really can be
      // likelier to get home than a three-tile tanki. But averaged over every
      // discard of every position, each extra step away has to cost you.
      final total = <int, double>{};
      final count = <int, int>{};
      for (final report in play()) {
        for (final line in report.lines) {
          total[line.shanten] = (total[line.shanten] ?? 0) + line.winProbability;
          count[line.shanten] = (count[line.shanten] ?? 0) + 1;
        }
      }

      final means = {
        for (final s in total.keys)
          if (count[s]! >= 100) s: total[s]! / count[s]!,
      };
      final steps = means.keys.toList()..sort();
      expect(steps.length, greaterThanOrEqualTo(4),
          reason: 'need a few distances to compare');

      for (var i = 1; i < steps.length; i++) {
        expect(
          means[steps[i]]!,
          lessThan(means[steps[i - 1]]!),
          reason: '${steps[i]}-shanten averages '
              '${means[steps[i]]!.toStringAsFixed(3)} against '
              '${steps[i - 1]}-shanten at '
              '${means[steps[i - 1]]!.toStringAsFixed(3)}',
        );
      }
    });
  });
}
