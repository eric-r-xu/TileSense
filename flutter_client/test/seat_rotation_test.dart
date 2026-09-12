import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';

void main() {
  for (final draw in [true, false]) {
    for (final dealerWins in [true, false]) {
      test('rotation: draw=$draw, dealer wins=$dealerWins', () {
        final r = GameController.rotateAfterRound(
            exhaustiveDraw: draw,
            dealerKept: dealerWins,
            dealer: 3,
            roundNumber: 7,
            honba: 3);
        final repeats = draw || dealerWins;
        expect(r.dealer, repeats ? 3 : 0);
        expect(r.roundNumber, repeats ? 7 : 8);
        expect(r.honba, 0);
      });
    }
  }
}
