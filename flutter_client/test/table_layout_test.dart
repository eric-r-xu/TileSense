import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/tile_face.dart';

/// The centre status box (round / wall / honba / riichi) sits between your own
/// pond and the one across from you. Those two are the only ponds whose rows
/// stack towards it, so they are the two that can bury it — the left and right
/// ponds are turned sideways and run out horizontally instead.
void main() {
  /// Vertical clearance between the centre box and the nearest pond tile above
  /// and below it. Negative means a pond is covering the box.
  ({double above, double below}) clearance(WidgetTester tester) {
    final box = find.ancestor(
        of: find.textContaining('East 1'), matching: find.byType(Container));
    final boxRect = tester.getRect(box.first);
    var above = double.negativeInfinity;
    var below = double.infinity;
    for (final e in find.byType(TileFace).evaluate()) {
      final r = tester.getRect(find.byWidget(e.widget));
      // Only the two ponds stacked on the box's own column.
      if ((r.center.dx - boxRect.center.dx).abs() > 220) continue;
      if (r.center.dy < boxRect.center.dy) {
        above = r.bottom > above ? r.bottom : above;
      } else {
        below = r.top < below ? r.top : below;
      }
    }
    return (above: boxRect.top - above, below: below - boxRect.bottom);
  }

  testWidgets('the builder keeps the centre box clear of both ponds',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Random'));
    await tester.pump(const Duration(milliseconds: 100));

    // A pond anchors its first row against the box and grows away from it, so
    // one row is the worst case however full the pond gets.
    final gap = clearance(tester);
    expect(gap.above, greaterThan(8),
        reason: 'the across pond is burying the status box');
    expect(gap.below, greaterThan(8),
        reason: 'your own pond is burying the status box');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('the live table keeps the same clearance', (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));

    final gap = clearance(tester);
    expect(gap.above, greaterThan(8));
    expect(gap.below, greaterThan(8));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
