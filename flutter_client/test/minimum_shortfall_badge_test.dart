import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/hong_kong/hong_kong_wall.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:mahjong_core/wall.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/main.dart' show kDesignSize;
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/table_view.dart';

import 'helpers.dart';

final _openChow =
    Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false);

/// The human seat holding [hand] beside [melds], on a paused table.
GameController _game(String hand,
    {Ruleset ruleset = Ruleset.riichi,
    List<Meld> melds = const [],
    int minimumFaan = 0}) {
  final game = GameController(ruleset: ruleset, seed: 5)..togglePause();
  final r = Round.posed(
    ruleset: ruleset,
    minimumFaan: minimumFaan,
    dealer: 0,
    roundWind: Wind.east,
    wall: ruleset.isRiichi
        ? Wall(1)
        : HongKongWall.fromTiles([Tile(990, TileType.sou1)]),
    startingPoints: List.filled(4, ruleset.startingPoints),
  );
  r.seats[kHumanSeat].hand = parseTiles(hand);
  r.seats[kHumanSeat].melds = melds;
  r.turn = 3;
  game.round = r;
  return game;
}

/// The badge text on the hand bar and beside the placard, or null for each
/// when it is absent. Disposes [game].
Future<(String?, String?)> _badges(
    WidgetTester tester, GameController game) async {
  String? label(Key key) {
    final found = find.descendant(
        of: find.byKey(key), matching: find.byType(Text));
    return found.evaluate().isEmpty
        ? null
        : tester.widget<Text>(found.first).data;
  }

  await tester.binding.setSurfaceSize(kDesignSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  try {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HandView(game: game, onToggleGuide: () {}))));
    await tester.pump(const Duration(milliseconds: 500));
    final chip = label(const Key('minimumShortfallChip'));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: TableView(game: game))));
    final badge = label(const Key('minimumShortfallBadge'));
    expect(tester.takeException(), isNull);
    return (chip, badge);
  } finally {
    game.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }
}

void main() {
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  testWidgets('an open riichi hand with no yaku cannot win at all',
      (tester) async {
    final game = _game('456p 789s 55s 23m', melds: [_openChow]);
    expect(await _badges(tester, game),
        ('NO YAKU · NO WIN', 'NO YAKU · NO WIN'));
  });

  testWidgets('a closed hand with no yaku warns but can still tsumo',
      (tester) async {
    final game = _game('789m 456p 789s 99s 13m');
    expect(await _badges(tester, game), ('NO YAKU', 'NO YAKU'));
  });

  testWidgets('a hand with a yaku shows no badge', (tester) async {
    final game = _game('234m 456p 678s 55s 46m');
    expect(await _badges(tester, game), (null, null));
  });

  testWidgets('Hong Kong names the table\'s faan minimum', (tester) async {
    // A chicken hand with no flowers: 1 faan off a discard, 2 self-picked.
    final game = _game('456p 789s 22m 55p',
        ruleset: Ruleset.hongKong, melds: [_openChow], minimumFaan: 2);
    expect(await _badges(tester, game), ('UNDER 2 FAAN', 'UNDER 2 FAAN'));
  });
}
