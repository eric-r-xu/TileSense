import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/tile_face.dart';

/// Putting your own hand in your own order: long-press a tile and drag it
/// where you want it. A plain tap instead raises a tile and a second tap
/// discards it, and the strip still scrolls — which is exactly why lifting a
/// tile to reorder it takes a long press and not a drag.
void main() {
  final handTiles = find.descendant(
    of: find.byType(HandView),
    matching: find.byType(TileFace),
  );

  /// The tile types across the concealed strip, left to right.
  List<TileType> strip(WidgetTester tester) => tester
      .widgetList<TileFace>(handTiles)
      .map((f) => f.tile?.type)
      .whereType<TileType>()
      .toList();

  /// The resting tiles: the strip without the drawn tile, which always sits
  /// last, apart from the others.
  List<TileType> resting(WidgetTester tester) {
    final all = strip(tester);
    return all.sublist(0, all.length - 1);
  }

  bool inTileOrder(List<TileType> tiles) {
    final want = [...tiles]..sort((a, b) => a.index.compareTo(b.index));
    return tiles.toString() == want.toString();
  }

  Future<void> startGame(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('charactersContinue')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Long-press the tile at [from] and drop it on the one at [to].
  Future<void> dragTile(WidgetTester tester, int from, int to) async {
    final start = tester.getCenter(handTiles.at(from));
    final end = tester.getCenter(handTiles.at(to));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600)); // hold to lift
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Tap the Sort chip once: Off → Hand → Hand+draw → Off.
  Future<void> cycleSort(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('sortHand')));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Sort starts on Hand, so tests that just want a stable, non-resorting
  /// order to drag within turn it off first (Hand → Hand+draw → Off) —
  /// exactly what a player would do before rearranging their hand by hand.
  Future<void> uncheckAutoSort(WidgetTester tester) async {
    await cycleSort(tester);
    await cycleSort(tester);
    expect(find.text('Sort: Off'), findsOneWidget);
  }

  testWidgets('a tile dragged right lands after the one it was dropped on',
      (tester) async {
    await startGame(tester);
    await uncheckAutoSort(tester);
    final before = strip(tester);
    expect(before.length, greaterThanOrEqualTo(13));

    await dragTile(tester, 0, 3);
    final after = strip(tester);

    // A move, never an add or a drop: the same tiles, rearranged.
    expect(after.length, before.length);
    expect(after[3], before[0]);
    expect(after.sublist(0, 3), before.sublist(1, 4));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a tile dragged left lands before the one it was dropped on',
      (tester) async {
    await startGame(tester);
    await uncheckAutoSort(tester);
    final before = strip(tester);

    await dragTile(tester, 4, 1);
    final after = strip(tester);

    expect(after[1], before[4]);
    expect(after[0], before[0]);
    expect(after[2], before[1]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('dragging while auto-sorted keeps the move and leaves auto-sort',
      (tester) async {
    await startGame(tester);

    // Auto-sort is checked by default, so the hand should already be sorted
    // with no tap needed.
    final sorted = resting(tester);
    expect(inTileOrder(sorted), isTrue,
        reason: 'auto-sort did not sort by default');
    expect(sorted[0], isNot(sorted[5]),
        reason: 'need two different tiles for the move to be visible');

    await dragTile(tester, 0, 5);

    // Index-for-index comparison is no use here: dropping out of auto-sort
    // also pulls the drawn tile out to its own slot on the right, so the
    // resting strip is a tile shorter than the sorted one was. What matters is
    // that the hand is no longer being held in tile order.
    bool sortedNow() => inTileOrder(resting(tester));

    expect(sortedNow(), isFalse,
        reason: 'the move was sorted straight back out');

    // A later rebuild must not undo it either — that is the whole reason the
    // drag drops out of auto-sort rather than fighting it.
    await tester.pump(const Duration(milliseconds: 400));
    expect(sortedNow(), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'unchecking auto-sort freezes the current order instead of reverting '
      'to draw order', (tester) async {
    await startGame(tester);
    final sortedResting = resting(tester);
    final drawnBefore = strip(tester).last;
    expect(inTileOrder(sortedResting), isTrue,
        reason: 'auto-sort did not sort by default');

    await uncheckAutoSort(tester);

    // The drawn tile stays in its own slot at the end, and the rest of the
    // hand keeps the sorted order it was just showing rather than jumping back
    // to draw order.
    expect(strip(tester).last, drawnBefore);
    expect(resting(tester), sortedResting);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'auto-sort keeps the drawn tile on the right, spaced from the rest',
      (tester) async {
    await startGame(tester);
    // Sorted: the resting tiles are in tile order, the drawn tile is not
    // filed among them.
    expect(inTileOrder(resting(tester)), isTrue);

    final rects = [
      for (var i = 0; i < handTiles.evaluate().length; i++)
        tester.getRect(handTiles.at(i)),
    ];
    final drawn = rects.last;
    final beforeDrawn = rects[rects.length - 2];
    expect(drawn.left, greaterThan(beforeDrawn.right),
        reason: 'the drawn tile sits to the right of every resting tile');
    final restingGap = rects[1].left - rects[0].right;
    expect(drawn.left - beforeDrawn.right, greaterThan(restingGap),
        reason: 'and is spaced a little further from them than they are '
            'from each other');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Sort: Hand+draw files the drawn tile in among the rest',
      (tester) async {
    await startGame(tester);
    expect(find.text('Sort: Hand'), findsOneWidget,
        reason: 'Sort starts on Hand');
    final hand = strip(tester);
    final drawn = hand.last;
    final restingRects = [
      for (var i = 0; i < hand.length; i++) tester.getRect(handTiles.at(i)),
    ];
    final restingGap = restingRects[1].left - restingRects[0].right;

    await cycleSort(tester);
    expect(find.text('Hand+draw'), findsOneWidget);

    // Same tiles, now all in tile order with no separated slot.
    final all = strip(tester);
    expect(inTileOrder(all), isTrue);
    expect([...all]..sort((a, b) => a.index.compareTo(b.index)),
        [...hand]..sort((a, b) => a.index.compareTo(b.index)));
    expect(all.contains(drawn), isTrue);
    for (var i = 1; i < all.length; i++) {
      final gap = tester.getRect(handTiles.at(i)).left -
          tester.getRect(handTiles.at(i - 1)).right;
      expect(gap, closeTo(restingGap, 0.5),
          reason: 'no tile is held apart in Hand+draw');
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'Hand+draw → Off freezes the sorted hand and puts the drawn tile back '
      'on the right', (tester) async {
    await startGame(tester);
    final sortedResting = resting(tester);
    final drawn = strip(tester).last;

    await cycleSort(tester); // Hand+draw
    await cycleSort(tester); // Off
    expect(find.text('Sort: Off'), findsOneWidget);
    expect(strip(tester).last, drawn);
    expect(resting(tester), sortedResting);

    await cycleSort(tester); // back to Hand
    expect(find.text('Sort: Hand'), findsOneWidget);
    expect(inTileOrder(resting(tester)), isTrue);
    expect(strip(tester).last, drawn);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'dragging while Hand+draw keeps the move, drawn tile included, and '
      'leaves sorting', (tester) async {
    await startGame(tester);
    await cycleSort(tester); // Hand+draw
    final before = strip(tester);
    expect(before[0], isNot(before[5]),
        reason: 'need two different tiles for the move to be visible');

    await dragTile(tester, 0, 5);
    expect(find.text('Sort: Off'), findsOneWidget);
    final after = strip(tester);
    expect(after.length, before.length,
        reason: 'the drawn tile stays placed in the strip, not moved apart');
    expect(after[5], before[0]);
    expect(after.sublist(0, 5), before.sublist(1, 6));

    await tester.pump(const Duration(milliseconds: 400));
    expect(strip(tester), after);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a first tap raises a tile, and a second discards it',
      (tester) async {
    await startGame(tester);
    final before = strip(tester).length;
    final tileRect = tester.getRect(handTiles.first);

    await tester.tap(handTiles.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    // Still in hand — the first tap only raised it.
    expect(strip(tester).length, before);
    await tester.pump(const Duration(milliseconds: 200)); // finish the rise
    expect(tester.getRect(handTiles.first).top, lessThan(tileRect.top),
        reason: 'a raised tile should sit higher than before');

    await tester.tap(handTiles.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(strip(tester).length, lessThan(before),
        reason: 'a second tap on the raised tile should discard it');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('tapping a different tile moves the raise instead of discarding',
      (tester) async {
    await startGame(tester);
    final before = strip(tester).length;

    await tester.tap(handTiles.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(handTiles.at(1), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(strip(tester).length, before,
        reason: 'tapping a second tile should raise it, not discard either');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
