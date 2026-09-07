import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';

void main() {
  group('rotateAfterRound', () {
    test('noten dealer at an exhaustive draw passes the button and advances '
        'the round wind (honba still ticks)', () {
      final r = GameController.rotateAfterRound(
        exhaustiveDraw: true,
        dealerKept: false,
        dealer: 0,
        roundNumber: 0,
        honba: 0,
      );
      expect(r.dealer, 1);
      expect(r.roundNumber, 1);
      expect(r.honba, 1);
    });

    test('tenpai dealer at an exhaustive draw keeps the seat and adds a honba',
        () {
      final r = GameController.rotateAfterRound(
        exhaustiveDraw: true,
        dealerKept: true,
        dealer: 2,
        roundNumber: 6,
        honba: 1,
      );
      expect(r.dealer, 2);
      expect(r.roundNumber, 6);
      expect(r.honba, 2);
    });

    test('dealer win keeps the seat and adds a honba', () {
      final r = GameController.rotateAfterRound(
        exhaustiveDraw: false,
        dealerKept: true,
        dealer: 1,
        roundNumber: 3,
        honba: 2,
      );
      expect(r.dealer, 1);
      expect(r.roundNumber, 3);
      expect(r.honba, 3);
    });

    test('non-dealer win passes the button, advances the round wind, and '
        'clears honba', () {
      final r = GameController.rotateAfterRound(
        exhaustiveDraw: false,
        dealerKept: false,
        dealer: 3,
        roundNumber: 5,
        honba: 4,
      );
      expect(r.dealer, 0);
      expect(r.roundNumber, 6);
      expect(r.honba, 0);
    });
  });
}
