// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/logic/sichuan_guide.dart';
import 'package:tilesense/logic/sichuan_value.dart';

import 'helpers.dart';

/// The Sichuan value model's formulas (`sichuan_value.dart`): the properties
/// that must hold whatever the dials are set to.
void main() {
  final saved = (
    SichuanValueTuning.valueScale,
    SichuanValueTuning.dealInScale,
    SichuanValueTuning.endSettlement,
    SichuanValueTuning.guideVoidPick,
  );
  tearDown(() {
    SichuanValueTuning.valueScale = saved.$1;
    SichuanValueTuning.dealInScale = saved.$2;
    SichuanValueTuning.endSettlement = saved.$3;
    SichuanValueTuning.guideVoidPick = saved.$4;
  });

  SichuanRival rival({
    int seat = 1,
    bool out = false,
    int? voidSuit = 2,
    int discards = 10,
    Set<TileType> thrown = const {},
    int melds = 0,
  }) =>
      SichuanRival(
          seat: seat,
          out: out,
          voidSuit: voidSuit,
          discards: discards,
          thrown: thrown,
          melds: melds);

  group('the chance of getting home', () {
    ({double win, double ready}) chain(
            {int shanten = 0,
            int outs = 6,
            int unseen = 70,
            int draws = 10,
            int rivals = 3}) =>
        SichuanValue.chain(
            shanten: shanten,
            outs: outs,
            unseen: unseen,
            draws: draws,
            rivals: rivals);

    test('a finished hand is home; a ready hand with no outs never gets there',
        () {
      expect(chain(shanten: -1).win, 1);
      expect(chain(outs: 0).win, 0);
      expect(chain(outs: 0).ready, 1,
          reason: 'it stands ready the whole way, and wins nothing');
    });

    test('more draws, more outs, closer to ready, and more rivals to feed it '
        'each raise the chance', () {
      expect(chain(draws: 12).win, greaterThan(chain(draws: 6).win));
      expect(chain(outs: 8).win, greaterThan(chain(outs: 4).win));
      expect(chain(rivals: 3).win, greaterThan(chain(rivals: 1).win));
      expect(chain(shanten: 0).win, greaterThan(chain(shanten: 1).win));
      expect(chain(shanten: 1).win, greaterThan(chain(shanten: 3).win));
    });

    test('win and ready are probabilities that never exceed one together', () {
      for (final shanten in [0, 1, 2, 4]) {
        for (final draws in [0, 1, 5, 20]) {
          final c = chain(shanten: shanten, draws: draws);
          expect(c.win, inInclusiveRange(0, 1));
          expect(c.ready, inInclusiveRange(0, 1));
          expect(c.win + c.ready, lessThanOrEqualTo(1 + 1e-9));
        }
      }
    });

    test('no draws left, no win; a hand one step off stays one step off', () {
      expect(chain(draws: 0).win, 0);
      expect(chain(shanten: 1, draws: 0).ready, 0);
    });

    test('draws are the wall shared by the seats still in', () {
      expect(SichuanValue.draws(48, 3), 12);
      expect(SichuanValue.draws(48, 1), 24);
      expect(SichuanValue.draws(0, 3), 1);
    });
  });

  group('what a Hu pays', () {
    test('a self-draw pays every seat still in one more; a Hu off a discard '
        'pays the discarder alone', () {
      // With no ron to be had, every win is a self-draw.
      final saveRon = SichuanValueTuning.ronPerRival;
      addTearDown(() => SichuanValueTuning.ronPerRival = saveRon);
      SichuanValueTuning.ronPerRival = 0;
      expect(SichuanValue.payoff(1, 3), (1 + 1) * 3);
      expect(SichuanValue.payoff(4, 2), (4 + 1) * 2);
      SichuanValueTuning.ronPerRival = 100;
      expect(SichuanValue.payoff(2, 3), closeTo(2, 0.1));
    });

    test('a bigger hand always pays more, and a thinner table pays less', () {
      expect(SichuanValue.payoff(4, 3), greaterThan(SichuanValue.payoff(2, 3)));
      expect(SichuanValue.payoff(2, 3), greaterThan(SichuanValue.payoff(2, 1)));
    });
  });

  group('the end of an unwon hand', () {
    test('ready is worth more than not, and being left short costs', () {
      double end(double ready, double unready) => SichuanValue.endValue(
          pReady: ready, pUnready: unready, readyValue: 1.5, rivals: 3);
      expect(end(1, 0), greaterThan(0));
      expect(end(0, 1), lessThan(0));
      expect(end(1, 0), greaterThan(end(0, 1)));
      SichuanValueTuning.endSettlement = false;
      expect(end(1, 0), 0);
    });
  });

  group('danger', () {
    test('a rival that has given up the suit can never be dealt into it', () {
      expect(
          SichuanValue.dealInCost(TileType.man5, [rival(voidSuit: 0)]), 0);
      expect(
          SichuanValue.dealInCost(TileType.man5, [rival(voidSuit: 1)]),
          greaterThan(0));
    });

    test('a tile a ready rival has already thrown is far safer', () {
      final fresh = SichuanValue.dealInCost(TileType.pin5, [rival()]);
      final thrown = SichuanValue.dealInCost(
          TileType.pin5, [rival(thrown: {TileType.pin5})]);
      expect(thrown, lessThan(fresh / 10));
    });

    test('a seat that is out is nothing to fear; one that has barely played '
        'is little', () {
      expect(SichuanValue.dealInCost(TileType.pin5, [rival(out: true)]), 0);
      expect(
          SichuanValue.dealInCost(TileType.pin5, [rival(discards: 2)]),
          lessThan(SichuanValue.dealInCost(TileType.pin5, [rival(discards: 12)])));
    });

    test('a suit not yet shown could be the rival\'s: two in three', () {
      final known = SichuanValue.dealInCost(TileType.pin5, [rival()]);
      final hidden =
          SichuanValue.dealInCost(TileType.pin5, [rival(voidSuit: null)]);
      expect(hidden, closeTo(known * 2 / 3, 1e-9));
    });

    test('every ready seat adds to it, and turning defence off removes it', () {
      final one = SichuanValue.dealInCost(TileType.pin5, [rival()]);
      final two = SichuanValue.dealInCost(
          TileType.pin5, [rival(), rival(seat: 2)]);
      expect(two, closeTo(2 * one, 1e-9));
      SichuanValueTuning.dealInScale = 0;
      expect(SichuanValue.dealInCost(TileType.pin5, [rival()]), 0);
    });

    test('a rival is more likely ready the more it has discarded, and with '
        'every meld shown', () {
      for (var n = 1; n < 20; n++) {
        expect(SichuanValue.readyChance(rival(discards: n + 1)),
            greaterThanOrEqualTo(SichuanValue.readyChance(rival(discards: n))));
      }
      expect(SichuanValue.readyChance(rival(melds: 2)),
          greaterThan(SichuanValue.readyChance(rival())));
      expect(SichuanValue.readyChance(rival(discards: 99)), lessThan(1));
    });
  });

  group('what a hand will be worth', () {
    test('a ready hand is scored on its real waits', () {
      // 1m is the only wait; the finished hand is a flush of pungs.
      final rest = parseTiles('111m 222m 333m 444m 5m');
      final live = List<int>.filled(34, 0)..[4] = 3;
      final wait = SichuanValue.waitValue(
        rest: rest,
        melds: const [],
        live34: live,
        context: ScoreContext(
            roundWind: Wind.east, seatWind: Wind.east, isTsumo: false, closed: true),
      );
      expect(wait.outs, 3);
      final direct = scoreSichuanHand(
          rest,
          Tile(9000, TileType.man5),
          const [],
          ScoreContext(
              roundWind: Wind.east,
              seatWind: Wind.east,
              isTsumo: false,
              closed: true));
      expect(wait.value, direct.points.toDouble());
      expect(wait.value, greaterThan(1));
    });

    test('a wait with no tile left to draw is worth nothing and counts no outs',
        () {
      final wait = SichuanValue.waitValue(
        rest: parseTiles('111m 222m 333m 444m 5m'),
        melds: const [],
        live34: List<int>.filled(34, 0),
        context: ScoreContext(
            roundWind: Wind.east, seatWind: Wind.east, isTsumo: false, closed: true),
      );
      expect(wait.outs, 0);
    });

    test('a scattered hand is worth the base; roots and a flush raise it, and '
        'turning the estimate off leaves only the roots', () {
      final scattered = parseTiles('137m 258p 369s 14m 25p');
      expect(SichuanValue.potentialValue(scattered, const [], null),
          closeTo(1, 0.05));

      final flushy = parseTiles('123m 456m 789m 11m 22m');
      final rooted = parseTiles('1111m 258p 369s 14m');
      expect(SichuanValue.potentialValue(flushy, const [], null),
          greaterThan(SichuanValue.potentialValue(scattered, const [], null)));
      expect(SichuanValue.potentialValue(rooted, const [], null),
          greaterThanOrEqualTo(2),
          reason: 'a root is one fan, which doubles a hand');

      SichuanValueTuning.valueScale = 0;
      expect(SichuanValue.potentialValue(flushy, const [], null), 1);
      expect(SichuanValue.potentialValue(rooted, const [], null), 2);
    });

    test('the void suit counts for nothing', () {
      final hand = parseTiles('1111s 123m 456m 789p');
      expect(SichuanValue.potentialValue(hand, const [], 2), lessThan(2));
    });
  });

  group('the suit to give up', () {
    test('with the dial off it is the rule it replaces', () {
      SichuanValueTuning.guideVoidPick = false;
      final hand = parseTiles('123m 456m 789p 11p 5s 9s');
      for (var f = 0; f < 3; f++) {
        expect(SichuanGuide.suggestVoidSuit(hand, fallback: f), f);
      }
    });

    test('it gives up the suit that is in the way of a hand nearly ready', () {
      // Man and pin make three sets and a pair on their own; sou is junk.
      final hand = parseTiles('123m 456m 789p 11p 5s 9s');
      expect(SichuanGuide.suggestVoidSuit(hand, fallback: 0), 2);
    });

    test('it never gives up a suit it does not hold when it holds all three',
        () {
      final hand = parseTiles('123m 456p 789s 11m 22p 3s');
      final suit = SichuanGuide.suggestVoidSuit(hand, fallback: 0);
      expect(suit, inInclusiveRange(0, 2));
      expect(hand.any((t) => t.type.suit == suit), isTrue);
    });
  });
}
