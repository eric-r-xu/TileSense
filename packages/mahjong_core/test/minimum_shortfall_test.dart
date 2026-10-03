import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'mcr/helpers.dart' show tiles;

/// Seat 1 (South, dealer 0) holding [hand] (13 tiles less three per meld)
/// beside [melds]. Hong Kong and Taiwanese minimums are covered beside their
/// own minimum tests.
Round _table(Ruleset ruleset, String hand, {List<Meld> melds = const []}) {
  final r = Round.posed(
    ruleset: ruleset,
    dealer: 0,
    roundWind: Wind.east,
    wall: ruleset.isRiichi
        ? Wall(1)
        : HongKongWall.fromTiles([Tile(990, TileType.sou1)]),
    startingPoints: List.filled(4, ruleset.startingPoints),
  );
  r.seats[1].hand = tiles(hand);
  r.seats[1].melds = melds;
  return r;
}

final _openChow =
    Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false);

void main() {
  group('riichi', () {
    test('an open hand with no yaku cannot win at all', () {
      final r = _table(Ruleset.riichi, '456p 789s 55s 23m', melds: [_openChow]);
      expect(r.minimumShortfall(1), MinimumShortfall.dead);
    });

    test('a closed hand with no yaku can still win by menzen tsumo', () {
      // A kanchan on 2m, so not pinfu either.
      final r = _table(Ruleset.riichi, '789m 456p 789s 99s 13m');
      expect(r.minimumShortfall(1), MinimumShortfall.ronOnly);
    });

    test('a hand with a yaku has no shortfall', () {
      final r = _table(Ruleset.riichi, '234m 456p 678s 55s 46m'); // tanyao
      expect(r.minimumShortfall(1), MinimumShortfall.none);
    });

    test('a hand that is not tenpai has no shortfall', () {
      final r = _table(Ruleset.riichi, '19m 19p 19s 1234z 258m');
      expect(r.minimumShortfall(1), MinimumShortfall.none);
    });
  });

  test('MCR: a hand under 8 fan cannot win', () {
    // 234m (open) 456p 789s 55m, waiting on 1s/4s: no Mixed Straight, so
    // nothing near 8 fan off a discard or self-drawn.
    final r = _table(Ruleset.mcr, '456p 789s 23s 55m', melds: [
      Meld(kind: MeldKind.sequence, low: TileType.man2, concealed: false)
    ]);
    expect(r.minimumShortfall(1), MinimumShortfall.dead);
  });
}
