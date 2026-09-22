import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';
import 'package:tilesense_mp/room.dart';
import 'package:tilesense_mp/table_loop.dart';

/// Kyuushu kyuuhai over the network: a `{"type":"action","kind":"kyuushu"}`
/// message reaches `Round.declareKyuushu` and actually aborts the round.
/// Same direct `Room`/`TableLoop` construction `seat_shuffle_test.dart` and
/// `telemetry_test.dart` use — nothing here needs the WebSocket layer.
void main() {
  test('a kyuushu action aborts the round for the declaring seat', () async {
    final room = Room(code: 'GAME01', ruleset: Ruleset.riichi, hanchan: true);
    for (final id in ['alice', 'bob', 'carol', 'dave']) {
      room.seats[room.seats.indexWhere((s) => s == null)] =
          Seat(guestId: id, name: id, character: room.resolveCharacter());
    }
    final loop = TableLoop(room, botTurnPace: Duration.zero);
    loop.start();
    // Let `_run()` reach the point where it is awaiting the seat on turn —
    // everything up to that await is synchronous.
    await Future<void>.delayed(Duration.zero);

    final seat = loop.round.turn;
    // Nine kinds of terminals/honors, plus five duplicates to round out a
    // 14-tile hand — overwritten directly, same as the round-level tests
    // do, since the point here is the message plumbing, not the deal.
    const codes = [
      '1m', '9m', '1p', '9p', '1s', '9s', 'E', 'S', 'W', // nine distinct
      '1m', '9m', '1p', '9p', '1s', // five duplicates
    ];
    loop.round.seats[seat].hand = [
      for (var i = 0; i < codes.length; i++) Tile(700 + i, _typeFor(codes[i])),
    ];
    expect(loop.round.canDeclareKyuushu(seat), isTrue,
        reason: 'sanity: the planted hand actually qualifies');

    loop.handleMessage(seat, {'type': 'action', 'kind': 'kyuushu'});
    await Future<void>.delayed(Duration.zero);

    expect(loop.round.phase, RoundPhase.finished);
    expect(loop.round.result!.kind, RoundEndKind.abortiveDraw);
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
