import 'package:web/web.dart' as web;

/// True when the browser reports more than one touch point. Real Macs report
/// 0, so on a "macOS" user agent this separates an iPad (whose Safari pretends
/// to be a Mac) from an actual desktop.
bool get hasMultiTouch {
  try {
    return web.window.navigator.maxTouchPoints > 1;
  } catch (_) {
    return false;
  }
}
