import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/tile_face.dart';

/// Putting your own hand in your own order: long-press a tile and drag it
/// where you want it. Tapping still discards and the strip still scrolls —
/// which is exactly why lifting a tile takes a long press and not a drag.
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

  Future<void> startGame(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start'));
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

  testWidgets('a tile dragged right lands after the one it was dropped on',
      (tester) async {
    await startGame(tester);
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
    await tester.tap(find.byKey(const Key('sortHand')));
    await tester.pump(const Duration(milliseconds: 100));

    final sorted = strip(tester);
    final inOrder = [...sorted]..sort((a, b) => a.index.compareTo(b.index));
    expect(sorted, inOrder, reason: 'auto-sort did not sort');
    expect(sorted[0], isNot(sorted[5]),
        reason: 'need two different tiles for the move to be visible');

    await dragTile(tester, 0, 5);

    // Index-for-index comparison is no use here: dropping out of auto-sort
    // also pulls the drawn tile out to its own slot on the right, so the
    // resting strip is a tile shorter than the sorted one was. What matters is
    // that the hand is no longer being held in tile order.
    bool sortedNow() {
      final now = strip(tester);
      final want = [...now]..sort((a, b) => a.index.compareTo(b.index));
      return now.toString() == want.toString();
    }

    expect(sortedNow(), isFalse,
        reason: 'the move was sorted straight back out');

    // A later rebuild must not undo it either — that is the whole reason the
    // drag drops out of auto-sort rather than fighting it.
    await tester.pump(const Duration(milliseconds: 400));
    expect(sortedNow(), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a plain tap still discards', (tester) async {
    await startGame(tester);
    final before = strip(tester).length;

    await tester.tap(handTiles.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(strip(tester).length, lessThan(before),
        reason: 'tapping a tile stopped discarding it');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
