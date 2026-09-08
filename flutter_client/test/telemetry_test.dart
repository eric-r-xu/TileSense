import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/telemetry/telemetry.dart';

void main() {
  test('telemetry is inert off the web (VM tests, native builds)', () {
    // Tests run on the VM with the platform stub, so `isWebPlatform` is false
    // and telemetry must be a no-op regardless of the release-mode default.
    expect(Telemetry.maybe(), isNull);
  });

  test('newUuid returns a v4 UUID', () {
    final id = newUuid();
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(id),
      isTrue,
      reason: id,
    );
    expect(newUuid(), isNot(id));
  });
}
