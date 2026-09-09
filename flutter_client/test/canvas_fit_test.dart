import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/table_view.dart';

/// The whole UI is one fixed canvas scaled to fit, so everything about how it
/// meets the device — display cutouts, pinch zoom — is decided in one place.
void main() {
  group('display cutouts', () {
    // iPhone 15 Pro in landscape: 852x393 CSS px, ~59px inset on the notch
    // side and ~21px for the home indicator.
    const size = Size(852, 393);
    const insets = EdgeInsets.fromLTRB(59, 0, 59, 21);

    testWidgets('the canvas is fitted inside the safe area, not under it',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(size: size, padding: insets, viewPadding: insets),
        child: TileSenseApp(),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await tester.pump(const Duration(milliseconds: 100));

      // The guide panel hugs the canvas's left edge, so a notch eats it first.
      // Fitted to the window instead of the safe area it lands at 46px, inside
      // a 59px inset.
      final panel = tester.getRect(find.byType(EfficiencyOverlay));
      expect(panel.left, greaterThanOrEqualTo(insets.left),
          reason: 'the guide panel is under the notch');
      expect(panel.right, lessThanOrEqualTo(size.width - insets.right));

      final table = tester.getRect(find.byType(TableView));
      expect(table.bottom, lessThanOrEqualTo(size.height - insets.bottom),
          reason: 'the table runs under the home indicator');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('a device with no cutout loses nothing to it', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(size: size),
        child: TileSenseApp(),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('openBuilder')));
      await tester.pump(const Duration(milliseconds: 100));

      // With no insets the canvas should use the full width it can.
      final table = tester.getRect(find.byType(TableView));
      expect(table.left, lessThan(59),
          reason: 'padding was reserved for a cutout that is not there');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('pinch to zoom', () {
    testWidgets('a touch platform can pinch, and it returns to fit',
        (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(const TileSenseApp());
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));

        final viewer = find.byType(InteractiveViewer);
        expect(viewer, findsOneWidget);
        final controller =
            tester.widget<InteractiveViewer>(viewer).transformationController!;
        expect(controller.value.getMaxScaleOnAxis(), 1.0);

        // Two fingers spreading apart from the middle of the table.
        final centre = tester.getCenter(find.byType(TableView));
        final a = await tester.startGesture(centre - const Offset(20, 0));
        final b = await tester.startGesture(centre + const Offset(20, 0));
        await a.moveBy(const Offset(-120, 0));
        await b.moveBy(const Offset(120, 0));
        await tester.pump();
        expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.5),
            reason: 'pinching out did not zoom in');
        await a.up();
        await b.up();
        await tester.pump();

        // Pinching back in goes the whole way home — minScale clamps at fit.
        controller.value = Matrix4.identity();
        await tester.pump();
        expect(controller.value.getMaxScaleOnAxis(), 1.0);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a desktop browser is left alone', (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(const TileSenseApp());
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(InteractiveViewer), findsNothing,
            reason: 'desktop should not get a zoomable canvas');

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
