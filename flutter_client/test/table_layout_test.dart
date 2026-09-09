import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

/// The centre status block (round / wall / honba / riichi) sits between your own
/// pond and the one across from you. Those two are the only ponds whose rows
/// stack towards it — the left and right ponds are turned and run out
/// horizontally — so they are the two that have to be placed against it: close
/// enough to keep the table compact, far enough not to bury it.
void main() {
  /// Vertical clearance between the centre block and the nearest pond tile
  /// above and below it. Negative means a pond is covering the block.
  ({double above, double below}) clearance(WidgetTester tester) {
    final block = find.ancestor(
        of: find.textContaining('East 1'), matching: find.byType(Container));
    final b = tester.getRect(block.first);
    var above = double.negativeInfinity;
    var below = double.infinity;
    for (final e in find.byType(TileFace).evaluate()) {
      final r = tester.getRect(find.byWidget(e.widget));
      // Only the two ponds stacked on the block's own column.
      if ((r.center.dx - b.center.dx).abs() > 220) continue;
      if (r.center.dy < b.center.dy) {
        above = r.bottom > above ? r.bottom : above;
      } else {
        below = r.top < below ? r.top : below;
      }
    }
    return (above: b.top - above, below: below - b.bottom);
  }

  /// Both screens should land in the same band. A pond anchors its first row
  /// against the block and grows away from it, so one row is the worst case
  /// however full the pond gets.
  void expectSnug(({double above, double below}) gap, String where) {
    for (final entry in {'above': gap.above, 'below': gap.below}.entries) {
      expect(entry.value, greaterThan(6),
          reason: '$where: the pond ${entry.key} is crowding the block');
      expect(entry.value, lessThan(40),
          reason: '$where: the pond ${entry.key} has drifted away from the '
              'block — it is placed off the table height, not a fraction of it');
    }
  }

  testWidgets('the builder tucks both ponds against the centre block',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Random'));
    await tester.pump(const Duration(milliseconds: 100));

    expectSnug(clearance(tester), 'builder');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the live table places them the same way', (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));

    // An empty pond renders nothing, so give the two of interest some tiles.
    final host = tester.widget<TableView>(find.byType(TableView)).game;
    for (final seat in [0, 2]) {
      for (var i = 0; i < 7; i++) {
        host.round.seats[seat].pond.add(
          Tile(700 + seat * 10 + i, TileType.values[1 + (seat * 7 + i) % 34]),
        );
      }
    }
    // Pause notifies listeners, which is what rebuilds the table.
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));

    expectSnug(clearance(tester), 'live table');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
