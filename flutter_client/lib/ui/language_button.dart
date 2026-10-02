/// The language picker every screen carries (see
/// test/language_everywhere_test.dart): a globe with the current language's
/// own name, opening a menu of all of them, each written in itself.
library;

import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../l10n/l10n.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.compact = false, this.controller});

  /// Just the globe, for a crowded bar; the name shows in its tooltip.
  final bool compact;

  /// Defaults to [AppLanguageController.instance].
  final AppLanguageController? controller;

  @override
  Widget build(BuildContext context) {
    final languages = controller ?? AppLanguageController.instance;
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: languages,
      builder: (context, current, _) => PopupMenuButton<AppLanguage>(
        key: const Key('languageButton'),
        tooltip: context.l10n.languageTooltip,
        initialValue: current,
        onSelected: languages.select,
        itemBuilder: (_) => [
          for (final l in AppLanguage.values)
            CheckedPopupMenuItem(
              key: Key('language_${l.name}'),
              value: l,
              checked: l == current,
              child: Text(l.nativeName),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, color: Colors.white70, size: 20),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(current.nativeName,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
