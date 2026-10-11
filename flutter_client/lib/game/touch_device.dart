/// Whether the browser reports a multi-touch screen. `touch_device_web.dart`
/// reads `navigator.maxTouchPoints`; `touch_device_stub.dart` is the fallback
/// for Android / iOS builds and the VM, where the answer is never needed.
library;

export 'touch_device_stub.dart'
    if (dart.library.js_interop) 'touch_device_web.dart';
