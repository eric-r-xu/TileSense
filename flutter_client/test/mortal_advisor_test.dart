import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mjai.dart' show MjaiEvent, mjaiTile;
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/guide_host.dart' show AutoplayBrain;
import 'package:tilesense/game/mortal_advisor.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'helpers.dart';

// A real reply from mortal_sidecar/server.py: 123m 567p 239s EE N P + 4s,
// where Mortal cuts North. Its 13 q-values line up with the set bits of
// mask_bits, one per legal discard.
const _reply = {
  'reaction': {
    'type': 'dahai',
    'actor': 0,
    'pai': 'N',
    'tsumogiri': false,
    'meta': {
      'q_values': [
        -7.025879, -7.5252876, -7.2788506, -6.4849367, -6.8578405, //
        -6.9889174, -6.5591946, -6.913914, -7.042, -1.0434326, //
        -6.8588524, 0.5512234, -2.3458648,
      ],
      'mask_bits': 3426279431,
    },
  },
  'riichi_discard': null,
};

/// Mortal configured, but its sidecar never answers.
class _NoSidecar extends MortalAdvisor {
  _NoSidecar() : super('http://unused');

  @override
  Future<Map<String, Object?>> ask(int seat, List<MjaiEvent> events) =>
      Future.error(StateError('sidecar down'));
}

void main() {
  test("ranks every legal discard by Mortal's q-values", () {
    final advice = MortalAdvice.fromReply(_reply, call: false);
    expect(advice.status, MortalStatus.ready);
    expect(advice.discard, 'N');
    expect(advice.action, isNull);
    expect(advice.riichi, isFalse);
    expect(advice.ranks, hasLength(13));
    expect(advice.rankOf(TileType.pei), 1);
    expect(advice.ranks.values.toSet(), {for (var i = 1; i <= 13; i++) i});
  });

  test('a riichi reads its discard from the follow-up step', () {
    final advice = MortalAdvice.fromReply({
      'reaction': {'type': 'reach', 'actor': 0},
      'riichi_discard': {
        'type': 'dahai',
        'pai': '5mr',
        'meta': {
          'q_values': [1.0, 2.0],
          'mask_bits': 1 | (1 << 4), // 1m and 5m
        },
      },
    }, call: false);
    expect(advice.riichi, isTrue);
    expect(advice.discard, '5m');
    expect(advice.ranks, {'5m': 1, '1m': 2});
  });

  test('calls name the call, and no reaction on a call is a pass', () {
    MortalAdvice read(Map<String, Object?>? reaction) =>
        MortalAdvice.fromReply({'reaction': reaction, 'riichi_discard': null},
            call: true);
    expect(read(null).action, 'PASS');
    expect(read({'type': 'none'}).action, 'PASS');
    expect(read({'type': 'pon'}).action, 'PON');
    expect(read({'type': 'hora'}).action, 'RON');
    expect(
        read({
          'type': 'chi',
          'pai': '4m',
          'consumed': ['3m', '5mr'],
        }).action,
        'CHI 345m');
  });

  group('the guide panel', () {
    // Tenpai: cut 9s. Mortal would declare riichi on that cut, and ranks 3p
    // and 4p behind it.
    final hand = parseTiles('123m 456m 789m 34p 55p 9s');
    final report = EfficiencyEngine().analyze(
      hand: hand,
      visibleCounts34: toCounts34(hand),
      canRiichi: true,
      valueContext: EfficiencyValueContext(
        melds: const [],
        roundWind: Wind.east,
        seatWind: Wind.east,
        isDealer: true,
        inRiichi: false,
        wallTilesRemaining: 40,
        doraIndicators: const [],
      ),
    );
    final riichi9s = MortalAdvice.fromReply({
      'reaction': {'type': 'reach', 'actor': 0},
      'riichi_discard': {
        'type': 'dahai',
        'pai': '9s',
        'meta': {
          'q_values': [0.1, 0.2, 3.0],
          'mask_bits': (1 << 11) | (1 << 12) | (1 << 26), // 3p 4p 9s
        },
      },
    }, call: false);

    // Mortal would rather cut 3p, where the guide cuts 9s.
    final cuts3p = MortalAdvice.fromReply({
      'reaction': {
        'type': 'dahai',
        'pai': '3p',
        'meta': {
          'q_values': [3.0, 0.2, 0.1],
          'mask_bits': (1 << 11) | (1 << 12) | (1 << 26), // 3p 4p 9s
        },
      },
      'riichi_discard': null,
    }, call: false);

    String topRow(WidgetTester tester) => mjaiTile(Tile(
        -1,
        tester
            .widgetList<TileFace>(find.descendant(
                of: find.byType(Table), matching: find.byType(TileFace)))
            .first
            .type!));

    /// Renders the panel with [advice], runs [check], then disposes the game
    /// (inside the test, so its turn timer is cancelled before the test ends).
    Future<void> show(WidgetTester tester, MortalAdvice? advice,
        void Function() check,
        {AutoplayBrain brain = AutoplayBrain.tilesense}) async {
      Sfx.i.enabled = false;
      final game = GameController(seed: 1)
        ..mortalAdvice = advice
        ..autoplayBrain = brain;
      try {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: EfficiencyOverlay(game: game, report: report),
            ),
          ),
        ));
        check();
      } finally {
        game.dispose();
      }
    }

    testWidgets("stars Mortal's pick, ranks the rest, and names the riichi",
        (tester) async {
      await show(tester, riichi9s, () {
        expect(find.text('Mortal bot'), findsOneWidget);
        expect(find.text('★R'), findsOneWidget);
        expect(find.text('2'), findsWidgets);
        expect(find.text('Mortal: RIICHI, cut 9s'), findsOneWidget);
        // Blue rings: one on the tile, one on the riichi line.
        final rings = find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border ==
                Border.all(color: const Color(0xff42a5f5), width: 2));
        expect(rings, findsNWidgets(2));
      });
    });

    testWidgets("rows follow the guide by default, Mortal's order when chosen",
        (tester) async {
      await show(tester, cuts3p, () => expect(topRow(tester), '9s'));
      await show(tester, cuts3p, () => expect(topRow(tester), '3p'),
          brain: AutoplayBrain.mortal);
      // Mortal chosen but still thinking: the guide's order is the fallback.
      await show(tester, MortalAdvice.thinking, () => expect(topRow(tester), '9s'),
          brain: AutoplayBrain.mortal);
    });

    testWidgets('shows … while Mortal thinks', (tester) async {
      await show(tester, MortalAdvice.thinking, () {
        expect(find.text('Mortal bot'), findsOneWidget);
        expect(find.text('…'), findsWidgets);
        expect(find.text('Mortal: thinking…'), findsOneWidget);
      });
    });

    testWidgets('has no Mortal column without MORTAL_URL', (tester) async {
      await show(tester, null, () {
        expect(find.text('Mortal bot'), findsNothing);
        expect(find.byKey(const ValueKey('mortal-line')), findsNothing);
      });
    });

    testWidgets('the AUTO-PLAY chips show with Mortal, and switch who it follows',
        (tester) async {
      Sfx.i.enabled = false;
      Future<GameController> render(MortalAdvisor? mortal) async {
        final game = GameController(seed: 1, mortal: mortal);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: EfficiencyOverlay(game: game, report: game.report),
            ),
          ),
        ));
        return game;
      }

      final without = await render(null);
      expect(find.byKey(const Key('guideBrain_mortal')), findsNothing);
      without.dispose();

      // Mortal configured but failing: the column just reads "—", and the
      // chips still show.
      final game = await render(_NoSidecar());
      try {
        expect(game.autoplayBrain, AutoplayBrain.tilesense);
        await tester.tap(find.byKey(const Key('guideBrain_mortal')));
        await tester.pump();
        expect(game.autoplayBrain, AutoplayBrain.mortal);
        await tester.tap(find.byKey(const Key('guideBrain_tilesense')));
        await tester.pump();
        expect(game.autoplayBrain, AutoplayBrain.tilesense);
      } finally {
        game.dispose();
      }
    });
  });
}
