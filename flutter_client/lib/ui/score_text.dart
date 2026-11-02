/// How a scored hand reads in words — one yaku per line, and the hand's
/// total — shared by the between-round result panel and the Hand Builder's
/// win panel, so a hand is described the same way wherever it is scored.
library;

import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/scoring.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';

/// One yaku (or faan, tai, fan) as a line: its name in this language and what
/// it is worth in [r]'s own units.
String yakuLine(AppLocalizations l10n, YakuResult y, Ruleset r) {
  final name = l10n.scoringName(y.name, r);
  if (r.isMcr) return l10n.yakuLineMcr(name, y.han);
  if (r.isTaiwanese) {
    return y.faan == 1
        ? l10n.yakuLineTaiOne(name, y.faan)
        : l10n.yakuLineTaiMany(name, y.faan);
  }
  if (r.isChineseStyle) return l10n.yakuLineFaan(name, y.faan);
  return y.yakuman > 0
      ? l10n.yakuLineYakuman(name)
      : l10n.yakuLineHan(name, y.han);
}

/// The hand's total: Taiwanese's points, Hong Kong's faan and chips, MCR's
/// and Sichuan's own tallies, or riichi's han and fu (or limit) and points.
String scoreTotalLine(AppLocalizations l10n, HandScore score, Ruleset r) {
  if (r.isSichuan) return l10n.sichuanScoreTotal(score.han, score.points);
  if (r.isMcr) {
    return l10n.mcrScoreTotal(score.mcrQualifyingPoints ?? score.han,
        score.mcrFlowerPoints ?? 0, score.points);
  }
  final limit = score.limitName.isEmpty
      ? ''
      : l10n.limitSuffix(l10n.limitName(score.limitName));
  // Taiwanese's pattern total and payout are the same flat number — see
  // taiwanese_scoring.dart — so there is nothing to show twice the way
  // "faan — chips" or "han fu — points" show two different scales.
  if (r.isTaiwanese) {
    return score.points == 1
        ? l10n.scorePointOne(score.points)
        : l10n.scorePointMany(score.points);
  }
  if (r.isChineseStyle) {
    return l10n.scoreFaanChips(score.faan, score.points, limit);
  }
  if (score.yakuman > 0) {
    return l10n.scoreLimitOnly(l10n.limitName(score.limitName), score.points);
  }
  return l10n.scoreHanFu(score.han, score.fu, limit, score.points);
}
