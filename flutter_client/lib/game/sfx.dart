import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Generic UI blips (from the Vala build's `click` / `hint` / `score_count`),
/// played for every seat.
enum SfxKind { riichi, chi, pon, kan, ron, tsumo, discard }

/// Orderic voice lines — only played for the human seat's own actions.
enum VoiceKind { chi, pon, kan, riichi, ron, tsumo, yeah }

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

  static const Map<VoiceKind, String> _voiceAsset = {
    VoiceKind.chi: 'orderic/Orderic_Chi.wav',
    VoiceKind.pon: 'orderic/Orderic_Pon.wav',
    VoiceKind.kan: 'orderic/Orderic_Kan.wav',
    VoiceKind.riichi: 'orderic/Orderic_Riichi.wav',
    VoiceKind.ron: 'orderic/Orderic_ron.wav',
    VoiceKind.tsumo: 'orderic/Orderic_Tsumo.wav',
    VoiceKind.yeah: 'orderic/Orderic_Yeah.wav',
  };

  void play(SfxKind kind) => _fire(_player, _asset[kind],
      volume: kind == SfxKind.discard ? 0.35 : 0.7);

  void voice(VoiceKind kind) => _fire(_voice, _voiceAsset[kind], volume: 0.9);

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
    _player.dispose();
    _voice.dispose();
  }
}
