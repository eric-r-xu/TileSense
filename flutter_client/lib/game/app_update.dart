/// "Get the latest version" for the web build. `app_update_web.dart` has the
/// real implementation; `app_update_stub.dart` is an inert fallback for
/// Android / iOS builds and the VM, where the button is never shown (store
/// builds update through the stores).
///
/// Nothing in the web bundle is content-hashed, and a home-screen / installed
/// app has no reload button, so the welcome screen offers one. To tell "you
/// are behind" from "you are current" the build stamps itself: deploys pass
/// `--dart-define=BUILD_ID=<id>` and publish the same id in `build_id.json`
/// next to `index.html` (see DEPLOYMENT.md). Without a build id the check is
/// inconclusive and the button simply refreshes.
library;

import 'app_update_stub.dart' if (dart.library.js_interop) 'app_update_web.dart'
    as platform;

/// The id this bundle was built with; empty for dev builds and deploys that
/// don't stamp one.
const String kBuildId = String.fromEnvironment('BUILD_ID');

enum UpdateStatus {
  /// The server is serving the build that is running.
  upToDate,

  /// The server has a different build.
  updateAvailable,

  /// No build id to compare, or the server's could not be read.
  unknown,
}

/// Pure comparison, split out so it can be tested without a browser.
UpdateStatus compareBuildIds(String running, String? server) {
  if (running.isEmpty || server == null || server.isEmpty) {
    return UpdateStatus.unknown;
  }
  return running == server
      ? UpdateStatus.upToDate
      : UpdateStatus.updateAvailable;
}

/// Whether to offer the button at all: web only.
bool get updateButtonVisible => platform.updateSupported;

/// Asks the server which build it is serving, bypassing every cache.
Future<UpdateStatus> checkForUpdate() async =>
    compareBuildIds(kBuildId, await platform.fetchServerBuildId());

/// Drops service workers and cached copies, re-downloads the app shell and
/// media, then reloads the page. Does not return on web.
Future<void> applyUpdate() => platform.reloadWithFreshFiles();
