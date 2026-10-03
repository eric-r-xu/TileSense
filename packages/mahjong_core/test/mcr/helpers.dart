import 'package:mahjong_core/mahjong_core.dart';

List<Tile> tiles(String text) {
  var id = 0;
  return [
    for (final match in RegExp(r'([1-9]+)([mpsz])').allMatches(text))
      for (final digit in match[1]!.split(''))
        Tile(id++,
            typeFrom34(('mpsz'.indexOf(match[2]!) * 9) + int.parse(digit) - 1))
  ];
}

HandScore score(String text,
    {int open = 0,
    Set<int> kongs = const {},
    Set<int> concealedKongs = const {},
    bool self = false,
    bool last = true,
    bool lastCopy = false,
    bool replacement = false,
    bool robbed = false,
    int flowers = 0,
    Wind seat = Wind.south,
    int? winIndex}) {
  final pieces = text.split(' ');
  final hand = <Tile>[];
  final melds = <Meld>[];
  for (var i = 0; i < pieces.length; i++) {
    final ts = tiles(pieces[i]);
    if (i < open || kongs.contains(i) || concealedKongs.contains(i)) {
      melds.add(Meld(
          kind: kongs.contains(i) || concealedKongs.contains(i)
              ? MeldKind.kan
              : ts.first.type == ts.last.type
                  ? MeldKind.triplet
                  : MeldKind.sequence,
          low: ts.first.type,
          concealed: concealedKongs.contains(i),
          tiles: ts));
    } else {
      hand.addAll(ts);
    }
  }
  final win = hand.removeAt(winIndex ?? hand.length - 1);
  return scoreMcrHand(
      hand,
      win,
      melds,
      ScoreContext(
        roundWind: Wind.east,
        seatWind: seat,
        isTsumo: self,
        closed: melds.every((m) => m.concealed),
        haitei: self && last,
        houtei: !self && last,
        rinshan: replacement,
        chankan: robbed,
        flowers: TileType.values.where((t) => t.isBonus).take(flowers).toList(),
      ),
      mcr: McrScoreContext(lastTile: lastCopy));
}

Set<String> names(HandScore s) => s.yaku.map((f) => f.name).toSet();
