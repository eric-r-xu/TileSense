import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/ui/meld_row.dart';
import 'package:tilesense/ui/tile_face.dart';

/// The tilted tile marks which neighbour a call came from, from the meld
/// owner's point of view. [mirrored] is the across seat, whose row is upright
/// for the viewer, so owner-left is screen-right.
void main() {
  Meld pon(int offset) => Meld(
        kind: MeldKind.triplet,
        low: TileType.man5,
        concealed: false,
        calledFromSeatOffset: offset,
        tiles: [
          Tile(1, TileType.man5),
          Tile(2, TileType.man5),
          Tile(3, TileType.man5),
        ],
      );

  Future<int> tiltedIndex(WidgetTester tester, Meld m, bool mirrored) async {
    await tester.pumpWidget(
        MaterialApp(home: MeldRow(m, mirrored: mirrored)));
    final faces = tester.widgetList<TileFace>(find.byType(TileFace)).toList();
    return faces.indexWhere((f) => f.rotationQuarterTurns != 0);
  }

  for (final mirrored in [false, true]) {
    testWidgets('pon tilt, mirrored=$mirrored', (tester) async {
      // offset 3 = from the owner's left, 2 = across, 1 = owner's right.
      expect(await tiltedIndex(tester, pon(3), mirrored), mirrored ? 2 : 0);
      expect(await tiltedIndex(tester, pon(2), mirrored), 1);
      expect(await tiltedIndex(tester, pon(1), mirrored), mirrored ? 0 : 2);
    });
  }
}
