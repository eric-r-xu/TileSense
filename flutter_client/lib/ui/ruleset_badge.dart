/// The rules in play, top right of a table's bar: the style's flag plus the
/// table's minimum where it has one — 🇯🇵, 🇭🇰 3 faan, 🇹🇼 5 tai.
library;

import 'package:flutter/material.dart';
import 'package:mahjong_core/ruleset.dart';

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
  String? get minimum => ruleset.isHongKong
      ? (minimumFaan > 0 ? '$minimumFaan faan' : null)
      : ruleset.isTaiwanese
          ? '$minimumPoints tai'
          : null;

  /// What the badge reads.
  String get label => switch (minimum) {
        final min? => '${ruleset.flag} $min',
        null => ruleset.flag,
      };

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Playing ${ruleset.label} rules'
            '${minimum == null ? '' : ', $minimum minimum'}.',
        child: Text(
          label,
          key: const Key('rulesetBadge'),
          style: TextStyle(
            color: const Color(0xffffdf76),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
