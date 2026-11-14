import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/net/online_availability.dart';

import 'loading_helpers.dart';

/// Play Online is web-only: the iOS and Android store builds are offline, and
/// their privacy disclosures depend on it. Flutter's VM tests are not the web,
/// so the default here is exactly what a native build gets.
Future<void> _boot(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(kDesignSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const TileSenseApp());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  preloadDeferredPages();

  tearDown(() => playOnlineOverride = null);

  test('defaults to unavailable off the web, and honors the test override', () {
    playOnlineOverride = null;
    expect(playOnlineAvailable, isFalse, reason: 'VM tests are not the web');
    playOnlineOverride = true;
    expect(playOnlineAvailable, isTrue);
  });

  testWidgets('native menu offers no Play Online, but keeps everything else',
      (tester) async {
    await _boot(tester);
    expect(find.byKey(const Key('playOnline')), findsNothing);
    expect(find.byKey(const Key('rejoinOnline')), findsNothing);
    expect(find.text('Play Online'), findsNothing);
    for (final key in ['singlePlayer', 'openBuilder', 'learnTile']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: '$key stays');
    }
  });

  testWidgets('web menu still offers Play Online', (tester) async {
    playOnlineOverride = true;
    await _boot(tester);
    expect(find.byKey(const Key('playOnline')), findsOneWidget);
  });
}
