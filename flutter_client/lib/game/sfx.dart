import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Call / win events that get a sound effect. The TileSense Vala build ships
/// only generic UI sounds (`click`, `hint`, `score_count`), so those are reused:
/// `hint` for a riichi declaration, `click` for a call (chi / pon / kan), and
/// `score_count` for a win (ron / tsumo).
enum SfxKind { riichi, chi, pon, kan, ron, tsumo, discard }

/// Fire-and-forget sound-effect player. Browsers block audio until the first
/// user gesture, so the first tap in the app is what actually "enables" sound;
/// every call is wrapped in try/catch so a blocked context never breaks play.
class Sfx {
  Sfx._();
  static final Sfx i = Sfx._();

  final AudioPlayer _player = AudioPlayer(playerId: 'tilesense-sfx')
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

  void play(SfxKind kind) {
    if (!enabled) return;
    final path = _asset[kind];
    if (path == null) return;
    () async {
      try {
        await _player.stop();
        await _player.play(AssetSource(path),
            volume: kind == SfxKind.discard ? 0.35 : 0.7);
      } catch (e) {
        if (kDebugMode) debugPrint('Sfx($kind) failed: $e');
      }
    }();
  }

  void dispose() => _player.dispose();
}
