import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'sfx.dart';

/// HTML user activation occurs on mouse-down, but on touch/pen it occurs at
/// pointer-up or touch-end. Keep both touch events for older iOS WebKit; the
/// repeated resume is harmless and protects the widest range of Safari builds.
const _kFirstGestureEvents = [
  'mousedown',
  'pointerup',
  'touchend',
  'keydown',
];

/// Hooks native pointer/touch/key events directly via the DOM — entirely
/// outside Flutter's widget tree and gesture system — to resume TileSense's
/// shared browser `AudioContext` (see `Sfx.unlock`).
///
/// A Flutter `Listener`/`GestureDetector` callback only fires after Flutter's
/// own pointer-event pipeline has already processed the native browser event;
/// on strict mobile browsers that extra hop alone can be enough for the
/// eventual `AudioContext.resume()` call to no longer be treated as tied to
/// the user's gesture. Calling straight into `Sfx.unlock()` from a listener
/// attached directly to `window` avoids that hop. The listener remains so it
/// can resume again after a browser suspends audio while backgrounded.
void armFirstGestureUnlock() {
  // Decode early so later calls have no fetch/decode delay. This lives in the
  // web-only implementation to keep native audio initialization unchanged.
  unawaited(Sfx.i.preload());
  void onEvent(web.Event event) => Sfx.i.unlock();
  final handler = onEvent.toJS;
  final options = web.AddEventListenerOptions(passive: true, capture: true);
  for (final type in _kFirstGestureEvents) {
    web.window.addEventListener(type, handler, options);
  }

  void onVisibilityChange(web.Event event) {
    if (!web.document.hidden) Sfx.i.recoverAfterForeground();
  }

  web.document.addEventListener('visibilitychange', onVisibilityChange.toJS);
}
