/// TileSensor, the app's mascot: the face of the TileSense guide beside your
/// hand, and the one who plays your seat under Auto-Play.
library;

import 'package:flutter/material.dart';

/// The mascot's picture.
const String kTileSensorAsset = 'assets/tilesensor.png';

/// How TileSensor introduces itself, in the tooltips wherever it appears.
const String kTileSensorIntro = "Hi, I'm TileSensor, your mahjong guide.\n"
    'I provide stats to help your mahjong decisions.\n'
    'I am part axolotl, part prairie dog. It is very nice to meet you, '
    'and I hope I can be helpful!';

/// The tooltip TileSensor's picture carries wherever it appears: its
/// [kTileSensorIntro] (plus an optional [footer] line, e.g. what a tap does),
/// centred and half again the size of an ordinary tooltip's text so the
/// introduction reads as the mascot talking, not as fine print.
class TileSensorTooltip extends StatelessWidget {
  const TileSensorTooltip({super.key, this.footer, required this.child});

  /// Added under the introduction after a blank line.
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
        text:
            footer == null ? kTileSensorIntro : '$kTileSensorIntro\n\n$footer',
        style: TextStyle(fontSize: base * 1.5),
      ),
      textAlign: TextAlign.center,
      child: child,
    );
  }
}
