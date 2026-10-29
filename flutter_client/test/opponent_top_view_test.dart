import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/ui/tile_face.dart';

/// An opponent's concealed tile is drawn as seen from above: the half nearest
/// its owner is white, the half toward you the usual back colour.
void main() {
  Future<List<Color>> halves(WidgetTester tester, AxisDirection edge,
      {int turns = 0}) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: TileFace(
          faceDown: true,
          size: TileSize.small,
          rotationQuarterTurns: turns,
          topViewEdge: edge,
        ),
      ),
    ));
    final boxes = find.descendant(
        of: find.byType(TileFace), matching: find.byType(ColoredBox));
    expect(boxes, findsNWidgets(2));
    // Each half has to actually fill its share of the tile, not collapse.
    final tile = tester.getSize(find.byType(TileFace));
    for (var i = 0; i < 2; i++) {
      final r = tester.getSize(boxes.at(i));
      expect(r.width * r.height, greaterThan(tile.width * tile.height * 0.4),
          reason: 'half $i has area');
    }
    // In reading order: left-to-right, then top-to-bottom.
    final ordered = boxes.evaluate().toList()
      ..sort((a, b) {
        final ra = tester.getRect(find.byWidget(a.widget));
        final rb = tester.getRect(find.byWidget(b.widget));
        return ra.top != rb.top
            ? ra.top.compareTo(rb.top)
            : ra.left.compareTo(rb.left);
      });
    return [for (final e in ordered) (e.widget as ColoredBox).color];
  }

  const white = Color(0xfff7f5ec);
  const teal = Color(0xff1f7a86);

  testWidgets('across: white on top, the near edge', (tester) async {
    expect(await halves(tester, AxisDirection.up), [white, teal]);
  });

  testWidgets('left seat: white on the left, tile lying on its side',
      (tester) async {
    expect(await halves(tester, AxisDirection.left, turns: 1), [white, teal]);
    final size = tester.getSize(find.byType(TileFace));
    expect(size.width, 30);
    expect(size.height, 22);
  });

  testWidgets('right seat: white on the right', (tester) async {
    expect(await halves(tester, AxisDirection.right, turns: 3), [teal, white]);
  });

  testWidgets('topViewDepth keeps the short side and thins the long one',
      (tester) async {
    for (final (turns, edge) in [
      (0, AxisDirection.up),
      (1, AxisDirection.left),
    ]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: TileFace(
            faceDown: true,
            size: TileSize.small,
            rotationQuarterTurns: turns,
            topViewEdge: edge,
            topViewDepth: 0.5,
          ),
        ),
      ));
      final size = tester.getSize(find.byType(TileFace));
      // A small tile is 22 x 30: the 22 stays, the 30 halves to 15.
      expect(size.shortestSide, 15);
      expect(size.longestSide, 22);
    }
  });
}
