import 'dart:convert';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'sanma/helpers.dart' show tiles;

Round fixture(Ruleset ruleset,
    {int dealer = 0, int honba = 2, int sticks = 3}) {
  final round = Round.posed(
    dealer: dealer,
    roundWind: Wind.east,
    ruleset: ruleset,
    honba: honba,
    riichiSticks: sticks,
    wall: ruleset.isSanma
        ? SanmaWall.posed(remaining: 0, dora: const [])
        : Wall.posed(remaining: 0, dora: const []),
    startingPoints: [
      for (var i = 0; i < 4; i++)
        ruleset.seatIsActive(i) ? ruleset.startingPoints : 0,
    ],
  );
  for (final s in round.activeSeats) {
    s.hand = tiles('19m 1258p 147s 1356z');
  }
  return round;
}

void ron(Round round, {bool multiple = false, bool declareRiichi = false}) {
  round.seats[1].hand = tiles('234p 567s 234s 67p 88s');
  if (multiple) round.seats[3].hand = tiles('234p 567s 234s 67p 88s');
  final discard = tiles('5p').single;
  round.seats[0].hand = [...tiles('123p 456p 789s 111s 2p'), discard];
  round.seats[0].drawn = discard;
  round.turn = 0;
  round.discard(0, discard, declareRiichi: declareRiichi);
  round.resolveCalls({if (multiple) 3: CallType.ron, 1: CallType.ron});
}

void main() {
  for (final ruleset in [Ruleset.riichi, Ruleset.sanma]) {
    group(ruleset.name, () {
      for (final dealer in [0, 1]) {
        test('tsumo records only honba actually paid, dealer=$dealer', () {
          final round = fixture(ruleset, dealer: dealer);
          final win = tiles('5p').single;
          round.seats[1].hand = [...tiles('234p 567s 234s 67p 88s'), win];
          round.seats[1].drawn = win;
          round.turn = 1;
          round.declareTsumo(1);
          final result = round.result!;
          final score = result.score!;
          final handPay = dealer == 1
              ? score.nonDealerPays * (ruleset.playerCount - 1)
              : score.dealerPays +
                  score.nonDealerPays * (ruleset.playerCount - 2);
          expect(result.honbaPayouts, {1: ruleset.isSanma ? 400 : 600});
          expect(result.riichiStickPayouts, {1: 3000});
          expect(
              result.pointDeltas[1],
              handPay +
                  result.honbaPayouts[1]! +
                  result.riichiStickPayouts[1]!);
          expect(round.riichiSticks, 0);
        });
      }

      test('ron records honba and deposits separately from hand value', () {
        final round = fixture(ruleset);
        ron(round);
        final result = round.result!;
        expect(result.honbaPayouts, {1: 600});
        expect(result.riichiStickPayouts, {1: 3000});
        expect(result.pointDeltas[1], result.score!.points + 600 + 3000);
      });

      test('multiple ron awards both bonuses only to the nearest winner', () {
        final round = fixture(ruleset);
        ron(round, multiple: true);
        final result = round.result!;
        expect(result.winners, [1, 3]);
        expect(result.honbaPayouts, {1: 600});
        expect(result.riichiStickPayouts, {1: 3000});
        expect(result.pointDeltas[1], result.scores[0].points + 3600);
        expect(result.pointDeltas[3], result.scores[1].points);
      });

      test('a ronned riichi declaration is refunded before itemizing sticks',
          () {
        final round = fixture(ruleset);
        ron(round, declareRiichi: true);
        expect(round.seats[0].riichi, isFalse);
        expect(round.result!.riichiStickPayouts, {1: 3000});
        expect(
            round.result!.pointDeltas[0], -round.result!.score!.points - 600);
      });

      test('zero honba and deposits award no bonus', () {
        final round = fixture(ruleset, honba: 0, sticks: 0);
        ron(round);
        expect(round.result!.honbaPayouts, isEmpty);
        expect(round.result!.riichiStickPayouts, isEmpty);
        expect(round.result!.pointDeltas[1], round.result!.score!.points);
      });

      for (final nagashi in [false, true]) {
        test('draw, nagashi=$nagashi, carries deposits without bonus payouts',
            () {
          final round = fixture(ruleset);
          if (nagashi) {
            final river = tiles('19m 123z');
            round.seats[1].pond = river;
            round.seats[1].allDiscards.addAll(river);
          }
          round.beginPosedPlay();
          expect(round.result!.isNagashiMangan, nagashi);
          expect(round.result!.honbaPayouts, isEmpty);
          expect(round.result!.riichiStickPayouts, isEmpty);
          expect(round.riichiSticks, 3);
        });
      }

      test('abortive draws award neither bonus', () {
        final round = fixture(ruleset);
        round.seats[0].hand = tiles('19m 19p 19s 1234567z 1z');
        round.declareKyuushu(0);
        expect(round.result!.honbaPayouts, isEmpty);
        expect(round.result!.riichiStickPayouts, isEmpty);
        expect(round.riichiSticks, 3);
      });

      test('bonus recipients and amounts survive JSON and every viewer remap',
          () {
        final round = fixture(ruleset);
        ron(round, multiple: true);
        for (final viewer in ruleset.activeSeats) {
          final wire = jsonDecode(
                  jsonEncode(roundSnapshotToJson(round, reveal: (_) => true)))
              as Map<String, dynamic>;
          final mirror = buildRoundFromSnapshot(wire, mySeat: viewer);
          final winner = ruleset.relativeSeat(1, viewer);
          expect(mirror.result!.honbaPayouts, {winner: 600});
          expect(mirror.result!.riichiStickPayouts, {winner: 3000});
        }
      });

      test('older snapshots without bonus fields still load', () {
        final round = fixture(ruleset);
        ron(round);
        final wire = roundSnapshotToJson(round, reveal: (_) => true);
        final result = wire['result'] as Map<String, dynamic>;
        result.remove('honbaPayouts');
        result.remove('riichiStickPayouts');
        final mirror = buildRoundFromSnapshot(wire, mySeat: 0);
        expect(mirror.result!.honbaPayouts, isEmpty);
        expect(mirror.result!.riichiStickPayouts, isEmpty);
        expect(mirror.result!.pointDeltas, round.result!.pointDeltas);
      });
    });
  }
}
