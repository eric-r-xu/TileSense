import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

void main() {
  testWidgets(
      'app boots to the table with the efficiency guide off by default',
      (tester) async {
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TileSense'), findsWidgets);
    expect(find.byType(TableView), findsOneWidget);
    expect(find.byType(HandView), findsOneWidget);
    expect(find.byType(EfficiencyOverlay), findsNothing);

    // The clefairy button next to the GitHub link turns it on.
    await tester.tap(find.byTooltip('Show guide'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EfficiencyOverlay), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('tapping a hand tile discards without crashing', (tester) async {
    await tester.pumpWidget(const TileSenseApp());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Tile faces are drawn as images now (see tile_face.dart), not glyph
    // Text, so find a tappable one by widget type instead of by its glyph.
    final tileInHand = find.descendant(
      of: find.byType(HandView),
      matching: find.byType(TileFace),
    );
    expect(tileInHand, findsWidgets);

    await tester.tap(tileInHand.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Still a live table, no exception thrown by the turn loop.
    expect(find.byType(TableView), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
