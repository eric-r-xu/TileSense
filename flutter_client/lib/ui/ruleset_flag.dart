/// A ruleset's flag: the emoji for a country's rules, or an image for rules
/// that have none (Sichuan is a province — see [Ruleset.flagAsset]).
library;

import 'package:flutter/material.dart';
import 'package:mahjong_core/ruleset.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';

/// The flag alone, sized to sit in a line of text at [size].
class RulesetFlag extends StatelessWidget {
  const RulesetFlag(this.ruleset,
      {super.key, this.size = 20, this.style, this.tooltip = true});

  final Ruleset ruleset;

  /// The text size the flag sits beside; an image flag is drawn at this height
  /// (a flag is wider than tall, so it reads a touch larger than an emoji).
  final double size;

  /// The style an emoji flag takes; its size is overridden by [size].
  final TextStyle? style;

  /// Whether sanma's flag explains itself on hover: three-player riichi. Off
  /// where the flag already sits inside a tooltip of its own, which says so.
  final bool tooltip;

  @override
  Widget build(BuildContext context) {
    final asset = ruleset.flagAsset;
    if (asset == null) {
      return Text(ruleset.flag, style: (style ?? const TextStyle()).copyWith(fontSize: size));
    }
    final flag = Semantics(
      label: context.l10n.rulesetTooltipName(ruleset),
      image: true,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.1),
          child: Image.asset(
            asset,
            key: Key('rulesetFlag_${ruleset.name}'),
            height: size * 0.95,
            width: size * 0.95 * 1.5,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            // A missing file must never take the table down with it.
            errorBuilder: (_, __, ___) =>
                Text(ruleset.flag, style: TextStyle(fontSize: size)),
          ),
        ),
      ),
    );
    if (!ruleset.isSanma || !tooltip) return flag;
    return Tooltip(
      key: const Key('sanmaFlagTooltip'),
      message: context.l10n.sanmaTooltip,
      child: flag,
    );
  }
}

/// The flag followed by the rules' name — what `rulesetFlagLabel` spells out
/// as text — with [suffix] (a minimum, "3 faan") after it when given. A
/// ruleset with an emoji flag stays a single [Text], exactly as before.
class RulesetFlagLabel extends StatelessWidget {
  const RulesetFlagLabel(this.ruleset,
      {super.key,
      this.style,
      this.suffix,
      this.textKey,
      this.tooltip = true});

  final Ruleset ruleset;

  /// See [RulesetFlag.tooltip].
  final bool tooltip;
  final TextStyle? style;
  final String? suffix;

  /// Key for the text part, where a test looks for the label.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = style ?? DefaultTextStyle.of(context).style;
    final tail = suffix == null ? '' : ' · $suffix';
    if (ruleset.flagAsset == null) {
      return Text('${l10n.rulesetFlagLabel(ruleset)}$tail',
          key: textKey, style: style);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RulesetFlag(ruleset, size: base.fontSize ?? 14, tooltip: tooltip),
        const SizedBox(width: 6),
        Flexible(
          child: Text('${l10n.rulesetName(ruleset)}$tail',
              key: textKey, style: style),
        ),
      ],
    );
  }
}
