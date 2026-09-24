import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

/// Regression test for `Ruleset.isBigHand`: Hong Kong's own `HandScore
/// .limitName` only flags the 13-faan payment-table cap, which is
/// essentially unreachable in an ordinary game — using it directly as the
/// "big enough to celebrate" gate (as the win-voice chain briefly did)
/// silenced the winner's "yeah" and the discarder's acquiescement for every
/// Hong Kong hand under that cap, however large. `isBigHand` gives Hong Kong
/// its own, actually-reachable threshold instead.
void main() {
  HandScore riichiScore({String limitName = ''}) => HandScore(
        yaku: const [],
        han: 1,
        fu: 30,
        yakuman: 0,
        points: 1000,
        dealerPays: 0,
        nonDealerPays: 1000,
        limitName: limitName,
        valid: true,
      );

  HandScore hkScore(int faan) => HandScore(
        yaku: const [],
        han: faan,
        fu: 0,
        yakuman: 0,
        points: 0,
        dealerPays: 0,
        nonDealerPays: 0,
        limitName: faan >= 13 ? '13+ faan cap' : '',
        valid: true,
      );

  test('riichi treats mangan+ (a non-empty limitName) as big', () {
    expect(Ruleset.riichi.isBigHand(riichiScore(limitName: 'Mangan')), isTrue);
    expect(Ruleset.riichi.isBigHand(riichiScore()), isFalse);
  });

  test('Hong Kong treats 5+ faan as big, not just the 13-faan cap', () {
    expect(Ruleset.hongKong.isBigHand(hkScore(3)), isFalse);
    expect(Ruleset.hongKong.isBigHand(hkScore(4)), isFalse);
    expect(Ruleset.hongKong.isBigHand(hkScore(5)), isTrue);
    expect(Ruleset.hongKong.isBigHand(hkScore(8)), isTrue);
    expect(Ruleset.hongKong.isBigHand(hkScore(13)), isTrue);
  });

  test(
      'Taiwanese treats 10+ points as big — its own 5-point minimum to win '
      'means every legal hand already clears a 5-point bar', () {
    expect(Ruleset.taiwanese.isBigHand(hkScore(5)), isFalse);
    expect(Ruleset.taiwanese.isBigHand(hkScore(8)), isFalse);
    expect(Ruleset.taiwanese.isBigHand(hkScore(10)), isTrue);
    expect(Ruleset.taiwanese.isBigHand(hkScore(40)), isTrue);
  });
}
