import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The game is landscape only. The OS locks it where it can; the rotate prompt
/// in main.dart is the fallback for web and windows the OS lets turn anyway.
void main() {
  test('Android locks the game activity to landscape', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:screenOrientation="sensorLandscape"'));
  });

  test('iOS lists only landscape orientations, on iPhone and iPad', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in [
      'UISupportedInterfaceOrientations',
      'UISupportedInterfaceOrientations~ipad',
    ]) {
      final list = RegExp('<key>$key</key>\\s*<array>(.*?)</array>',
              dotAll: true)
          .firstMatch(plist)
          ?.group(1);
      expect(list, isNotNull, reason: key);
      expect(list, contains('UIInterfaceOrientationLandscapeLeft'));
      expect(list, contains('UIInterfaceOrientationLandscapeRight'));
      expect(list, isNot(contains('Portrait')), reason: key);
    }
  });
}
