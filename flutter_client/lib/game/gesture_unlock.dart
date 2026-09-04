/// Arms a native (non-Flutter) hook on the first several user gestures to
/// prime the audio players before mobile browsers' autoplay gating can block
/// them. See `gesture_unlock_web.dart` for the real implementation and why it
/// bypasses Flutter's own event pipeline, and `sfx.dart`'s class doc for the
/// full picture. `gesture_unlock_stub.dart` is a no-op used on Android/iOS,
/// which don't gate audio this way.
library;

export 'gesture_unlock_stub.dart'
    if (dart.library.js_interop) 'gesture_unlock_web.dart';
