import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_backend.dart';

/// Generic UI blips (`click` / `hint` / `score_count`), played for every seat.
enum SfxKind { riichi, chi, pon, kan, ron, tsumo, discard }

/// A spoken line. Each seat's character has its own recording of every kind
/// (falling back to silence where a character is missing that line).
enum VoiceKind { chi, pon, kan, riichi, ron, tsumo, yeah, acquiescement, win }

/// The four table personalities — one per seat (0 = the human, Orderic).
enum Character { orderic, grant, hubert, astaroth }

/// Fire-and-forget sound player.
///
/// Browsers use a dedicated Web Audio backend with one shared `AudioContext`;
/// native apps retain the existing two-channel `audioplayers` implementation.
/// The voice channel is serial on both so one line completes (or reaches its
/// watchdog) before the next begins.
class Sfx {
  Sfx._();
  static final Sfx i = Sfx._();

  final AudioBackend _audio = AudioBackend();

  bool enabled = true;

  /// Test seam: when set, every line the game asks for is recorded here. The
  /// audio stack has no plugin under a test binding, so this is the only way
  /// to assert that a call actually voices.
  @visibleForTesting
  static List<(Character, VoiceKind)>? debugVoiceLog;

  /// Test seam: the clip a character uses for a line, or null if it has none.
  @visibleForTesting
  static String? debugAssetFor(Character character, VoiceKind kind) =>
      _voiceAsset[character]?[kind];

  static const Map<SfxKind, String> _asset = {
    SfxKind.riichi: 'sfx/hint.wav',
    SfxKind.chi: 'sfx/click.wav',
    SfxKind.pon: 'sfx/click.wav',
    SfxKind.kan: 'sfx/click.wav',
    SfxKind.ron: 'sfx/score_count.wav',
    SfxKind.tsumo: 'sfx/score_count.wav',
    SfxKind.discard: 'sfx/click.wav',
  };

  /// Per-character voice assets. `null` means that character has no recording
  /// for that line, so it is silently skipped.
  static const Map<Character, Map<VoiceKind, String?>> _voiceAsset = {
    Character.orderic: {
      VoiceKind.chi: 'orderic/Orderic_Chi.wav',
      VoiceKind.pon: 'orderic/Orderic_Pon.wav',
      VoiceKind.kan: 'orderic/Orderic_Kan.wav',
      VoiceKind.riichi: 'orderic/Orderic_Riichi.wav',
      VoiceKind.ron: 'orderic/Orderic_ron.wav',
      VoiceKind.tsumo: 'orderic/Orderic_Tsumo.wav',
      VoiceKind.yeah: 'orderic/Orderic_Yeah.wav',
      VoiceKind.acquiescement: 'orderic/Orderic_Acquiescement.wav',
      VoiceKind.win: 'orderic/Orderic_Win.wav',
    },
    Character.grant: {
      VoiceKind.chi: 'grant/Grant_Chi.wav',
      VoiceKind.pon: 'grant/Grant_Pon.wav',
      VoiceKind.kan: 'grant/Grant_Kan.wav',
      VoiceKind.riichi: 'grant/Grant_Riichi.wav',
      VoiceKind.ron: 'grant/Grant_ron.wav',
      VoiceKind.tsumo: 'grant/Grant_Tsumo.wav',
      VoiceKind.yeah: 'grant/Grant_Yeah.wav',
      VoiceKind.acquiescement: 'grant/Grant_Acquiescement.wav',
      VoiceKind.win: 'grant/Grant_Win.wav',
    },
    Character.hubert: {
      VoiceKind.chi: 'hubert/Hubert_Chi.wav',
      VoiceKind.pon: 'hubert/Hubert_Pon.wav',
      VoiceKind.kan: 'hubert/Hubert_Kan.wav',
      VoiceKind.riichi: 'hubert/Hubert_Riichi.wav',
      VoiceKind.ron: 'hubert/Hubert_ron.wav',
      VoiceKind.tsumo: 'hubert/Hubert_Tsumo.wav',
      VoiceKind.yeah: 'hubert/Hubert_Yeah.wav',
      VoiceKind.acquiescement: 'hubert/Hubert_Acquiescement.wav',
      VoiceKind.win: 'hubert/Hubert_Win.wav',
    },
    // Astaroth's call lines are derived from his mood takes (see
    // tools/mkastaroth or the PR notes); yeah / acquiescement stay on the
    // originals.
    Character.astaroth: {
      VoiceKind.chi: 'astaroth/Astaroth_Chi.wav',
      VoiceKind.pon: 'astaroth/Astaroth_Pon.wav',
      VoiceKind.kan: 'astaroth/Astaroth_Kan.wav',
      VoiceKind.riichi: 'astaroth/Astaroth_Riichi.wav',
      VoiceKind.ron: 'astaroth/Astaroth_ron.wav',
      VoiceKind.tsumo: 'astaroth/Astaroth_Tsumo.wav',
      VoiceKind.yeah: 'astaroth/Astaroth_Yeah.wav',
      VoiceKind.acquiescement: 'astaroth/Astaroth_Acquiescement.wav',
      VoiceKind.win: 'astaroth/Astaroth_Win.wav',
    },
  };

  // --- autoplay unlock ---------------------------------------------------

  /// Resume browser audio directly from a native user gesture. This is a no-op
  /// in the native backend and is safe to repeat if a browser re-suspends.
  void unlock() => _audio.unlock();

  // --- preloading --------------------------------------------------------

  /// Every clip the game can actually play, blips first.
  static Iterable<String> get _allClips sync* {
    yield* {..._asset.values};
    for (final lines in _voiceAsset.values) {
      for (final path in lines.values) {
        if (path != null) yield path;
      }
    }
  }

  /// Start fetching and decoding every browser clip. Native assets are already
  /// local, so the native backend returns immediately.
  Future<void> preload() => _audio.preload(_allClips);

  // --- blips -----------------------------------------------------------

  void play(SfxKind kind) =>
      _fire(_asset[kind], volume: kind == SfxKind.discard ? 0.35 : 0.7);

  void _fire(String? path, {required double volume}) {
    if (!enabled || path == null) return;
    // ignore: discarded_futures
    _audio.playEffect(path, volume: volume).catchError((e) {
      if (kDebugMode) debugPrint('Sfx($path) failed: $e');
    });
  }

  // --- voice queue ---------------------------------------------------

  /// Lines waiting to be spoken. Kept short: if lines are requested faster than
  /// they play we drop the stalest pending ones rather than fall further behind.
  final List<String> _voiceQueue = [];
  static const int _maxVoiceQueue = 4;

  bool _voiceBusy = false;

  /// Bumped every time a line starts, so a stale `onPlayerComplete` or watchdog
  /// from a previous line can't advance the queue twice.
  int _voiceGen = 0;
  Timer? _voiceWatchdog;

  void voice(VoiceKind kind, {Character character = Character.orderic}) {
    debugVoiceLog?.add((character, kind));
    final path = _voiceAsset[character]?[kind];
    if (path != null) _enqueueVoice([path]);
  }

  /// Speak several lines back to back on the voice channel, each with its own
  /// speaker — e.g. a mangan+ ron is the winner's "ron" then "yeah", then the
  /// discarder's resigned acknowledgement. Queued as one unit after anything
  /// already pending.
  void voiceChain(List<(Character, VoiceKind)> steps) {
    debugVoiceLog?.addAll(steps);
    final paths = [
      for (final (character, k) in steps)
        if (_voiceAsset[character]?[k] != null) _voiceAsset[character]![k]!,
    ];
    if (paths.isNotEmpty) _enqueueVoice(paths);
  }

  void _enqueueVoice(List<String> paths) {
    if (!enabled) return;
    _voiceQueue.addAll(paths);
    if (_voiceQueue.length > _maxVoiceQueue) {
      _voiceQueue.removeRange(0, _voiceQueue.length - _maxVoiceQueue);
    }
    if (!_voiceBusy) _pumpVoice();
  }

  void _pumpVoice() {
    if (_voiceBusy || _voiceQueue.isEmpty) return;
    final path = _voiceQueue.removeAt(0);
    _voiceBusy = true;
    final gen = ++_voiceGen;

    _voiceWatchdog?.cancel();
    _voiceWatchdog = null;

    // ignore: discarded_futures
    _audio
        .startVoice(
      path,
      volume: 0.9,
      onEnded: () => _stepDone(gen),
    )
        .then((_) {
      if (gen != _voiceGen) return;
      // Safety net, armed only once playback is actually under way. A failure
      // to start takes the catchError path instead and needs no timer.
      _voiceWatchdog?.cancel();
      _voiceWatchdog = Timer(const Duration(seconds: 8), () => _stepDone(gen));
    }).catchError((e) {
      if (kDebugMode) debugPrint('Sfx($path) failed: $e');
      _stepDone(gen);
    });
  }

  void _stepDone(int gen) {
    if (gen != _voiceGen) return; // superseded
    _voiceWatchdog?.cancel();
    _voiceWatchdog = null;
    _voiceBusy = false;
    _pumpVoice();
  }

  void dispose() {
    _voiceWatchdog?.cancel();
    _voiceQueue.clear();
    // ignore: discarded_futures
    _audio.dispose();
  }
}
