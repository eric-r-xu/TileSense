/// The labelled back button every screen keeps in its top-left corner.
library;

import 'package:flutter/material.dart';

import '../main.dart' show isPhoneLayout;

/// Arrow plus a word ("Menu", "Back", "Leave"), never a bare icon, so the
/// target is wide as well as tall. On a phone it is at least [phoneTarget]
/// each way, which is 44pt at the ~0.48× a landscape phone draws the canvas
/// at. A bar that holds it on a phone has to be at least that tall, plus its
/// padding.
class BarBackButton extends StatelessWidget {
  const BarBackButton({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.foregroundColor = Colors.white,
  });

  /// The width a bar's `leadingWidth` should give this button.
  static const double leadingWidth = 132;

  /// A phone's minimum tap target in canvas pixels (see the class doc).
  static const double phoneTarget = 92;

  /// The smallest the button gets on a desktop.
  static const double desktopHeight = 48;

  final Key buttonKey;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneLayout(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Tooltip(
        message: tooltip,
        child: TextButton.icon(
          key: buttonKey,
          onPressed: onPressed,
          icon: Icon(Icons.arrow_back, size: phone ? 30 : 24),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: foregroundColor,
            minimumSize: phone
                ? const Size(phoneTarget, phoneTarget)
                : const Size(desktopHeight, desktopHeight),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
