import 'package:flutter/foundation.dart';

/// Test-only override for [playOnlineAvailable]; leave null in app code.
@visibleForTesting
bool? playOnlineOverride;

/// Whether Play Online is offered on this platform.
///
/// Online play exists on the web only. The iOS and Android store builds are
/// fully offline, which is what their privacy disclosures (and the missing
/// Android INTERNET permission) assume. Defaulting to [kIsWeb] means a native
/// build can never expose the button by forgetting a build flag.
bool get playOnlineAvailable => playOnlineOverride ?? kIsWeb;
