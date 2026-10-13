import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';

import 'helpers.dart';

/// A double ron where one winner is the dealer is a dealer win: the button
/// stays put (renchan), whichever seat the dealer is and whichever seat the
/// other winner is.
void main() {
  for (final ruleset in [Ruleset.riichi, Ruleset.hongKong]) {
    for (var dealer = 0; dealer < 4; dealer++) {
      test('${ruleset.name}: dealer $dealer wins a double ron and keeps the '
          'deal', () {
        final game =
            GameController(seed: 3, startingDealer: dealer, ruleset: ruleset);
        game.paused = true;
        final other = (dealer + 1) % 4;
        final feeder = (dealer + 2) % 4;

        // Dealer and `other` both wait on 5p/8p; `feeder` cuts 5p.
        final round = Round(
          seed: 1,
          dealer: dealer,
          roundWind: Wind.east,
          honba: 0,
          riichiSticks: 0,
          startingPoints: List.filled(4, 25000),
          ruleset: ruleset,
        );
        round.seats[dealer].hand =
            sortByType(parseTiles('345m 678m 234s 67p 44s'));
        round.seats[dealer].melds = [];
        round.seats[other].hand =
            sortByType(parseTiles('234m 567m 234p 67p 88s'));
        round.seats[other].melds = [];
        final feed = Tile(900, TileType.pin5);
        round.seats[feeder].hand = [
          ...parseTiles('123m 456m 789m 111s 2p'),
          feed
        ];
        round.seats[feeder].drawn = feed;
        round.turn = feeder;
        round.phase = RoundPhase.discarding;
        round.discard(feeder, feed);
        round.resolveCalls({dealer: CallType.ron, other: CallType.ron});
        expect(round.result!.winners, containsAll([dealer, other]));

        game.round = round;
        game.phase = GamePhase.roundEnd;
        game.continueFromRoundEnd();

        expect(game.round.dealer, dealer,
            reason: 'the dealer won, so the deal does not pass');
        expect(game.phase, GamePhase.playing);
        expect(game.dealerRepeat, 1);
      });
    }
  }
}
