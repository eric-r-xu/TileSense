import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/scenario/scenario_controller.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

import 'loading_helpers.dart';
import 'scenario_test.dart' show fill;

void main() {
  preloadDeferredPages();

  group('Sichuan in the builder', () {
    test('needs your void suit, then reads the table like the game', () {
      final c = ScenarioController()..setRuleset(Ruleset.sichuan);
      c.edit((s) => fill(s, s.hand, '123m 456m 78m 12p 55p 99s'));
      expect(c.blockedReason, contains('Void suit'));

      // Give up the sou: the 9s pair is what the guide wants cut first.
      c.edit((s) => s.seats[0].voidSuit = 2);
      expect(c.blockedReason, isNull);
      expect(c.round.seats[0].voidSuit, 2);
      expect(c.round.mustDiscardVoid(0), isTrue);
      expect(c.report.lines, isNotEmpty);
      expect(c.report.lines.firstWhere((l) => l.recommended).discard.suit, 2);
    });

    test('has no dora, flowers or chi, and a 108-tile wall', () {
      final c = ScenarioController()..setRuleset(Ruleset.sichuan);
      expect(c.scenario.maxWall, 56);
      expect(c.scenario.wallRemaining, lessThanOrEqualTo(56));
      expect(c.round.wall.remaining, c.scenario.wallRemaining);
      c.edit((s) => s.hand.add(s.mint(TileType.ton)));
      expect(c.scenario.problems(),
          contains('Sichuan has no honors or flowers.'));
    });

    test('an opponent\'s void suit shows once named; Hu seats sit out', () {
      final c = ScenarioController()..setRuleset(Ruleset.sichuan);
      expect(c.round.seats[2].voidRevealed, isFalse);
      c.edit((s) {
        s.seats[2].voidSuit = 0;
        s.seats[3].out = true;
      });
      expect(c.round.seats[2].voidRevealed, isTrue);
      expect(c.round.seats[2].voidSuit, 0);
      expect(c.round.seats[3].out, isTrue);
      expect(c.round.seats[3].huOrder, isNonZero);
    });

    test('Clear keeps the void suits, as it keeps the winds', () {
      final c = ScenarioController()..setRuleset(Ruleset.sichuan);
      c.edit((s) => s.seats[0].voidSuit = 1);
      c.edit((s) => s.clear());
      expect(c.scenario.seats[0].voidSuit, 1);
    });

    testWidgets('the Menu switches to it and Random poses a scored table',
        (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await pumpLoadedPage(tester);

      await tapBuilderMenu(tester, 'builderMenuRuleset_sichuan');
      ScenarioController builder() =>
          tester.widget<TableView>(find.byType(TableView)).game
              as ScenarioController;
      expect(builder().ruleset, Ruleset.sichuan);

      // Nothing of riichi's or Hong Kong's is offered.
      expect(find.textContaining('Dora'), findsNothing);
      expect(find.textContaining('flowers'), findsNothing);
      expect(find.text('riichi'), findsNothing);
      expect(find.byKey(const Key('builderVoid_0')), findsOneWidget);

      await tapBuilderMenu(tester, 'builderMenuRandom');
      expect(find.textContaining('Scored:'), findsOneWidget);
      expect(builder().scenario.seats[0].voidSuit, isNotNull);
      expect(
          [
            for (final t in builder().scenario.hand) t.type.isSuit,
          ],
          everyElement(isTrue));

      // Naming your suit from the chips; only an opponent can leave it unshown.
      await tester.tap(find.byKey(const Key('builderVoid_0')));
      await tester.pump();
      expect(find.byKey(const Key('builderVoidSuit_none')), findsNothing);
      await tester.tap(find.byKey(const Key('builderVoidSuit_1')));
      await tester.pump();
      expect(builder().scenario.seats[0].voidSuit, 1);
      expect(tester.takeException(), isNull);
      expect(find.byType(TileFace), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
