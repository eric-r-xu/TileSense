/// The app's named colours and button styles, so a screen says what a colour
/// is for rather than spelling its hex.
///
/// There are three golds, each with one job: [AppColors.gold] for borders,
/// fills and selected state, [AppColors.goldText] for headings and text set on
/// the dark felt, and [AppColors.goldBright] for a highlight that has to pop
/// (a selected ruleset, a score).
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  /// The felt behind every screen, and the letterbox bars round the canvas.
  static const Color background = Color(0xff042020);

  /// A modal bottom sheet's body.
  static const Color sheet = Color(0xff0c3030);

  /// Borders, fills and the selected state of a control.
  static const Color gold = Color(0xffcaa24e);

  /// Headings and text on the felt.
  static const Color goldText = Color(0xffe9d58f);

  /// A highlight that has to stand out.
  static const Color goldBright = Color(0xffffdf76);

  /// A link, or a quiet action such as Back.
  static const Color link = Color(0xff80cbc4);

  /// A right answer, a win, a good sign.
  static const Color right = Color(0xff43a047);

  /// A wrong answer.
  static const Color wrong = Color(0xffe53935);
}

/// The three button looks the screens share: one gold call to action, an
/// outlined gold alternative beside it, and a quiet teal link.
abstract final class AppButtons {
  /// The call to action: gold, black text. For an `ElevatedButton`.
  static ButtonStyle primary({
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
  }) =>
      ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        padding: padding,
        minimumSize: minimumSize,
      );

  /// What sits beside a [primary]: gold outline, gold text. For an
  /// `OutlinedButton`.
  static ButtonStyle secondary({
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
  }) =>
      OutlinedButton.styleFrom(
        foregroundColor: AppColors.goldText,
        side: const BorderSide(color: AppColors.gold),
        padding: padding,
        minimumSize: minimumSize,
      );

  /// A link or a utility action: teal text. For a `TextButton`.
  static ButtonStyle link({double fontSize = 14}) => TextButton.styleFrom(
        foregroundColor: AppColors.link,
        textStyle: TextStyle(fontSize: fontSize),
      );
}
