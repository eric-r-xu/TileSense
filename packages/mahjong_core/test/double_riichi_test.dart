import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

/// Double riichi is only for a riichi declared on the seat's very first
/// discard, before any call or kan. The dealer's second discard used to still
/// count: the first-go-around window was only closed *after* that discard
/// landed, and a kan in riichi mode never closed it at all.
void main() {
  Round newRound() => Round(
        seed: 7,
        dealer: 0,
        roundWind: Wind.east,
        startingPoints: List.filled(4, Ruleset.riichi.startingPoints),
      );

  /// Plays one plain (non-riichi) discard for the seat on turn, passing on
  /// any call offer so the go-around is not interrupted.
  void plainDiscard(Round r) {
    final seat = r.turn;
    r.discard(seat, r.legalDiscards(seat).first);
    if (r.phase == RoundPhase.callOffer) r.resolveCalls({});
  }

  test('riichi on the first discard is double riichi', () {
    final r = newRound();
    r.discard(0, r.legalDiscards(0).first, declareRiichi: true);
    expect(r.seats[0].doubleRiichi, isTrue);
  });

  test('non-dealer riichi on their first discard is double riichi', () {
    final r = newRound();
    plainDiscard(r);
    expect(r.turn, 1);
    r.discard(1, r.legalDiscards(1).first, declareRiichi: true);
    expect(r.seats[1].doubleRiichi, isTrue);
  });

  test("dealer riichi on their second discard is plain riichi", () {
    final r = newRound();
    for (var i = 0; i < 4; i++) {
      plainDiscard(r);
    }
    expect(r.turn, 0);
    r.discard(0, r.legalDiscards(0).first, declareRiichi: true);
    expect(r.seats[0].riichi, isTrue);
    expect(r.seats[0].doubleRiichi, isFalse);
  });

  test('a concealed kan ends the double riichi window', () {
    final r = newRound();
    plainDiscard(r);
    // Give seat 1 a concealed quad of a type nobody else holds a copy of.
    final seat = r.seats[1];
    const type = TileType.man1;
    for (final s in r.seats) {
      s.hand.removeWhere((t) => t.type == type);
    }
    seat.hand.addAll([for (var i = 0; i < 4; i++) Tile(900 + i, type)]);
    r.closedKan(1, type);
    r.discard(1, r.legalDiscards(1).first, declareRiichi: true);
    expect(r.seats[1].doubleRiichi, isFalse);
  });

  test("a concealed kan breaks another seat's ippatsu", () {
    final r = newRound();
    r.discard(0, r.legalDiscards(0).first, declareRiichi: true);
    if (r.phase == RoundPhase.callOffer) r.resolveCalls({});
    expect(r.seats[0].ippatsu, isTrue);
    final seat = r.seats[1];
    const type = TileType.man1;
    for (final s in r.seats) {
      s.hand.removeWhere((t) => t.type == type);
    }
    seat.hand.addAll([for (var i = 0; i < 4; i++) Tile(900 + i, type)]);
    r.closedKan(1, type);
    expect(r.seats[0].ippatsu, isFalse);
  });
}
