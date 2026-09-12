/// Hong Kong scoring from the supplied sheet. Legacy han/fu context fields are
/// retained for source compatibility; only faan and HK bonuses affect scoring.
library;

import 'hand_parse.dart';
import 'hong_kong_rules.dart';
export 'hong_kong_rules.dart';
import 'meld.dart';
import 'tile.dart';

/// Traditional capped faan-laak table, in abstract chips (no currency).
class ScoreContext {
  ScoreContext({
    required this.roundWind,
    required this.seatWind,
    required this.isTsumo,
    required this.closed,
    this.flowers = const [],
    this.flowersEnabled = true,
    this.heavenly = false,
    this.earthly = false,
    this.blessingOfMan = false,
    this.doubleKong = false,
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

  final List<TileType> flowers;
  final bool flowersEnabled;
  final bool heavenly;
  final bool earthly;
  final bool blessingOfMan;
  final bool doubleKong;
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
  int get faan => han;
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
  int get faan => han;
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

/// [concealed] excludes the winning tile and all declared melds.
HandScore scoreHand(
    List<Tile> concealed, Tile winTile, List<Meld> openMelds, ScoreContext ctx,
    {required bool isDealer}) {
  final all = [...concealed, winTile];
  if (openMelds.length > 4 ||
      all.length != 14 - openMelds.length * 3 ||
      all.any((t) => !t.type.isPlayingTile)) {
    return HandScore.invalid();
  }
  for (final m in openMelds) {
    if (m.kind == MeldKind.pair ||
        !m.low.isPlayingTile ||
        (m.isSequence && (!m.low.isSuit || m.low.number > 7))) {
      return HandScore.invalid();
    }
  }
  final types = [
    ...all.map((t) => t.type),
    ...openMelds.expand((m) => m.types)
  ];
  if (types.any((t) => types.where((x) => x == t).length > 4)) {
    return HandScore.invalid();
  }
  HandScore? best;
  for (final d in decompose(toCounts34(all), openMelds: openMelds.length)) {
    final patterns = <YakuResult>[];
    void add(String name, int faan) => patterns.add(YakuResult(name, faan));
    final groups = [...openMelds, ...d.melds];
    final pungs = groups.where((m) => m.isTripletLike).toList();
    final dragons = pungs.where((m) => m.low.isDragon).length;
    final winds = pungs.where((m) => m.low.isWind).length;
    final closed = openMelds.every((m) => m.concealed);
    // Indented entries on the supplied sheet replace their parent.
    if (d.kokushi) add('Thirteen Orphans', 13);
    if (d.sevenPairs) {
      if (!HongKongRules.sevenPairs) continue;
      add('Seven Pairs', 4);
    }
    if (!d.kokushi && !d.sevenPairs && groups.every((m) => m.isSequence)) {
      add('All Sequences', 1);
    }
    final concealedPungs =
        pungs.length == 4 && closed && (ctx.isTsumo || d.pair == winTile.type);
    final allKongs = groups.where((m) => m.isKan).length == 4;
    final allHonors = types.every((t) => t.isHonor);
    final allTerminals = types.every((t) => t.isTerminal);
    final mixedTerminals =
        !d.kokushi && !d.sevenPairs && types.every((t) => t.isTerminalOrHonor);
    if (pungs.length == 4) {
      if (allKongs) {
        add(mixedTerminals ? 'All Quadruplets (upgrade)' : 'All Quadruplets',
            mixedTerminals ? 10 : 13);
      } else if (concealedPungs) {
        add(
            mixedTerminals
                ? 'All Concealed Triplets (upgrade)'
                : 'All Concealed Triplets',
            mixedTerminals ? 5 : 8);
      } else if (!mixedTerminals) {
        add('All Triplets', 3);
      }
    }
    // Terminal/honor entries already include the ordinary 3-faan triplet award.
    if (allHonors) {
      add('All Honours', 10);
    } else if (allTerminals) {
      add('All Terminals', 13);
    } else if (mixedTerminals) {
      add('Mixed Terminals', 4);
    }

    if (dragons == 3) {
      add('Big Three Dragons', 8);
    } else if (dragons == 2 && (d.pair?.isDragon ?? false)) {
      add('Small Three Dragons', 5);
    } else {
      for (final m in pungs.where((m) => m.low.isDragon)) {
        add('${m.low.displayName} Pung', 1);
      }
    }
    if (winds == 4) {
      add('Big Four Winds', 13);
    } else if (winds == 3 && (d.pair?.isWind ?? false)) {
      add('Small Four Winds', 6);
    } else {
      for (final m in pungs) {
        if (m.low == ctx.seatWind.tile) add('Seat Wind', 1);
        if (m.low == ctx.roundWind.tile) add('Round Wind', 1);
      }
    }
    final suits = types.where((t) => t.isSuit).map((t) => t.suit).toSet();
    if (suits.length == 1) {
      if (types.any((t) => t.isHonor)) {
        add('Mixed Flush', 3);
      } else {
        add('Full Flush', 7);
      }
    }
    if (ctx.isTsumo) {
      if (ctx.doubleKong) {
        add('Double Kong Replacement', 9);
      } else if (ctx.rinshan) {
        add('Win by Kong Replacement', 2);
      } else {
        add('Self-Pick', 1);
      }
    }
    if (closed) add('Concealed Hand', 1);
    if (ctx.haitei || ctx.houtei) add('Moon Under the Sea', 1);
    if (ctx.chankan && !ctx.isTsumo) add('Robbing the Kong', 1);
    if (ctx.heavenly && ctx.isTsumo && isDealer && closed) {
      add('Blessing of Heaven', 13);
    }
    if (ctx.earthly && !ctx.isTsumo && !isDealer && closed) {
      add('Blessing of Earth', 13);
    }
    if (ctx.blessingOfMan && ctx.isTsumo && !isDealer && closed) {
      add('Blessing of Man', 13);
    }
    if (closed && openMelds.isEmpty && _nineGates(types)) add('Nine Gates', 13);
    if (ctx.flowersEnabled) _flowerPatterns(ctx.flowers, ctx.seatWind, add);
    final faan = patterns.fold(0, (int n, p) => n + p.faan);
    if (patterns.isEmpty) add('Chicken Hand', 0);
    final score = _finalise(patterns, faan, selfDraw: ctx.isTsumo);
    if (best == null || score.faan > best.faan) best = score;
  }
  return best ?? HandScore.invalid();
}

bool _nineGates(List<TileType> tiles) {
  if (tiles.length != 14 ||
      tiles.any((t) => !t.isSuit || t.suit != tiles.first.suit)) {
    return false;
  }
  final counts = List<int>.filled(10, 0);
  for (final t in tiles) {
    counts[t.number]++;
  }
  return counts[1] >= 3 &&
      counts[9] >= 3 &&
      List.generate(7, (i) => counts[i + 2]).every((n) => n >= 1);
}

void _flowerPatterns(
    List<TileType> tiles, Wind seat, void Function(String, int) add) {
  final flowers = tiles.where((t) => t.isBonus).toSet();
  if (flowers.isEmpty) add('No Flowers or Seasons', 1);
  for (final t in flowers) {
    if (t.bonusNumber == seat.index + 1) add(t.displayName, 1);
  }
  if (flowers.where((t) => t.index < TileType.spring.index).length == 4) {
    add('All Flowers', 2);
  }
  if (flowers.where((t) => t.index >= TileType.spring.index).length == 4) {
    add('All Seasons', 2);
  }
}

/// A flower declaration is an independent win; it needs no completed hand.
HandScore scoreFlowerWin(int flowerCount) {
  if (flowerCount != 7 && flowerCount != 8) return HandScore.invalid();
  final faan = flowerCount == 7 ? 3 : 8;
  return _finalise([
    YakuResult(flowerCount == 7 ? 'Seven Flowers' : 'Eight Flowers', faan)
  ], faan, selfDraw: true);
}

HandScore _finalise(List<YakuResult> patterns, int faan,
    {required bool selfDraw}) {
  final base = HongKongRules.basePoints(faan);
  return HandScore(
      yaku: patterns,
      han: faan,
      fu: 0,
      yakuman: 0,
      points: base * (selfDraw ? 3 : 2),
      dealerPays: base,
      nonDealerPays: selfDraw ? base : base * 2,
      limitName: faan >= HongKongRules.limitFaan ? '13+ faan cap' : '',
      valid: true);
}
