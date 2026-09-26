import 'loading_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/telemetry/telemetry.dart' show persistentClientId;
import 'package:tilesense/ui/efficiency_overlay.dart';
import 'package:tilesense/ui/table_view.dart';

/// The whole UI is one fixed canvas scaled to fit, so everything about how it
/// meets the device — display cutouts, pinch zoom — is decided in one place.
void main() {
  preloadDeferredPages();

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
      await pumpLoadedPage(tester);

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
      await pumpLoadedPage(tester);

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
        await tester.tap(find.text('Single Player'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('charactersContinue')));
        await tester.pump(); // Render the startup/loading frame.
        // The table is created after a loading frame.
        await tester.pump();
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

    testWidgets('a desktop browser zooms, but only on purpose', (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(const TileSenseApp());
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Single Player'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('charactersContinue')));
        await tester.pump(); // Render the startup/loading frame.
        // The table is created after a loading frame.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final viewer = find.byType(InteractiveViewer);
        expect(viewer, findsOneWidget, reason: 'desktop zooms too now');
        final controller =
            tester.widget<InteractiveViewer>(viewer).transformationController!;
        expect(controller.value.getMaxScaleOnAxis(), 1.0);

        // A bare trackpad pinch must do nothing. This is the whole reason
        // desktop is on its own path: the window is already the right size,
        // and a stray two-finger gesture rescaling the table mid-hand is the
        // accident being avoided.
        final centre = tester.getCenter(find.byType(TableView));
        final a = await tester.startGesture(centre - const Offset(20, 0));
        final b = await tester.startGesture(centre + const Offset(20, 0));
        await a.moveBy(const Offset(-120, 0));
        await b.moveBy(const Offset(120, 0));
        await tester.pump();
        expect(controller.value.getMaxScaleOnAxis(), 1.0,
            reason: 'a bare pinch should not scale the desktop canvas');
        await a.up();
        await b.up();
        await tester.pump();

        // The buttons do. Reset is offered only once there is something to
        // reset, so it starts disabled and the canvas starts at fit.
        expect(
            tester
                .widget<IconButton>(find.byKey(const Key('zoomReset')))
                .onPressed,
            isNull);
        await tester.tap(find.byKey(const Key('zoomIn')));
        await tester.pump();
        expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.0),
            reason: 'the zoom-in button did nothing');

        await tester.tap(find.byKey(const Key('zoomOut')));
        await tester.pump();
        expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 0.001),
            reason: 'zooming back out did not return to fit');

        // At fit the canvas exactly fills its box, so the offset has to come
        // home too — otherwise reset leaves letterbox where table should be.
        await tester.tap(find.byKey(const Key('zoomIn')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('zoomReset')));
        await tester.pump();
        expect(controller.value, Matrix4.identity());

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'the client id is behind an ID chip, away from Back, and copies from '
        'its dialog', (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      try {
        await tester.pumpWidget(const TileSenseApp());
        await tester.pump(const Duration(milliseconds: 100));

        // Not on the title screen.
        final id = persistentClientId();
        expect(id, matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(find.text(id), findsNothing);

        await tester.tap(find.byKey(const Key('playOnline')));
        final chip = find.byKey(const Key('clientIdButton'));
        await pumpUntilFound(tester, chip);
        // Only the chip shows: the id itself waits behind it.
        expect(find.text(id), findsNothing);

        // Back is a big labelled target on the left; the chip is at the
        // other end of the bar, nowhere near it.
        final back = tester.getRect(find.byKey(const Key('onlineBack')));
        expect(back.width, greaterThanOrEqualTo(44));
        expect(back.height, greaterThanOrEqualTo(44));
        expect(back.left, lessThan(20));
        expect(tester.getRect(chip).left, greaterThan(kDesignSize.width / 2));

        // The dialog shows the id, and Copy copies it.
        await tester.tap(chip);
        await tester.pump(const Duration(milliseconds: 300));
        expect(
            tester
                .widget<SelectableText>(
                    find.byKey(const Key('clientIdValue')))
                .data,
            id);
        await tester.tap(find.byKey(const Key('clientIdCopy')));
        await tester.pump();
        expect(copied, id);
        expect(find.text('Copied'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.tap(find.byKey(const Key('clientIdClose')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.text(id), findsNothing);

        // Back to the title screen.
        await tester.tap(find.byKey(const Key('onlineBack')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('playOnline')), findsOneWidget);
        expect(find.text(id), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('on a phone the lobby\'s Back and ID chip clear 44pt',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(852, 393));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.byKey(const Key('playOnline')));
      await tester.tap(find.byKey(const Key('playOnline')));
      await pumpLoadedPage(tester);
      await tester.pump(const Duration(milliseconds: 100));
      for (final key in ['onlineBack', 'clientIdButton']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(r.height, greaterThanOrEqualTo(44), reason: key);
        expect(r.width, greaterThanOrEqualTo(44), reason: key);
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the keyboard shortcuts zoom and reset', (tester) async {
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(const TileSenseApp());
        await tester.pump(const Duration(milliseconds: 100));
        final controller = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!;

        Future<void> press(LogicalKeyboardKey key) async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
          await tester.sendKeyEvent(key);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
          await tester.pump();
        }

        await press(LogicalKeyboardKey.equal);
        expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.0));

        await press(LogicalKeyboardKey.digit0);
        expect(controller.value, Matrix4.identity());

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
