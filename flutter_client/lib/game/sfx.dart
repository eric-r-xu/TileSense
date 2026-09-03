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

/// Fire-and-forget sound player. Browsers block audio until the first user
/// gesture, so the first tap in the app is what "enables" sound; every call is
/// wrapped in try/catch so a blocked context never breaks play. Voice lines get
/// their own player so they can overlap the generic blips.
class Sfx {
  Sfx._();
  static final Sfx i = Sfx._();

  final AudioPlayer _player = AudioPlayer(playerId: 'tilesense-sfx')
    ..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _voice = AudioPlayer(playerId: 'tilesense-voice')
    ..setReleaseMode(ReleaseMode.stop);

  bool enabled = true;

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

  StreamSubscription<void>? _chainSub;

  void play(SfxKind kind) => _fire(_player, _asset[kind],
      volume: kind == SfxKind.discard ? 0.35 : 0.7);

  void voice(VoiceKind kind, {Character character = Character.orderic}) {
    _chainSub?.cancel();
    _fire(_voice, _voiceAsset[character]?[kind], volume: 0.9);
  }

  /// Play a sequence of lines back to back on the voice channel, each with its
  /// own speaker — e.g. a mangan+ ron is the winner's "ron" then "yeah", then
  /// the discarder's resigned acknowledgement.
  void voiceChain(List<(Character, VoiceKind)> steps) {
    if (!enabled || steps.isEmpty) return;
    _chainSub?.cancel();
    final paths = [
      for (final (character, k) in steps)
        if (_voiceAsset[character]?[k] != null) _voiceAsset[character]![k]!,
    ];
    if (paths.isEmpty) return;
    var idx = 0;
    void next() {
      if (idx >= paths.length) {
        _chainSub?.cancel();
        _chainSub = null;
        return;
      }
      final path = paths[idx++];
      () async {
        try {
          await _voice.stop();
          await _voice.play(AssetSource(path), volume: 0.9);
        } catch (e) {
          if (kDebugMode) debugPrint('Sfx($path) failed: $e');
        }
      }();
    }

    _chainSub = _voice.onPlayerComplete.listen((_) => next());
    next();
  }

  void _fire(AudioPlayer player, String? path, {required double volume}) {
    if (!enabled || path == null) return;
    () async {
      try {
        await player.stop();
        await player.play(AssetSource(path), volume: volume);
      } catch (e) {
        if (kDebugMode) debugPrint('Sfx($path) failed: $e');
      }
    }();
  }

  void dispose() {
    _chainSub?.cancel();
    _player.dispose();
    _voice.dispose();
  }
}
