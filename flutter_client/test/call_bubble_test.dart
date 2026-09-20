import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/call_callout.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/ui/table_view.dart';

void main() {
  testWidgets('a call flashes an all-caps bubble for 0.86s then clears',
      (tester) async {
    final game = GameController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 1600, height: 760, child: TableView(game: game)),
      ),
    ));
    expect(find.text('PON'), findsNothing);

    CallCallout.i.show(2, 'pon');
    await tester.pump();
    expect(find.text('PON'), findsOneWidget);
    // It is drawn in the root overlay, above the whole table, not inside it.
    expect(
        find.descendant(of: find.byType(TableView), matching: find.text('PON')),
        findsNothing);
    expect(
        find.descendant(of: find.byType(Overlay), matching: find.text('PON')),
        findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PON'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PON'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });
}
