import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:mahjong_core/wall.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/main.dart' show TileSenseApp, kDesignSize;
import 'package:tilesense/ui/online_lobby_page.dart';
import 'package:tilesense/ui/scoring_view.dart';

import 'helpers.dart';
import 'l10n_helpers.dart';

/// The Phase 1 screens in each non-English language, on a desktop canvas and
/// a landscape phone: nothing overflows or throws with the longer (or wider)
/// text. English is covered by every other test.
void main() {
  tearDown(() => AppLanguageController.instance.select(AppLanguage.english));
  const phone = Size(852, 393);

  for (final language in [
    AppLanguage.japanese,
    AppLanguage.simplifiedChinese,
    AppLanguage.traditionalChinese,
  ]) {
    group(language.nativeName, () {
      setUp(() => AppLanguageController.instance.select(language));

      for (final size in [kDesignSize, phone]) {
        testWidgets('welcome, character select and the table at $size',
            (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(const TileSenseApp());
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: 'welcome');
          // Single Player, by its key-less button: the first ElevatedButton
          // (its label is no longer English here).
          await tester.tap(find.byType(ElevatedButton).first);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'character select');
          await tester.tap(find.byKey(const Key('charactersContinue')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: 'table');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 5));
        });
      }

      for (final ruleset in Ruleset.values) {
        testWidgets('the online lobby under ${ruleset.name}', (tester) async {
          final game = OnlineGameController();
          addTearDown(game.dispose);
          await pumpLocalized(
              tester,
              OnlineLobbyPage(
                  controller: game, initialRuleset: ruleset, onExit: () {}));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('a riichi win on the score screen', (tester) async {
        Sfx.i.enabled = false;
        addTearDown(() => Sfx.i.enabled = true);
        final game = GameController(seed: 5);
        addTearDown(game.dispose);
        game.togglePause();
        final r = Round.posed(
          dealer: 0,
          roundWind: Wind.east,
          wall: Wall.posed(remaining: 0, dora: const []),
          startingPoints: List.filled(4, 25000),
        );
        final win = Tile(900, TileType.pin5);
        r.turn = 1;
        r.seats[1].hand = [...parseTiles('123m 456p 789s 22m 55p'), win];
        r.seats[1].drawn = win;
        r.declareTsumo(1);
        game.round = r;
        game.phase = GamePhase.roundEnd;
        await pumpLocalized(tester, Scaffold(body: ScoringView(game: game)));
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Tsumo'), findsNothing,
            reason: 'the result title is translated');
      });
    });
  }
}
