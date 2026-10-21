/// The frame the app's non-table screens share: the felt, a labelled Back in
/// the top-left corner, the language picker in the top-right, and the content
/// centred in a scroll view that is at least as tall as the screen.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'bar_back_button.dart';
import 'language_button.dart';
import 'theme.dart';

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.child,
    required this.onBack,
    required this.backKey,
    this.padding = const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
    this.footer,
  });

  /// The screen's content, laid out in a column and centred.
  final Widget child;

  /// What the top-left Back does, and the key a test finds it by.
  final VoidCallback onBack;
  final Key backKey;

  /// Around [child] inside the scroll view.
  final EdgeInsetsGeometry padding;

  /// Pinned under the content, outside its scroll: the place for a primary
  /// action or a [BackFooter] within a thumb's reach.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Material ancestor: without one, Text on web can render with a stray
    // underline decoration.
    return Material(
      color: AppColors.background,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                // At least as tall as the screen, so on a taller canvas the
                // page sits in the middle rather than at the top.
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Center(
                        child: Padding(padding: padding, child: child),
                      ),
                    ),
                  ),
                ),
              ),
              if (footer != null) footer!,
            ],
          ),
          // Overlaid rather than given a row of their own: these screens are
          // tight against the design canvas's height.
          Positioned(
            left: 4,
            top: 8,
            child: BarBackButton(
              buttonKey: backKey,
              label: l10n.back,
              tooltip: l10n.backToMainMenu,
              onPressed: onBack,
              foregroundColor: AppColors.link,
            ),
          ),
          const Positioned(right: 8, top: 8, child: LanguageButton()),
        ],
      ),
    );
  }
}
