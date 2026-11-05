import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/mortal_advisor.dart';
import 'package:tilesense/game/sfx.dart';

/// Offline riichi: the Nagomi bot plays the fine-tuned model from her own
/// sidecar, falls back to Saeko's Mortal and then SimpleBot, and stays on
/// SimpleBot in sanma and under Hong Kong rules. Saeko keeps her Mortal.

/// A Mortal that records who asks and either plays the tile just drawn and
/// passes every call (when [works]) or fails like a sidecar that is down.
class _Mortal extends MortalAdvisor {
  _Mortal({this.works = true}) : super('http://unused');
  final bool works;
  final asked = <int>{};
  final hanchans = <bool>{};

  @override
  Future<Map<String, Object?>> ask(int seat, List<MjaiEvent> events,
      {bool hanchan = true}) async {
    asked.add(seat);
    hanchans.add(hanchan);
    if (!works) throw StateError('sidecar down');
    final last = events.last;
    if (last['type'] == 'tsumo' && last['actor'] == seat) {
      return {
        'reaction': {
          'type': 'dahai',
          'actor': seat,
          'pai': last['pai'],
          'tsumogiri': true,
        },
      };
    }
    return {'reaction': null};
  }
}

void main() {
  const seats = [
    Character.orderic,
    Character.saeko,
    Character.nagomi,
    Character.astaroth,
  ];
  const saekoSeat = 1, nagomiSeat = 2;

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

  testWidgets('Nagomi asks her own Mortal; Saeko and your seat ask Saeko\'s',
      (tester) async {
    Sfx.i.enabled = false;
    final saeko = _Mortal(), nagomi = _Mortal();
    final game = GameController(
        seed: 7, seatCharacters: seats, mortal: saeko, nagomiMortal: nagomi);
    try {
      await playHands(tester, game);
      expect(nagomi.asked, {nagomiSeat});
      expect(saeko.asked, contains(saekoSeat));
      expect(saeko.asked, isNot(contains(nagomiSeat)));
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets("Nagomi falls back to Saeko's Mortal when hers fails",
      (tester) async {
    Sfx.i.enabled = false;
    final saeko = _Mortal(), nagomi = _Mortal(works: false);
    final game = GameController(
        seed: 7, seatCharacters: seats, mortal: saeko, nagomiMortal: nagomi);
    try {
      await playHands(tester, game);
      expect(nagomi.asked, {nagomiSeat});
      expect(saeko.asked, contains(nagomiSeat));
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets("with no Nagomi sidecar she plays Saeko's Mortal",
      (tester) async {
    Sfx.i.enabled = false;
    final saeko = _Mortal();
    final game = GameController(seed: 7, seatCharacters: seats, mortal: saeko);
    try {
      await playHands(tester, game);
      expect(saeko.asked, containsAll([saekoSeat, nagomiSeat]));
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('with both Mortals down Nagomi still plays, on SimpleBot',
      (tester) async {
    Sfx.i.enabled = false;
    final saeko = _Mortal(works: false), nagomi = _Mortal(works: false);
    final game = GameController(
        seed: 7, seatCharacters: seats, mortal: saeko, nagomiMortal: nagomi);
    try {
      // The hand has to finish (playHands fails on a stall) with both her
      // Mortal and Saeko's tried for her seat and both failing.
      await playHands(tester, game);
      expect(nagomi.asked, {nagomiSeat});
      expect(saeko.asked, contains(nagomiSeat));
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('a Nagomi-only app (no Saeko Mortal) still plays her model',
      (tester) async {
    Sfx.i.enabled = false;
    final nagomi = _Mortal();
    final game =
        GameController(seed: 7, seatCharacters: seats, nagomiMortal: nagomi);
    try {
      await playHands(tester, game);
      expect(nagomi.asked, {nagomiSeat});
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('hanchan and East-only games tell her which they are',
      (tester) async {
    for (final hanchan in [true, false]) {
      Sfx.i.enabled = false;
      final nagomi = _Mortal();
      final game = GameController(
          seed: 7,
          seatCharacters: seats,
          mortal: _Mortal(),
          nagomiMortal: nagomi,
          hanchan: hanchan);
      try {
        await playHands(tester, game);
        expect(nagomi.hanchans, {hanchan}, reason: 'hanchan: $hanchan');
      } finally {
        game.dispose();
        Sfx.i.enabled = true;
      }
    }
  });

  testWidgets('sanma: Nagomi has no model and never asks hers', (tester) async {
    Sfx.i.enabled = false;
    final nagomi = _Mortal(), sanma = _Mortal();
    // Seat 2 is sanma's empty seat; Nagomi sits on the left, seat 3.
    final game = GameController(
        seed: 7,
        seatCharacters: const [
          Character.orderic,
          Character.grant,
          Character.hubert,
          Character.nagomi,
        ],
        mortal: sanma,
        nagomiMortal: nagomi,
        ruleset: Ruleset.sanma);
    try {
      await playHands(tester, game);
      expect(nagomi.asked, isEmpty);
      expect(sanma.asked.difference({kHumanSeat}), isEmpty);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });

  testWidgets('Nagomi stays on SimpleBot under Hong Kong rules',
      (tester) async {
    Sfx.i.enabled = false;
    final nagomi = _Mortal(), saeko = _Mortal();
    final game = GameController(
        seed: 7,
        seatCharacters: seats,
        mortal: saeko,
        nagomiMortal: nagomi,
        ruleset: Ruleset.hongKong);
    try {
      await playHands(tester, game);
      expect(nagomi.asked, isEmpty);
      expect(saeko.asked, isEmpty);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
    }
  });
}
