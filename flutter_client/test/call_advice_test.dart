import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/tile.dart';
import 'helpers.dart';
import 'hk_helpers.dart';

CallAdvice advise(String spec, TileType offered,
    {Set<GuidedAction> available = const {GuidedAction.pon},
    List<Meld> melds = const [],
    bool legacy = false}) {
  final hand = parseTiles(spec);
  final counts = toCounts34(hand);
  counts[offered.index - 1]++;
  return EfficiencyEngine().adviseCall(
      hand: hand,
      offered: Tile(900, offered),
      available: available,
      visibleCounts34: counts,
      context: hkContext(melds: melds, legacy: legacy));
}

void main() {
  test('a chicken hand win is always recommended', () {
    final advice = advise('456p 789s 22m 55p', TileType.pin5, available: {
      GuidedAction.ron
    }, melds: [
      Meld(kind: MeldKind.sequence, low: TileType.man1, concealed: false)
    ]);
    expect(advice.recommended, GuidedAction.ron);
    expect(advice.forAction(GuidedAction.ron)!.expectedValue, greaterThan(0));
    expect(advice.reason.toLowerCase(), isNot(contains('furiten')));
  });
  test('opening without a special pattern can still advance the hand', () {
    final advice = advise('123m 456p 789s 25p 22s', TileType.sou2);
    final pung = advice.forAction(GuidedAction.pon)!;
    expect(pung.eligible, isTrue);
    expect(pung.expectedValue, greaterThan(0));
    expect(pung.reason, isNot(contains('yaku')));
  });
  test('a call that does not advance shape is declined', () {
    final advice = advise('123m 456m 789m 12p RR', TileType.chun);
    expect(advice.forAction(GuidedAction.pon)!.eligible, isFalse);
    expect(advice.recommended, GuidedAction.pass);
  });
  test('pung to a valuable ready hand is taken', () {
    final advice = advise('1m 234m 567m 78p 99s RR', TileType.chun);
    expect(advice.recommended, GuidedAction.pon);
    expect(advice.forAction(GuidedAction.pon)!.shantenAfter, 0);
  });
  test('legacy dora and deposits cannot change a call value', () {
    final plain = advise('1m 234m 567m 78p 99s RR', TileType.chun);
    final legacy =
        advise('1m 234m 567m 78p 99s RR', TileType.chun, legacy: true);
    expect(legacy.forAction(GuidedAction.pon)!.expectedValue,
        plain.forAction(GuidedAction.pon)!.expectedValue);
  });
  test('chow advice selects a legal run and discard', () {
    final advice = advise('1m 234m 567m 67p 99s RR', TileType.pin5,
        available: {GuidedAction.chi});
    final chow = advice.forAction(GuidedAction.chi)!;
    expect(chow.meldLow, TileType.pin5);
    expect(chow.discardAfter, isNotNull);
  });
  test('concealed kong needs four tiles and uses replacement-draw reasoning',
      () {
    final hand = parseTiles('1111m 234p 567p 99s 12s');
    final engine = EfficiencyEngine();
    final good = engine.adviseClosedKan(
        hand: hand,
        kanType: TileType.man1,
        visibleCounts34: toCounts34(hand),
        context: hkContext());
    expect(good.eligible, isTrue);
    expect(good.reason, contains('replacement draw'));
    expect(good.reason, isNot(contains('dora')));
    final bad = engine.adviseClosedKan(
        hand: hand,
        kanType: TileType.pin2,
        visibleCounts34: toCounts34(hand),
        context: hkContext());
    expect(bad.eligible, isFalse);
  });
  test('added kong advice refuses a tile without an existing pung', () {
    final hand = parseTiles('123m 456m 789p 234s EE');
    final advice = EfficiencyEngine().adviseAddedKan(
        hand: hand,
        kanType: TileType.ton,
        melds: [],
        visibleCounts34: toCounts34(hand),
        context: hkContext());
    expect(advice.eligible, isFalse);
  });
}
