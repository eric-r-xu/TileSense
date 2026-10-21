/// The labelled back button every screen keeps in its top-left corner, and
/// [BackFooter], the same way out within a thumb's reach at the bottom.
library;

import 'package:flutter/material.dart';

import '../main.dart' show isPhoneLayout;
import 'theme.dart';

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
    this.phoneSized,
  });

  /// Overrides whether to size for a thumb. Null follows [isPhoneLayout]; a
  /// mouse user in a shrunken window passes false, so it fits a bar that
  /// stayed desktop height.
  final bool? phoneSized;

  /// The width a bar's `leadingWidth` should give this button.
  static const double leadingWidth = 132;

  /// A phone's minimum tap target in canvas pixels (see the class doc).
  static const double phoneTarget = 92;

  /// The smallest the button gets on a desktop.
  static const double desktopHeight = 48;

  /// The height a bar holding this button needs: tall enough on a phone that
  /// the button keeps its full [phoneTarget] rather than being squeezed to the
  /// bar's 50, which is a target half the size a thumb needs.
  static double toolbarHeight(BuildContext context) =>
      isPhoneLayout(context) ? phoneTarget + 8 : 50;

  final Key buttonKey;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final phone = phoneSized ?? isPhoneLayout(context);
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

/// A full-width "Back to menu" at the bottom of a screen's panel. The top-left
/// [BarBackButton] is the furthest point from a thumb on a phone held in
/// landscape, so screens with a panel down one side repeat the way out here,
/// where the thumb already rests. At least [BarBackButton.phoneTarget] tall on
/// a phone, 48 elsewhere.
class BackFooter extends StatelessWidget {
  const BackFooter({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneLayout(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: buttonKey,
            onPressed: onPressed,
            icon: Icon(Icons.arrow_back, size: phone ? 30 : 22),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.link,
              side: const BorderSide(color: AppColors.link),
              minimumSize: Size(
                  0,
                  phone
                      ? BarBackButton.phoneTarget
                      : BarBackButton.desktopHeight),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
