import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get updateSupported => true;

/// Media the host lets browsers reuse for a day (see
/// `flutter_client/DEPLOYMENT.md`). A plain
/// reload would keep serving a changed voice line or tile from that cache.
final _mediaKey =
    RegExp(r'assets/[\x20-\x7e]+?\.(?:wav|png|jpe?g|webp|ttf|otf)');

Future<web.Response> _fetch(String url, String cache) =>
    web.window.fetch(url.toJS, web.RequestInit(cache: cache)).toDart;

/// The id in `build_id.json`, or null when it is missing or unreadable. The
/// host's SPA fallback answers a missing file with `index.html` and a 200, so
/// the body is parsed rather than trusted.
Future<String?> fetchServerBuildId() async {
  try {
    final res = await _fetch(
        '${const String.fromEnvironment('UPDATE_BASE_HREF')}build_id.json?t=${DateTime.now().millisecondsSinceEpoch}',
        'no-store');
    if (!res.ok) return null;
    final body = jsonDecode((await res.text().toDart).toDart);
    final id = body is Map ? body['build_id'] : null;
    return id is String ? id : null;
  } catch (_) {
    return null;
  }
}

Future<void> reloadWithFreshFiles() async {
  try {
    await _dropWorkersAndCaches();
    await _refetch().timeout(const Duration(seconds: 25));
  } catch (_) {
    // Best effort: a failed or slow refresh should still end in a reload.
  }
  web.window.location.reload();
}

Future<void> _dropWorkersAndCaches() async {
  try {
    final regs =
        (await web.window.navigator.serviceWorker.getRegistrations().toDart)
            .toDart;
    for (final r in regs) {
      await r.unregister().toDart;
    }
  } catch (_) {}
  try {
    final names = (await web.window.caches.keys().toDart).toDart;
    for (final n in names) {
      await web.window.caches.delete(n.toDart).toDart;
    }
  } catch (_) {}
}

/// `cache: 'reload'` skips the HTTP cache on the way in and overwrites the
/// entry on the way out, so the reload that follows reads the new bytes.
Future<void> _refetch() async {
  const shell = [
    'index.html',
    'flutter_bootstrap.js',
    'main.dart.js',
    'manifest.json',
    'version.json',
    'assets/AssetManifest.bin.json',
  ];
  final urls = <String>[...shell, ...await _mediaUrls()];
  const batch = 8;
  for (var i = 0; i < urls.length; i += batch) {
    await Future.wait(urls.skip(i).take(batch).map((u) async {
      try {
        await _fetch(u, 'reload');
      } catch (_) {}
    }));
  }
}

/// The bundled media, read out of Flutter's asset manifest. It is a base64
/// string of a binary blob; the asset keys sit in it as plain strings, and the
/// files are served under `assets/` + key.
Future<List<String>> _mediaUrls() async {
  try {
    final res = await _fetch('assets/AssetManifest.bin.json', 'reload');
    final b64 = jsonDecode((await res.text().toDart).toDart) as String;
    final blob = latin1.decode(base64Decode(b64), allowInvalid: true);
    return {for (final m in _mediaKey.allMatches(blob)) 'assets/${m.group(0)}'}
        .map(Uri.encodeFull)
        .toList();
  } catch (_) {
    return const [];
  }
}
