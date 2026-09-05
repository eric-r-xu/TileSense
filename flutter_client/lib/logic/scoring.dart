/// Hand scoring: yaku detection and han/fu -> points.
///
/// A documented *subset* of the Vala client's `source/Game/Logic/TileRules.vala`
/// (`Yaku.get_yaku`, `Scoring`). It covers the common yaku, the standard fu
/// table, the yakuman set, and dora/ura/aka. Rare fu corner cases and some
/// double-yakuman rules are approximated — this is a trainer, not a ruleset
/// arbiter.
library;

import 'hand_parse.dart';
import 'meld.dart';
import 'tile.dart';

class ScoreContext {
  ScoreContext({
    required this.roundWind,
    required this.seatWind,
    required this.isTsumo,
    required this.closed,
    this.riichi = false,
    this.doubleRiichi = false,
    this.ippatsu = false,
    this.haitei = false,
    this.houtei = false,
    this.rinshan = false,
    this.chankan = false,
    this.doraIndicators = const [],
    this.uraIndicators = const [],
    this.akaCount = 0,
  });

  final Wind roundWind;
  final Wind seatWind;
  final bool isTsumo;
  final bool closed;
  final bool riichi;
  final bool doubleRiichi;
  final bool ippatsu;
  final bool haitei;
  final bool houtei;
  final bool rinshan;
  final bool chankan;
  final List<TileType> doraIndicators;
  final List<TileType> uraIndicators;
  final int akaCount;
}

class YakuResult {
  const YakuResult(this.name, this.han, {this.yakuman = 0});
  final String name;
  final int han;
  final int yakuman;
}

class HandScore {
  HandScore({
    required this.yaku,
    required this.han,
    required this.fu,
    required this.yakuman,
    required this.points,
    required this.dealerPays,
    required this.nonDealerPays,
    required this.limitName,
    required this.valid,
  });

  final List<YakuResult> yaku;
  final int han;
  final int fu;
  final int yakuman;

  /// Total point swing for the winner.
  final int points;

  /// Tsumo: amount the dealer pays (0 when the winner is the dealer).
  final int dealerPays;

  /// Tsumo: amount each non-dealer pays. Ron: the full [points].
  final int nonDealerPays;

  final String limitName;
  final bool valid;

  static HandScore invalid() => HandScore(
        yaku: const [],
        han: 0,
        fu: 0,
        yakuman: 0,
        points: 0,
        dealerPays: 0,
        nonDealerPays: 0,
        limitName: '',
        valid: false,
      );
}

/// Score a winning hand. [concealed] is the 13-tile concealed hand (no win
/// tile), [winTile] the 14th, [openMelds] the player's calls.
HandScore scoreHand(
  List<Tile> concealed,
  Tile winTile,
  List<Meld> openMelds,
  ScoreContext ctx, {
  required bool isDealer,
}) {
  final all = [...concealed, winTile];
  final counts = toCounts34(all);
  final decomps = decompose(counts, openMelds: openMelds.length);
  if (decomps.isEmpty) return HandScore.invalid();

  HandScore? best;
  for (final d in decomps) {
    final s = _scoreDecomp(d, all, winTile, openMelds, ctx, isDealer: isDealer);
    if (s.valid && (best == null || s.points > best.points)) best = s;
  }
  return best ?? HandScore.invalid();
}

HandScore _scoreDecomp(
  HandDecomposition d,
  List<Tile> allTiles,
  Tile winTile,
  List<Meld> openMelds,
  ScoreContext ctx, {
  required bool isDealer,
}) {
  final yaku = <YakuResult>[];
  var yakuman = 0;

  // All groups (open + concealed) for hand-shape yaku.
  final groups = <Meld>[...openMelds, ...d.melds];

  // Every tile type in the hand, called melds included. [allTiles] is only the
  // concealed part plus the winning tile, so anything scanning the *whole*
  // hand — dora, and the honitsu/chinitsu suit check — has to add the melds
  // back in or a ponned dora goes uncounted and a called meld in a second suit
  // is invisible to the flush check.
  final allTypes = <TileType>[
    ...allTiles.map((t) => t.type),
    ...openMelds.expand((m) => m.types),
  ];

  if (d.kokushi) {
    yaku.add(const YakuResult('Kokushi Musou', 0, yakuman: 1));
    yakuman += 1;
  } else if (d.sevenPairs) {
    if (_isTsuuiisou(groups, d)) {
      yaku.add(const YakuResult('Tsuuiisou', 0, yakuman: 1));
      yakuman += 1;
    }
    yaku.add(const YakuResult('Chiitoitsu', 2));
  } else {
    yakuman += _yakumanYaku(groups, d, ctx, yaku, isDealer: isDealer);
    if (yakuman == 0) {
      _standardYaku(groups, d, allTypes, winTile, openMelds, ctx, yaku);
    }
  }

  // Dora only counts when there is at least one real yaku/yakuman.
  final hasRealYaku = yakuman > 0 || yaku.isNotEmpty;
  if (!hasRealYaku) return HandScore.invalid();

  if (yakuman == 0) {
    final dora = _countDora(allTypes, ctx.doraIndicators);
    if (dora > 0) yaku.add(YakuResult('Dora', dora));
    if (ctx.riichi || ctx.doubleRiichi) {
      final ura = _countDora(allTypes, ctx.uraIndicators);
      if (ura > 0) yaku.add(YakuResult('Ura Dora', ura));
    }
    if (ctx.akaCount > 0) yaku.add(YakuResult('Aka Dora', ctx.akaCount));
  }

  final han = yaku.fold(0, (a, y) => a + y.han);
  final fu = yakuman > 0
      ? 0
      : _calcFu(d, groups, winTile, ctx, yaku, isDealer: isDealer);

  return _finalise(yaku, han, fu, yakuman, ctx, isDealer: isDealer);
}

// --- yakuman ---------------------------------------------------------------

int _yakumanYaku(
  List<Meld> groups,
  HandDecomposition d,
  ScoreContext ctx,
  List<YakuResult> out, {
  required bool isDealer,
}) {
  var count = 0;
  final triplets = groups.where((g) => g.isTripletLike).toList();

  // Suuankou: four concealed triplets.
  final concealedTriplets =
      d.melds.where((g) => g.isTripletLike && g.concealed).length;
  if (concealedTriplets == 4) {
    out.add(const YakuResult('Suuankou', 0, yakuman: 1));
    count += 1;
  }

  // Daisangen / Shousangen handled here for the yakuman half.
  final dragonTriplets = triplets.where((g) => g.low.isDragon).length;
  if (dragonTriplets == 3) {
    out.add(const YakuResult('Daisangen', 0, yakuman: 1));
    count += 1;
  }

  // Suushiihou.
  final windTriplets = triplets.where((g) => g.low.isWind).length;
  final windPairIsWind = d.pair != null && d.pair!.isWind;
  if (windTriplets == 4) {
    out.add(const YakuResult('Daisuushii', 0, yakuman: 2));
    count += 2;
  } else if (windTriplets == 3 && windPairIsWind) {
    out.add(const YakuResult('Shousuushii', 0, yakuman: 1));
    count += 1;
  }

  // Tsuuiisou: all honors.
  if (_allGroupsAndPair(groups, d, (t) => t.isHonor)) {
    out.add(const YakuResult('Tsuuiisou', 0, yakuman: 1));
    count += 1;
  }

  // Chinroutou: all terminals.
  if (_allGroupsAndPair(groups, d, (t) => t.isTerminal)) {
    out.add(const YakuResult('Chinroutou', 0, yakuman: 1));
    count += 1;
  }

  // Ryuuiisou: all green.
  if (_allGroupsAndPair(groups, d, _isGreenType)) {
    out.add(const YakuResult('Ryuuiisou', 0, yakuman: 1));
    count += 1;
  }

  // Chuuren poutou: closed, one suit, 1112345678999 + any.
  if (ctx.closed && _isChuuren(groups, d)) {
    out.add(const YakuResult('Chuuren Poutou', 0, yakuman: 1));
    count += 1;
  }

  return count;
}

// --- standard yaku ------------------------------------------------------------

void _standardYaku(
  List<Meld> groups,
  HandDecomposition d,
  List<TileType> allTypes,
  Tile winTile,
  List<Meld> openMelds,
  ScoreContext ctx,
  List<YakuResult> out,
) {
  final closed = ctx.closed;
  final seqs = groups.where((g) => g.isSequence).toList();
  final triplets = groups.where((g) => g.isTripletLike).toList();

  if (ctx.doubleRiichi) {
    out.add(const YakuResult('Double Riichi', 2));
  } else if (ctx.riichi) {
    out.add(const YakuResult('Riichi', 1));
  }
  if (ctx.ippatsu) out.add(const YakuResult('Ippatsu', 1));
  if (closed && ctx.isTsumo) out.add(const YakuResult('Menzen Tsumo', 1));
  if (ctx.haitei) out.add(const YakuResult('Haitei Raoyue', 1));
  if (ctx.houtei) out.add(const YakuResult('Houtei Raoyui', 1));
  if (ctx.rinshan) out.add(const YakuResult('Rinshan Kaihou', 1));
  if (ctx.chankan) out.add(const YakuResult('Chankan', 1));

  // Tanyao.
  if (_allGroupsAndPair(groups, d, (t) => !t.isTerminalOrHonor)) {
    out.add(const YakuResult('Tanyao', 1));
  }

  // Yakuhai.
  for (final g in triplets) {
    if (g.low.isDragon) out.add(YakuResult('Yakuhai (${g.low.displayName})', 1));
    if (g.low == ctx.roundWind.tile) out.add(const YakuResult('Round Wind', 1));
    if (g.low == ctx.seatWind.tile) out.add(const YakuResult('Seat Wind', 1));
  }

  // Shousangen (non-yakuman half): 2 dragon triplets + dragon pair.
  final dragonTriplets = triplets.where((g) => g.low.isDragon).length;
  if (dragonTriplets == 2 && d.pair != null && d.pair!.isDragon) {
    out.add(const YakuResult('Shousangen', 2));
  }

  // Pinfu: closed, all sequences, non-yakuhai pair, ryanmen wait.
  if (closed &&
      seqs.length == 4 &&
      d.pair != null &&
      !_isYakuhaiPair(d.pair!, ctx) &&
      _isRyanmenWait(d, winTile)) {
    out.add(const YakuResult('Pinfu', 1));
  }

  // Iipeiko / Ryanpeikou (closed only).
  if (closed) {
    final pairsOfSeq = _identicalSequencePairs(d.melds);
    if (pairsOfSeq >= 2) {
      out.add(const YakuResult('Ryanpeikou', 3));
    } else if (pairsOfSeq == 1) {
      out.add(const YakuResult('Iipeiko', 1));
    }
  }

  // Sanshoku doujun.
  if (_hasSanshokuDoujun(seqs)) {
    out.add(YakuResult('Sanshoku Doujun', closed ? 2 : 1));
  }
  // Sanshoku doukou.
  if (_hasSanshokuDoukou(triplets)) {
    out.add(const YakuResult('Sanshoku Doukou', 2));
  }

  // Ittsu.
  if (_hasIttsu(seqs)) {
    out.add(YakuResult('Ittsu', closed ? 2 : 1));
  }

  // Chanta / Junchan.
  final everyGroupHasTOrH = groups.every((g) => g.hasTerminalOrHonor) &&
      (d.pair == null || d.pair!.isTerminalOrHonor);
  if (everyGroupHasTOrH && seqs.isNotEmpty) {
    final junchan = groups.every((g) => !_groupTypes(g).any((t) => t.isHonor)) &&
        (d.pair == null || !d.pair!.isHonor);
    out.add(YakuResult(junchan ? 'Junchan' : 'Chanta', closed ? (junchan ? 3 : 2) : (junchan ? 2 : 1)));
  }

  // Toitoi.
  if (triplets.length == 4) out.add(const YakuResult('Toitoi', 2));

  // Sanankou: three concealed triplets.
  final concealedTriplets = d.melds
      .where((g) => g.isTripletLike && g.concealed)
      .length;
  if (concealedTriplets == 3) out.add(const YakuResult('Sanankou', 2));

  // Sankantsu.
  if (groups.where((g) => g.isKan).length == 3) {
    out.add(const YakuResult('Sankantsu', 2));
  }

  // Honroutou.
  if (_allGroupsAndPair(groups, d, (t) => t.isTerminalOrHonor) &&
      triplets.length == 4) {
    out.add(const YakuResult('Honroutou', 2));
  }

  // Honitsu / Chinitsu.
  final suits = <int>{};
  var hasHonor = false;
  for (final t in allTypes) {
    if (t.isHonor) {
      hasHonor = true;
    } else {
      suits.add(t.suit);
    }
  }
  if (suits.length == 1) {
    if (!hasHonor) {
      out.add(YakuResult('Chinitsu', closed ? 6 : 5));
    } else {
      out.add(YakuResult('Honitsu', closed ? 3 : 2));
    }
  }
}

// --- fu ---------------------------------------------------------------------

int _calcFu(
  HandDecomposition d,
  List<Meld> groups,
  Tile winTile,
  ScoreContext ctx,
  List<YakuResult> yaku, {
  required bool isDealer,
}) {
  if (d.sevenPairs) return 25;

  final isPinfu = yaku.any((y) => y.name == 'Pinfu');
  if (isPinfu) return ctx.isTsumo ? 20 : 30;

  var fu = 20;
  if (ctx.closed && !ctx.isTsumo) fu += 10; // menzen ron
  if (ctx.isTsumo) fu += 2;

  for (final g in groups) {
    if (!g.isTripletLike) continue;
    final terminalHonor = g.low.isTerminalOrHonor;
    var base = terminalHonor ? 8 : 4; // closed simple = 4
    if (!g.concealed) base ~/= 2; // open
    if (g.isKan) base *= 4;
    fu += base;
  }

  // Pair value.
  if (d.pair != null && _isYakuhaiPair(d.pair!, ctx)) {
    fu += 2;
    if (d.pair! == ctx.roundWind.tile && d.pair! == ctx.seatWind.tile) fu += 2;
  }

  // Wait fu (kanchan / penchan / tanki = +2; ryanmen / shanpon = 0).
  if (_isTankiWait(d, winTile) ||
      _isKanchanWait(d, winTile) ||
      _isPenchanWait(d, winTile)) {
    fu += 2;
  }

  // Open hand with 20 fu (kuipinfu shape) stays at 20.
  if (fu == 20 && !ctx.closed && !ctx.isTsumo) return 20;

  return ((fu + 9) ~/ 10) * 10;
}

// --- final score ----------------------------------------------------------

HandScore _finalise(
  List<YakuResult> yaku,
  int han,
  int fu,
  int yakuman,
  ScoreContext ctx, {
  required bool isDealer,
}) {
  int basic;
  var limitName = '';

  if (yakuman > 0) {
    basic = 8000 * yakuman;
    limitName = yakuman == 1 ? 'Yakuman' : '$yakuman× Yakuman';
  } else {
    basic = fu * (1 << (han + 2));
    if (han >= 13) {
      basic = 8000;
      limitName = 'Kazoe Yakuman';
    } else if (han >= 11) {
      basic = 6000;
      limitName = 'Sanbaiman';
    } else if (han >= 8) {
      basic = 4000;
      limitName = 'Baiman';
    } else if (han >= 6) {
      basic = 3000;
      limitName = 'Haneman';
    } else if (han >= 5 || basic >= 2000) {
      basic = 2000;
      limitName = 'Mangan';
    }
  }

  int ceil100(int n) => ((n + 99) ~/ 100) * 100;

  int total;
  var dealerPays = 0;
  var nonDealerPays = 0;

  if (ctx.isTsumo) {
    if (isDealer) {
      nonDealerPays = ceil100(basic * 2);
      total = nonDealerPays * 3;
    } else {
      dealerPays = ceil100(basic * 2);
      nonDealerPays = ceil100(basic);
      total = dealerPays + nonDealerPays * 2;
    }
  } else {
    total = ceil100(basic * (isDealer ? 6 : 4));
    nonDealerPays = total;
  }

  return HandScore(
    yaku: yaku,
    han: han,
    fu: fu,
    yakuman: yakuman,
    points: total,
    dealerPays: dealerPays,
    nonDealerPays: nonDealerPays,
    limitName: limitName,
    valid: true,
  );
}

// --- helpers --------------------------------------------------------------

List<TileType> _groupTypes(Meld g) => g.types;

bool _isGreenType(TileType t) =>
    t == TileType.sou2 ||
    t == TileType.sou3 ||
    t == TileType.sou4 ||
    t == TileType.sou6 ||
    t == TileType.sou8 ||
    t == TileType.hatsu;

bool _allGroupsAndPair(
  List<Meld> groups,
  HandDecomposition d,
  bool Function(TileType) test,
) {
  for (final g in groups) {
    if (!g.types.every(test)) return false;
  }
  if (d.pair != null && !test(d.pair!)) return false;
  if (d.sevenPairs) {
    return d.melds.every((m) => test(m.low));
  }
  return true;
}

bool _isYakuhaiPair(TileType pair, ScoreContext ctx) =>
    pair.isDragon || pair == ctx.roundWind.tile || pair == ctx.seatWind.tile;

int _countDora(List<TileType> types, List<TileType> indicators) {
  var n = 0;
  for (final ind in indicators) {
    final target = ind.doraTarget;
    n += types.where((t) => t == target).length;
  }
  return n;
}

int _identicalSequencePairs(List<Meld> concealedMelds) {
  final seqs = concealedMelds.where((m) => m.isSequence).map((m) => m.low).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  var pairs = 0;
  for (var i = 0; i + 1 < seqs.length; i += 1) {
    if (seqs[i] == seqs[i + 1]) {
      pairs++;
      i++; // consume the pair
    }
  }
  return pairs;
}

bool _hasSanshokuDoujun(List<Meld> seqs) {
  for (final s in seqs) {
    if (!s.low.isSuit) continue;
    final n = s.low.number;
    final haveMan = seqs.any((x) => x.low.isMan && x.low.number == n);
    final havePin = seqs.any((x) => x.low.isPin && x.low.number == n);
    final haveSou = seqs.any((x) => x.low.isSou && x.low.number == n);
    if (haveMan && havePin && haveSou) return true;
  }
  return false;
}

bool _hasSanshokuDoukou(List<Meld> triplets) {
  for (final t in triplets) {
    if (!t.low.isSuit) continue;
    final n = t.low.number;
    final haveMan = triplets.any((x) => x.low.isMan && x.low.number == n);
    final havePin = triplets.any((x) => x.low.isPin && x.low.number == n);
    final haveSou = triplets.any((x) => x.low.isSou && x.low.number == n);
    if (haveMan && havePin && haveSou) return true;
  }
  return false;
}

bool _hasIttsu(List<Meld> seqs) {
  for (final suit in [0, 1, 2]) {
    final lows = seqs
        .where((s) => s.low.suit == suit)
        .map((s) => s.low.number)
        .toSet();
    if (lows.contains(1) && lows.contains(4) && lows.contains(7)) return true;
  }
  return false;
}

bool _isTsuuiisou(List<Meld> groups, HandDecomposition d) {
  if (d.sevenPairs) return d.melds.every((m) => m.low.isHonor);
  return false;
}

bool _isChuuren(List<Meld> groups, HandDecomposition d) {
  // Reconstruct the concealed tile multiset from the decomposition.
  final counts = List<int>.filled(34, 0);
  for (final g in d.melds) {
    for (final t in g.types) {
      counts[t.index - 1]++;
    }
  }
  if (d.pair != null) counts[d.pair!.index - 1] += 2;
  final suits = <int>{};
  for (var i = 0; i < 34; i++) {
    if (counts[i] > 0) {
      final t = typeFrom34(i);
      if (t.isHonor) return false;
      suits.add(t.suit);
    }
  }
  if (suits.length != 1) return false;
  final base = suits.first * 9;
  const pattern = [3, 1, 1, 1, 1, 1, 1, 1, 3];
  for (var i = 0; i < 9; i++) {
    if (counts[base + i] < pattern[i]) return false;
  }
  return true;
}

// Wait-shape detection: figure out which group the win tile completed.
bool _isRyanmenWait(HandDecomposition d, Tile winTile) {
  for (final m in d.melds.where((m) => m.isSequence)) {
    final n = m.low.number;
    if (winTile.type == m.low && n <= 7 && n >= 1) {
      // completed at the low end -> ryanmen unless penchan (12 waiting 3)
      if (n != 1) return true;
    }
    if (winTile.type == TileType.values[m.low.index + 2] && m.low.number <= 7) {
      // completed at the high end -> ryanmen unless penchan (89 waiting 7)
      if (m.low.number + 2 != 9) return true;
    }
  }
  return false;
}

bool _isTankiWait(HandDecomposition d, Tile winTile) =>
    d.pair != null && winTile.type == d.pair;

bool _isKanchanWait(HandDecomposition d, Tile winTile) {
  for (final m in d.melds.where((m) => m.isSequence)) {
    if (winTile.type == TileType.values[m.low.index + 1]) return true;
  }
  return false;
}

bool _isPenchanWait(HandDecomposition d, Tile winTile) {
  for (final m in d.melds.where((m) => m.isSequence)) {
    if (m.low.number == 1 && winTile.type == TileType.values[m.low.index + 2]) {
      return true;
    }
    if (m.low.number == 7 && winTile.type == m.low) return true;
  }
  return false;
}
