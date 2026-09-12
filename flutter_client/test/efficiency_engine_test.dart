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
    int honba = 0,
    int riichiSticks = 0,
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
        honba: honba,
        riichiSticks: riichiSticks,
      ),
      opponentRiichi: opponentRiichi,
      opponentDiscards: opponentDiscards,
      passedDiscardsAfterRiichi: passedDiscardsAfterRiichi,
    );
    return report.lines.singleWhere((line) => line.discard == discard);
  }

  group('lines at different distances are quoted in the same money', () {
    /// Every discard is scored now, including ones that step backwards. That
    /// only works if a backwards line cannot be flattered by a generic value
    /// estimate the hand itself could never reach.
    EfficiencyReport read(String spec, {int wall = 40}) {
      final hand = parseTiles(spec);
      expect(hand.length, 14);
      return EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: true,
        valueContext: EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: wall,
          doraIndicators: const [TileType.pei],
        ),
      );
    }

    test('a sound tenpai is kept when nothing is threatening', () {
      for (final spec in [
        '234m 567m 234p 99s 45s 1m', // ryanmen, 8 live
        '123m 456m 789m 22p 45s 9s', // ryanmen, 8 live
      ]) {
        final r = read(spec);
        expect(r.currentShanten, 0, reason: '"$spec" should be tenpai');
        final reco = r.lines.firstWhere((l) => l.recommended);
        expect(reco.shanten, 0,
            reason: '"$spec": recommended cutting ${reco.discard.code}, '
                'which drops to ${reco.shanten}-shanten');
      }
    });

    test('a dire tenpai may still be worth breaking', () {
      // Four sets and 4s5s: a tanki with three tiles live. Trading it for a
      // 36-tile 1-shanten is a real play, and the numbers should say so —
      // this is the one case where stepping back genuinely wins more often.
      final r = read('234m 567m 234p 678p 4s 5s');
      final ready = r.lines.firstWhere((l) => l.shanten == 0);
      final back = r.lines.firstWhere((l) => l.recommended);
      expect(ready.ukeire, lessThan(4), reason: 'the wait really is that thin');
      expect(back.shanten, 1);
      expect(back.winProbability, greaterThan(ready.winProbability));
    });

    test('a cheap hand is not credited with an average hand\'s payout', () {
      // 234m 567m 234p 99s 45s is a plain pinfu — well under the generic
      // pre-tenpai estimate. Its backwards lines must be quoted at what this
      // hand is really worth, not at that estimate.
      final r = read('234m 567m 234p 99s 45s 1m');
      final tenpai = r.lines.firstWhere((l) => l.shanten == 0);
      expect(tenpai.averagePoints, lessThan(3900),
          reason: 'this hand really is cheap');
      for (final l in r.lines.where((l) => l.shanten > 0)) {
        expect(l.averagePoints, closeTo(tenpai.averagePoints, 1),
            reason: '${l.discard.code} is priced off a different hand');
      }
    });

    test('a healthy tenpai is not out-run by a step backwards', () {
      final r = read('234m 567m 234p 99s 45s 1m');
      final ready = r.lines.firstWhere((l) => l.shanten == 0);
      for (final l in r.lines.where((l) => l.shanten > 0)) {
        expect(l.winProbability, lessThan(ready.winProbability),
            reason: 'cutting ${l.discard.code} drops to '
                '${l.shanten}-shanten yet scores a better chance to win');
      }
    });
  });

  group('push and fold at tenpai', () {
    // 234m 567m 234p 99s 45s + a 1m float. Cutting 1m is tenpai on 3s/6s and
    // 1m is live — that is the push. 3p and 5s are genbutsu but break tenpai.
    const spec = '234m 567m 234p 99s 45s 1m';
    const pond = [TileType.sou5, TileType.pin3];

    ({DiscardLine push, DiscardLine best}) read(
      List<TileType> dora, {
      bool oppDealer = false,
      int wall = 40,
    }) {
      final hand = parseTiles(spec);
      final visible = toCounts34(hand);
      for (final t in [...pond, ...dora]) {
        visible[t.index - 1]++;
      }
      final r = EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: visible,
        canRiichi: true,
        defenseHand: hand,
        opponentRiichi: true,
        opponentIsDealer: oppDealer,
        opponentDiscards: pond,
        valueContext: EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: wall,
          doraIndicators: dora,
        ),
      );
      return (
        push: r.lines.firstWhere((l) => l.shanten == 0),
        best: r.lines.firstWhere((l) => l.recommended),
      );
    }

    test('a cheap tenpai is not worth the lock-in, a big one is', () {
      final cheap = read(const [TileType.pei]); // ~2200 points
      expect(cheap.best.safety!.isSafe, isTrue,
          reason: 'a cheap tenpai should fold to the genbutsu');

      final big = read(const [TileType.sou8, TileType.man1]); // ~7800
      expect(big.push.averagePoints, greaterThan(cheap.push.averagePoints));
      expect(big.best.shanten, 0, reason: 'a big tenpai should push');
    });

    test('the same push is worth less against a dealer, and late', () {
      const dora = [TileType.sou8, TileType.man1];
      final base = read(dora).push;
      expect(read(dora, oppDealer: true).push.expectedValue,
          lessThan(base.expectedValue),
          reason: 'dealing into the dealer costs more');
      expect(read(dora, wall: 12).push.expectedValue,
          lessThan(base.expectedValue),
          reason: 'fewer draws left to win, same exposure');
    });

    test('pure expected value reaches the same verdict as the fold switch', () {
      // The switch only fires before tenpai; everywhere it does fire, the EV
      // ranking should already agree with it, or it is papering over the model.
      for (final dora in [
        const [TileType.pei],
        const [TileType.sou8],
        const [TileType.sou8, TileType.man1],
      ]) {
        for (final dealer in [false, true]) {
          for (final wall in [40, 12]) {
            final hand = parseTiles(spec);
            final visible = toCounts34(hand);
            for (final t in [...pond, ...dora]) {
              visible[t.index - 1]++;
            }
            final r = EfficiencyEngine().analyze(
              hand: hand,
              visibleCounts34: visible,
              canRiichi: true,
              defenseHand: hand,
              opponentRiichi: true,
              opponentIsDealer: dealer,
              opponentDiscards: pond,
              valueContext: EfficiencyValueContext(
                melds: const [],
                roundWind: Wind.east,
                seatWind: Wind.south,
                isDealer: false,
                inRiichi: false,
                wallTilesRemaining: wall,
                doraIndicators: dora,
              ),
            );
            final pureEv = r.lines.firstWhere((l) => l.bestExpectedValue);
            final switched = r.lines.firstWhere((l) => l.recommended);
            expect(pureEv.discard, switched.discard,
                reason: 'dora ${dora.length}, dealer $dealer, wall $wall: '
                    'EV says ${pureEv.discard.code}, '
                    'switch says ${switched.discard.code}');
          }
        }
      }
    });

    test('the riichi lock-in is priced off the turns it exposes you for', () {
      // Declaring commits you to tsumogiri for the rest of the hand, so the
      // charge has to shrink as there are fewer turns left to be exposed for.
      final long = read(const [TileType.pei], wall: 60).push;
      final short = read(const [TileType.pei], wall: 16).push;
      expect(long.riichiLockCost, greaterThan(short.riichiLockCost));
      expect(short.riichiLockCost, greaterThan(0));
    });
  });

  group('tenpai win probability', () {
    DiscardLine best(String spec, int wall) {
      final hand = parseTiles(spec);
      final report = EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: true,
        valueContext: EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: wall,
          doraIndicators: const [TileType.pei],
        ),
      );
      return (report.lines.toList()
            ..sort((a, b) => b.winProbability.compareTo(a.winProbability)))
          .first;
    }

    const tenpaiRyanmen = '123m 456m 789m 22p 45s 9s';
    const oneAway = '123m 456m 789m 24p 46s 9s';

    test('an early riichi on a ryanmen is a coin flip, not a formality', () {
      final l = best(tenpaiRyanmen, 70);
      expect(l.shanten, 0);
      // The old estimator counted two shots on every draw and never asked
      // whether the hand was still running: it read 91% here.
      expect(l.winProbability, inInclusiveRange(0.45, 0.65),
          reason: 'scored ${(l.winProbability * 100).round()}%');
    });

    test('tenpai is worth more than one step short of it', () {
      final ready = best(tenpaiRyanmen, 70);
      final nearly = best(oneAway, 70);
      expect(ready.shanten, 0);
      expect(nearly.shanten, 1);
      expect(ready.winProbability, greaterThan(nearly.winProbability),
          reason: 'a ready hand must beat an unready one — the two estimators '
              'used to be calibrated apart, and this was the wrong way round');
    });

    test('the chance falls away as the wall runs down', () {
      var previous = 1.0;
      for (final wall in [70, 50, 30, 16, 8]) {
        final l = best(tenpaiRyanmen, wall);
        expect(l.winProbability, lessThan(previous),
            reason: 'wall $wall did not drop below the wall before it');
        previous = l.winProbability;
      }
      expect(previous, lessThan(0.2));
    });
  });

  group('pre-tenpai win probability', () {
    /// The best pre-tenpai line of [spec] with [wall] tiles left.
    DiscardLine preTenpai(String spec, int wall) {
      final hand = parseTiles(spec);
      expect(hand.length, 14, reason: '"$spec" must be a full 14');
      final report = EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: true,
        valueContext: EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: wall,
          doraIndicators: const [TileType.pei],
        ),
      );
      // Compare like with like: the best line at the hand's own shanten, not
      // a deliberately backwards one (those are scored too now).
      final best =
          report.lines.map((l) => l.shanten).reduce((a, b) => a < b ? a : b);
      final lines = report.lines.where((l) => l.shanten == best).toList()
        ..sort((a, b) => b.winProbability.compareTo(a.winProbability));
      return lines.first;
    }

    // 1-shanten, 20 tiles of acceptance — an ordinary hand one away.
    const closeNarrow = '123m 456m 789m 24p 46s 9s';
    // 1-shanten, 12 tiles — the same distance out but a thinner shape.
    const closeThin = '23m 45m 67p 89p 23s 56s 99m';
    // 2-shanten, 45 tiles — six partial sets. The shape the old estimator
    // flattered most: it reused that width at every step and scored it 83%.
    const farWide = '234m 23m 45p 67p 23s 56s 9s';
    // 2-shanten, 12 tiles — further out and thin.
    const farThin = '13m 24p 46s 68s 35p 79m 19s';

    test('no pre-tenpai hand is anywhere near a sure thing', () {
      for (final spec in [closeNarrow, closeThin, farWide, farThin]) {
        final l = preTenpai(spec, 70);
        expect(l.winProbability, greaterThan(0));
        expect(l.winProbability, lessThan(0.6),
            reason: '"$spec" at ${l.shanten}-shanten (ukeire ${l.ukeire}) '
                'scores ${(l.winProbability * 100).round()}% off a full wall');
      }
    });

    test('the same shape is worth less further from home', () {
      final near = preTenpai(closeThin, 70);
      final far = preTenpai(farThin, 70);
      expect(near.ukeire, far.ukeire, reason: 'same width, different distance');
      expect(far.shanten, greaterThan(near.shanten));
      expect(far.winProbability, lessThan(near.winProbability));
    });

    test('being closer in beats being wider further out', () {
      // This asserted the reverse until the width premium was capped, and as a
      // statement about hands in the abstract the reverse is true: measured in
      // self-play, a 2-shanten hand holding 45 tiles of acceptance went on to
      // win about 23% of the time, against 14% for a 1-shanten hand holding 8.
      //
      // But the estimator is not asked to rank hands in the abstract. It ranks
      // *discards*, and stepping back from 1-shanten into a wider 2-shanten is
      // not the same thing as having been dealt the wider hand: it costs a
      // turn, and it arrives in worse shape than the hands that landed in that
      // bucket on their own. Paying width the premium it appeared to have
      // earned made the guide retreat on a third of its discards — 26% of them
      // with no riichi on the board — and cost it 0.46 of a placement over
      // 3000 paired hanchan.
      //
      // The cap buys that back at the price of this ordering, and the trade is
      // not close. With the premium left on even the immediate step, none of
      // the nine (style, focus) settings beat the bot; with it capped, six of
      // nine do, the best by 0.26 of a placement.
      expect(preTenpai(closeThin, 70).winProbability,
          greaterThan(preTenpai(farWide, 70).winProbability));
    });

    test('the chance falls away as the wall runs down', () {
      var previous = 1.0;
      for (final wall in [70, 50, 30, 16, 8]) {
        final l = preTenpai(closeNarrow, wall);
        expect(l.winProbability, lessThan(previous),
            reason: 'wall $wall did not drop below the wall before it');
        previous = l.winProbability;
      }
      expect(previous, lessThan(0.1), reason: 'a dying wall should be bleak');
    });
  });

  group('the arithmetic the panel shows', () {
    test('the reported terms reconstruct expected value exactly', () {
      for (final spec in [
        '1m 234m 567m 99s 78p 33p W', // pre-tenpai
        '123m 456m 789m 123p 5s 9s', // tenpai
      ]) {
        for (final riichi in [false, true]) {
          final hand = parseTiles(spec);
          final report = EfficiencyEngine().analyze(
            hand: hand,
            visibleCounts34: toCounts34(hand),
            canRiichi: true,
            defenseHand: riichi ? hand : null,
            opponentRiichi: riichi,
            opponentDiscards: riichi ? const [TileType.pin9] : const [],
            valueContext: const EfficiencyValueContext(
              melds: [],
              roundWind: Wind.east,
              seatWind: Wind.south,
              isDealer: false,
              inRiichi: false,
              wallTilesRemaining: 40,
              doraIndicators: [TileType.pei],
              honba: 2,
              riichiSticks: 1,
            ),
          );
          for (final l in report.lines) {
            expect(
              l.winProbability * (l.averagePoints + l.winBonus) -
                  l.riichiLockCost -
                  l.dealInCost -
                  l.commitmentCost,
              closeTo(l.expectedValue, 1e-9),
              reason: 'cut ${l.discard.code} of "$spec" '
                  '(riichi: $riichi) does not add up',
            );
            expect(l.winProbability, inInclusiveRange(0, 1));
          }
        }
      }
    });
  });

  group('deal-in cost', () {
    /// The same hand and the same visible tiles both times — only what the
    /// riichi opponent has discarded differs, so nothing but the safety of the
    /// cut can move the number.
    DiscardLine cutWest(List<TileType> pond, {bool opponentIsDealer = false}) {
      final hand = parseTiles('1m 234m 567m 99s 78p 33p W');
      return EfficiencyEngine()
          .analyze(
            hand: hand,
            visibleCounts34: toCounts34(hand),
            canRiichi: true,
            defenseHand: hand,
            opponentRiichi: true,
            opponentIsDealer: opponentIsDealer,
            opponentDiscards: pond,
            valueContext: const EfficiencyValueContext(
              melds: [],
              roundWind: Wind.east,
              seatWind: Wind.south,
              isDealer: false,
              inRiichi: false,
              wallTilesRemaining: 40,
              doraIndicators: [TileType.pei],
            ),
          )
          .lines
          .firstWhere((l) => l.discard == TileType.shaa);
    }

    test('a dangerous cut is charged and a genbutsu one is not', () {
      final dangerous = cutWest(const [TileType.pei]);
      final genbutsu = cutWest(const [TileType.shaa]);

      expect(genbutsu.safety!.isSafe, isTrue);
      expect(genbutsu.dealInCost, 0);
      expect(dangerous.safety!.isSafe, isFalse);
      expect(dangerous.dealInCost, greaterThan(0));

      // Identical hands, so the only gap between them is the risk — both the
      // tile itself and the turns pushing it commits you to.
      expect(genbutsu.expectedValue - dangerous.expectedValue,
          closeTo(dangerous.riskCost, 1e-9));
      expect(genbutsu.commitmentCost, 0,
          reason: 'folding commits you to nothing');
      expect(dangerous.commitmentCost, greaterThan(0));
    });

    test('a dealer riichi costs more to deal into', () {
      final vsNonDealer = cutWest(const [TileType.pei]);
      final vsDealer = cutWest(const [TileType.pei], opponentIsDealer: true);
      expect(vsDealer.dealInCost, greaterThan(vsNonDealer.dealInCost));
      expect(vsDealer.expectedValue, lessThan(vsNonDealer.expectedValue));
    });

    test('nothing is charged with no riichi to deal into', () {
      final hand = parseTiles('1m 234m 567m 99s 78p 33p W');
      final report = EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: true,
        valueContext: const EfficiencyValueContext(
          melds: [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: 40,
          doraIndicators: [TileType.pei],
        ),
      );
      expect(report.lines.every((l) => l.dealInCost == 0), isTrue);
    });

    test('safer tiles are never charged more than riskier ones', () {
      final hand = parseTiles('1m 234m 567m 99s 78p 33p W');
      final report = EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: true,
        defenseHand: hand,
        opponentRiichi: true,
        opponentDiscards: const [TileType.pin9],
        valueContext: const EfficiencyValueContext(
          melds: [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: 40,
          doraIndicators: [TileType.pei],
        ),
      );
      final rated = report.lines.where((l) => l.safety != null).toList()
        ..sort((a, b) => a.safety!.rating.compareTo(b.safety!.rating));
      for (var i = 1; i < rated.length; i++) {
        expect(rated[i].dealInCost, lessThanOrEqualTo(rated[i - 1].dealInCost),
            reason: '${rated[i].discard.code} is rated safer than '
                '${rated[i - 1].discard.code} but costs more');
      }
    });
  });

  group('honba and riichi sticks', () {
    test('both raise EV, and by the win probability times the pot', () {
      final base = analyzeTenpai(isDealer: false);
      final withHonba = analyzeTenpai(isDealer: false, honba: 3);
      final withSticks = analyzeTenpai(isDealer: false, riichiSticks: 2);

      expect(withHonba.expectedValue, greaterThan(base.expectedValue));
      expect(withSticks.expectedValue, greaterThan(base.expectedValue));

      // 3 honba pays 900, 2 sticks pay 2000. Both ride on the same win, so
      // the two gains must sit in exactly that ratio.
      final honbaGain = withHonba.expectedValue - base.expectedValue;
      final stickGain = withSticks.expectedValue - base.expectedValue;
      expect(stickGain / honbaGain, closeTo(2000 / 900, 1e-9));
    });

    test('they do not inflate what the hand itself is worth', () {
      final base = analyzeTenpai(isDealer: false);
      final rich = analyzeTenpai(isDealer: false, honba: 5, riichiSticks: 3);
      expect(rich.averagePoints, base.averagePoints);
      expect(rich.valuePlan, base.valuePlan);
    });

    test('an empty table is unchanged', () {
      expect(
          analyzeTenpai(isDealer: false, honba: 0, riichiSticks: 0)
              .expectedValue,
          analyzeTenpai(isDealer: false).expectedValue);
    });
  });

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
    // chances left to actually hit the wait. Higher win probability raises
    // the payoff term and shrinks the deposit (it scales by 1 - win), so this
    // should be better while staying on the same RIICHI plan (the damaten
    // gate never enters it).
    //
    // Both samples sit above the turn where the curve bottoms out. Under a
    // live riichi, the third term — being locked into tsumogiri — grows with
    // the turns left rather than shrinking, so from a nearly dead wall the
    // value first falls as draws are added and only then climbs. Comparing
    // across that turning point says nothing about draws.
    final fewDraws = analyzeTenpai(
      isDealer: false,
      canRiichi: true,
      opponentRiichi: true,
      wallTilesRemaining: 24,
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
