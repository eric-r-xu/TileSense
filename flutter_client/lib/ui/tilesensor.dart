/// TileSensor, the app's mascot: the face of the TileSense guide beside your
/// hand, and the one who plays your seat under Auto-Play.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// The mascot's picture.
const String kTileSensorAsset = 'assets/tilesensor.png';

/// The tooltip TileSensor's picture carries wherever it appears: its
/// introduction (plus an optional [footer] line, e.g. what a tap does),
/// centred and half again the size of an ordinary tooltip's text so the
/// introduction reads as the mascot talking, not as fine print.
class TileSensorTooltip extends StatelessWidget {
  const TileSensorTooltip({super.key, this.footer, required this.child});

  /// Added as one more line under the introduction.
  final String? footer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Flutter's own tooltip default: 14 on phones, 12 everywhere else.
    final base = theme.tooltipTheme.textStyle?.fontSize ??
        switch (theme.platform) {
          TargetPlatform.android ||
          TargetPlatform.iOS ||
          TargetPlatform.fuchsia =>
            14.0,
          _ => 12.0,
        };
    final intro = context.l10n.mascotIntro('TileSensor', 'TileSense');
    // Split only the brand names for emphasis; translators control word order.
    final runs = <TextSpan>[];
    var start = 0;
    for (final match in RegExp(r'TileSensor|TileSense').allMatches(intro)) {
      runs.add(TextSpan(text: intro.substring(start, match.start)));
      runs.add(TextSpan(
          text: match.group(0),
          style: const TextStyle(fontWeight: FontWeight.w800)));
      start = match.end;
    }
    runs.add(TextSpan(text: intro.substring(start)));
    return Tooltip(
      // Only the size is set here, so the tooltip keeps its themed colour.
      richMessage: TextSpan(
        // One line height throughout, footer included, so every row sits the
        // same distance from the next.
        style: TextStyle(fontSize: base * 1.5, height: 1.4),
        children: [
          ...runs,
          if (footer != null) TextSpan(text: '\n$footer'),
        ],
      ),
      textAlign: TextAlign.center,
      child: child,
    );
  }
}
