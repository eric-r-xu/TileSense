import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/hong_kong/hong_kong_safety.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import '../helpers.dart';
import 'hk_helpers.dart';

Meld _pung(TileType t) =>
    Meld(kind: MeldKind.triplet, low: t, concealed: false);
Meld _chow(TileType t) =>
    Meld(kind: MeldKind.sequence, low: t, concealed: false);

void main() {
  // Every switch this file flips is restored, so the rest of the suite runs on
  // the shipped guide.
  tearDown(() {
    HongKongGuideTuning.readThreatDiscards = false;
    HongKongGuideTuning.readThreatFlush = false;
    HongKongGuideTuning.dealInByVisibleFaan = false;
    HongKongGuideTuning.potentialFaanInEstimate = false;
  });

  group('rankHongKongSafety reads the threat', () {
    final hand = parseTiles('5m 5p 5s E');
    Map<TileType, int> ratings(
            {List<Meld> melds = const [],
            List<TileType> discards = const []}) =>
        {
          for (final r in rankHongKongSafety(hand,
              visibleCounts34: toCounts34(hand),
              threatMelds: melds,
              threatDiscards: discards))
            r.type: r.rating
        };

    test('no melds and no discards leave the by-type ratings alone', () {
      expect(ratings(), {
        for (final r
            in rankHongKongSafety(hand, visibleCounts34: toCounts34(hand)))
          r.type: r.rating
      });
    });

    test('sets all in one suit make that suit dangerous, the rest safe', () {
      final flush = ratings(melds: [
        _chow(TileType.pin1),
        _pung(TileType.pin7),
        _pung(TileType.chun)
      ]);
      final plain = ratings();
      expect(flush[TileType.pin5]!, lessThan(plain[TileType.pin5]!));
      expect(flush[TileType.man5]!, greaterThan(plain[TileType.man5]!));
      expect(flush[TileType.sou5]!, greaterThan(plain[TileType.sou5]!));
      expect(flush[TileType.ton], plain[TileType.ton],
          reason: 'honours still fit a mixed flush');
    });

    test('one suited set, or two suits, is no flush read', () {
      expect(ratings(melds: [_chow(TileType.pin1), _pung(TileType.chun)]),
          ratings());
      expect(ratings(melds: [_chow(TileType.pin1), _chow(TileType.man1)]),
          ratings());
    });

    test('their own discard reads safer but never certainly safe', () {
      final read = rankHongKongSafety(hand,
          visibleCounts34: toCounts34(hand), threatDiscards: [TileType.man5]);
      final man5 = read.firstWhere((r) => r.type == TileType.man5);
      expect(man5.rating, greaterThan(ratings()[TileType.man5]!));
      expect(man5.isSafe, isFalse);
      expect(man5.label, contains('discarded it themselves'));
    });
  });

  group('the engine', () {
    // A calm 14-tile hand facing a threat whose three exposed sets are all
    // pinzu: the 5p is the tile a flush read should keep.
    final threatMelds = [
      _chow(TileType.pin1),
      _pung(TileType.pin7),
      _pung(TileType.chun),
    ];
    EfficiencyReport read() {
      final hand = parseTiles('123m 456m 789s 11s 5p 9m');
      return EfficiencyEngine().analyze(
        hand: hand,
        visibleCounts34: toCounts34(hand),
        canRiichi: false,
        valueContext: hkContext(),
        defenseHand: hand,
        opponentRiichi: true,
        opponentMelds: threatMelds,
      );
    }

    test('only reads the threat with the switch on', () {
      final off = read().defense.firstWhere((r) => r.type == TileType.pin5);
      HongKongGuideTuning.readThreatFlush = true;
      final on = read().defense.firstWhere((r) => r.type == TileType.pin5);
      expect(on.rating, lessThan(off.rating));
    });

    test('reads the threat\'s own discards only with the switch on', () {
      EfficiencyReport withPond() {
        final hand = parseTiles('123m 456m 789s 11s 5p 9m');
        return EfficiencyEngine().analyze(
          hand: hand,
          visibleCounts34: toCounts34(hand),
          canRiichi: false,
          valueContext: hkContext(),
          defenseHand: hand,
          opponentRiichi: true,
          opponentDiscards: [TileType.pin5],
        );
      }

      int pin5() =>
          withPond().defense.firstWhere((r) => r.type == TileType.pin5).rating;
      final off = pin5();
      HongKongGuideTuning.readThreatDiscards = true;
      expect(pin5(), greaterThan(off));
    });

    test('prices a deal-in from the faan the threat shows', () {
      final flat = read().lines.firstWhere((l) => l.discard == TileType.pin5);
      HongKongGuideTuning.dealInByVisibleFaan = true;
      final visible =
          read().lines.firstWhere((l) => l.discard == TileType.pin5);
      // Red dragon + mixed-flush spread + one: five faan, far above the flat 16.
      expect(visible.dealInCost, greaterThan(flat.dealInCost));
    });

    test('credits a dragon pair and a near-flush only with the switch on', () {
      double value() => hkReport('13p 46p 8p RR 1m 5s 9s ESNW')
          .lines
          .firstWhere((l) => l.discard == TileType.man1)
          .averagePoints;
      final off = value();
      HongKongGuideTuning.potentialFaanInEstimate = true;
      expect(value(), greaterThan(off));
    });
  });
}
