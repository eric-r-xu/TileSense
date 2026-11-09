import 'dart:math';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('agari with wilds', () {
    bool agari(String naturals, int wilds, {int open = 0}) {
      final c = toCounts34(tiles(naturals));
      return isAgariFuzhou(c, wilds: wilds, meldCount: open);
    }

    test('a plain 17-tile hand: five melds and a pair', () {
      expect(agari('123m 456m 789m 123p 456p 99s', 0), isTrue);
      expect(agari('123m 456m 789m 123p 456p 98s', 0), isFalse);
    });

    test('a wild fills a missing tile of a run, a triplet or the pair', () {
      expect(agari('123m 456m 789m 123p 45p 99s', 1), isTrue); // run
      expect(agari('123m 456m 789m 123p 456p 9s', 1), isTrue); // pair
      expect(agari('123m 456m 789m 123p 456p 99s', 0), isTrue);
      expect(agari('123m 456m 789m 123p 11p 99s', 1), isTrue); // 11p + wild
    });

    test('three wilds make a meld of their own', () {
      expect(agari('123m 456m 789m 123p 99s', 3), isTrue);
      expect(agari('123m 456m 789m 123p 99s', 2), isFalse);
    });

    test('open melds shorten the hand', () {
      expect(agari('123m 456m 789m 99s', 0, open: 2), isTrue);
      expect(agari('123m 456m 789m 9s', 1, open: 2), isTrue);
    });

    test('a run can lean on a wild at either end or the middle', () {
      expect(agari('24m 456m 789m 123p 456p 99s', 1), isTrue); // 2_4
      expect(agari('12m 456m 789m 123p 456p 99s', 1), isTrue); // 12_
      expect(agari('23m 456m 789m 123p 456p 99s', 1), isTrue); // _23
    });

    test('sequences only', () {
      final c = toCounts34(tiles('123m 456m 789m 123p 456p 99s'));
      expect(isAgariFuzhou(c, allowTriplets: false), isTrue);
      final d = toCounts34(tiles('111m 456m 789m 123p 456p 99s'));
      expect(isAgariFuzhou(d), isTrue);
      expect(isAgariFuzhou(d, allowTriplets: false), isFalse);
    });

    test('matches the plain checker with no wilds, and brute force with some',
        () {
      final rng = Random(7);
      var wins = 0;
      for (var n = 0; n < 4000; n++) {
        final w = rng.nextInt(4);
        final open = rng.nextInt(3);
        final natural = 17 - open * 3 - w;
        final c = List<int>.filled(34, 0);
        // Bias towards compact hands so wins are common enough to test.
        for (var k = 0; k < natural; k++) {
          final suit = rng.nextInt(2);
          var i = suit * 9 + rng.nextInt(5) + (rng.nextBool() ? 0 : 3);
          if (c[i] >= 4) i = (i + 1) % 27;
          if (c[i] < 4) c[i]++;
        }
        if (c.fold<int>(0, (a, b) => a + b) != natural) continue;
        final fast = isAgariFuzhou(c, wilds: w, meldCount: open);
        // Brute force: try every assignment of the wilds.
        bool brute(List<int> cc, int left) {
          if (left == 0) return isAgari(cc, meldCount: open, totalMelds: 5);
          for (var i = 0; i < 27; i++) {
            cc[i]++;
            final ok = brute(cc, left - 1);
            cc[i]--;
            if (ok) return true;
          }
          return false;
        }

        final slow = brute(List.of(c), w);
        expect(fast, slow, reason: 'counts=$c wilds=$w open=$open');
        if (fast) wins++;
      }
      expect(wins, greaterThan(50), reason: 'the sample should include wins');
    });
  });

  group('waits and gold', () {
    test('without gold, waits are plain tiles', () {
      final hand = tiles('123m 456m 789m 123p 45p 99s');
      expect(waitTilesFuzhou(hand), unorderedEquals([type('3p'), type('6p')]));
    });

    test('Gold tiles in hand are wild and the Gold itself is always a wait',
        () {
      final gold = {type('5s')};
      // 15 naturals + a gold 5s; ready on 6p/3p as before? 123m 456m 789m
      // 123p 4p 99s + gold: gold makes 45p-> needs one more.
      final hand = [...tiles('123m 456m 789m 123p 4p 99s'), ...tiles('5s')];
      final waits = waitTilesFuzhou(hand, goldTypes: gold);
      expect(waits, contains(type('5s')), reason: 'drawing a gold finishes it');
      expect(waits, contains(type('3p')));
      expect(waits, contains(type('5p')));
    });

    test('a hand that is not ready has no waits, not even the Gold', () {
      final hand = tiles(junk16);
      expect(waitTilesFuzhou(hand, goldTypes: {type('5s')}), isEmpty);
      expect(isTenpaiFuzhou(hand, goldTypes: {type('5s')}), isFalse);
    });

    test('splitGold sorts wilds from naturals and drops stray flowers', () {
      final s = splitGold([
        ...tiles('12m 5s 5s'),
        Tile(1, TileType.plum),
      ], {type('5s'), TileType.plum});
      expect(s.wilds, 3);
      expect(s.counts.fold<int>(0, (a, b) => a + b), 2);
    });
  });

  group('wild shanten', () {
    final calc = TileEfficiencyCalculator();
    int shanten(List<int> c, int w, int open) =>
        calc.wildShanten(trainerCountsFromTypeCounts(c),
            openMelds: open, wilds: w);

    test('agrees with the wait search across random 16-tile hands', () {
      final rng = Random(11);
      var ready = 0;
      for (var n = 0; n < 3000; n++) {
        final w = rng.nextInt(4);
        final open = rng.nextInt(3);
        final natural = 16 - open * 3 - w;
        final c = List<int>.filled(34, 0);
        for (var k = 0; k < natural; k++) {
          var i = rng.nextInt(2) * 9 + rng.nextInt(6) + (rng.nextBool() ? 0 : 3);
          if (c[i] >= 4) i = (i + 1) % 27;
          if (c[i] < 4) c[i]++;
        }
        if (c.fold<int>(0, (a, b) => a + b) != natural) continue;
        final hasWait = [
          for (var i = 0; i < 27; i++)
            if (c[i] < 4)
              () {
                c[i]++;
                final ok = isAgariFuzhou(c, wilds: w, meldCount: open);
                c[i]--;
                return ok;
              }()
        ].any((x) => x);
        final s = shanten(c, w, open);
        expect(s == 0, hasWait, reason: 'counts=$c wilds=$w open=$open s=$s');
        if (hasWait) ready++;
      }
      expect(ready, greaterThan(30));
    });

    test('a complete 17-tile hand is -1 and a spare wild reaches it', () {
      final c = toCounts34(tiles('123m 456m 789m 123p 456p 99s'));
      expect(shanten(c, 0, 0), -1);
      final d = toCounts34(tiles('123m 456m 789m 123p 456p 9s'));
      expect(shanten(d, 1, 0), -1);
    });

    test('one-shanten agrees with a draw-and-discard search', () {
      final rng = Random(23);
      var oneShanten = 0;
      for (var n = 0; n < 250; n++) {
        final w = rng.nextInt(3);
        final natural = 16 - w;
        final c = List<int>.filled(34, 0);
        for (var k = 0; k < natural; k++) {
          var i = rng.nextInt(2) * 9 + rng.nextInt(6) + (rng.nextBool() ? 0 : 3);
          if (c[i] >= 4) i = (i + 1) % 27;
          if (c[i] < 4) c[i]++;
        }
        if (c.fold<int>(0, (a, b) => a + b) != natural) continue;
        if (shanten(c, w, 0) == 0) continue;
        // Reachable in one step: draw a tile (or a wild), discard one, ready.
        bool readyAfterOneStep() {
          bool ready(List<int> cc, int ww) {
            for (var i = 0; i < 27; i++) {
              if (cc[i] >= 4) continue;
              cc[i]++;
              final ok = isAgariFuzhou(cc, wilds: ww);
              cc[i]--;
              if (ok) return true;
            }
            return isAgariFuzhou(cc, wilds: ww + 1);
          }

          // draw a natural or a wild, then discard a natural or a wild
          for (var d = -1; d < 27; d++) {
            final cc = List<int>.of(c);
            var ww = w;
            if (d < 0) {
              ww++;
            } else {
              if (cc[d] >= 4) continue;
              cc[d]++;
            }
            for (var x = -1; x < 27; x++) {
              final c2 = List<int>.of(cc);
              var w2 = ww;
              if (x < 0) {
                if (w2 == 0) continue;
                w2--;
              } else {
                if (c2[x] == 0) continue;
                c2[x]--;
              }
              if (ready(c2, w2)) return true;
            }
          }
          return false;
        }

        final s = shanten(c, w, 0);
        expect(s <= 1, readyAfterOneStep(),
            reason: 'counts=$c wilds=$w s=$s');
        if (s == 1) oneShanten++;
      }
      expect(oneShanten, greaterThan(10));
    });
  });
}
