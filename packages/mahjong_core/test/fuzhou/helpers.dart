import 'package:mahjong_core/mahjong_core.dart';

var _nextId = 5000;

/// Tiles from shorthand like `123m 45p`, each with a fresh unique id.
List<Tile> tiles(String text) => [
      for (final match in RegExp(r'([1-9]+)([mps])').allMatches(text))
        for (final digit in match[1]!.split(''))
          Tile(_nextId++,
              typeFrom34('mps'.indexOf(match[2]!) * 9 + int.parse(digit) - 1))
    ];

/// One suit tile type from `5m`, `9s`...
TileType type(String code) => tiles(code).single.type;

/// A 16-tile hand nowhere near ready: every tile three apart, so no pair, run
/// or wait to speak of.
const junk16 = '147m 147p 147s 258m 258p 3s';

/// A round dealt from a fixed wall: every seat holds [junk16], the dealer will
/// flip [gold], and [draws] come off the wall in order (the first is the
/// dealer's first draw).
Round fixture({
  Tile? gold,
  List<Tile> draws = const [],
  int dealer = 0,
  int honba = 0,
}) {
  final deal = <Tile>[];
  for (var i = 0; i < 4; i++) {
    deal.addAll(tiles(junk16));
  }
  final wall = FuzhouWall.fromTiles([...deal, ...draws],
      gold: gold ?? Tile(-300, TileType.sou9));
  return Round(
    seed: 1,
    dealer: dealer,
    roundWind: Wind.east,
    honba: honba,
    startingPoints: List.filled(4, 500),
    ruleset: Ruleset.fuzhou,
    wall: wall,
  );
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

Set<String> names(HandScore s) => s.yaku.map((y) => y.name).toSet();

int points(HandScore s, String name) =>
    s.yaku.where((y) => y.name == name).fold(0, (a, y) => a + y.han);
