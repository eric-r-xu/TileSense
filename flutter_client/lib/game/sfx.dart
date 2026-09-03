import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The call / win events that get a sound effect. The TileSense Vala build ships
/// only generic UI sounds (`click`, `hint`, `score_count`), so those are reused
/// here: `hint` for a riichi declaration, `click` for a call (pon / kan / chi),
/// and `score_count` for a win (ron / tsumo).
enum SfxKind { riichi, pon, kan, chi, ron, tsumo }

/// Fire-and-forget sound-effect player. All playback is wrapped in try/catch so
/// a blocked autoplay policy (web, before the first user gesture) or a missing
/// asset never breaks the game loop.
class Sfx {
  Sfx._();
  static final Sfx i = Sfx._();

  final AudioPlayer _player = AudioPlayer(playerId: 'tilesense-sfx')
    ..setReleaseMode(ReleaseMode.stop);

  bool enabled = true;

  static const Map<SfxKind, String> _asset = {
    SfxKind.riichi: 'sfx/hint.wav',
    SfxKind.pon: 'sfx/click.wav',
    SfxKind.kan: 'sfx/click.wav',
    SfxKind.chi: 'sfx/click.wav',
    SfxKind.ron: 'sfx/score_count.wav',
    SfxKind.tsumo: 'sfx/score_count.wav',
  };

  void play(SfxKind kind) {
    if (!enabled) return;
    final path = _asset[kind];
    if (path == null) return;
    () async {
      try {
        await _player.stop();
        await _player.play(AssetSource(path), volume: 0.7);
      } catch (e) {
        if (kDebugMode) debugPrint('Sfx($kind) failed: $e');
      }
    }();
  }

  void dispose() => _player.dispose();
}
