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
      await tester.pump();
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
      await tester.pump();
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
        await tester.tap(find.text('Play Offline'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('charactersContinue')));
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
        await tester.tap(find.text('Play Offline'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('charactersContinue')));
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

    testWidgets('the client id is white text, top-left, on the online screen',
        (tester) async {
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
        await tester.pump(const Duration(milliseconds: 100));
        final text = find.byKey(const Key('clientId'));
        expect(text, findsOneWidget);
        expect(find.text(id), findsOneWidget);
        expect(tester.widget<SelectableText>(text).style?.color, Colors.white);

        // Top-left, immediately after the back arrow.
        final back = tester.getRect(find.byTooltip('Back to menu'));
        final rect = tester.getRect(text);
        expect(rect.left, greaterThanOrEqualTo(back.right - 1));
        expect(rect.top, lessThan(60));
        expect(rect.left, lessThan(120));

        // Tapping copies it.
        await tester.tap(text);
        await tester.pump();
        expect(copied, id);

        // Back on the title screen, it is gone again.
        await tester.pump(const Duration(seconds: 3));
        await tester.tap(find.byTooltip('Back to menu'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(id), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
        debugDefaultTargetPlatformOverride = null;
      }
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
