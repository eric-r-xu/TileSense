import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

/// The status panel (round / wall / honba / riichi) sits in the table's
/// top-left corner, clear of every tile and of the guide panel below it. That
/// leaves the middle of the table to the ponds: your pond and the one across
/// from you render the same size as the turned side ponds and meet across the
/// middle with just a sliver of felt between them.
void main() {
  Rect statusPanel(WidgetTester tester) => tester.getRect(find
      .ancestor(
          of: find.textContaining('East 1'), matching: find.byType(Container))
      .first);

  /// Every tile on the table, as (rect, TileFace).
  List<(Rect, TileFace)> tableTiles(WidgetTester tester) => [
        for (final e in find
            .descendant(
                of: find.byType(TableView), matching: find.byType(TileFace))
            .evaluate())
          (tester.getRect(find.byWidget(e.widget)), e.widget as TileFace),
      ];

  Future<void> startGame(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

    // An empty pond renders nothing, so give every pond three full rows —
    // as far as a pond gets in an ordinary round.
    final host = tester.widget<TableView>(find.byType(TableView)).game;
    for (final seat in [0, 1, 2, 3]) {
      for (var i = 0; i < 18; i++) {
        host.round.seats[seat].pond.add(
          Tile(700 + seat * 30 + i, TileType.values[(seat * 7 + i) % 34]),
        );
      }
    }
    // Pause notifies listeners, which is what rebuilds the table.
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the status panel sits top-left, clear of every tile',
      (tester) async {
    await startGame(tester);
    final table = tester.getRect(find.byType(TableView));
    final panel = statusPanel(tester);

    expect(panel.left - table.left, lessThan(12),
        reason: 'the panel hugs the left edge');
    expect(panel.top - table.top, lessThan(12), reason: 'and the top edge');
    for (final (r, _) in tableTiles(tester)) {
      expect(r.overlaps(panel), isFalse,
          reason: 'a tile at $r is under the status panel at $panel');
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the guide panel starts below the status panel', (tester) async {
    await startGame(tester);
    // Resume first: the pause veil would otherwise sit over everything.
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bottomGuideToggle')));
    await tester.pump();

    final guide = tester.getRect(find.byType(EfficiencyOverlay));
    final panel = statusPanel(tester);
    expect(guide.top, greaterThan(panel.bottom),
        reason: 'the guide panel is covering the status panel');
    expect(guide.top - panel.bottom, lessThan(20),
        reason: 'and sits right under it, not far down the screen');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the builder keeps its guide panel below the status panel too',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final guide = tester.getRect(find.byType(EfficiencyOverlay));
    expect(guide.top, greaterThan(statusPanel(tester).bottom));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'all four ponds render the same size, and the top and bottom ones '
      'meet across the middle', (tester) async {
    await startGame(tester);
    final table = tester.getRect(find.byType(TableView));
    final midX = table.center.dx;

    // Pond tiles are the table's `normal` faces; the top and bottom ponds sit
    // on the centre column, the side ponds well off it.
    final pond = [
      for (final t in tableTiles(tester))
        if (t.$2.size == TileSize.normal &&
            t.$1.top > table.top + 60 && // below the dead wall row
            t.$1.bottom < table.bottom - 40)
          t,
    ];
    final centre = [
      for (final t in pond)
        if ((t.$1.center.dx - midX).abs() < 160) t
    ];
    final side = [
      for (final t in pond)
        if ((t.$1.center.dx - midX).abs() > 200) t
    ];
    expect(centre, hasLength(36), reason: 'three rows each, top and bottom');
    expect(side, hasLength(36));

    // A side pond is turned, so its tiles lie on their side: compare long
    // edge to long edge. Each pond's newest tile is caught mid drop-in (it
    // starts a little small), so compare the size most tiles have.
    double commonLongEdge(List<(Rect, TileFace)> tiles) {
      final counts = <double, int>{};
      for (final (r, _) in tiles) {
        final e = (r.width > r.height ? r.width : r.height).roundToDouble();
        counts[e] = (counts[e] ?? 0) + 1;
      }
      return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    expect(commonLongEdge(centre), commonLongEdge(side),
        reason: 'top and bottom pond tiles should match the side ponds');

    final midY = (centre.map((t) => t.$1.center.dy).reduce((a, b) => a + b)) /
        centre.length;
    final above = centre
        .where((t) => t.$1.center.dy < midY)
        .map((t) => t.$1.bottom)
        .reduce((a, b) => a > b ? a : b);
    final below = centre
        .where((t) => t.$1.center.dy > midY)
        .map((t) => t.$1.top)
        .reduce((a, b) => a < b ? a : b);
    expect(below - above, inInclusiveRange(4, 24),
        reason: 'the two ponds should meet across the middle of the table');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
