/// Arms a native (non-Flutter) hook on user gestures to resume the shared web
/// audio context before mobile browsers' autoplay gating can block it. See
/// `gesture_unlock_web.dart` for the real implementation and why it bypasses
/// Flutter's own event pipeline, and `sfx.dart`'s class doc for the full
/// picture. `gesture_unlock_stub.dart` is a no-op used on Android/iOS, which
/// don't gate audio this way.
library;

export 'gesture_unlock_stub.dart'
    if (dart.library.js_interop) 'gesture_unlock_web.dart';
