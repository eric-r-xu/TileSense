/// The Hand Builder tour: a short, one-time walk through the builder's screen,
/// shown the first time it opens. Like the table tour it lights the real
/// widgets one at a time — the tile palette, the slot being filled, the chips
/// that choose the slot, the table, the status line, the guide and the Menu —
/// so each is explained where it lives, then gets out of the way for good.
///
/// It can be replayed from the builder's Menu. The guide step offers a sample
/// hand, so a newcomer sees TileSensor read a table without placing 14 tiles
/// first.
library;

import 'e2e_id.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'spotlight_tour.dart';
import 'theme.dart';

/// Whether the builder tour has been seen on this device; the same pattern as
/// the table tour's [TableTour].
abstract final class BuilderTour {
  static const storageKey = 'ts_builder_tour_seen';
  static final _seen = SeenOnce(storageKey);

  /// Whether a first visit opens the tour. Off in tests (see
  /// `flutter_test_config.dart`) unless a test turns it on.
  static bool get autoShow => _seen.autoShow;
  static set autoShow(bool v) => _seen.autoShow = v;

  static bool get shouldAutoShow => _seen.shouldAutoShow;

  static void markSeen() => _seen.markSeen();

  /// Forgets that the tour was seen (for tests).
  static void reset() => _seen.reset();
}

/// The widgets the tour points at, keyed so it can find them on screen.
class BuilderTourTargets {
  /// The tile palette along the bottom.
  final palette = GlobalKey(debugLabel: 'builderTourPalette');

  /// The tiles in the slot being filled.
  final contents = GlobalKey(debugLabel: 'builderTourContents');

  /// The chips that choose the slot.
  final chips = GlobalKey(debugLabel: 'builderTourChips');
  final table = GlobalKey(debugLabel: 'builderTourTable');
  final status = GlobalKey(debugLabel: 'builderTourStatus');

  /// The guide panel (or the win panel, once the hand wins).
  final guide = GlobalKey(debugLabel: 'builderTourGuide');
  final menu = GlobalKey(debugLabel: 'builderTourMenu');
}

/// The tour over the whole builder. [onDone] runs on the last step's button
/// and on Skip; either way the tour is marked seen. [onSample] fills the table
/// with a sample hand, from the guide step's button; the tour stays on that
/// step.
class BuilderTourOverlay extends StatelessWidget {
  const BuilderTourOverlay({
    super.key,
    required this.targets,
    required this.onDone,
    required this.onSample,
  });

  final BuilderTourTargets targets;
  final VoidCallback onDone;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SpotlightTour(
      keyPrefix: 'builderTour',
      seen: BuilderTour._seen,
      onDone: onDone,
      doneLabel: l10n.builderTourDone,
      steps: [
        TourStep(
          target: targets.palette,
          title: l10n.builderTourPaletteTitle,
          body: l10n.builderTourPaletteBody,
        ),
        TourStep(
          target: targets.contents,
          title: l10n.builderTourContentsTitle,
          body: l10n.builderTourContentsBody,
        ),
        TourStep(
          target: targets.chips,
          title: l10n.builderTourChipsTitle,
          body: l10n.builderTourChipsBody,
        ),
        TourStep(
          target: targets.table,
          title: l10n.builderTourTableTitle,
          body: l10n.builderTourTableBody,
        ),
        TourStep(
          target: targets.status,
          title: l10n.builderTourStatusTitle,
          body: l10n.builderTourStatusBody,
        ),
        TourStep(
          target: targets.guide,
          title: l10n.builderTourGuideTitle,
          body: l10n.builderTourGuideBody,
          extra: Align(
            alignment: Alignment.centerLeft,
            child: e2eId(
              'builderTourSample',
              OutlinedButton.icon(
                key: const Key('builderTourSample'),
                onPressed: onSample,
                icon: const Icon(Icons.casino),
                label: Text(l10n.builderTourSample,
                    style: const TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.goldText,
                    side: const BorderSide(color: AppColors.gold),
                    minimumSize: const Size(0, 48)),
              ),
            ),
          ),
        ),
        TourStep(
          target: targets.menu,
          title: l10n.builderTourMenuTitle,
          body: l10n.builderTourMenuBody,
        ),
      ],
    );
  }
}
