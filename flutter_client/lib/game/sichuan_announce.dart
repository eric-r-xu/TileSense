/// The bubble, chime and voice line for a Sichuan Hu. A Hu does not end the
/// hand there, so it is announced as it happens, by the single-player and the
/// online table alike.
library;

import 'package:mahjong_core/mahjong_core.dart';

import 'call_callout.dart';
import 'sfx.dart';

/// [who] is the character voicing the seat that went out, [hu.seat] being
/// the seat as the screen numbers it.
void announceSichuanHu(SichuanHu hu, Ruleset ruleset, Character who) {
  final line = hu.selfDrawn ? VoiceKind.tsumo : VoiceKind.ron;
  Sfx.i.play(hu.selfDrawn ? SfxKind.tsumo : SfxKind.ron);
  CallCallout.i.show(hu.seat, line.name);
  if (ruleset.isBigHand(hu.score)) {
    Sfx.i.voiceChain([(who, line), (who, VoiceKind.yeah)]);
  } else {
    Sfx.i.voice(line, character: who);
  }
}
