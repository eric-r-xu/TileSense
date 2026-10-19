import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';

/// Bot Saeko on Mortal declares kyuushu kyuuhai when Mortal says to (a
/// `ryukyoku` reply), as single player's autoplay does, rather than playing
/// on with a discard.
void main() {
  test('bot Saeko aborts the hand when Mortal calls kyuushu kyuuhai', () async {
    // Whether Saeko's first question still falls in the first go-around
    // depends on the shuffled wall (a call by an earlier seat ends it), so
    // retry on a fresh table until the planted hand qualifies.
    for (var attempt = 0; attempt < 30; attempt++) {
      final room = Room(code: 'SAEKO1', ruleset: Ruleset.riichi, hanchan: false);
      room.seats[0] = Seat(
          guestId: 'alice',
          name: 'alice',
          character: room.resolveCharacter('eric'));
      Round? asked;
      int? saekoSeat;
      var qualified = false;
      late TableLoop loop;
      loop = TableLoop(
        room,
        botTurnPace: Duration.zero,
        afterCallPace: Duration.zero,
        callDiscardHold: Duration.zero,
        disconnectGrace: Duration.zero,
        abandonGrace: const Duration(milliseconds: 400),
        continueTimeout: Duration.zero,
        continueLock: Duration.zero,
        mortal: (seat, events) async {
          final last = events.last;
          if (asked != null || last['type'] != 'tsumo' || last['actor'] != seat) {
            return {'reaction': null}; // pass any call; later turns are not under test
          }
          asked = loop.round;
          saekoSeat = seat;
          // Nine kinds of terminals/honors and five duplicates, planted as
          // kyuushu_kyuuhai_test.dart does: the point is the reply handling.
          const codes = [
            '1m', '9m', '1p', '9p', '1s', '9s', 'E', 'S', 'W', //
            '1m', '9m', '1p', '9p', '1s',
          ];
          loop.round.seats[seat].hand = [
            for (var i = 0; i < codes.length; i++) Tile(700 + i, _typeFor(codes[i])),
          ];
          qualified = loop.round.canDeclareKyuushu(seat);
          if (!qualified) {
            return {'reaction': null}; // not the first go-around: try again
          }
          return {
            'reaction': {
              'type': 'ryukyoku',
              'actor': seat,
              'reason': 'kyushu_kyuhai',
            }
          };
        },
      );
      loop.start();
      loop.handleDisconnect(0); // every seat a bot, so the hand plays itself
      for (var i = 0; i < 200 && !(asked?.finished ?? false); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final round = asked;
      if (round == null || !round.finished || !qualified) continue;
      expect(round.result!.kind, RoundEndKind.abortiveDraw,
          reason: 'Mortal said kyuushu kyuuhai; the table must abort the hand');
      expect(round.seats[saekoSeat!].allDiscards, isEmpty,
          reason: 'an aborted hand is not a discard');
      return;
    }
    fail('no attempt got Saeko a first-go-around turn');
  });
}

TileType _typeFor(String code) => switch (code) {
      '1m' => TileType.man1,
      '9m' => TileType.man9,
      '1p' => TileType.pin1,
      '9p' => TileType.pin9,
      '1s' => TileType.sou1,
      '9s' => TileType.sou9,
      'E' => TileType.ton,
      'S' => TileType.nan,
      'W' => TileType.shaa,
      _ => throw ArgumentError(code),
    };
