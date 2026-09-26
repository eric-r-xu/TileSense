import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Only `loadLibrary()` is called on these, which the analyzer does not count
// as a use of the import — warming them is the whole point of this file.
// ignore: unused_import
import 'package:tilesense/ui/online_page.dart' deferred as online;
// ignore: unused_import
import 'package:tilesense/ui/scenario_page.dart' deferred as scenario;

/// Pump until a deferred page has loaded and laid out.
///
/// Deferred libraries do real I/O, which happens outside the fake test clock,
/// so the frame that shows the optional page only arrives once that I/O has
/// completed. Each turn of the loop gives the real event loop a slice with
/// [WidgetTester.runAsync], then pumps one frame.
///
/// Deliberately does *not* end with [WidgetTester.pumpAndSettle]: the online
/// page animates continuously, so it never reaches a settled state and the
/// wait times out instead of returning.
Future<void> pumpLoadedPage(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }

  // The spinner also disappears when loading *fails* — the loader swaps it for
  // a Retry button. Say so plainly rather than letting the caller fail later
  // with a confusing "widget not found".
  expect(
    find.textContaining('Couldn’t finish loading'),
    findsNothing,
    reason: 'the deferred page failed to load',
  );

  // The page itself may do async work as it mounts — the multiplayer lobby
  // reads a persisted client id, for instance — which also lives outside the
  // fake clock. Give it a few more real slices before handing back.
  for (var i = 0; i < 5; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Pump, in real-time slices, until [finder] matches — or fail saying so.
///
/// More reliable than a fixed number of frames: a deferred library is cached
/// per isolate, so the second test in a file to open the same page loads it
/// instantly while the first waits on real I/O. Waiting for the widget itself
/// works for both.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int tries = 60,
}) async {
  for (var i = 0; i < tries; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  fail('timed out waiting for $finder');
}

/// Load every optional page once, before any test in the file runs.
///
/// Call from `main()` in any file that opens the builder or multiplayer.
/// Deferred loading is per-isolate, and inside a widget test loading a second
/// *distinct* library returns a future that never completes — so a file that
/// visits both would hang on whichever it opened second. Doing both here, in
/// `setUpAll` and outside the test zone, sidesteps that entirely; in a real
/// web build each is still fetched on demand.
void preloadDeferredPages() {
  setUpAll(() async {
    await online.loadLibrary();
    await scenario.loadLibrary();
  });
}

/// Opens the builder's Menu, taps the item keyed [key], and closes the sheet
/// again if that item left it open (a dial does; Random, Clear and Back to
/// start close it themselves).
Future<void> tapBuilderMenu(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(const Key('phoneMenu')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pump(const Duration(milliseconds: 100));
  final done = find.byKey(const Key('builderMenuDone'));
  if (done.evaluate().isNotEmpty) await tester.tap(done);
  await tester.pump(const Duration(milliseconds: 500));
}
