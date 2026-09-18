import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// True when the page is already running as an installed web app (or in
/// fullscreen display mode) — there is no browser chrome left to hide, so the
/// button is not offered.
bool get _isStandalone {
  try {
    if (web.window.matchMedia('(display-mode: standalone)').matches ||
        web.window.matchMedia('(display-mode: fullscreen)').matches) {
      return true;
    }
    // iOS Safari's home-screen apps only expose this legacy flag.
    return (web.window.navigator as JSObject)['standalone'] == true.toJS;
  } catch (_) {
    return false;
  }
}

bool get fullscreenButtonVisible => !_isStandalone;

/// iPhone Safari has no Fullscreen API for arbitrary elements; iPad Safari and
/// every desktop / Android browser do.
bool get canFullscreen {
  try {
    final root = web.document.documentElement;
    return root != null && (root as JSObject).has('requestFullscreen');
  } catch (_) {
    return false;
  }
}

bool get isFullscreen {
  try {
    return web.document.fullscreenElement != null;
  } catch (_) {
    return false;
  }
}

Future<void> toggleFullscreen() async {
  try {
    if (isFullscreen) {
      await web.document.exitFullscreen().toDart;
    } else {
      await web.document.documentElement!.requestFullscreen().toDart;
    }
  } catch (_) {
    // Denied (no user activation, or blocked by policy) — stay as we are.
  }
}

void Function() listenFullscreenChange(void Function() onChange) {
  void handler(web.Event _) => onChange();
  final js = handler.toJS;
  web.document.addEventListener('fullscreenchange', js);
  return () => web.document.removeEventListener('fullscreenchange', js);
}
