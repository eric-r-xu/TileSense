import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'sfx.dart';

/// Event types likely to be the very first thing a player does on the page.
const _kFirstGestureEvents = ['pointerdown', 'touchend', 'keydown', 'mousedown'];

/// Hooks native pointer/touch/key events directly via the DOM — entirely
/// outside Flutter's widget tree and gesture system — to prime `Sfx`'s audio
/// players (see `Sfx.unlock` and the class doc on `Sfx`).
///
/// A Flutter `Listener`/`GestureDetector` callback only fires after Flutter's
/// own pointer-event pipeline has already processed the native browser event;
/// on strict mobile browsers that extra hop alone can be enough for the
/// eventual `AudioContext.resume()` call to no longer be treated as tied to
/// the user's gesture. Calling straight into `Sfx.unlock()` from a listener
/// attached directly to `window` avoids that hop entirely. The listener is
/// never removed — `Sfx.unlock()` itself is cheap and keeps trying on every
/// gesture, since one success isn't a lasting guarantee (mobile Safari can
/// need more than one attempt, and a context can be re-suspended later).
void armFirstGestureUnlock() {
  void onEvent(web.Event event) => Sfx.i.unlock();
  final handler = onEvent.toJS;
  final options = web.AddEventListenerOptions(passive: true);
  for (final type in _kFirstGestureEvents) {
    web.window.addEventListener(type, handler, options);
  }
}
