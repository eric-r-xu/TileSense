import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/scenario/scenario_controller.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/scenario_win_panel.dart';
import 'package:tilesense/ui/table_view.dart';

import 'loading_helpers.dart';
import 'scenario_test.dart' show fill;

void main() {
  preloadDeferredPages();

  ScenarioController controller() =>
      ScenarioController(askMortal: false, scoreWins: true);

  group('a complete hand is scored as a win', () {
    test("a triple yakuman of all honors is recognised, not read as a discard",
        () {
      // Three each of Chun, Haku, Hatsu and East, and a pair of North, all
      // concealed: all dragons, all honors, four concealed triplets.
      final c = controller();
      c.edit((s) => fill(s, s.hand, 'RRR BBB GGG EEE NN'));

      final win = c.win!;
      expect(win.wins, isTrue);
      expect(win.byTsumo, isTrue);
      expect(win.score.yakuman, greaterThanOrEqualTo(3));
      final names = win.score.yaku.map((y) => y.name).join(' | ');
      expect(names, contains('Daisangen'));
      expect(names, contains('Tsuuiisou'));
      expect(names, contains('Suuankou'));
      // The guide stands down: there is nothing left to discard.
      expect(c.report.lines, isEmpty);
      c.dispose();
    });

    test('a tile short of complete is still a discard read', () {
      final c = controller();
      c.edit((s) => fill(s, s.hand, '234m 567m 345p 678s 9s 1p'));
      expect(c.win, isNull);
      expect(c.report.lines, isNotEmpty);
      c.dispose();
    });

    test('the winning tile and tsumo or ron change the score', () {
      final c = controller();
      // 111m 222p 333s 444m 99p: four concealed triplets on a tsumo; on a
      // ron the triplet the winning tile completes is open.
      c.edit((s) => fill(s, s.hand, '111m 222p 333s 444m 99p'));
      expect(c.win!.wins, isTrue);
      expect(c.win!.score.yakuman, 1);

      c.edit((s) {
        s.winByTsumo = false;
        s.winType = TileType.man4;
      });
      expect(c.win!.byTsumo, isFalse);
      expect(c.win!.score.yakuman, 0,
          reason: 'a ron on a triplet leaves it open: no four concealed');
      c.dispose();
    });

    test('a closed ron with no yaku is flagged, and the discard read stays',
        () {
      final c = controller();
      c.edit((s) {
        fill(s, s.hand, '234m 567m 345p 678p 99s');
        s.winByTsumo = false;
      });
      expect(c.win!.wins, isFalse);
      expect(c.win!.problem, contains('no yaku'));
      expect(c.report.lines, isNotEmpty);

      // Closed, the same tiles on a tsumo are menzen tsumo.
      c.edit((s) => s.winByTsumo = true);
      expect(c.win!.wins, isTrue);
      c.dispose();
    });

    test('riichi adds its han, and ippatsu one more', () {
      final c = controller();
      c.edit((s) => fill(s, s.hand, '234m 567m 345p 678p 99s'));
      final base = c.win!.score.han;
      c.edit((s) => s.riichi = true);
      expect(c.win!.score.han, base + 1);
      c.edit((s) => s.ippatsu = true);
      expect(c.win!.score.han, base + 2);
      // Riichi never reaches the real seat, so the table is not left in it.
      expect(c.round.seats[0].riichi, isFalse);
      c.dispose();
    });

    test('a hong kong hand under the faan minimum cannot win', () {
      final c = controller()..setRuleset(Ruleset.hongKong);
      c.edit((s) {
        s.minimumFaan = 5;
        fill(s, s.hand, '234m 567p 345s 66s 789m');
      });
      final win = c.win!;
      expect(win.wins, isFalse);
      expect(win.problem, contains('5-faan minimum'));
      c.dispose();
    });

    test('a 13-tile hand that is tenpai says what it waits on', () {
      final c = controller();
      c.edit((s) => fill(s, s.hand, '234m 567m 345p 678s 9s'));
      expect(c.win, isNull);
      expect(c.waits, contains(TileType.sou9));
      expect(c.blockedReason, contains('Tenpai'));
      expect(c.blockedReason, contains('9s'));
      c.dispose();
    });

    test('a ron on the offered tile is a win once the hand can ron it', () {
      final c = controller();
      // Riichi tanyao-less hand: needs a yaku, so riichi makes the ron valid.
      c.edit((s) {
        fill(s, s.hand, '234m 567m 345p 678p 9s');
        s.offered = s.mint(TileType.sou9);
        s.offeredFrom = 2;
      });
      expect(c.win, isNull, reason: 'no yaku, so the call read answers');
      expect(c.humanCallOption, isNull);

      c.edit((s) => s.riichi = true);
      expect(c.win?.wins, isTrue);
      expect(c.win!.fromOffer, isTrue);
      c.dispose();
    });
  });

  group('the builder shows it', () {
    testWidgets('a complete hand opens the win panel, and its choices re-score',
        (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await pumpLoadedPage(tester);

      final c = tester.widget<TableView>(find.byType(TableView)).game
          as ScenarioController;
      c.edit((s) => s.clear());
      await tester.pump();
      // An empty table says where to begin.
      expect(find.textContaining('Tap the tiles below'), findsOneWidget);
      expect(find.byType(ScenarioWinPanel), findsNothing);
      expect(find.byType(EfficiencyOverlay), findsOneWidget);

      c.edit((s) => fill(s, s.hand, 'RRR BBB GGG EEE NN'));
      await tester.pump();
      expect(find.byType(ScenarioWinPanel), findsOneWidget);
      expect(find.byType(EfficiencyOverlay), findsNothing);
      expect(find.byKey(const Key('winTotal')), findsOneWidget);
      expect(find.textContaining('Winning hand'), findsWidgets);

      await tester.tap(find.byKey(const Key('winRon')));
      await tester.pump();
      expect(c.win!.byTsumo, isFalse);
      await tester.tap(find.byKey(const Key('winTile_N')));
      await tester.pump();
      expect(c.scenario.winType, TileType.pei);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
