import 'package:mahjong_core/mahjong_core.dart';

var _nextId = 1000;

/// Tiles from shorthand like `123m 45p`, each with a fresh unique id so hands
/// built in one test never collide.
List<Tile> tiles(String text) => [
      for (final match in RegExp(r'([1-9]+)([mps])').allMatches(text))
        for (final digit in match[1]!.split(''))
          Tile(_nextId++,
              typeFrom34('mps'.indexOf(match[2]!) * 9 + int.parse(digit) - 1))
    ];

/// Scores [text], a hand written as space-separated groups whose last tile is
/// the winning tile. Groups whose index is in [open] are exposed pungs, in
/// [kongs] exposed kongs, in [concealedKongs] concealed kongs.
HandScore score(String text,
    {Set<int> open = const {},
    Set<int> kongs = const {},
    Set<int> concealedKongs = const {},
    bool self = false,
    bool last = false,
    bool replacement = false,
    bool robbed = false,
    bool afterKong = false}) {
  final pieces = text.split(' ');
  final hand = <Tile>[];
  final melds = <Meld>[];
  for (var i = 0; i < pieces.length; i++) {
    final ts = tiles(pieces[i]);
    if (open.contains(i) || kongs.contains(i) || concealedKongs.contains(i)) {
      melds.add(Meld(
          kind: kongs.contains(i) || concealedKongs.contains(i)
              ? MeldKind.kan
              : MeldKind.triplet,
          low: ts.first.type,
          concealed: concealedKongs.contains(i),
          tiles: ts));
    } else {
      hand.addAll(ts);
    }
  }
  final win = hand.removeLast();
  return scoreSichuanHand(
      hand,
      win,
      melds,
      ScoreContext(
        roundWind: Wind.east,
        seatWind: Wind.south,
        isTsumo: self,
        closed: melds.every((m) => m.concealed),
        haitei: self && last,
        houtei: !self && last,
        rinshan: replacement,
        chankan: robbed,
        afterKong: afterKong,
      ));
}

Set<String> names(HandScore s) => s.yaku.map((y) => y.name).toSet();

/// A round with every seat's void suit set to [voids] (default sou), the deal
/// replaced by [wallTiles] drawn after 52 filler tiles, and the turn with
/// seat 0 ready to discard. Tests then set the seats' hands directly.
Round fixture({
  List<int> voids = const [2, 2, 2, 2],
  List<Tile> wallTiles = const [],
  int dealer = 0,
}) {
  final filler = tiles('1111m 2222m 3333m 4444m 5555m 6666m 7777m 8888m 9999m 1111p 2222p 3333p 4444p');
  final wall = SichuanWall.fromTiles([...filler, ...wallTiles]);
  final round = Round(
    seed: 1,
    dealer: dealer,
    roundWind: Wind.east,
    startingPoints: List.filled(4, 0),
    ruleset: Ruleset.sichuan,
    wall: wall,
  );
  for (var i = 0; i < 4; i++) {
    round.seats[i].voidSuit = voids[i];
  }
  round.turn = dealer;
  round.phase = RoundPhase.discarding;
  return round;
}

void setHand(Round round, int seat, String text, {String? drawn}) {
  final s = round.seats[seat];
  s.hand = sortByType(tiles(text));
  if (drawn != null) {
    final d = tiles(drawn).single;
    s.hand = [...s.hand, d];
    s.drawn = d;
  }
}

/// 13 tiles with no sou, no pair-wait and nowhere near ready.
const junk = '147m 258p 369m 14p 7p 2m';
