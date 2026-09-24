import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';

import 'helpers.dart';

/// Take back: each press undoes your latest decision this hand, and the bots'
/// moves after it, by re-dealing the same wall and replaying up to it.
void main() {
  setUp(() {
    CallCallout.i.clear();
    Sfx.i.enabled = false;
  });
  tearDown(() => Sfx.i.enabled = true);

  /// Everything a take-back has to restore, as one comparable string.
  String snapshot(GameController g) {
    final r = g.round;
    return [
      'turn ${r.turn} ${r.phase.name} wall ${r.wall.remaining} '
          'sticks ${r.riichiSticks}',
      for (final s in r.seats)
        '${s.seat}: hand ${[for (final t in s.hand) t.id]} '
            'pond ${[for (final t in s.pond) t.id]} '
            'melds ${s.melds.length} riichi ${s.riichi} pts ${s.points}',
    ].join('\n');
  }

  bool yourMove(GameController g) =>
      g.round.finished || g.isHumanTurn || g.awaitingHumanCall;

  /// A few bot turns, each with its step delay and any call pause.
  Future<void> untilYourMove(WidgetTester tester, GameController g) =>
      pumpUntil(tester, () => yourMove(g), tries: 300);

  /// Discards on your turn, passes on a call — your first legal choice.
  void playOnce(GameController g) {
    if (g.awaitingHumanCall) {
      g.answerCall(CallType.none);
    } else {
      g.humanDiscard(g.round.legalDiscards(kHumanSeat).first);
    }
  }

  testWidgets('nothing to take back before your first decision',
      (tester) async {
    final g = GameController(seed: 11)..setAutoWin(false);
    try {
      await untilYourMove(tester, g);
      expect(g.canUndo, isFalse);
      expect(g.undoLabel, isNull);
    } finally {
      g.dispose();
    }
  });

  testWidgets('a discard, and the bots after it, are taken back',
      (tester) async {
    final g = GameController(seed: 11)..setAutoWin(false);
    try {
      await pumpUntil(tester, () => g.isHumanTurn);
      final before = snapshot(g);
      final tile = g.round.legalDiscards(kHumanSeat).first;

      g.humanDiscard(tile);
      expect(g.canUndo, isTrue);
      expect(g.undoLabel, tile.type.displayName);

      // Let the table move on to your next decision.
      await pumpUntil(tester, () => yourMove(g) && snapshot(g) != before);
      expect(snapshot(g), isNot(before));

      g.undo();
      expect(snapshot(g), before);
      expect(g.isHumanTurn, isTrue);
      expect(g.canUndo, isFalse);
    } finally {
      g.dispose();
    }
  });

  testWidgets('pressed again, it keeps stepping back', (tester) async {
    final g = GameController(seed: 23)..setAutoWin(false);
    try {
      final points = <String>[];
      for (var i = 0; i < 3; i++) {
        await untilYourMove(tester, g);
        if (g.round.finished) break;
        points.add(snapshot(g));
        playOnce(g);
      }
      expect(points, hasLength(3));

      for (final expected in points.reversed) {
        expect(g.canUndo, isTrue);
        g.undo();
        expect(snapshot(g), expected);
      }
      expect(g.canUndo, isFalse);
    } finally {
      g.dispose();
    }
  });

  testWidgets('a passed call is offered again', (tester) async {
    // Play first-legal discards until some seed offers you a call.
    for (var seed = 1; seed <= 40; seed++) {
      final g = GameController(seed: seed)..setAutoWin(false);
      try {
        for (var turn = 0; turn < 30; turn++) {
          await untilYourMove(tester, g);
          if (g.round.finished) break;
          if (!g.awaitingHumanCall) {
            playOnce(g);
            continue;
          }
          final before = snapshot(g);
          final offered = g.humanCallOption!.types;
          g.answerCall(CallType.none);
          expect(g.undoLabel, 'Pass');

          g.undo();
          expect(g.awaitingHumanCall, isTrue);
          expect(g.humanCallOption!.types, offered);
          expect(snapshot(g), before);
          return;
        }
      } finally {
        g.dispose();
      }
    }
    fail('no seed in 1..40 offered a call');
  });

  testWidgets('undo hands your seat back from Auto-Play', (tester) async {
    final g = GameController(seed: 11)..setAutoWin(false);
    try {
      await pumpUntil(tester, () => g.isHumanTurn);
      g.humanDiscard(g.round.legalDiscards(kHumanSeat).first);
      g.setAutoplay(true);
      g.undo();
      expect(g.autoplay, isFalse);
      expect(g.isHumanTurn, isTrue);
    } finally {
      g.dispose();
    }
  });

  testWidgets('not while paused, and not across a new hand', (tester) async {
    final g = GameController(seed: 11)..setAutoWin(false);
    try {
      await pumpUntil(tester, () => g.isHumanTurn);
      g.humanDiscard(g.round.legalDiscards(kHumanSeat).first);
      g.togglePause();
      expect(g.canUndo, isFalse);
      g.togglePause();
      expect(g.canUndo, isTrue);

      g.newGame();
      expect(g.canUndo, isFalse);
    } finally {
      g.dispose();
    }
  });
}
