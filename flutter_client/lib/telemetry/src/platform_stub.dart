/// Non-web fallback for the telemetry platform bindings. Selected by the
/// conditional import in `telemetry.dart` whenever `dart:io` is available
/// (the Dart VM used by tests, and the Android / iOS builds), so `package:web`
/// is never compiled off the web.
library;

bool get isWebPlatform => false;

bool beaconSend(String url, String body) => false;

String? localStorageGet(String key) => null;

void localStorageSet(String key, String value) {}
