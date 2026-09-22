import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';

import 'helpers.dart';

/// Kyuushu kyuuhai (nine kinds of terminals/honors): any seat may abort the
/// round on their own first uninterrupted draw if their 14-tile hand holds
/// nine or more *different* terminal/honor types.
void main() {
  Round freshRound({Ruleset ruleset = Ruleset.riichi}) => Round(
        seed: 7,
        dealer: 0,
        roundWind: Wind.east,
        honba: 0,
        riichiSticks: 0,
        startingPoints: List.filled(4, 25000),
        ruleset: ruleset,
      );

  group('Round.canDeclareKyuushu', () {
    test('nine different terminal/honor types on your own first draw', () {
      final round = freshRound();
      round.seats[0].hand = parseTiles('19m 19p 19s ESW 11m 11p E');
      expect(round.seats[0].hand.length, 14);
      round.turn = 0;
      round.phase = RoundPhase.discarding;

      expect(round.canDeclareKyuushu(0), isTrue);
    });

    test('only eight different types is not enough', () {
      final round = freshRound();
      round.seats[0].hand = parseTiles('19m 19p 19s ES 11m 11p 11p');
      expect(round.seats[0].hand.length, 14);
      round.turn = 0;
      round.phase = RoundPhase.discarding;

      expect(round.canDeclareKyuushu(0), isFalse);
    });

    test('not available once you have already discarded this hand', () {
      final round = freshRound();
      round.seats[0].hand = parseTiles('19m 19p 19s ESW 11m 11p E');
      round.seats[0].pond.add(Tile(999, TileType.man2));
      round.turn = 0;
      round.phase = RoundPhase.discarding;

      expect(round.canDeclareKyuushu(0), isFalse);
    });

    test('not your turn, not offered', () {
      final round = freshRound();
      round.seats[1].hand = parseTiles('19m 19p 19s ESW 11m 11p E');
      round.turn = 0; // not seat 1
      round.phase = RoundPhase.discarding;

      expect(round.canDeclareKyuushu(1), isFalse);
    });

    test('Hong Kong has no such rule', () {
      final round = freshRound(ruleset: Ruleset.hongKong);
      round.seats[0].hand = parseTiles('19m 19p 19s ESW 11m 11p E');
      round.turn = 0;
      round.phase = RoundPhase.discarding;

      expect(round.canDeclareKyuushu(0), isFalse);
    });

    test('a call anywhere at the table voids it for everyone', () {
      final round = freshRound();
      // Seat 1 can pon whatever seat 0 discards.
      round.seats[1].hand = [
        Tile(700, TileType.chun),
        Tile(701, TileType.chun),
        ...parseTiles('456m 234p 99s 234s'),
      ];
      final feed = Tile(703, TileType.chun);
      round.seats[0].hand = [...parseTiles('123m 456m 789m 123p 4p'), feed];
      round.seats[0].drawn = feed;
      round.turn = 0;
      round.phase = RoundPhase.discarding;

      round.discard(0, feed);
      expect(round.phase, RoundPhase.callOffer);
      round.resolveCalls({1: CallType.pon});
      expect(round.phase, RoundPhase.discarding,
          reason: 'sanity: the pon actually went through');

      // Point straight at seat 2 with an otherwise-qualifying, still
      // untouched hand — the only thing standing between it and eligibility
      // is that a call already happened at the table this hand.
      round.seats[2].hand = parseTiles('19m 19p 19s ESW 11m 11p E');
      round.turn = 2;

      expect(round.canDeclareKyuushu(2), isFalse,
          reason: 'a pon anywhere already broke the first go-around');
    });
  });

  test('declareKyuushu aborts the round with no winners', () {
    final round = freshRound();
    round.seats[0].hand = parseTiles('19m 19p 19s ESW 11m 11p E');
    round.turn = 0;
    round.phase = RoundPhase.discarding;

    round.declareKyuushu(0);

    expect(round.phase, RoundPhase.finished);
    expect(round.result!.kind, RoundEndKind.abortiveDraw);
    expect(round.result!.winners, isEmpty);
  });

  testWidgets(
      'GameController: declaring it ends the round and the dealer repeats',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 3);
    final round = game.round;
    try {
      round.seats[kHumanSeat].hand = parseTiles('19m 19p 19s ESW 11m 11p E');
      round.turn = kHumanSeat;
      round.phase = RoundPhase.discarding;
      expect(game.humanCanDeclareKyuushu, isTrue);

      final dealerBefore = round.dealer;
      final honbaBefore = round.honba;
      game.humanDeclareKyuushu();
      expect(game.phase, GamePhase.roundEnd);

      // A fresh Round is dealt on continue — check the new one, not the
      // finished one still captured above.
      game.continueFromRoundEnd();

      expect(game.round.dealer, dealerBefore,
          reason: 'an abortive draw always keeps the dealer');
      expect(game.round.honba, honbaBefore + 1);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });
}
