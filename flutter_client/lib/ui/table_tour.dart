/// The table tour: a short, one-time walk through the single-player table's
/// controls, shown over the first hand a newcomer plays. It spotlights the real
/// widgets one at a time — the hand, the buttons beside it, TileSensor (the
/// guide), the rulebook and the menu — so each control is explained where it
/// lives, and
/// then gets out of the way for good. It can be replayed from the Learn popup
/// and, on a phone, from the menu sheet.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'spotlight_tour.dart';
import 'theme.dart';

/// Whether the tour has been seen on this device; the same pattern as
/// `LearnToPlay`.
abstract final class TableTour {
  static const storageKey = 'ts_table_tour_seen';
  static final _seen = SeenOnce(storageKey);

  /// Whether a first hand opens the tour. Off in tests (see
  /// `flutter_test_config.dart`) unless a test turns it on.
  static bool get autoShow => _seen.autoShow;
  static set autoShow(bool v) => _seen.autoShow = v;

  static bool get shouldAutoShow => _seen.shouldAutoShow;

  static void markSeen() => _seen.markSeen();

  /// Forgets that the tour was seen (for tests).
  static void reset() => _seen.reset();
}

/// The widgets the tour points at, keyed so it can find them on screen.
class TableTourTargets {
  final hand = GlobalKey(debugLabel: 'tourHand');
  final toggles = GlobalKey(debugLabel: 'tourToggles');
  final guide = GlobalKey(debugLabel: 'tourGuide');

  /// The bar's rulebook button; a phone has no such button, so its step
  /// points at [menu], where Rules is.
  final rules = GlobalKey(debugLabel: 'tourRules');
  final menu = GlobalKey(debugLabel: 'tourMenu');
}

/// The tour over the whole table. [onDone] runs on the last step's button and
/// on Skip; either way the tour is marked seen.
class TableTourOverlay extends StatelessWidget {
  const TableTourOverlay({
    super.key,
    required this.targets,
    required this.onDone,
    required this.phone,
    this.onOpenRules,
  });

  final TableTourTargets targets;

  /// On a phone the menu is the Menu button beside your hand; elsewhere the
  /// settings are along the top bar.
  final bool phone;
  final VoidCallback onDone;

  /// Opens the rulebook over the tour, from the rulebook step's button; the
  /// tour stays on that step underneath.
  final VoidCallback? onOpenRules;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SpotlightTour(
      keyPrefix: 'tableTour',
      seen: TableTour._seen,
      onDone: onDone,
      doneLabel: l10n.tourDone,
      steps: [
        TourStep(
          target: targets.hand,
          title: l10n.tourHandTitle,
          body: l10n.tourHandBody,
        ),
        TourStep(
          target: targets.toggles,
          title: l10n.tourButtonsTitle,
          body: l10n.tourButtonsBody,
          extra: _legend(l10n),
        ),
        TourStep(
          target: targets.guide,
          title: l10n.tourGuideTitle,
          body: l10n.tourGuideBody,
        ),
        TourStep(
          target: phone ? targets.menu : targets.rules,
          title: l10n.tourRulesTitle,
          body: phone ? l10n.tourRulesBodyPhone : l10n.tourRulesBodyDesktop,
          extra: onOpenRules == null
              ? null
              : OutlinedButton.icon(
                  key: const Key('tableTourOpenRules'),
                  onPressed: onOpenRules,
                  icon: const Icon(Icons.menu_book),
                  label: Text(l10n.tourRulesOpen,
                      style: const TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldText,
                      side: const BorderSide(color: AppColors.gold),
                      minimumSize: const Size(0, 48)),
                ),
        ),
        TourStep(
          target: targets.menu,
          title: l10n.tourMenuTitle,
          body: phone ? l10n.tourMenuBodyPhone : l10n.tourMenuBodyDesktop,
        ),
      ],
    );
  }

  /// The four buttons beside the hand, by the icons they show: on a phone the
  /// buttons are icons alone, so this is where their names are spelled out.
  Widget _legend(AppLocalizations l10n) {
    Widget row(IconData icon, String name, String what) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.goldText),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$name  ',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: what),
                  ]),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 15, height: 1.35),
                ),
              ),
            ],
          ),
        );
    return Column(
      key: const Key('tableTourLegend'),
      children: [
        // The same icons the buttons show (Discard's is a pointing hand).
        row(Icons.sort, l10n.sortCaption, l10n.tourLegendSortBody),
        row(Icons.touch_app, l10n.discardCaption, l10n.tourLegendDiscardBody),
        row(Icons.emoji_events, l10n.autoWinCaption,
            l10n.tourLegendAutoWinBody),
        row(Icons.skip_next, l10n.autoPassCaption, l10n.tourLegendAutoPassBody),
      ],
    );
  }
}
