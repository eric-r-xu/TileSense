/// The guide panel's simple view for new players: one best discard with a
/// plain-language reason, instead of the table of shanten, ukeire, EV,
/// placement and safety figures. Which view shows is a per-device choice.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../logic/efficiency_engine.dart';
import '../telemetry/src/platform_web.dart'
    if (dart.library.io) '../telemetry/src/platform_stub.dart' as platform;
import 'tile_face.dart';

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
  const SimpleGuideBody({super.key, required this.report});

  final EfficiencyReport report;

  String _status(AppLocalizations l10n) {
    final s = report.currentShanten;
    if (s < 0) return l10n.guideStatusComplete;
    if (s == 0) return l10n.guideStatusReady;
    return l10n.guideStatusSteps(s);
  }

  String _outlook(AppLocalizations l10n, DiscardLine line) =>
      switch (outlookOf(line, report)) {
        DiscardOutlook.wins => l10n.guideOutlookWins,
        DiscardOutlook.waiting => l10n.guideOutlookWaiting(line.ukeire),
        DiscardOutlook.onTrack => l10n.guideOutlookOnTrack(line.ukeire),
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
        Text(_status(l10n),
            key: const Key('simpleGuideStatus'),
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.35)),
        const SizedBox(height: 8),
        Container(
          key: const Key('simpleGuideBest'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0x3343a047),
            border: Border.all(color: const Color(0xff43a047)),
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
