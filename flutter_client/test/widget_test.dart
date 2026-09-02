import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/table_view.dart';

void main() {
  testWidgets('app boots to the table with the efficiency guide', (tester) async {
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TileSense — 2D Efficiency'), findsWidgets);
    expect(find.byType(TableView), findsOneWidget);
    expect(find.byType(HandView), findsOneWidget);
    expect(find.byType(EfficiencyOverlay), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('tapping a hand tile discards without crashing', (tester) async {
    await tester.pumpWidget(const TileSenseApp());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    final glyph = find.byWidgetPredicate(
      (w) => w is Text && w.data != null && _isMahjongGlyph(w.data!),
    );
    expect(glyph, findsWidgets);

    await tester.tap(glyph.last, warnIfMissed: false);
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

bool _isMahjongGlyph(String s) {
  if (s.runes.length != 1) return false;
  final r = s.runes.first;
  return r >= 0x1F007 && r <= 0x1F02B; // mahjong tiles Unicode block
}
