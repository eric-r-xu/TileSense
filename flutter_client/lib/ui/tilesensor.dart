/// TileSensor, the app's mascot: the face of the TileSense guide beside your
/// hand, and the one who plays your seat under Auto-Play.
library;

import 'package:flutter/material.dart';

/// The mascot's picture.
const String kTileSensorAsset = 'assets/tilesensor.png';

/// How TileSensor introduces itself, in the tooltips wherever it appears, as
/// (text, bold) runs — its own name and the app's are set in bold. Short
/// lines of about the same length, each broken by hand, so the centred block
/// reads as even rows rather than a ragged wrap.
const List<(String, bool)> _intro = [
  ("I'm ", false),
  ('TileSensor', true),
  (': part prairie dog, part axolotl.\n'
      'I pick your best discards and calls.\n'
      "Turn on Auto-Play and I'll play your seat.\n"
      'Misplayed? Take it back and try again.\n'
      'Play along and level up your ', false),
  ('TileSense', true),
  ('.', false),
];

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
    return Tooltip(
      // Only the size is set here, so the tooltip keeps its themed colour.
      richMessage: TextSpan(
        // One line height throughout, footer included, so every row sits the
        // same distance from the next.
        style: TextStyle(fontSize: base * 1.5, height: 1.4),
        children: [
          for (final (text, bold) in _intro)
            TextSpan(
              text: text,
              style: bold ? const TextStyle(fontWeight: FontWeight.w800) : null,
            ),
          if (footer != null) TextSpan(text: '\n$footer'),
        ],
      ),
      textAlign: TextAlign.center,
      child: child,
    );
  }
}
