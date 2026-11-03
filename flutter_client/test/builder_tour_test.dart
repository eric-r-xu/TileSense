import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/builder_tour.dart';
import 'package:tilesense/ui/scenario_page.dart';
import 'package:tilesense/ui/table_tour.dart';

import 'loading_helpers.dart';

/// The Hand Builder tour over a newcomer's first visit to the builder.
void main() {
  preloadDeferredPages();

  setUp(() {
    BuilderTour.autoShow = true;
    BuilderTour.reset();
  });
  tearDown(() => BuilderTour.autoShow = false);

  const steps = 7;
  const guideStep = 5;

  Future<void> openBuilder(WidgetTester tester, {Size? size}) async {
    await tester.binding.setSurfaceSize(size ?? kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.byKey(const Key('openBuilder')));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await pumpLoadedPage(tester);
  }

  /// The tour's Next button is on screen, so the tour can always go on.
  void expectNextReachable(WidgetTester tester, int step) {
    final screen = tester.getRect(find.byKey(const Key('builderTour')));
    final next = tester.getRect(find.byKey(const Key('builderTourNext')));
    expect(screen.contains(next.topLeft) && screen.contains(next.bottomRight),
        isTrue,
        reason: 'step $step: Next at $next is off the $screen screen');
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('builderTourNext')));
    await tester.pump();
  }

  Future<void> closeTest(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('a first visit opens the tour; its seven steps end it for good',
      (tester) async {
    await openBuilder(tester);
    expect(find.byType(ScenarioPage), findsOneWidget);
    expect(find.byKey(const Key('builderTour')), findsOneWidget);
    for (var step = 0; step < steps; step++) {
      expect(find.byKey(Key('builderTourStep_$step')), findsOneWidget);
      expectNextReachable(tester, step);
      expect(find.text('${step + 1} of $steps'), findsOneWidget);
      // Only the guide step offers a sample hand.
      expect(find.byKey(const Key('builderTourSample')),
          step == guideStep ? findsOneWidget : findsNothing);
      // Skip is for any step but the last, which has its own button.
      expect(find.byKey(const Key('builderTourSkip')),
          step == steps - 1 ? findsNothing : findsOneWidget);
      await next(tester);
    }
    expect(find.byKey(const Key('builderTour')), findsNothing);
    expect(BuilderTour.shouldAutoShow, isFalse);
    expect(tester.takeException(), isNull);
    await closeTest(tester);
  });

  testWidgets(
      'every step finds its target, so none falls back to a centred card',
      (tester) async {
    await openBuilder(tester);
    final screen = tester.getRect(find.byKey(const Key('builderTour')));
    for (var step = 0; step < steps; step++) {
      // The overlay centres a step's card only when its target is not on
      // screen; a found target puts the card beside it instead.
      final card = tester.getRect(find.byKey(Key('builderTourStep_$step')));
      expect((card.center - screen.center).distance, greaterThan(1),
          reason: 'step $step has no target to light');
      expect(screen.contains(card.topLeft), isTrue, reason: 'step $step');
      expect(screen.contains(card.bottomRight), isTrue, reason: 'step $step');
      await next(tester);
    }
    await closeTest(tester);
  });

  testWidgets('the tour holds the builder still until it is done',
      (tester) async {
    await openBuilder(tester);
    expect(find.textContaining('Your hand (0)'), findsOneWidget);
    // A tap on the palette goes to the tour, not through it to the tile.
    await tester.tapAt(tester.getCenter(find.byKey(const Key('builderTour'))));
    await tester.pump();
    expect(find.textContaining('Your hand (0)'), findsOneWidget);
    expect(find.byKey(const Key('builderTour')), findsOneWidget);
    await closeTest(tester);
  });

  testWidgets('the guide step can load a sample hand and stays put',
      (tester) async {
    await openBuilder(tester);
    for (var i = 0; i < guideStep; i++) {
      await next(tester);
    }
    expect(find.byKey(const Key('builderTourStep_$guideStep')), findsOneWidget);
    expect(find.textContaining('Your hand (0)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('builderTourSample')));
    await tester.pump();
    expect(find.textContaining('Your hand (0)'), findsNothing);
    expect(find.textContaining('Your hand ('), findsOneWidget);
    expect(find.byKey(const Key('builderTourStep_$guideStep')), findsOneWidget,
        reason: 'the tour waits where it was');
    expect(tester.takeException(), isNull);
    await closeTest(tester);
  });

  testWidgets('Skip ends it for good; the builder Menu brings it back',
      (tester) async {
    await openBuilder(tester);
    await tester.tap(find.byKey(const Key('builderTourSkip')));
    await tester.pump();
    expect(find.byKey(const Key('builderTour')), findsNothing);
    expect(BuilderTour.shouldAutoShow, isFalse);

    await tester.tap(find.byKey(const Key('phoneMenu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byKey(const Key('builderMenuTour')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('builderMenuTour')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('builderTour')), findsOneWidget);
    expect(find.byKey(const Key('builderTourStep_0')), findsOneWidget,
        reason: 'a replay starts from the top');
    await closeTest(tester);
  });

  testWidgets('a visit after the tour was seen opens straight to the builder',
      (tester) async {
    BuilderTour.markSeen();
    await openBuilder(tester);
    expect(find.byType(ScenarioPage), findsOneWidget);
    expect(find.byKey(const Key('builderTour')), findsNothing);
    await closeTest(tester);
  });

  testWidgets('on a phone every step fits, with no layout errors',
      (tester) async {
    await openBuilder(tester, size: const Size(852, 393));
    for (var step = 0; step < steps; step++) {
      expect(find.byKey(Key('builderTourStep_$step')), findsOneWidget);
      expectNextReachable(tester, step);
      expect(tester.takeException(), isNull, reason: 'step $step');
      await next(tester);
    }
    expect(find.byKey(const Key('builderTour')), findsNothing);
    await closeTest(tester);
  });

  testWidgets('the two tours remember being seen separately', (tester) async {
    TableTour.reset();
    BuilderTour.markSeen();
    expect(BuilderTour.shouldAutoShow, isFalse);
    expect(TableTour.shouldAutoShow, isFalse,
        reason: 'autoShow is off in tests unless a test turns it on');
    TableTour.autoShow = true;
    addTearDown(() => TableTour.autoShow = false);
    expect(TableTour.shouldAutoShow, isTrue,
        reason: 'seeing the builder tour says nothing of the table tour');
  });
}
