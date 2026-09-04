import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Generic UI blips (from the Vala build's `click` / `hint` / `score_count`),
/// played for every seat.
enum SfxKind { riichi, chi, pon, kan, ron, tsumo, discard }

/// A spoken line. Each seat's character has its own recording of every kind
/// (falling back to silence where a character is missing that line).
enum VoiceKind { chi, pon, kan, riichi, ron, tsumo, yeah, acquiescement, win }

/// The four table personalities — one per seat (0 = the human, Orderic).
enum Character { orderic, grant, hubert, astaroth }

/// Fire-and-forget sound player.
///
/// Two things browsers (Chrome on Android especially) get strict about:
///
///  * **Autoplay unlock is per media element, and only from a user gesture.**
///    The blip player gets unlocked by the first tap that plays a blip, but the
///    voice player is only ever driven by bot turns on timers — so without
///    priming it inside a real gesture, every spoken line is silently rejected.
///    [unlock] does that priming; call it from a root pointer-down listener.
///  * **`play()` rejects if a `pause()`/`stop()` interrupts it.** The voice
///    channel therefore runs a serial queue: one line plays to completion (or a
///    watchdog) before the next starts, so we never stop a line mid-`play()`.
class Sfx {
  Sfx._();
  static final Sfx i = Sfx._();

  final AudioPlayer _player = AudioPlayer(playerId: 'tilesense-sfx')
    ..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _voice = AudioPlayer(playerId: 'tilesense-voice')
    ..setReleaseMode(ReleaseMode.stop);

  bool enabled = true;

  /// A short existing clip, played muted, purely to unlock a media element.
  static const String _primeAsset = 'sfx/click.wav';

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
      VoiceKind.yeah: 'hubert/Hubert_YEAH.wav',
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

  bool _unlocked = false;

  /// Prime both players so the browser will let them play later. Must be called
  /// from within a real user gesture (e.g. a root `Listener.onPointerDown`);
  /// no-op after the first successful call and on non-web platforms, which
  /// don't gate audio this way.
  void unlock() {
    if (_unlocked) return;
    _unlocked = true;
    if (!kIsWeb) return;
    for (final p in [_player, _voice]) {
      try {
        // Start playback synchronously here — any `await` before `play()` drops
        // us out of the gesture and the browser rejects it. Muted so priming is
        // inaudible; stop as soon as it has started.
        // ignore: discarded_futures
        p.play(AssetSource(_primeAsset), volume: 0).then((_) {
          // ignore: discarded_futures
          p.stop();
        }).catchError((_) {});
      } catch (_) {
        // Priming failed; real plays below will still try on their own.
      }
    }
  }

  // --- blips -----------------------------------------------------------

  void play(SfxKind kind) => _fire(_asset[kind],
      volume: kind == SfxKind.discard ? 0.35 : 0.7);

  void _fire(String? path, {required double volume}) {
    if (!enabled || path == null) return;
    () async {
      try {
        await _player.stop();
        await _player.play(AssetSource(path), volume: volume);
      } catch (e) {
        if (kDebugMode) debugPrint('Sfx($path) failed: $e');
      }
    }();
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
  StreamSubscription<void>? _voiceCompleteSub;
  Timer? _voiceWatchdog;

  void voice(VoiceKind kind, {Character character = Character.orderic}) {
    final path = _voiceAsset[character]?[kind];
    if (path != null) _enqueueVoice([path]);
  }

  /// Speak several lines back to back on the voice channel, each with its own
  /// speaker — e.g. a mangan+ ron is the winner's "ron" then "yeah", then the
  /// discarder's resigned acknowledgement. Queued as one unit after anything
  /// already pending.
  void voiceChain(List<(Character, VoiceKind)> steps) {
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

    // The previous line has already completed by the time we get here, so this
    // stop() has no in-flight play() to interrupt — it just resets position.
    _voiceCompleteSub?.cancel();
    _voiceCompleteSub = _voice.onPlayerComplete.listen((_) => _stepDone(gen));

    // Safety net: on web `onPlayerComplete` can fail to fire if the element
    // errors out. Don't let the queue wedge.
    _voiceWatchdog?.cancel();
    _voiceWatchdog =
        Timer(const Duration(seconds: 8), () => _stepDone(gen));

    () async {
      try {
        await _voice.stop();
        await _voice.play(AssetSource(path), volume: 0.9);
      } catch (e) {
        if (kDebugMode) debugPrint('Sfx($path) failed: $e');
        _stepDone(gen);
      }
    }();
  }

  void _stepDone(int gen) {
    if (gen != _voiceGen) return; // superseded
    _voiceWatchdog?.cancel();
    _voiceWatchdog = null;
    _voiceCompleteSub?.cancel();
    _voiceCompleteSub = null;
    _voiceBusy = false;
    _pumpVoice();
  }

  void dispose() {
    _voiceWatchdog?.cancel();
    _voiceCompleteSub?.cancel();
    _voiceQueue.clear();
    _player.dispose();
    _voice.dispose();
  }
}
