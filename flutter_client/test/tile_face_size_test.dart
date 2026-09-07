import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/ui/tile_face.dart';

/// Guards that adding accent layers to a tile face does not change how big the
/// tile box or its artwork renders — the regression reported after the pin/sou
/// recolour ("resized / spacing off").
void main() {
  testWidgets('every tile — accented or not — has the same box and artwork rect',
      (t) async {
    const types = [
      TileType.man1, // accented (red 萬)
      TileType.man5,
      TileType.pin1, // plain green
      TileType.pin2, // green accent
      TileType.pin3, // green + red accent
      TileType.pin5, // plain
      TileType.pin8, // plain
      TileType.sou1, // red accent
      TileType.sou3, // plain green
      TileType.sou5, // red centre stick
      TileType.sou9, // red middle column
      TileType.ton, // plain honour
    ];

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final ty in types)
              TileFace(type: ty, size: TileSize.large, showIndex: false),
          ],
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 50));

    final faces = find.byType(TileFace).evaluate().toList();
    expect(faces.length, types.length);

    Size? boxSize;
    Size? artSize;
    for (var i = 0; i < faces.length; i++) {
      final faceBox = faces[i].renderObject! as RenderBox;
      boxSize ??= faceBox.size;
      expect(faceBox.size, boxSize, reason: '${types[i]} box differs');

      final img = find
          .descendant(of: find.byWidget(faces[i].widget), matching: find.byType(Image))
          .first;
      final imgBox = t.renderObject<RenderBox>(img);
      artSize ??= imgBox.size;
      expect(imgBox.size, artSize, reason: '${types[i]} artwork differs');
    }
  });
}
