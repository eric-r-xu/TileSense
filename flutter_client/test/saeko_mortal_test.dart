import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/mortal_advisor.dart';
import 'package:tilesense/game/sfx.dart';

import 'helpers.dart';

/// Mortal without a sidecar: records which seats ask, and answers [reply]
/// (or throws, when [reply] is null).
class _FakeMortal extends MortalAdvisor {
  _FakeMortal([this.reply]) : super('http://unused');
  final Map<String, Object?>? reply;
  final asked = <int>{};

  @override
  Future<Map<String, Object?>> ask(int seat, List<MjaiEvent> events) async {
    asked.add(seat);
    return reply ?? (throw StateError('sidecar down'));
  }
}

void main() {
  /// Seat 1 on its turn holding [hand] and having drawn [drawn].
  Round turnFor(String hand, String drawn) {
    final game = GameController(seed: 4);
    addTearDown(game.dispose);
    final round = game.round;
    final tile = parseTiles(drawn).single;
    round.seats[1]
      ..hand = [...parseTiles(hand), tile]
      ..drawn = tile
      ..melds = [];
    round.turn = 1;
    round.phase = RoundPhase.discarding;
    return round;
  }

  Map<String, Object?> dahai(String pai, {bool tsumogiri = false}) =>
      {'type': 'dahai', 'actor': 1, 'pai': pai, 'tsumogiri': tsumogiri};

  group('MortalMove.turn', () {
    test('cuts the tile Mortal names, and the drawn one when it says so', () {
      final round = turnFor('123m 456m 789m 11p 45s', '9s');
      final cut = MortalMove.turn({'reaction': dahai('1m')}, round, 1);
      expect(cut.discard!.type, TileType.man1);
      expect(cut.riichi, isFalse);
      final drawn = MortalMove.turn(
          {'reaction': dahai('9s', tsumogiri: true)}, round, 1);
      expect(drawn.discard, same(round.seats[1].drawn));
    });

    test('a riichi plays the discard the sidecar paired with it', () {
      final round = turnFor('123m 456m 789m 11p 45s', '9s');
      final move = MortalMove.turn({
        'reaction': {'type': 'reach', 'actor': 1},
        'riichi_discard': dahai('9s'),
      }, round, 1);
      expect(move.riichi, isTrue);
      expect(move.discard!.type, TileType.sou9);
    });

    test('a move the table does not offer is refused', () {
      final round = turnFor('123m 456m 789m 11p 45s', '9s');
      expect(() => MortalMove.turn({'reaction': dahai('C')}, round, 1),
          throwsStateError);
      expect(() => MortalMove.turn({'reaction': null}, round, 1),
          throwsStateError);
    });
  });

  group('MortalMove.call', () {
    /// Seat 0 discards 4m to seat 1, who holds 35m (a chi) and 44m (a pon).
    Round callFor() {
      final game = GameController(seed: 4);
      addTearDown(game.dispose);
      final round = game.round;
      final fed = parseTiles('4m').single;
      round.seats[1]
        ..hand = parseTiles('35m 44m 789m 11p 45s 9s')
        ..drawn = null
        ..melds = [];
      round.seats[0]
        ..hand = [...parseTiles('123p 456p 789p 111s 2s'), fed]
        ..drawn = fed;
      round.turn = 0;
      round.phase = RoundPhase.discarding;
      round.discard(0, fed);
      return round;
    }

    test('a chi names its run by the lowest tile', () {
      final round = callFor();
      final call = MortalMove.call({
        'reaction': {'type': 'chi', 'actor': 1, 'target': 0, 'pai': '4m',
          'consumed': ['3m', '5m']},
      }, round, 1, {CallType.chi, CallType.pon});
      expect(call.call, CallType.chi);
      expect(call.chiLow, TileType.man3);
    });

    test('no reaction is a pass; a call not offered is refused', () {
      final round = callFor();
      expect(MortalMove.call({'reaction': null}, round, 1, {CallType.pon}).call,
          CallType.none);
      expect(
          () => MortalMove.call({
                'reaction': {'type': 'pon', 'actor': 1}
              }, round, 1, {CallType.chi}),
          throwsStateError);
    });
  });

  group('routing', () {
    const seats = [
      Character.orderic,
      Character.saeko,
      Character.hubert,
      Character.astaroth,
    ];

    /// Plays [game] until [hands] hands have ended, failing if it stalls.
    Future<void> playHands(WidgetTester tester, GameController game,
        {int hands = 1}) async {
      game
        ..setFastMode(true)
        ..setAutoplay(true);
      var ended = 0;
      for (var i = 0; i < 3000 && ended < hands; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (game.phase != GamePhase.playing) {
          ended++;
          if (game.phase == GamePhase.roundEnd) game.continueFromRoundEnd();
        }
      }
      expect(ended, hands, reason: 'the game stalled');
    }

    testWidgets('only Saeko asks Mortal, and a failing Mortal falls back',
        (tester) async {
      Sfx.i.enabled = false;
      final mortal = _FakeMortal(); // always fails: SimpleBot plays her
      final game =
          GameController(seed: 7, seatCharacters: seats, mortal: mortal);
      try {
        await playHands(tester, game);
        // Seat 0 is you: the guide column asks about your first turn. Of
        // the bots, only Saeko (seat 1) asks.
        expect(mortal.asked.difference({kHumanSeat}), {1});
      } finally {
        game.dispose();
        Sfx.i.enabled = true;
      }
    });

    testWidgets('an unplayable reply also falls back, without stalling',
        (tester) async {
      Sfx.i.enabled = false;
      final mortal = _FakeMortal({'reaction': null});
      final game =
          GameController(seed: 7, seatCharacters: seats, mortal: mortal);
      try {
        await playHands(tester, game);
        // Seat 0 is you: the guide column asks about your first turn. Of
        // the bots, only Saeko (seat 1) asks.
        expect(mortal.asked.difference({kHumanSeat}), {1});
      } finally {
        game.dispose();
        Sfx.i.enabled = true;
      }
    });

    testWidgets('Saeko stays on SimpleBot under Hong Kong rules',
        (tester) async {
      Sfx.i.enabled = false;
      final mortal = _FakeMortal();
      final game = GameController(
          seed: 7,
          seatCharacters: seats,
          mortal: mortal,
          ruleset: Ruleset.hongKong);
      try {
        await playHands(tester, game);
        expect(mortal.asked, isEmpty);
      } finally {
        game.dispose();
        Sfx.i.enabled = true;
      }
    });
  });
}
