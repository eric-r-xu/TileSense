/// The rules in play, top right of a table's bar: the style's flag plus the
/// table's minimum where it has one — 🇯🇵, 🇭🇰 3 faan, 🇹🇼 5 tai.
library;

import 'package:flutter/material.dart';
import 'package:mahjong_core/ruleset.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import 'ruleset_flag.dart';

class RulesetBadge extends StatelessWidget {
  const RulesetBadge({
    super.key,
    required this.ruleset,
    required this.minimumFaan,
    required this.minimumPoints,
    this.fontSize = 20,
  });

  final Ruleset ruleset;

  /// Hong Kong's minimum faan; shown only when the table sets one (> 0).
  final int minimumFaan;

  /// Taiwanese's minimum tai; Taiwanese always has one, so always shown.
  final int minimumPoints;
  final double fontSize;

  /// "3 faan" / "5 tai", or null — riichi's one-yaku rule isn't a points
  /// floor, and a Hong Kong table may set none.
  String? _minimum(AppLocalizations l10n) => ruleset.isHongKong
      ? (minimumFaan > 0 ? l10n.faanCount(minimumFaan) : null)
      : ruleset.isTaiwanese
          ? l10n.taiCount(minimumPoints)
          : null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final minimum = _minimum(l10n);
    return Tooltip(
      message: l10n.badgeTooltip(l10n.rulesetName(ruleset),
          minimum == null ? '' : l10n.badgeMinimum(minimum)),
      child: ruleset.flagAsset != null
          ? Row(
              key: const Key('rulesetBadge'),
              mainAxisSize: MainAxisSize.min,
              children: [
                RulesetFlag(ruleset, size: fontSize),
                if (minimum != null)
                  Text(' $minimum',
                      style: TextStyle(
                        color: const Color(0xffffdf76),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                      )),
              ],
            )
          : Text(
              minimum == null ? ruleset.flag : '${ruleset.flag} $minimum',
              key: const Key('rulesetBadge'),
              style: TextStyle(
                color: const Color(0xffffdf76),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
