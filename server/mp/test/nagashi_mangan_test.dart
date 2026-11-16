import 'dart:async';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';

void main() {
  for (final ruleset in [Ruleset.riichi, Ruleset.sanma]) {
    for (final tenpai in [true, false]) {
      for (final dealerQualifies in [true, false]) {
        test(
            '${ruleset.name}: online dealer tenpai=$tenpai, nagashi=$dealerQualifies',
            () async {
          final resultFrame = Completer<Map<String, dynamic>>();
          final nextFrame = Completer<Map<String, dynamic>>();
          final room = Room(code: 'NAGASH', ruleset: ruleset, hanchan: true);
          for (final i in ruleset.activeSeats) {
            room.seats[i] = Seat(
                guestId: 'player$i',
                name: 'Player $i',
                character: room.resolveCharacter())
              ..send = (message) {
                if (message['type'] == 'round_result' &&
                    !resultFrame.isCompleted) {
                  resultFrame.complete(message);
                } else if (message['type'] == 'state' &&
                    resultFrame.isCompleted &&
                    !nextFrame.isCompleted) {
                  nextFrame.complete(message);
                }
              };
          }
          final loop = TableLoop(room,
              botTurnPace: Duration.zero, continueTimeout: Duration.zero);
          loop.start();
          await Future<void>.delayed(Duration.zero);
          final dealer = loop.round.dealer;
          final recipient = dealerQualifies ? dealer : ruleset.nextSeat(dealer);
          var id = 5000;
          List<Tile> hand(List<int> indices) =>
              [for (final i in indices) Tile(id++, typeFrom34(i))];
          final round = Round.posed(
            dealer: dealer,
            roundWind: Wind.east,
            riichiSticks: 1,
            ruleset: ruleset,
            wall: ruleset.isSanma
                ? SanmaWall.posed(remaining: 0, dora: const [])
                : Wall.posed(remaining: 0, dora: const []),
            startingPoints: [
              for (var i = 0; i < 4; i++)
                ruleset.seatIsActive(i)
                    ? ruleset.startingPoints - (i == 0 ? 1000 : 0)
                    : 0
            ],
          );
          for (final s in round.activeSeats) {
            s.hand = hand([0, 8, 9, 10, 13, 16, 18, 21, 24, 27, 29, 31, 32]);
          }
          if (tenpai) {
            round.seats[dealer].hand =
                hand([10, 11, 12, 13, 14, 15, 19, 20, 21, 23, 24, 16, 16]);
          }
          final pond = hand([0, 8, 27]);
          round.seats[recipient].pond = pond;
          round.seats[recipient].allDiscards.addAll(pond);
          if (!dealerQualifies) {
            final middle = hand([13]).single;
            round.seats[dealer].pond.add(middle);
            round.seats[dealer].allDiscards.add(middle);
          }
          final discard = hand([27]).single;
          round.seats[dealer].hand.add(discard);
          round.seats[dealer].drawn = discard;
          round.turn = dealer;
          loop.round = round;
          loop.handleMessage(dealer,
              {'type': 'action', 'kind': 'discard', 'tileId': discard.id});

          final message =
              await resultFrame.future.timeout(const Duration(seconds: 3));
          final result = buildRoundFromSnapshot(
              message['round'] as Map<String, dynamic>,
              mySeat: dealer);
          expect(result.result!.kind, RoundEndKind.exhaustiveDraw);
          expect(result.result!.isNagashiMangan, isTrue);
          expect(result.result!.winners,
              [ruleset.relativeSeat(recipient, dealer)]);
          expect(result.result!.tenpaiAtDraw.contains(result.dealer), tenpai);

          await nextFrame.future.timeout(const Duration(seconds: 3));
          expect(loop.round.dealer, tenpai ? dealer : ruleset.nextSeat(dealer));
          expect(loop.round.honba, 1);
          expect(loop.round.riichiSticks, 1);
          if (ruleset.isSanma) {
            expect(result.result!.pointDeltas[2], 0);
            expect(loop.round.seats[2].points, 0);
          }
        });
      }
    }
  }
}
