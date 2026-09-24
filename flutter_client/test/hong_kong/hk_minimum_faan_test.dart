import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import '../helpers.dart';
import 'hk_helpers.dart';

void main() {
  // An open chow and a non-matching flower: cutting the 9m leaves a chicken
  // hand ready on 2m/5p — 0 faan on a discard, 1 on a self-pick.
  final chow = [
    Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false)
  ];
  DiscardLine cut9m(int minimumFaan) => hkReport('456p 789s 22m 55p 9m',
          melds: chow, flowers: [TileType.plum], minimumFaan: minimumFaan)
      .lines
      .firstWhere((l) => l.discard == TileType.man9);

  test('a ready hand under the minimum is worth less, then nothing', () {
    final any = cut9m(0);
    final selfPickOnly = cut9m(1);
    final dead = cut9m(2);
    expect(any.shanten, 0);
    expect(any.expectedValue, greaterThan(selfPickOnly.expectedValue));
    expect(selfPickOnly.expectedValue, greaterThan(0));
    expect(dead.expectedValue, lessThanOrEqualTo(0));
    expect(dead.valuePlan, 'NO LIVE WAIT');
  });

  test('the guide names the minimum rather than promising any hand wins', () {
    expect(cut9m(0).reason, contains('chicken'));
    expect(cut9m(1).reason, contains('1 faan'));
  });

  test('an unready hand is priced as reaching at least the minimum', () {
    double value(int minimumFaan) =>
        hkReport('123m 456p 789s 25p 22s 9m', minimumFaan: minimumFaan)
            .lines
            .firstWhere((l) => l.discard == TileType.man9)
            .averagePoints;
    expect(value(3), greaterThan(value(0)));
  });

  test('tsumo advice scores a self-pick that clears the minimum', () {
    final hand = parseTiles('456p 789s 22m 55p 5p');
    final advice = EfficiencyEngine().adviseTsumo(
        hand: hand,
        drawn: hand.last,
        context:
            hkContext(melds: chow, flowers: [TileType.plum], minimumFaan: 1));
    expect(advice.expectedValue, greaterThan(0));
  });
}
