import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/table_view.dart';
import 'package:tilesense/ui/tile_face.dart';

void main() {
  testWidgets('app boots to the table with the efficiency guide off by default',
      (tester) async {
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Welcome screen first — Start hands off to the table.
    expect(find.text('Single Player'), findsOneWidget);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TileSense'), findsWidgets);
    expect(find.byType(TableView), findsOneWidget);
    expect(find.byType(HandView), findsOneWidget);
    expect(find.byType(EfficiencyOverlay), findsNothing);

    // The clefairy mascot in the AppBar turns it on.
    await tester.tap(find.byKey(const Key('guideToggle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EfficiencyOverlay), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'the pause button toggles the paused overlay, which itself resumes on tap',
      (tester) async {
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('PAUSED'), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('PAUSED'), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);

    // The full-screen overlay itself is also tappable to resume, for mobile
    // users who'd rather tap anywhere than hunt for the small AppBar button.
    await tester.tap(find.textContaining('PAUSED'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('PAUSED'), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'the back-to-menu button pauses the game and returns to it on Start',
      (tester) async {
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TableView), findsOneWidget);
    expect(find.textContaining('PAUSED'), findsNothing);

    // Leaving the game for the welcome screen pauses it and offers the
    // builder again.
    await tester.tap(find.byKey(const Key('backToMenu')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TableView), findsNothing);
    expect(find.byKey(const Key('openBuilder')), findsOneWidget);

    // Start un-pauses and returns to the same game rather than dealing a new
    // one.
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TableView), findsOneWidget);
    expect(find.textContaining('PAUSED'), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('tapping a hand tile discards without crashing', (tester) async {
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
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

    // A first tap only raises the tile; a second discards it.
    await tester.tap(tileInHand.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('Play Online and the builder each carry an emoji on the left',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));

    for (final (emojiKey, title) in [
      ('playOnlineEmoji', 'Play Online'),
      ('openBuilderEmoji', 'Custom Hand & Context Builder'),
    ]) {
      final emoji = tester.getRect(find.byKey(Key(emojiKey)));
      final label = tester.getRect(find.text(title));
      expect(emoji.right, lessThanOrEqualTo(label.left),
          reason: '$title\'s emoji should sit to its left');
    }
    expect(tester.takeException(), isNull,
        reason: 'the button row still fits the welcome screen');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
