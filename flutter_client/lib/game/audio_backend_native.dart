import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// The native audio implementation.
///
/// This deliberately keeps TileSense's established two-channel
/// `audioplayers` setup on Android, iOS, macOS, Windows, and Linux. Only the
class AudioBackend {
  AudioBackend();

  AudioPlayer? _effectsPlayer;
  AudioPlayer? _voicePlayer;
  AudioPlayer get _effects =>
      _effectsPlayer ??= AudioPlayer(playerId: 'tilesense-sfx')
        ..setReleaseMode(ReleaseMode.stop);
  AudioPlayer get _voice =>
      _voicePlayer ??= AudioPlayer(playerId: 'tilesense-voice')
        ..setReleaseMode(ReleaseMode.stop);
  StreamSubscription<void>? _voiceCompleteSub;

  /// Browser-only cache warming; packaged native assets need no preparation.
  Future<void> preload(Iterable<String> paths) async {}

  /// Native apps are not subject to browser autoplay policy.
  void unlock() {}

  /// Browser-only recovery hook; native audio lifecycle is unchanged.
  void recoverAfterForeground() {}

  Future<void> playEffect(String path, {required double volume}) =>
      _effects.play(AssetSource(path), volume: volume);

  Future<void> startVoice(
    String path, {
    required double volume,
    required void Function() onEnded,
  }) async {
    await _voiceCompleteSub?.cancel();
    _voiceCompleteSub = _voice.onPlayerComplete.listen((_) {
      final subscription = _voiceCompleteSub;
      _voiceCompleteSub = null;
      // ignore: discarded_futures
      subscription?.cancel();
      onEnded();
    });
    await _voice.play(AssetSource(path), volume: volume);
  }

  Future<void> dispose() async {
    await _voiceCompleteSub?.cancel();
    await Future.wait([
      if (_effectsPlayer != null) _effectsPlayer!.dispose(),
      if (_voicePlayer != null) _voicePlayer!.dispose(),
    ]);
  }
}
