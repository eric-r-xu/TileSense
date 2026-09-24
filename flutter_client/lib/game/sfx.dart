import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_backend.dart';

/// Generic UI blips (`click` / `hint` / `score_count`), played for every seat.
enum SfxKind { riichi, chi, pon, kan, ron, tsumo, discard }

/// A spoken line. Each seat's character has its own recording of every kind
/// (falling back to silence where a character is missing that line).
///
/// [rinshan] is a tsumo on a kong's replacement tile (see [tsumoLineFor]).
/// Only characters with a signature line for it record one; everyone else
/// falls back to their plain [tsumo].
enum VoiceKind {
  chi,
  pon,
  kan,
  riichi,
  ron,
  tsumo,
  rinshan,
  yeah,
  acquiescement,
  win
}

/// The yaku that mark a win on a kong's replacement tile, riichi and
/// Hong Kong spellings.
const Set<String> _kongReplacementYaku = {
  'Rinshan Kaihou',
  'Win by Kong Replacement',
  'Double Kong Replacement',
};

/// The self-draw line for a tsumo whose hand scored [yakuNames]:
/// [VoiceKind.rinshan] when it won on a kong's replacement tile, otherwise
/// the plain [VoiceKind.tsumo].
VoiceKind tsumoLineFor(Iterable<String> yakuNames) =>
    yakuNames.any(_kongReplacementYaku.contains)
        ? VoiceKind.rinshan
        : VoiceKind.tsumo;

/// The table personalities. Offline, every seat's persona is
/// customisable (`kSeatCharacters` in game_controller.dart is the default,
/// human seat included); online, a human picks their own from
/// [kSelectableCharacters] on the lobby screen and the server assigns
/// whatever's left to bot-filled seats — see `Room.resolveCharacter` on the
/// multiplayer server, whose spellings (`.name` here) this enum must
/// keep matching.
enum Character {
  eric,
  orderic,
  grant,
  hubert,
  astaroth,
  erika,
  melissa,
  matityahu,
  sherman,
  saeko
}

/// The personas a human can pick from online. `resolveCharacter`
/// falls back to any unclaimed character in the full pool for a
/// bot-filled seat regardless of this list, so nothing needs holding back
/// here for that. Order is display order on the picker.
const List<Character> kSelectableCharacters = [
  Character.eric,
  Character.orderic,
  Character.astaroth,
  Character.grant,
  Character.hubert,
  Character.erika,
  Character.melissa,
  Character.matityahu,
  Character.sherman,
  Character.saeko,
];

const Map<Character, String> kCharacterName = {
  Character.eric: 'Eric',
  Character.orderic: 'Orderic',
  Character.grant: 'Grant',
  Character.hubert: 'Hubert',
  Character.astaroth: 'Astaroth',
  Character.erika: 'Erika',
  Character.melissa: 'Melissa',
  Character.matityahu: 'Matityahu',
  Character.sherman: 'Sherman',
  Character.saeko: 'Saeko',
};

const Map<Character, String> kCharacterPortrait = {
  Character.eric: 'assets/eric/eric.png',
  Character.orderic: 'assets/orderic/orderic.png',
  Character.grant: 'assets/grant/grant.png',
  Character.hubert: 'assets/hubert/hubert.png',
  Character.astaroth: 'assets/astaroth/astaroth.png',
  Character.erika: 'assets/erika/erika.png',
  Character.melissa: 'assets/melissa/melissa.png',
  Character.matityahu: 'assets/matityahu/matityahu.png',
  Character.sherman: 'assets/sherman/sherman.png',
  Character.saeko: 'assets/saeko/saeko.png',
};

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

  /// On by default; the character-select screen's Sound checkbox and the
  /// toggle in `ui/hand_view.dart` (both via `GameController.setSoundOn`) turn
  /// it off. Browsers keep the audio context locked until the first gesture
  /// (see `armFirstGestureUnlock`), so nothing plays before the player has
  /// tapped something regardless of this flag.
  bool enabled = true;

  /// Test seam: when set, every line the game asks for is recorded here. The
  /// audio stack has no plugin under a test binding, so this is the only way
  /// to assert that a call actually voices.
  @visibleForTesting
  static List<(Character, VoiceKind)>? debugVoiceLog;

  /// Test seam: the clip a character uses for a line, or null if it has none.
  @visibleForTesting
  static String? debugAssetFor(Character character, VoiceKind kind) =>
      _voicePath(character, kind);

  static String? _voicePath(Character character, VoiceKind kind) {
    final lines = _voiceAsset[character];
    if (kind == VoiceKind.rinshan) {
      return lines?[VoiceKind.rinshan] ?? lines?[VoiceKind.tsumo];
    }
    return lines?[kind];
  }

  static const Map<SfxKind, String> _asset = {
    SfxKind.riichi: 'sfx/hint.wav',
    SfxKind.chi: 'sfx/click.wav',
    SfxKind.pon: 'sfx/click.wav',
    SfxKind.kan: 'sfx/click.wav',
    SfxKind.ron: 'sfx/score_count.wav',
    SfxKind.tsumo: 'sfx/score_count.wav',
    // A tile discard has no other action sound of its own — riichi, a call
    // or a kan all take priority over this one when a discard also declares
    // or completes one of those — so this is the plain tile-on-table clink.
    SfxKind.discard: 'TileClink.wav',
  };

  /// Per-character voice assets. `null` means that character has no recording
  /// for that line, so it is silently skipped.
  static const Map<Character, Map<VoiceKind, String?>> _voiceAsset = {
    Character.sherman: {
      VoiceKind.chi: 'sherman/Sherman_Chi.wav',
      VoiceKind.pon: 'sherman/Sherman_Pon.wav',
      VoiceKind.kan: 'sherman/Sherman_Kan.wav',
      VoiceKind.riichi: 'sherman/Sherman_Riichi.wav',
      VoiceKind.ron: 'sherman/Sherman_ron.wav',
      VoiceKind.tsumo: 'sherman/Sherman_Tsumo.wav',
      VoiceKind.yeah: 'sherman/Sherman_Yeah.wav',
      VoiceKind.acquiescement: 'sherman/Sherman_Acquiescement.wav',
      VoiceKind.win: 'sherman/Sherman_Win.wav',
    },
    Character.matityahu: {
      VoiceKind.chi: 'matityahu/Matityahu_Chi.wav',
      VoiceKind.pon: 'matityahu/Matityahu_Pon.wav',
      VoiceKind.kan: 'matityahu/Matityahu_Kan.wav',
      VoiceKind.riichi: 'matityahu/Matityahu_Riichi.wav',
      VoiceKind.ron: 'matityahu/Matityahu_ron.wav',
      VoiceKind.tsumo: 'matityahu/Matityahu_Tsumo.wav',
      VoiceKind.yeah: 'matityahu/Matityahu_Yeah.wav',
      VoiceKind.acquiescement: 'matityahu/Matityahu_Acquiescement.wav',
      VoiceKind.win: 'matityahu/Matityahu_Win.wav',
    },
    Character.eric: {
      VoiceKind.chi: 'eric/Eric_Chi.wav',
      VoiceKind.pon: 'eric/Eric_Pon.wav',
      VoiceKind.kan: 'eric/Eric_Kan.wav',
      VoiceKind.riichi: 'eric/Eric_Riichi.wav',
      VoiceKind.ron: 'eric/Eric_ron.wav',
      VoiceKind.tsumo: 'eric/Eric_Tsumo.wav',
      VoiceKind.yeah: 'eric/Eric_Yeah.wav',
      VoiceKind.acquiescement: 'eric/Eric_Acquiescement.wav',
      VoiceKind.win: 'eric/Eric_Win.wav',
    },
    Character.erika: {
      VoiceKind.chi: 'erika/Erika_Chi.wav',
      VoiceKind.pon: 'erika/Erika_Pon.wav',
      VoiceKind.kan: 'erika/Erika_Kan.wav',
      VoiceKind.riichi: 'erika/Erika_Riichi.wav',
      VoiceKind.ron: 'erika/Erika_ron.wav',
      VoiceKind.tsumo: 'erika/Erika_Tsumo.wav',
      VoiceKind.yeah: 'erika/Erika_Yeah.wav',
      VoiceKind.acquiescement: 'erika/Erika_Acquiescement.wav',
      VoiceKind.win: 'erika/Erika_Win.wav',
    },
    Character.melissa: {
      VoiceKind.chi: 'melissa/Melissa_Chi.wav',
      VoiceKind.pon: 'melissa/Melissa_Pon.wav',
      VoiceKind.kan: 'melissa/Melissa_Kan.wav',
      VoiceKind.riichi: 'melissa/Melissa_Riichi.wav',
      VoiceKind.ron: 'melissa/Melissa_ron.wav',
      VoiceKind.tsumo: 'melissa/Melissa_Tsumo.wav',
      VoiceKind.yeah: 'melissa/Melissa_Yeah.wav',
      VoiceKind.acquiescement: 'melissa/Melissa_Acquiescement.wav',
      VoiceKind.win: 'melissa/Melissa_Win.wav',
    },
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
    // Saeko is modelled on Saki Miyanaga; her lines from the anime, in
    // Japanese (tools/mksaeko.py): her signature "Tsumo. Rinshan kaihou." only on an actual win off a
    // kong's replacement tile, and "Mahjong is fun!" for a match win.
    Character.saeko: {
      VoiceKind.chi: 'saeko/Saeko_Chi.wav',
      VoiceKind.pon: 'saeko/Saeko_Pon.wav',
      VoiceKind.kan: 'saeko/Saeko_Kan.wav',
      VoiceKind.riichi: 'saeko/Saeko_Riichi.wav',
      VoiceKind.ron: 'saeko/Saeko_ron.wav',
      VoiceKind.tsumo: 'saeko/Saeko_Tsumo.wav',
      VoiceKind.rinshan: 'saeko/Saeko_Rinshan.wav',
      VoiceKind.yeah: 'saeko/Saeko_Yeah.wav',
      VoiceKind.acquiescement: 'saeko/Saeko_Acquiescement.wav',
      VoiceKind.win: 'saeko/Saeko_Win.wav',
    },
  };

  // --- autoplay unlock ---------------------------------------------------

  /// Resume browser audio directly from a native user gesture. This is a no-op
  /// in the native backend and is safe to repeat if a browser re-suspends.
  void unlock() => _audio.unlock();

  /// Recover browser audio after returning from a background tab/app. No-op on
  /// native platforms, whose lifecycle remains managed by `audioplayers`.
  void recoverAfterForeground() => _audio.recoverAfterForeground();

  // --- preloading --------------------------------------------------------

  /// Effects first, then only the characters needed at the current table.
  @visibleForTesting
  static Iterable<String> preloadPaths(Iterable<Character> characters) sync* {
    yield* {..._asset.values};
    for (final character in characters.toSet()) {
      final lines = _voiceAsset[character] ?? const {};
      for (final path in lines.values) {
        if (path != null) yield path;
      }
    }
  }

  /// With no characters, warm only the four shared effects. Further calls
  /// add selected voices; playback can still fetch any uncached clip on demand.
  Future<void> preload({Iterable<Character> characters = const []}) =>
      _audio.preload(preloadPaths(characters));

  // --- blips -----------------------------------------------------------

  void play(SfxKind kind) =>
      _fire(_asset[kind], volume: kind == SfxKind.discard ? 0.35 : 0.7);

  void _fire(String? path, {required double volume}) {
    if (!enabled || path == null) return;
    // ignore: discarded_futures
    _audio.playEffect(path, volume: volume).catchError((e) {
      _warnPlaybackFailed('effect', path, e);
    });
  }

  /// Playback failures are non-fatal (missing plugin, blocked autoplay, decode
  /// error). Surfaced only in debug builds so a silent clip is diagnosable.
  static void _warnPlaybackFailed(String channel, String path, Object error) {
    if (kDebugMode) debugPrint('Sfx: $channel "$path" failed: $error');
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
    final path = _voicePath(character, kind);
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
        if (_voicePath(character, k) case final path?) path,
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
      _warnPlaybackFailed('voice', path, e);
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
