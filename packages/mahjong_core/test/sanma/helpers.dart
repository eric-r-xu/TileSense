import 'package:mahjong_core/mahjong_core.dart';

var _nextId = 5000;

/// Tiles from shorthand like `19m 45p 1z`, each with a fresh unique id; `z`
/// is the honors in the order east, south, west, north, white, green, red.
List<Tile> tiles(String text) => [
      for (final match in RegExp(r'([1-9]+)([mpsz])').allMatches(text))
        for (final digit in match[1]!.split(''))
          Tile(_nextId++,
              typeFrom34('mpsz'.indexOf(match[2]!) * 9 + int.parse(digit) - 1))
    ];

/// A sanma round dealt from filler, with [live] the next draws after the
/// deal (four sou by default), [replacements] the dead wall's replacement draws and [indicators]
/// its dora/ura pairs. Seat [dealer] is to discard; tests set hands directly.
Round fixture({
  List<Tile>? live,
  List<Tile> replacements = const [],
  List<Tile>? indicators,
  int dealer = 0,
  List<int>? points,
}) {
  final filler = tiles(
      '1111p 2222p 3333p 4444p 5555p 6666p 7777p 8888p 9999p 111s');
  final wall = SanmaWall.fromTiles(
    live: [...filler, ...(live ?? tiles('6s 7s 8s 9s'))],
    replacements: replacements.isEmpty ? tiles('22s 33s 44s 55s') : replacements,
    indicators: indicators ?? tiles('7z 6z 5z 6s 7s 8s'),
  );
  final round = Round(
    seed: 1,
    dealer: dealer,
    roundWind: Wind.east,
    startingPoints: points ?? List.filled(4, 35000),
    ruleset: Ruleset.sanma,
    wall: wall,
  );
  round.turn = dealer;
  round.phase = RoundPhase.discarding;
  return round;
}

void setHand(Round round, int seat, String text, {String? drawn}) {
  final s = round.seats[seat];
  s.hand = sortByType(tiles(text));
  s.drawn = null;
  if (drawn != null) {
    final d = tiles(drawn).single;
    s.hand = [...s.hand, d];
    s.drawn = d;
  }
}
