/// Native builds are already full screen; there is nothing to offer.
bool get fullscreenButtonVisible => false;

/// Whether the browser can enter fullscreen from a page at all.
bool get canFullscreen => false;

bool get isFullscreen => false;

Future<void> toggleFullscreen() async {}

/// Calls [onChange] when fullscreen is entered or left. Returns a disposer.
void Function() listenFullscreenChange(void Function() onChange) => () {};
