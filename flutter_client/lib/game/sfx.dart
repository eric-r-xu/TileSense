import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Generic UI blips (`click` / `hint` / `score_count`), played for every seat.
enum SfxKind { riichi, chi, pon, kan, ron, tsumo, discard }

/// A spoken line. Each seat's character has its own recording of every kind
/// (falling back to silence where a character is missing that line).
enum VoiceKind { chi, pon, kan, riichi, ron, tsumo, yeah, acquiescement, win }

/// The four table personalities — one per seat (0 = the human, Orderic).
enum Character { orderic, grant, hubert, astaroth }

/// Fire-and-forget sound player.
///
/// Mobile browsers (Safari and Chrome both, more strictly than desktop) gate
/// audio on a real user gesture in a few ways this works around:
///
///  * **Autoplay unlock is per player, and only from a user gesture.** Each of
///    `_player`/`_voice` plays through its own `AudioContext` (see
///    `audioplayers`' web backend), which starts suspended until resumed from
///    a gesture. [unlock] primes both — see `gesture_unlock.dart`, which calls
///    it from a raw native event listener rather than through Flutter's own
///    event pipeline, and keeps calling it on every gesture rather than just
///    the first (cheap — a muted, sub-second clip — and mobile Safari in
///    particular can need more than one attempt, or can re-suspend a context
///    later, e.g. after the tab is backgrounded).
///  * **Every extra `await` between the gesture and the actual native
///    `play()` call is a chance to no longer count as gesture-linked.** So
///    neither [play] nor [voice]/[voiceChain] call `stop()` before playing —
///    `AudioPlayer.play()` already restarts from the beginning on its own.
///  * **`play()` rejects if a `pause()`/`stop()` interrupts it.** The voice
///    channel therefore runs a serial queue: one line plays to completion (or a
///    watchdog) before the next starts, so nothing here stops a line
///    mid-`play()` (the only `stop()` calls left are [unlock]'s own priming,
///    each on a clip it just started itself).
class Sfx {
  Sfx._();
  static final Sfx i = Sfx._();

  final AudioPlayer _player = AudioPlayer(playerId: 'tilesense-sfx')
    ..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _voice = AudioPlayer(playerId: 'tilesense-voice')
    ..setReleaseMode(ReleaseMode.stop);

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

  /// Prime both players so the browser will let them play later. Best called
  /// from as close to a raw native pointer/touch/key event as possible — see
  /// `gesture_unlock.dart`, which hooks one before Flutter's own event
  /// pipeline even sees it, since that extra hop is enough for strict mobile
  /// browsers to no longer count a later call as gesture-linked.
  ///
  /// Deliberately *not* one-shot: kept cheap enough (a muted, sub-second clip,
  /// immediately stopped) to call on every single gesture for the life of the
  /// app, since a single successful unlock isn't a guarantee — mobile Safari
  /// in particular can need a couple of attempts, and any browser can
  /// re-suspend an `AudioContext` later (e.g. the tab being backgrounded and
  /// foregrounded). No-op on non-web platforms, which don't gate audio this
  /// way.
  void unlock() {
    if (!kIsWeb) return;
    // The first gesture is also the earliest point worth spending bandwidth on
    // the clips themselves.
    // ignore: discarded_futures
    preload();
    for (final p in [_player, _voice]) {
      try {
        // Play (muted) synchronously here, with no `await` before it - any
        // `await` first drops us out of the gesture and the browser rejects
        // the resume it would otherwise grant. The muted volume only silences
        // this priming clip; it doesn't change whether the browser treats the
        // call as gesture-linked (that's keyed off the element being muted,
        // which we never set — only its Web Audio gain, here 0).
        // ignore: discarded_futures
        p.play(AssetSource(_primeAsset), volume: 0).then((_) {
          // ignore: discarded_futures
          p.stop();
        }).catchError((_) {});
      } catch (_) {
        // Priming failed; the next gesture (or a real play) gets another shot.
      }
    }
  }

  // --- preloading --------------------------------------------------------

  bool _preloaded = false;

  /// Every clip the game can actually play, blips first.
  static Iterable<String> get _allClips sync* {
    yield* {..._asset.values};
    for (final lines in _voiceAsset.values) {
      for (final path in lines.values) {
        if (path != null) yield path;
      }
    }
  }

  /// Pull every clip through the browser's HTTP cache up front.
  ///
  /// `audioplayers` builds a fresh `<audio>` element every time the source URL
  /// changes — and for voice lines that is *every single line* — so without
  /// this each one is fetched at the exact moment it is needed, which is what
  /// shows up as lag before a call. Warming the cache moves that cost to
  /// start-up, where nothing is waiting on it. The bytes are evicted straight
  /// away so they are not also held in Dart memory.
  ///
  /// Web only: elsewhere the clips are already local.
  Future<void> preload() async {
    if (_preloaded || !kIsWeb) return;
    _preloaded = true;
    final keys = {for (final path in _allClips) 'assets/$path'}.toList();

    // A few at a time: one-at-a-time would serialise ~40 round trips on a
    // mobile connection, all at once would fight the rest of the page load.
    const batch = 6;
    for (var i = 0; i < keys.length; i += batch) {
      final slice = keys.skip(i).take(batch);
      await Future.wait([
        for (final key in slice)
          rootBundle.load(key).then((_) => rootBundle.evict(key)).catchError(
            (_) {
              // A clip that will not load just stays uncached; play() copes.
            },
          ),
      ]);
    }
  }

  // --- blips -----------------------------------------------------------

  void play(SfxKind kind) =>
      _fire(_asset[kind], volume: kind == SfxKind.discard ? 0.35 : 0.7);

  void _fire(String? path, {required double volume}) {
    if (!enabled || path == null) return;
    // No `stop()` first: `play()` already restarts from the beginning on its
    // own (see `AudioPlayer.play` -> `start`, which always resets position),
    // and skipping it means one fewer `await` between this call and the
    // browser's actual play — the fewer hops, the less chance a strict mobile
    // browser no longer considers it linked to whatever gesture triggered it.
    // ignore: discarded_futures
    _player.play(AssetSource(path), volume: volume).catchError((e) {
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
  StreamSubscription<void>? _voiceCompleteSub;
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

    _voiceCompleteSub?.cancel();
    _voiceCompleteSub = _voice.onPlayerComplete.listen((_) => _stepDone(gen));
    _voiceWatchdog?.cancel();
    _voiceWatchdog = null;

    // No `stop()` first — see `_fire`: `play()` restarts from the beginning
    // on its own, and this is the call most likely to be running right off
    // the back of a user gesture (a call/riichi line triggered by the human's
    // own tap), so it's the one where an extra `await` most matters.
    // ignore: discarded_futures
    _voice.play(AssetSource(path), volume: 0.9).then((_) {
      if (gen != _voiceGen) return;
      // Safety net, armed only once playback is actually under way: on web
      // `onPlayerComplete` can fail to fire if the element errors out
      // mid-clip, and the queue would wedge behind it. A play that fails
      // outright takes the catchError path instead and needs no timer.
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
