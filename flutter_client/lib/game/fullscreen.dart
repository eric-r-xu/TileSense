/// Browser fullscreen for the web build. `fullscreen_web.dart` has the real
/// implementation; `fullscreen_stub.dart` is an inert fallback for Android /
/// iOS builds and the VM, where the button is never shown.
library;

export 'fullscreen_stub.dart'
    if (dart.library.js_interop) 'fullscreen_web.dart';
