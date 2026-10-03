import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'helpers.dart' show tiles;

void main() {
  final calc = McrEfficiencyCalculator();
  // Every tile live except the hand's own copies.
  List<int> remaining(List<int> hand) => [
        for (var i = 0; i < hand.length; i++)
          i % 10 == 0 || i == 0 ? 0 : (4 - hand[i]).clamp(0, 4)
      ];

  test('an open hand between draws has acceptance, as a closed one does', () {
    // 456m 13p 678s 88s beside an exposed South pung: one away, waiting to
    // fill 2p or pair up — the same shape as the closed hand with a South
    // pung of its own.
    final open = toTrainerCounts(tiles('456m13p678s88s'));
    final closed = toTrainerCounts(tiles('456m13p678s88s222z'));
    final shantenOpen = calc.calculateWaitingShanten(open);
    expect(shantenOpen, calc.calculateWaitingShanten(closed));
    final a = calc.acceptance(open, remaining(open));
    expect(a.count, greaterThan(0));
    expect(a.tiles, containsAll([trainerIndexOf(TileType.pin2)]));
  });

  test('every discard of an open hand that is one away keeps acceptance', () {
    // Eleven tiles: the hand above with 8p and 3s drawn, before discarding.
    final hand = toTrainerCounts(tiles('456m138p36788s'));
    for (final line in calc.calculate(hand, remaining(hand))) {
      if (line.shanten == 1) expect(line.ukeire, greaterThan(0));
    }
  });
}
