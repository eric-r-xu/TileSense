/// The guide panel's simple view for new players: one best discard with a
/// plain-language reason, instead of the table of shanten, ukeire, EV,
/// placement and safety figures. Which view shows is a per-device choice.
library;

import 'package:flutter/material.dart';
import 'package:mahjong_core/round.dart' show MinimumShortfall;
import 'package:mahjong_core/tile.dart' show TileType;

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import '../logic/efficiency_engine.dart';
import '../telemetry/src/platform_web.dart'
    if (dart.library.io) '../telemetry/src/platform_stub.dart' as platform;
import 'tile_face.dart';
import 'theme.dart';

/// Whether the guide shows its simple view. New players start on it; the
/// panel's view chip switches, and the choice is remembered on this device.
abstract final class BeginnerGuide {
  static const storageKey = 'ts_guide_view';

  /// The view before anything is remembered. Tests that read the full table
  /// turn this off.
  static bool defaultOn = true;

  static final ValueNotifier<bool> on = ValueNotifier(_initial());

  static bool _initial() => switch (platform.localStorageGet(storageKey)) {
        'simple' => true,
        'full' => false,
        _ => defaultOn,
      };

  static void set(bool simple) {
    platform.localStorageSet(storageKey, simple ? 'simple' : 'full');
    on.value = simple;
  }
}

/// How many more tiles the hand needs to win, from the guide's read of it on
/// your turn: 0 when it is already complete, 1 when one discard leaves it
/// waiting on a single winning draw, and so on.
int tilesAway(EfficiencyReport report) => report.currentShanten + 1;

/// The tiles that would complete the hand once it is [tilesAway] == 1, from
/// the guide's pick; empty for a hand further out, or already complete.
List<TileType> winningTiles(EfficiencyReport report) {
  if (report.lines.isEmpty || tilesAway(report) != 1) return const [];
  return simpleChoices(report, count: 1).first.accepts;
}

/// What a discard does for the hand, in the terms the simple view uses.
enum DiscardOutlook { wins, waiting, onTrack, furtherAway }

/// How [line] leaves a hand whose guide read is [report].
DiscardOutlook outlookOf(DiscardLine line, EfficiencyReport report) {
  if (line.shanten < 0) return DiscardOutlook.wins;
  if (line.shanten == 0) return DiscardOutlook.waiting;
  return line.shanten > report.currentShanten
      ? DiscardOutlook.furtherAway
      : DiscardOutlook.onTrack;
}

/// The guide's pick, then the best of the rest, at most [count] in all.
List<DiscardLine> simpleChoices(EfficiencyReport report, {int count = 3}) {
  final best = report.lines.firstWhere((l) => l.recommended,
      orElse: () => report.lines.first);
  return [
    best,
    ...report.lines.where((l) => l != best).take(count - 1),
  ];
}

/// The simple view's body: where the hand stands, the best discard and why,
/// and a couple of alternatives.
class SimpleGuideBody extends StatelessWidget {
  const SimpleGuideBody(
      {super.key,
      required this.report,
      this.shortfall = MinimumShortfall.none,
      this.complete = false});

  final EfficiencyReport report;

  /// True when the hand is already a winning one (you can declare the win).
  /// The report only ranks discards, so it reads such a hand as one tile
  /// away; the caller knows better.
  final bool complete;

  /// Set when the hand is ready but too cheap to win at this table.
  final MinimumShortfall shortfall;

  /// The most steps the meter draws; a hand further out shows it empty.
  static const meterSteps = 6;

  String _status(AppLocalizations l10n) {
    final away = _away;
    return away <= 0 ? l10n.guideStatusComplete : l10n.guideAway(away);
  }

  int get _away => complete ? 0 : tilesAway(report);

  /// A bar that fills as the hand nears a win, and the tiles that finish it.
  Widget _meter(AppLocalizations l10n) {
    final filled = meterSteps - _away.clamp(0, meterSteps);
    final done = _away <= 0;
    final waits = complete ? const <TileType>[] : winningTiles(report);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_status(l10n),
            key: const Key('simpleGuideStatus'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.35)),
        const SizedBox(height: 4),
        Row(
          key: const Key('simpleGuideMeter'),
          children: [
            for (var i = 0; i < meterSteps; i++)
              Expanded(
                child: Container(
                  key: Key('meterStep_$i'),
                  height: 6,
                  margin: EdgeInsets.only(right: i == meterSteps - 1 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: i < filled
                        ? (done ? AppColors.right : AppColors.gold)
                        : const Color(0x33ffffff),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        if (waits.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
              l10n.guideWinningTiles(
                  simpleChoices(report, count: 1).first.ukeire),
              key: const Key('simpleGuideWaitsLabel'),
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 3),
          Wrap(
            key: const Key('simpleGuideWaits'),
            spacing: 3,
            runSpacing: 3,
            children: [
              for (final t in waits) TileFace(type: t, size: TileSize.small),
            ],
          ),
        ],
        if (shortfall != MinimumShortfall.none) ...[
          const SizedBox(height: 6),
          Container(
            key: const Key('simpleGuideShortfall'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x33ffa000),
              border: Border.all(color: const Color(0xffffa000)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(l10n.minimumShortfallTooltip(shortfall),
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10, height: 1.3)),
          ),
        ],
      ],
    );
  }

  String _outlook(AppLocalizations l10n, DiscardLine line) =>
      switch (outlookOf(line, report)) {
        DiscardOutlook.wins => l10n.guideOutlookWins,
        DiscardOutlook.waiting => l10n.guideOutlookWaiting(line.ukeire),
        // A tile count only means something near the end: from further out
        // it is most of the wall.
        DiscardOutlook.onTrack => line.shanten <= 1
            ? l10n.guideOutlookOnTrack(line.ukeire)
            : l10n.guideOutlookOnTrackFar,
        DiscardOutlook.furtherAway => l10n.guideOutlookFurther,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choices = simpleChoices(report);
    final best = choices.first;
    return Column(
      key: const Key('simpleGuide'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _meter(l10n),
        const SizedBox(height: 8),
        Container(
          key: const Key('simpleGuideBest'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0x3343a047),
            border: Border.all(color: AppColors.right),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              TileFace(type: best.discard, size: TileSize.normal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.guideBestDiscard,
                        style: const TextStyle(
                            color: Color(0xff9ccc65),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(_outlook(l10n, best),
                        key: const Key('simpleGuideBestWhy'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (choices.length > 1) ...[
          const SizedBox(height: 8),
          Text(l10n.guideOtherChoices,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
          for (final line in choices.skip(1))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                key: Key('simpleGuideRow_${line.discard.code}'),
                children: [
                  TileFace(type: line.discard, size: TileSize.small),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_outlook(l10n, line),
                        style: TextStyle(
                            color: outlookOf(line, report) ==
                                    DiscardOutlook.furtherAway
                                ? const Color(0xffff8a80)
                                : Colors.white70,
                            fontSize: 11,
                            height: 1.3)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
