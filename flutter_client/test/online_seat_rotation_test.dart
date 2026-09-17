import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart' show Character;

/// Regression test for a bug where a guest dealt into any server seat other
/// than 0 saw the wrong player at their own "bottom" position and the wrong
/// character controlling their neighbors: `seatLabel`/`characterForSeat`
/// receive a *local* seat (the same rotated frame `round` is built in, where
/// 0 is always "me"), but were comparing that number directly against
/// `lobbySeats`, which is indexed by the real, unrotated server seat. The
/// bug only showed for guests seated anywhere but server seat 0, which is
/// exactly what made it easy to miss.
void main() {
  final seats = [
    const LobbySeat(
      seat: 0,
      name: 'Eric',
      character: Character.eric,
      isBot: false,
      isHost: true,
      connected: true,
    ),
    const LobbySeat(
      seat: 1,
      name: 'Matthew',
      character: Character.hubert,
      isBot: false,
      isHost: false,
      connected: true,
    ),
    const LobbySeat(
      seat: 2,
      name: null,
      character: Character.grant,
      isBot: true,
      isHost: false,
      connected: true,
    ),
    const LobbySeat(
      seat: 3,
      name: null,
      character: Character.astaroth,
      isBot: true,
      isHost: false,
      connected: true,
    ),
  ];

  test(
      'a guest at server seat 0 sees themselves at local seat 0 (identity case)',
      () {
    expect(OnlineGameController.labelForLocalSeat(seats, 0, 0), 'Eric (you)');
    expect(OnlineGameController.characterForLocalSeat(seats, 0, 0),
        Character.eric);
  });

  test('a guest at server seat 1 still sees themselves at local seat 0', () {
    // This is the reported bug: Matthew is dealt into server seat 1, so his
    // own local seat 0 ("the bottom, you") must resolve to his own entry —
    // not to whoever the server happens to call seat 0.
    expect(
        OnlineGameController.labelForLocalSeat(seats, 1, 0), 'Matthew (you)');
    expect(OnlineGameController.characterForLocalSeat(seats, 1, 0),
        Character.hubert);
  });

  test('local seats 1-3 wrap forward through the remaining server seats', () {
    // mySeat=1 (Matthew): local 1 -> server 2, local 2 -> server 3,
    // local 3 -> server 0 (Eric) — the inverse of
    // `buildRoundFromSnapshot`'s `localSeat = (serverSeat - mySeat + 4) % 4`.
    expect(OnlineGameController.labelForLocalSeat(seats, 1, 1), 'Bot');
    expect(OnlineGameController.characterForLocalSeat(seats, 1, 1),
        Character.grant);
    expect(OnlineGameController.labelForLocalSeat(seats, 1, 2), 'Bot');
    expect(OnlineGameController.characterForLocalSeat(seats, 1, 2),
        Character.astaroth);
    expect(OnlineGameController.labelForLocalSeat(seats, 1, 3), 'Eric');
    expect(OnlineGameController.characterForLocalSeat(seats, 1, 3),
        Character.eric);
  });

  test('an unseated slot falls back to a seat number and Hubert', () {
    final sparse = [seats[0]];
    expect(OnlineGameController.labelForLocalSeat(sparse, 0, 2), 'Seat 3');
    expect(OnlineGameController.characterForLocalSeat(sparse, 0, 2),
        Character.hubert);
  });
}
