/// Taiwanese point scoring for a 17-tile hand (5 melds and a pair, or seven
/// pairs and a pung), following the San Diego Mahjong Club cheat sheet's
/// point chart. Shares [ScoreContext], [HandScore] and [YakuResult] with
/// riichi and Hong Kong scoring; points travel in the `han` fields, same as
/// Hong Kong's faan.
///
/// Unlike Hong Kong's doubling faan table, points here are flat and additive
/// (a hand's score is just the sum of its patterns), a hand needs at least
/// [TaiwaneseRules.minimumPoints] to win, and there is no dealer premium on
/// the hand's own value — everyone pays the same amount. The dealer's win
/// streak instead earns a separate additive bonus, computed in `round.dart`
/// (which knows the streak) rather than here.
///
/// Two patterns from the sheet are not implemented: "Riichi" (a first-turn-
/// only declaration this house rule adds) and "Robbing the Flower" (stealing
/// an eighth flower off another player's meld attempt) — both are rare,
/// interactive edge cases outside a normal hand's scoring.
library;

import '../meld.dart';
import '../scoring.dart';
import '../tile.dart';
import 'taiwanese_hand_parse.dart';
import 'taiwanese_rules.dart';

/// Score a Taiwanese win. [concealed] excludes the winning tile and all
/// declared melds.
HandScore scoreTaiwaneseHand(
    List<Tile> concealed, Tile winTile, List<Meld> openMelds, ScoreContext ctx,
    {required bool isDealer}) {
  final all = [...concealed, winTile];
  if (openMelds.length > 5 ||
      all.length != 17 - openMelds.length * 3 ||
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
  final countTypes = [
    ...all.map((t) => t.type),
    ...openMelds.expand((m) => m.types)
  ];
  if (countTypes.any((t) => countTypes.where((x) => x == t).length > 4)) {
    return HandScore.invalid();
  }

  HandScore? best;
  final decompositions =
      decomposeTaiwanese(toCounts34(all), openMelds: openMelds.length);
  for (final d in decompositions) {
    final patterns = <YakuResult>[];
    void add(String name, int points) =>
        patterns.add(YakuResult(name, points));

    final groups = [...openMelds, ...d.melds];
    final types = [
      ...all.map((t) => t.type),
      ...openMelds.expand((m) => m.types),
    ];
    final closed = openMelds.every((m) => m.concealed);

    if (d.sevenPairsAndPung) {
      if (TaiwaneseRules.sevenPairsAndPung) add('Seven Pairs and a Pung', 30);
    } else {
      final pungs = groups.where((m) => m.isTripletLike).toList();
      final sequences = groups.where((m) => m.isSequence).toList();
      final suits = types.where((t) => t.isSuit).map((t) => t.suit).toSet();
      final hasHonor = types.any((t) => t.isHonor);

      if (suits.length == 1 && !hasHonor) {
        add('Full Flush', 40);
      } else if (suits.length == 1 && hasHonor) {
        add('Half Flush', 10);
      }

      if (pungs.length == 5) {
        add('All Pungs', 10);
      } else if (sequences.length == 5) {
        if (ctx.flowers.isEmpty && !(d.pair?.isHonor ?? false)) {
          add('All Chows', 10);
        } else {
          add('All Chows with Flowers or Honors', 3);
        }
      }

      if (_hasPureStraight(sequences)) add('Pure Straight', 5);

      final dragonPungs = pungs.where((m) => m.low.isDragon).length;
      if (dragonPungs == 3) {
        add('Big Three Dragons', 30);
      } else if (dragonPungs == 2 && (d.pair?.isDragon ?? false)) {
        add('Little Three Dragons', 10);
      } else {
        for (var i = 0; i < dragonPungs; i++) add('Value Honor', 1);
      }

      final windPungs = pungs.where((m) => m.low.isWind).toList();
      final pairIsWind = d.pair?.isWind ?? false;
      if (windPungs.length == 4) {
        add('Big Four Winds', 40);
      } else if (windPungs.length == 3 && pairIsWind) {
        add('Little Four Winds', 30);
      } else if (windPungs.length == 3) {
        add('Big Three Winds', 10);
      } else if (windPungs.length == 2 && pairIsWind) {
        add('Little Three Winds', 5);
      } else {
        for (final m in windPungs) {
          if (m.low == ctx.seatWind.tile) add('Value Honor', 1);
        }
      }
    }

    final noFlowers = ctx.flowersEnabled && ctx.flowers.isEmpty;
    final noHonors = !types.any((t) => t.isHonor);
    if (noFlowers && noHonors) {
      add('No Flower or Honor Tiles', 3);
    } else {
      if (noFlowers) add('No Flower Tiles', 1);
      if (noHonors) add('No Honors', 1);
    }
    if (ctx.flowersEnabled) {
      for (var i = 0; i < ctx.flowers.length; i++) add('Flower Tile', 1);
    }

    if (ctx.isTsumo) add('Self-Drawn', 1);
    if (closed) {
      if (ctx.isTsumo) {
        add('Fully Concealed Hand', 3);
      } else {
        add('Concealed Hand', 1);
      }
    }

    final meldedKongs =
        groups.where((m) => m.isKan && !m.concealed).length;
    final concealedKongs = groups.where((m) => m.isKan && m.concealed).length;
    for (var i = 0; i < meldedKongs; i++) add('Melded Kong', 1);
    for (var i = 0; i < concealedKongs; i++) add('Concealed Kong', 2);

    if (!d.sevenPairsAndPung) {
      final concealedPungCount =
          groups.where((m) => m.isTripletLike && m.concealed).length;
      if (concealedPungCount >= 5) {
        add('Five Concealed Pungs', 40);
      } else if (concealedPungCount == 4) {
        add('Four Concealed Pungs', 10);
      } else if (concealedPungCount == 3) {
        add('Three Concealed Pungs', 5);
      } else if (concealedPungCount == 2) {
        add('Two Concealed Pungs', 2);
      }

      final completesPair = d.pair == winTile.type;
      final winSeqs = d.melds
          .where((m) => m.isSequence && m.types.contains(winTile.type));
      final winSeq = winSeqs.isEmpty ? null : winSeqs.first;
      if (completesPair) {
        add('Single Wait', 2);
      } else if (winSeq != null &&
          winTile.type.number == winSeq.low.number + 1) {
        add('Closed Wait', 2);
      }

      if (!ctx.isTsumo && openMelds.length == 5) add('Melded Hand', 10);
    }

    if (ctx.chankan && !ctx.isTsumo) add('Robbing the Kong', 1);
    if (ctx.isTsumo && ctx.haitei) add('Last Tile Draw', 1);
    if (ctx.heavenly && ctx.isTsumo && isDealer && closed) {
      add('Blessings of Heaven', 40);
    }
    if (ctx.earthly && !ctx.isTsumo && !isDealer && closed) {
      add('Blessings of Earth', 40);
    }
    if (ctx.discardCount < 5) {
      add('Win Within 5 Discards', 10);
    } else if (ctx.discardCount < 10) {
      add('Win Within 5 to 10 Discards', 5);
    }

    final points = patterns.fold(0, (int n, p) => n + p.faan);
    final score = _finish(patterns, points);
    if (best == null || score.faan > best.faan) best = score;
  }
  return best ?? HandScore.invalid();
}

/// Having all eight flower and season tiles instantly wins the round; no
/// other patterns are scored.
HandScore scoreTaiwaneseFlowerWin(int flowerCount) {
  if (flowerCount != 8) return HandScore.invalid();
  return _finish([const YakuResult('All Flowers', 30)], 30);
}

bool _hasPureStraight(List<Meld> sequences) {
  for (final s1 in sequences) {
    if (s1.low.number != 1) continue;
    final suit = s1.low.suit;
    final has4 =
        sequences.any((m) => m.low.suit == suit && m.low.number == 4);
    final has7 =
        sequences.any((m) => m.low.suit == suit && m.low.number == 7);
    if (has4 && has7) return true;
  }
  return false;
}

/// Payments: a flat, additive point total, the same for every seat — no
/// dealer premium and no self-draw multiplier on the hand's own value (see
/// the file doc comment for the separate dealer-streak bonus).
HandScore _finish(List<YakuResult> patterns, int points) {
  if (points < TaiwaneseRules.minimumPoints) return HandScore.invalid();
  return HandScore(
      yaku: patterns,
      han: points,
      fu: 0,
      yakuman: 0,
      points: points,
      dealerPays: points,
      nonDealerPays: points,
      limitName: '',
      valid: true);
}
