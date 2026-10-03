/// MCR fan detection and maximum legal combination, per §3.9.1 and Appendix 1.
library;

import '../meld.dart';
import '../scoring.dart';
import '../tile.dart';
import 'mcr_fan.dart';
import 'mcr_hand_parse.dart';

class McrScoreContext {
  const McrScoreContext({this.lastTile = false});

  /// Three other copies were publicly exposed before the winning tile.
  final bool lastTile;
}

class _FanUse {
  const _FanUse(this.id, [this.mask = 0, this.count = 1]);
  final int id, mask, count;
  McrFan get fan => mcrFans[id - 1];
  int get points => fan.points * count;
}

HandScore scoreMcrHand(
    List<Tile> concealed, Tile winTile, List<Meld> melds, ScoreContext ctx,
    {bool isDealer = false, McrScoreContext mcr = const McrScoreContext()}) {
  if (![...concealed, winTile].every((t) => t.type.isPlayingTile) ||
      melds.any((m) =>
          m.kind == MeldKind.pair || !m.types.every((t) => t.isPlayingTile)))
    return HandScore.invalid();
  final allTypes = [
    ...concealed.map((t) => t.type),
    winTile.type,
    ...melds.expand((m) => m.types)
  ];
  final allCounts = List<int>.filled(34, 0);
  for (final t in allTypes) {
    allCounts[t.index - 1]++;
  }
  if (allCounts.any((n) => n > 4)) return HandScore.invalid();
  final shapes = decomposeMcr(toCounts34([...concealed, winTile]),
      openMelds: melds.length);
  if (shapes.isEmpty) return HandScore.invalid();
  final soleWait = waitTilesMcr(concealed, openMelds: melds.length).length == 1;
  List<_FanUse>? best;
  var bestPoints = -1;
  for (final shape in shapes) {
    final d = shape.hand;
    final groups = [...melds, ...d.melds];
    // Enumerate which concealed element received the winning tile. Never
    // borrow a wait or concealed-pung interpretation from another reading.
    final assignments = <int>[
      if (d.pair == winTile.type) -1,
      for (var i = melds.length; i < groups.length; i++)
        if (groups[i].types.contains(winTile.type)) i,
      if (shape.knitted.contains(winTile.type.index - 1) ||
          d.kokushi ||
          d.sevenPairs)
        -2,
      if (shape.honorsKnitted) -2,
    ];
    for (final assignment in assignments.toSet()) {
      final candidates = _detect(shape, groups, melds, allTypes, allCounts,
          concealed, winTile, ctx, mcr, soleWait, assignment);
      final chosen = _maximum(candidates);
      if (chosen.isEmpty) chosen.add(const _FanUse(43));
      final points = chosen.fold<int>(0, (a, f) => a + f.points);
      if (points > bestPoints) {
        bestPoints = points;
        best = chosen;
      }
    }
  }
  if (best == null || bestPoints < 8) return HandScore.invalid();
  final flowers = ctx.flowersEnabled
      ? ctx.flowers.where((t) => t.isBonus).toSet().length
      : 0;
  final total = bestPoints + flowers;
  return HandScore(
      yaku: [
        for (final f in best)
          YakuResult(
              f.id == 67 && f.count == 3
                  ? 'Melded and Concealed Kongs'
                  : f.fan.name,
              f.points),
        if (flowers > 0) YakuResult(mcrFans[80].name, flowers),
      ],
      han: total,
      fu: 0,
      yakuman: 0,
      points: ctx.isTsumo ? 3 * (total + 8) : total + 24,
      dealerPays: total + 8,
      nonDealerPays: total + 8,
      limitName: '',
      valid: true,
      mcrQualifyingPoints: bestPoints,
      mcrFlowerPoints: flowers);
}

List<_FanUse> _detect(
    McrShape shape,
    List<Meld> groups,
    List<Meld> exposed,
    List<TileType> types,
    List<int> counts,
    List<Tile> concealed,
    Tile win,
    ScoreContext ctx,
    McrScoreContext mcr,
    bool soleWait,
    int assignment) {
  final out = <_FanUse>[];
  void add(int id, bool yes, {int mask = 0, int count = 1}) {
    if (yes && count > 0) out.add(_FanUse(id, mask, count));
  }

  final d = shape.hand;
  final standard = !d.sevenPairs &&
      !d.kokushi &&
      !shape.honorsKnitted &&
      shape.knitted.isEmpty;
  final pungs = [
    for (var i = 0; i < groups.length; i++)
      if (groups[i].isTripletLike) i
  ];
  final chows = [
    for (var i = 0; i < groups.length; i++)
      if (groups[i].isSequence) i
  ];
  final winds = pungs.where((i) => groups[i].low.isWind).toList();
  final dragons = pungs.where((i) => groups[i].low.isDragon).toList();
  final kongs = pungs.where((i) => groups[i].isKan).toList();
  final hiddenKongs = kongs.where((i) => groups[i].concealed).length;
  final hiddenPungs = pungs
      .where((i) =>
          groups[i].concealed &&
          (ctx.isTsumo || i != assignment || i < exposed.length))
      .length;
  final suits = types.where((t) => t.isSuit).map((t) => t.suit).toSet();
  final honors = types.any((t) => t.isHonor);
  bool all(bool Function(TileType) f) => types.every(f);
  int mask(Iterable<int> ids) => ids.fold(0, (a, i) => a | (1 << i));
  add(1, winds.length == 4);
  add(2, dragons.length == 3);
  add(
      3,
      all((t) => const [
            TileType.sou2,
            TileType.sou3,
            TileType.sou4,
            TileType.sou6,
            TileType.sou8,
            TileType.hatsu
          ].contains(t)));
  final before = toCounts34(concealed);
  add(
      4,
      exposed.isEmpty &&
          suits.length == 1 &&
          !honors &&
          List.generate(34, (i) => i).every((i) =>
              before[i] ==
              (i ~/ 9 == suits.first && i < 27
                  ? (i % 9 == 0 || i % 9 == 8 ? 3 : 1)
                  : 0)));
  add(5, kongs.length == 4);
  final pairIndices = [
    for (var i = 0; i < 34; i++)
      if (counts[i] == 2) i
  ];
  add(
      6,
      d.sevenPairs &&
          suits.length == 1 &&
          !honors &&
          pairIndices.length == 7 &&
          pairIndices.last - pairIndices.first == 6);
  add(7, d.kokushi);
  add(8, all((t) => t.isTerminal));
  add(9, winds.length == 3 && (d.pair?.isWind ?? false));
  add(10, dragons.length == 2 && (d.pair?.isDragon ?? false));
  add(11, all((t) => t.isHonor));
  add(12, hiddenPungs == 4);
  add(
      13,
      standard &&
          chows.length == 4 &&
          suits.length == 1 &&
          d.pair?.number == 5 &&
          chows.where((i) => groups[i].low.number == 1).length == 2 &&
          chows.where((i) => groups[i].low.number == 7).length == 2);
  add(17, kongs.length == 3);
  add(18, honors && suits.isNotEmpty && all((t) => t.isTerminalOrHonor));
  add(19, d.sevenPairs);
  add(20, shape.honorsKnitted && counts.skip(27).every((n) => n == 1));
  add(21,
      standard && pungs.length == 4 && all((t) => t.isSuit && t.number.isEven));
  add(22, suits.length == 1 && !honors);
  add(25, all((t) => t.isSuit && t.number >= 7));
  add(26, all((t) => t.isSuit && t.number >= 4 && t.number <= 6));
  add(27, all((t) => t.isSuit && t.number <= 3));
  add(
      29,
      standard &&
          chows.length == 4 &&
          d.pair?.number == 5 &&
          chows.every((i) => groups[i].low.suit != d.pair!.suit) &&
          {for (final i in chows) groups[i].low.suit}.length == 2 &&
          {for (final i in chows) groups[i].low.index}.length == 4 &&
          chows.every((i) => [1, 7].contains(groups[i].low.number)));
  add(
      31,
      standard &&
          d.pair?.number == 5 &&
          groups.every((m) => m.types.any((t) => t.number == 5)));
  add(33, hiddenPungs == 3);
  add(34, shape.honorsKnitted);
  add(35,
      shape.knitted.isNotEmpty && shape.knitted.every((i) => counts[i] > 0));
  add(36, all((t) => t.isSuit && t.number >= 6));
  add(37, all((t) => t.isSuit && t.number <= 4));
  add(38, winds.length >= 3, mask: mask(winds));
  add(
      40,
      all((t) =>
          t == TileType.haku ||
          (t.isPin && [1, 2, 3, 4, 5, 8, 9].contains(t.number)) ||
          (t.isSou && [2, 4, 5, 6, 8, 9].contains(t.number))));
  add(44, ctx.isTsumo && ctx.haitei);
  add(45, !ctx.isTsumo && ctx.houtei);
  add(46, ctx.isTsumo && ctx.rinshan);
  add(47, !ctx.isTsumo && ctx.chankan);
  add(48, hiddenKongs == 2);
  add(49, standard && pungs.length == 4);
  add(50, suits.length == 1 && honors);
  add(
      52,
      suits.length == 3 &&
          types.any((t) => t.isWind) &&
          types.any((t) => t.isDragon));
  add(
      53,
      exposed.length == 4 &&
          exposed.every((m) => !m.concealed) &&
          !ctx.isTsumo);
  add(54, dragons.length >= 2, mask: mask(dragons));
  add(
      55,
      standard &&
          (d.pair?.isTerminalOrHonor ?? false) &&
          groups.every((m) => m.hasTerminalOrHonor));
  add(56, ctx.closed && ctx.isTsumo);
  add(57, kongs.length - hiddenKongs == 2);
  // Appendix 1, fan 57: one concealed + one melded kong is six points.
  if (kongs.length == 2 && hiddenKongs == 1) {
    out.add(const _FanUse(67, 0, 3));
  } else {
    add(67, hiddenKongs == 1);
  }
  add(58, mcr.lastTile && !ctx.chankan);
  for (final i in pungs) {
    final t = groups[i].low;
    add(59, t.isDragon, mask: 1 << i);
    add(60, t == ctx.roundWind.tile, mask: 1 << i);
    add(61, t == ctx.seatWind.tile, mask: 1 << i);
    add(73, t.isTerminal || t.isWind, mask: 1 << i);
  }
  add(62, ctx.closed && !ctx.isTsumo);
  add(
      63,
      (standard && chows.length == 4 ||
              shape.knitted.isNotEmpty &&
                  !shape.honorsKnitted &&
                  chows.length == 1) &&
          !honors);
  add(64, true,
      count: List.generate(34, (i) => i)
          .where((i) =>
              counts[i] == 4 && !kongs.any((k) => groups[k].low.index - 1 == i))
          .length);
  add(66, hiddenPungs == 2);
  add(68, all((t) => t.isSuit && !t.isTerminal));
  add(
      74,
      kongs.length - hiddenKongs == 1 &&
          !(kongs.length == 2 && hiddenKongs == 1));
  add(75, suits.length == 2);
  add(76, !honors);
  if (soleWait && !d.sevenPairs && !d.kokushi && !shape.honorsKnitted) {
    add(79, assignment == -1);
    if (assignment >= 0 && groups[assignment].isSequence) {
      final low = groups[assignment].low;
      add(
          77,
          low.number == 1 && win.type.number == 3 ||
              low.number == 7 && win.type.number == 7);
      add(78, win.type.number == low.number + 1);
    }
  }
  add(80, ctx.isTsumo);
  // Relationships use physical group masks: a pair of groups cannot be
  // reused to score another relationship, and implied sub-patterns cannot stack.
  for (var subset = 1; subset < (1 << groups.length); subset++) {
    final ids = [
      for (var i = 0; i < groups.length; i++)
        if (subset & (1 << i) != 0) i
    ];
    final ms = ids.map((i) => groups[i]).toList()
      ..sort((a, b) => a.low.number.compareTo(b.low.number));
    final n = ms.length;
    if (n < 2 || n > 4) continue;
    final seq = ms.every((m) => m.isSequence);
    final pung = ms.every((m) => m.isTripletLike && m.low.isSuit);
    final sameSuit = ms.every((m) => m.low.suit == ms.first.low.suit);
    final different = ms.map((m) => m.low.suit).toSet().length == n;
    final sameNumber = ms.every((m) => m.low.number == ms.first.low.number);
    bool shifted(int step) => List.generate(n - 1, (i) => i)
        .every((i) => ms[i + 1].low.number - ms[i].low.number == step);
    void relationship(int id, bool yes) => add(id, yes, mask: subset);
    if (n == 4) {
      relationship(14, seq && sameSuit && sameNumber);
      relationship(15, pung && sameSuit && shifted(1));
      relationship(16, seq && sameSuit && (shifted(1) || shifted(2)));
    } else if (n == 3) {
      relationship(23, seq && sameSuit && sameNumber);
      relationship(24, pung && sameSuit && shifted(1));
      relationship(
          28, seq && sameSuit && shifted(3) && ms.first.low.number == 1);
      relationship(30, seq && sameSuit && (shifted(1) || shifted(2)));
      relationship(32, pung && different && sameNumber);
      relationship(
          39, seq && different && shifted(3) && ms.first.low.number == 1);
      relationship(41, seq && different && sameNumber);
      relationship(42, pung && different && shifted(1));
      relationship(51, seq && different && shifted(1));
    } else {
      relationship(65, pung && different && sameNumber);
      relationship(69, seq && sameSuit && sameNumber);
      relationship(70, seq && different && sameNumber);
      relationship(71, seq && sameSuit && shifted(3));
      relationship(
          72,
          seq &&
              sameSuit &&
              ms.first.low.number == 1 &&
              ms.last.low.number == 7);
    }
  }
  return out;
}

bool _excludes(_FanUse a, _FanUse b) =>
    a.fan.excludes.contains(b.id) &&
    (!a.fan.setScoped || b.mask == 0 || (a.mask & b.mask) == b.mask);

bool _relationship(_FanUse f) => const {
      14,
      15,
      16,
      23,
      24,
      28,
      30,
      32,
      39,
      41,
      42,
      51,
      65,
      69,
      70,
      71,
      72
    }.contains(f.id);

List<_FanUse> _maximum(List<_FanUse> candidates) {
  candidates.sort((a, b) => b.points.compareTo(a.points));
  final suffix = List<int>.filled(candidates.length + 1, 0);
  for (var i = candidates.length - 1; i >= 0; i--) {
    suffix[i] = suffix[i + 1] + candidates[i].points;
  }
  var bestPoints = -1;
  var best = <_FanUse>[];
  final chosen = <_FanUse>[];
  void search(int i, int points, int used) {
    if (points + suffix[i] <= bestPoints) return;
    if (i == candidates.length) {
      bestPoints = points;
      best = List.of(chosen);
      return;
    }
    final next = candidates[i];
    var allowed = !chosen.any((f) => _excludes(f, next) || _excludes(next, f));
    if (_relationship(next)) {
      final overlap = used & next.mask;
      // Joining an existing combination can add only one previously used set.
      if (overlap != 0 && overlap & (overlap - 1) != 0) allowed = false;
      if (chosen.any((f) =>
          _relationship(f) && f.id == next.id && f.mask & next.mask != 0))
        allowed = false;
    }
    if (allowed) {
      chosen.add(next);
      search(i + 1, points + next.points,
          _relationship(next) ? used | next.mask : used);
      chosen.removeLast();
    }
    search(i + 1, points, used);
  }

  search(0, 0, 0);
  return best;
}
