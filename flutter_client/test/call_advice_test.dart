import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/meld.dart';
import 'package:tilesense/logic/tile.dart';

import 'helpers.dart';

/// Covers the guide's call advisor: every option is scored through the same
/// expected-value model the discard table uses, then filtered by three hard
/// rules — a call has to advance the hand, leave a yaku to finish on, and not
/// commit you while a riichi is out and you are still behind.
void main() {
  CallAdvice advise(
    String handSpec,
    TileType offered, {
    Set<GuidedAction> available = const {GuidedAction.pon},
    List<Meld> melds = const [],
    List<TileType> doraIndicators = const [],
    bool isDealer = false,
    bool opponentRiichi = false,
    List<TileType> opponentDiscards = const [],
  }) {
    final hand = parseTiles(handSpec);
    final visible = toCounts34(hand)..[offered.index - 1] += 1;
    for (final indicator in doraIndicators) {
      visible[indicator.index - 1] += 1;
    }
    return EfficiencyEngine().adviseCall(
      hand: hand,
      offered: Tile(999, offered),
      available: available,
      visibleCounts34: visible,
      context: EfficiencyValueContext(
        melds: melds,
        roundWind: Wind.east,
        seatWind: isDealer ? Wind.east : Wind.south,
        isDealer: isDealer,
        inRiichi: false,
        wallTilesRemaining: 40,
        doraIndicators: doraIndicators,
      ),
      opponentDiscards: opponentDiscards,
      allDiscards: opponentDiscards,
      opponentRiichi: opponentRiichi,
    );
  }

  ActionAdvice optionFor(CallAdvice advice, GuidedAction action) =>
      advice.forAction(action)!;

  group('ron and tsumo', () {
    test('a win on offer is always taken, and reports what it is worth', () {
      final advice = advise(
        '123m 456m 789m 23p 55p',
        TileType.pin4,
        available: const {GuidedAction.ron, GuidedAction.pon},
      );
      expect(advice.recommended, GuidedAction.ron);
      expect(optionFor(advice, GuidedAction.ron).expectedValue, greaterThan(0));
      expect(advice.reason, contains('furiten'));
    });

    test('tsumo reports the score and is never declined', () {
      final hand = parseTiles('123m 456m 789m 234p 55p');
      final drawn = hand.last;
      final advice = EfficiencyEngine().adviseTsumo(
        hand: hand,
        drawn: drawn,
        context: EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: 40,
          doraIndicators: const [],
        ),
      );
      expect(advice.action, GuidedAction.tsumo);
      expect(advice.shantenAfter, -1);
      expect(advice.expectedValue, greaterThan(0));
    });
  });

  group('the three hard rules', () {
    test('a call that gets you no closer is refused', () {
      // Already tenpai on 3p; ponning the dragons only swaps one tenpai for a
      // worse one and gives up a concealed hand.
      final advice = advise('123m 456m 789m 12p RR', TileType.chun);
      final pon = optionFor(advice, GuidedAction.pon);
      expect(pon.eligible, isFalse);
      expect(pon.reason, contains('no closer'));
      expect(advice.recommended, GuidedAction.pass);
    });

    test('a call that leaves no yaku to finish on is refused', () {
      // Open, no yakuhai, terminals present — nothing left to win on.
      final advice = advise('123m 456p 789s 25p 22s', TileType.sou2);
      final pon = optionFor(advice, GuidedAction.pon);
      expect(pon.eligible, isFalse);
      expect(pon.expectedValue, 0);
      expect(pon.reason, contains('yaku'));
      expect(advice.recommended, GuidedAction.pass);
    });

    test('a call that commits you behind a riichi is refused', () {
      const hand = '123m 456m 2p 5p 8p RR 3s 6s';
      final calm = optionFor(advise(hand, TileType.chun), GuidedAction.pon);
      final threatened = optionFor(
        advise(hand, TileType.chun,
            opponentRiichi: true, opponentDiscards: const [TileType.pin2]),
        GuidedAction.pon,
      );

      // Same call, same shape gain — only the danger changes the verdict.
      expect(calm.shantenAfter, lessThan(3));
      expect(calm.eligible, isTrue);
      expect(threatened.eligible, isFalse);
      expect(threatened.reason, contains('fold'));
    });
  });

  group('expected value drives the verdict', () {
    test('pon is taken when it buys a real tenpai', () {
      // Ponning the dragons leaves 234m 567m + 99s pair + a 78p ryanmen: a
      // proper tenpai with a yaku, clearly better than the closed 1-shanten.
      final advice = advise('1m 234m 567m 78p 99s RR', TileType.chun);
      expect(advice.recommended, GuidedAction.pon);
      final pon = optionFor(advice, GuidedAction.pon);
      final pass = optionFor(advice, GuidedAction.pass);
      expect(pon.shantenAfter, 0);
      expect(pon.expectedValue, greaterThan(pass.expectedValue));
    });

    test('dora sitting in the called meld raises the call value', () {
      const hand = '1m 234m 567m 78p 99s RR';
      final plain = advise(hand, TileType.chun);
      // Indicator hatsu makes chun dora, so the pon drags three dora with it.
      final withDora =
          advise(hand, TileType.chun, doraIndicators: const [TileType.hatsu]);

      expect(
        optionFor(withDora, GuidedAction.pon).expectedValue,
        greaterThan(optionFor(plain, GuidedAction.pon).expectedValue * 2),
      );
    });

    test('a cheap tanki tenpai loses to a healthy closed hand', () {
      // Pon reaches tenpai, but only a 1000-point tanki — the closed
      // 1-shanten is worth more, so the guide leaves it.
      final advice = advise('123m 456m 789m 25p RR', TileType.chun);
      final pon = optionFor(advice, GuidedAction.pon);
      expect(pon.eligible, isTrue, reason: 'it does clear the hard rules');
      expect(pon.expectedValue,
          lessThan(optionFor(advice, GuidedAction.pass).expectedValue));
      expect(advice.recommended, GuidedAction.pass);
    });
  });

  group('chi', () {
    // The round engine never offers chi, but the advisor evaluates it so the
    // strategy is in place if it ever does.
    test('chi is evaluated and can be taken', () {
      final advice = advise(
        '1m 234m 567m 67p 99s RR',
        TileType.pin5,
        available: const {GuidedAction.chi},
      );
      final chi = optionFor(advice, GuidedAction.chi);
      expect(chi.shantenAfter, lessThan(2));
      expect(chi.discardAfter, isNotNull);
    });

    test('chi picks the best of several possible sequences', () {
      // 5p could be taken as 345p, 456p or 567p — all three are considered.
      final advice = advise(
        '345m 678m 34567p 99s',
        TileType.pin5,
        available: const {GuidedAction.chi},
      );
      expect(advice.forAction(GuidedAction.chi), isNotNull);
    });
  });

  group('closed kan', () {
    ActionAdvice kanAdvice({
      required String handSpec,
      required TileType kanType,
      bool opponentRiichi = false,
    }) {
      final hand = parseTiles(handSpec);
      return EfficiencyEngine().adviseClosedKan(
        hand: hand,
        kanType: kanType,
        visibleCounts34: toCounts34(hand),
        context: EfficiencyValueContext(
          melds: const [],
          roundWind: Wind.east,
          seatWind: Wind.south,
          isDealer: false,
          inRiichi: false,
          wallTilesRemaining: 40,
          doraIndicators: const [],
        ),
        opponentRiichi: opponentRiichi,
      );
    }

    test('a shape-neutral kan is taken when the table is calm', () {
      final advice = kanAdvice(
        handSpec: '1111m 234m 567m 99s 5p',
        kanType: TileType.man1,
      );
      expect(advice.eligible, isTrue);
      expect(advice.reason, contains('dora indicator'));
    });

    test('the same kan is declined while a riichi is out and you are behind',
        () {
      final advice = kanAdvice(
        handSpec: '1111m 234m 567m 99s 5p',
        kanType: TileType.man1,
        opponentRiichi: true,
      );
      expect(advice.eligible, isFalse);
      expect(advice.reason, contains('dora'));
    });

    test('a kan you cannot actually make is refused', () {
      final advice = kanAdvice(
        handSpec: '123m 456m 789m 234p 55p',
        kanType: TileType.man1,
      );
      expect(advice.eligible, isFalse);
    });
  });

  group('open kan', () {
    test('a shape-neutral kan with no yaku path is refused', () {
      // Calling 2s leaves three complete mixed-suit sequences and a 5p tanki.
      // The shape survives, but the open hand has no yaku and cannot score.
      final advice = advise(
        '123m 456p 789s 5p 222s',
        TileType.sou2,
        available: const {GuidedAction.kan},
      );
      final kan = optionFor(advice, GuidedAction.kan);

      expect(kan.shantenAfter, 0);
      expect(kan.eligible, isFalse);
      expect(kan.expectedValue, 0);
      expect(kan.reason, contains('yaku'));
      expect(advice.recommended, GuidedAction.pass);
    });
  });
}
