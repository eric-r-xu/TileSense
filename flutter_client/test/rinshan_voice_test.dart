import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';


void main() {
  HandScore score(List<String> yaku) => HandScore(
        yaku: [for (final name in yaku) YakuResult(name, 1)],
        han: yaku.length,
        fu: 30,
        yakuman: 0,
        points: 1000,
        dealerPays: 0,
        nonDealerPays: 1000,
        limitName: '',
        valid: true,
      );

  RoundResult tsumo(List<String> yaku) => RoundResult(
        kind: RoundEndKind.tsumo,
        winners: const [0],
        pointDeltas: const {},
        label: '',
        scores: [score(yaku)],
      );

  List<(Character, VoiceKind)> voiced(RoundResult res, Ruleset ruleset) {
    Sfx.i.enabled = false;
    final log = <(Character, VoiceKind)>[];
    Sfx.debugVoiceLog = log;
    try {
      OnlineGameController.playRoundEndVoice(
          res, ruleset, (_) => Character.saeko);
    } finally {
      Sfx.debugVoiceLog = null;
      Sfx.i.enabled = true;
    }
    return log;
  }

  testWidgets('a plain tsumo is just "Tsumo"', (tester) async {
    expect(voiced(tsumo(['Menzen Tsumo', 'Riichi']), Ruleset.riichi),
        [(Character.saeko, VoiceKind.tsumo)]);
  });

  testWidgets('a rinshan kaihou tsumo gets her signature line',
      (tester) async {
    expect(voiced(tsumo(['Menzen Tsumo', 'Rinshan Kaihou']), Ruleset.riichi),
        [(Character.saeko, VoiceKind.rinshan)]);
    expect(
        voiced(tsumo(['Win by Kong Replacement']), Ruleset.hongKong),
        [(Character.saeko, VoiceKind.rinshan)]);
  });

  testWidgets('the rinshan line is only Saeko\'s; others use their tsumo',
      (tester) async {
    expect(Sfx.debugAssetFor(Character.saeko, VoiceKind.tsumo),
        'saeko/Saeko_Tsumo.wav');
    expect(Sfx.debugAssetFor(Character.saeko, VoiceKind.rinshan),
        'saeko/Saeko_Rinshan.wav');
    expect(Sfx.debugAssetFor(Character.grant, VoiceKind.rinshan),
        'grant/Grant_Tsumo.wav');
  });
}
