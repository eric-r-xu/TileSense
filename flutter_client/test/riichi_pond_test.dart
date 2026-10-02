import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

void main() {
  for (final online in [false, true]) {
    testWidgets('${online ? 'online' : 'offline'} rotates the riichi pond tile',
        (tester) async {
      Sfx.i.enabled = false;
      final offline = GameController(seed: 7);
      final remote = OnlineGameController();
      addTearDown(() => Sfx.i.enabled = true);
      final round = offline.round;
      final tile = round.legalDiscards(0).first;
      round.discard(0, tile, declareRiichi: true);
      // A later discard must not move the sideways marker.
      round.seats[0].pond.add(Tile(90000, TileType.sou9));
      if (online) {
        remote.debugReceive({
          'type': 'state',
          'yourSeat': 2,
          'gamePhase': 'playing',
          'handInWind': 1,
          'tablePoints': List.filled(4, 25000),
          'discardSerial': 2,
          'lastDiscardSeat': 0,
          'lastDiscardTsumogiri': false,
          'turnDeadlineMs': null,
          'round': roundSnapshotToJson(round, reveal: (s) => s == 2),
        });
      }
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TableView(game: online ? remote : offline)),
      ));
      final declaration = tester.widget<TileFace>(find
          .byWidgetPredicate((w) => w is TileFace && w.tile?.id == tile.id));
      expect(declaration.rotationQuarterTurns, 1);
      final later = tester.widget<TileFace>(
          find.byWidgetPredicate((w) => w is TileFace && w.tile?.id == 90000));
      expect(later.rotationQuarterTurns, 0);
      await tester.pumpWidget(const SizedBox());
      offline.dispose();
      remote.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
