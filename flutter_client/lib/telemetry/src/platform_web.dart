/// Web implementation of the telemetry platform bindings: `navigator.sendBeacon`
/// for transport and `localStorage` for the persistent client id. This file is
/// only compiled for the web target (see the conditional import in
/// `telemetry.dart`).
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get isWebPlatform => true;

bool beaconSend(String url, String body) {
  try {
    // A text/plain string body keeps this a CORS "simple request" (no
    // preflight). The server reads the raw body regardless of content type.
    return web.window.navigator.sendBeacon(url, body.toJS);
  } catch (_) {
    return false;
  }
}

String? localStorageGet(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void localStorageSet(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {
    // Private mode / storage disabled — ignore.
  }
}
