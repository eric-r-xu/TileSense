import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

void main() {
  const discard = TileType.sou9;

  DiscardLine analyzeTenpai({
    required bool isDealer,
    bool canRiichi = false,
    List<TileType> doraIndicators = const [],
    bool opponentRiichi = false,
    List<TileType> opponentDiscards = const [],
    List<TileType> passedDiscardsAfterRiichi = const [],
    int wallTilesRemaining = 40,
  }) {
    final hand = parseTiles('123m 456m 789m 34p 55p 9s');
    final visible = toCounts34(hand);
    for (final indicator in doraIndicators) {
      visible[indicator.index - 1]++;
    }
    for (final t in {...opponentDiscards, ...passedDiscardsAfterRiichi}) {
      visible[t.index - 1]++;
    }

    final report = EfficiencyEngine().analyze(
      hand: hand,
      visibleCounts34: visible,
      canRiichi: canRiichi,
      valueContext: EfficiencyValueContext(
        melds: const [],
        roundWind: Wind.east,
        seatWind: isDealer ? Wind.east : Wind.south,
        isDealer: isDealer,
        inRiichi: false,
        wallTilesRemaining: wallTilesRemaining,
        doraIndicators: doraIndicators,
      ),
      opponentRiichi: opponentRiichi,
      opponentDiscards: opponentDiscards,
      passedDiscardsAfterRiichi: passedDiscardsAfterRiichi,
    );
    return report.lines.singleWhere((line) => line.discard == discard);
  }

  test('tenpai EV uses the scoring result', () {
    final base = analyzeTenpai(isDealer: false);
    final withDora = analyzeTenpai(
      isDealer: false,
      doraIndicators: const [TileType.man1], // 2m is dora.
    );

    expect(base.shanten, 0);
    expect(base.expectedValue, greaterThan(0));
    expect(base.averagePoints, greaterThan(0));
    expect(withDora.averagePoints, greaterThan(base.averagePoints));
    expect(withDora.expectedValue, greaterThan(base.expectedValue));
  });

  test('dealer status increases expected value for the same waits', () {
    final nonDealer = analyzeTenpai(isDealer: false);
    final dealer = analyzeTenpai(isDealer: true);

    expect(dealer.averagePoints, greaterThan(nonDealer.averagePoints));
    expect(dealer.expectedValue, greaterThan(nonDealer.expectedValue));
  });

  test('riichi value and its 1000-point risk inform the plan', () {
    final line = analyzeTenpai(isDealer: false, canRiichi: true);

    expect(line.valuePlan, 'RIICHI');
    expect(line.recommendRiichi, isTrue);
    expect(line.expectedValue, greaterThan(0));
  });

  test('a live opponent riichi costs expected value on top of the flat risk',
      () {
    final calm = analyzeTenpai(isDealer: false, canRiichi: true);
    final threatened = analyzeTenpai(
      isDealer: false,
      canRiichi: true,
      opponentRiichi: true,
    );

    // No safety information at all (no discards) reads as genuinely
    // dangerous, so the same riichi is worth strictly less against a live
    // opponent riichi than with none out.
    expect(threatened.expectedValue, lessThan(calm.expectedValue));
  });

  test(
      'more safety information on the board costs less than a fully blind read',
      () {
    // Blind: no discards anywhere, so the whole 34-type pool reads
    // dangerous. Informed: a broad swath of unrelated tiles (not the
    // waits themselves — danger comes from *any* forced future discard,
    // not just the winning tiles) are already known-safe genbutsu.
    final blind = analyzeTenpai(
      isDealer: false,
      canRiichi: true,
      opponentRiichi: true,
    );
    const knownSafe = [
      TileType.sou1,
      TileType.sou2,
      TileType.sou3,
      TileType.sou4,
      TileType.sou5,
      TileType.sou6,
      TileType.sou7,
      TileType.sou8,
      TileType.pin1,
      TileType.pin6,
      TileType.pin7,
      TileType.pin8,
      TileType.pin9,
      TileType.ton,
      TileType.nan,
      TileType.shaa,
      TileType.pei,
      TileType.haku,
      TileType.hatsu,
      TileType.chun,
    ];
    final informed = analyzeTenpai(
      isDealer: false,
      canRiichi: true,
      opponentRiichi: true,
      opponentDiscards: knownSafe,
      passedDiscardsAfterRiichi: knownSafe,
    );

    expect(informed.expectedValue, greaterThan(blind.expectedValue));
  });

  test(
      'more draws left still recommends riichi against a live opponent '
      'riichi, and is worth more than fewer draws under the same danger', () {
    // Same hand, same board danger, same points on offer — just more
    // chances left to actually hit the wait. Higher win probability both
    // raises the payoff term and shrinks the risk terms (they scale by
    // 1 - winProbability), so this should be unambiguously better while
    // staying on the same RIICHI plan (the damaten gate never enters it).
    final fewDraws = analyzeTenpai(
      isDealer: false,
      canRiichi: true,
      opponentRiichi: true,
      wallTilesRemaining: 8,
    );
    final manyDraws = analyzeTenpai(
      isDealer: false,
      canRiichi: true,
      opponentRiichi: true,
      wallTilesRemaining: 40,
    );

    expect(fewDraws.valuePlan, 'RIICHI');
    expect(manyDraws.valuePlan, 'RIICHI');
    expect(manyDraws.recommendRiichi, isTrue);
    expect(manyDraws.expectedValue, greaterThan(fewDraws.expectedValue));
  });
}
