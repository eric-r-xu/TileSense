import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/round.dart';
import '../logic/efficiency_engine.dart';
import 'tile_face.dart';

/// The translucent bottom-left training panel. Mirrors the Vala client's
/// `TileEfficiencyOverlay`: an action guide, an "expected value / efficiency"
/// table, and — when an opponent is in riichi — a defensive safety table.
class EfficiencyOverlay extends StatefulWidget {
  const EfficiencyOverlay({super.key, required this.game, required this.report});
  final GameController game;
  final EfficiencyReport report;

  @override
  State<EfficiencyOverlay> createState() => _EfficiencyOverlayState();
}

class _EfficiencyOverlayState extends State<EfficiencyOverlay> {
  bool _minimized = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final screen = MediaQuery.sizeOf(context);
    final panelWidth = (screen.width - 16).clamp(280.0, 360.0).toDouble();
    // Take up most of the available height so the defensive-play table is
    // never clipped when an opponent is in riichi.
    final panelMaxHeight = (screen.height - 150).clamp(320.0, 760.0).toDouble();
    return Material(
      color: const Color(0xdd031213),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: panelWidth,
        constraints: BoxConstraints(maxHeight: panelMaxHeight),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(r),
            if (!_minimized) ...[
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _actionsGuide(),
                      if (r.lines.isEmpty)
                        Text(r.headline ?? 'Waiting…',
                            style: const TextStyle(color: Colors.white70))
                      else
                        _efficiencyTable(r),
                      if (r.defending) ...[
                        const SizedBox(height: 12),
                        _defenseTable(r),
                      ],
                      const SizedBox(height: 10),
                      const Text(
                        'ukeire = live tiles that reduce shanten · '
                        'EV = probability-weighted points · '
                        'safety 15 = genbutsu',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(EfficiencyReport r) {
    return InkWell(
      onTap: () => setState(() => _minimized = !_minimized),
      child: Row(
        children: [
          const Icon(Icons.insights, size: 16, color: Color(0xffe9d58f)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _minimized ? 'GUIDE — tap to expand' : 'GUIDE',
              style: const TextStyle(
                color: Color(0xffe9d58f),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (r.recommendRiichi && !_minimized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xff2e7d32),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('RIICHI',
                  style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          Icon(_minimized ? Icons.expand_more : Icons.expand_less,
              size: 16, color: Colors.white54),
        ],
      ),
    );
  }

  /// An "ACTIONS" block naming the calls that are live this turn (riichi, pon,
  /// kan, ron, tsumo) with a short recommendation, echoing the Vala guide's
  /// action lines.
  Widget _actionsGuide() {
    final game = widget.game;
    final r = widget.report;
    final rows = <(String, Color)>[];

    if (game.humanCanTsumo) {
      rows.add(('Tsumo — you can win off your draw', const Color(0xff81c784)));
    }
    if (game.awaitingHumanCall) {
      final types = game.humanCallOption!.types;
      if (types.contains(CallType.ron)) {
        rows.add(('Ron — the discard completes your hand',
            const Color(0xff81c784)));
      }
      if (types.contains(CallType.pon)) {
        rows.add(('Pon — call the discard for a triplet (opens your hand)',
            const Color(0xffe9d58f)));
      }
      if (types.contains(CallType.kan)) {
        rows.add(('Kan — call the discard for a quad + dead-wall draw',
            const Color(0xffe9d58f)));
      }
      rows.add(('Pass — keep your hand concealed', Colors.white54));
    }
    if (game.humanCanRiichi) {
      rows.add((
        r.recommendRiichi
            ? 'Riichi — recommended: declare and discard sideways'
            : 'Riichi — available (tenpai, hand closed)',
        r.recommendRiichi ? const Color(0xff81c784) : const Color(0xffe9d58f),
      ));
    }
    for (final t in game.humanClosedKanTypes) {
      rows.add(('Closed kan ${t.code} — four in hand, draw from the dead wall',
          const Color(0xffe9d58f)));
    }
    if (rows.isEmpty) {
      rows.add((
        r.tenpai
            ? 'Tenpai — stay damaten or riichi on your turn'
            : 'No call available — discard toward tenpai',
        Colors.white54,
      ));
    }
    rows.add(('Damaten worth it from ~5200 pts (7700 as dealer)',
        Colors.white38));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACTIONS',
              style: TextStyle(
                  color: Color(0xffe9d58f),
                  fontWeight: FontWeight.w700,
                  fontSize: 11)),
          const SizedBox(height: 2),
          for (final (text, color) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text('· $text',
                  style: TextStyle(color: color, fontSize: 10.5)),
            ),
        ],
      ),
    );
  }

  Widget _efficiencyTable(EfficiencyReport r) {
    final rows = r.lines.take(10).toList();
    // "Highlight the autoplay action in blue, and any ties in best EV / safest
    // in green." The autoplay action is the recommended line; a green tie is
    // any other line matching the top EV, or (while defending) the top safety.
    final topEv = rows.isEmpty
        ? 0
        : rows
            .map((l) => l.expectedValue.round())
            .reduce((a, b) => a > b ? a : b);
    final topSafety = r.defending
        ? rows
            .map((l) => l.safety?.rating ?? -1)
            .fold<int>(-1, (a, b) => a > b ? a : b)
        : -1;
    bool isGreenTie(DiscardLine l) {
      if (l.recommended) return false;
      final evTie = topEv > 0 && l.expectedValue.round() == topEv;
      final safeTie = topSafety >= 0 && (l.safety?.rating ?? -1) == topSafety;
      return evTie || safeTie;
    }

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(36),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.1),
        3: FlexColumnWidth(1.6),
      },
      border: TableBorder.all(color: const Color(0x33ffffff)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(const ['', 'S', 'U', 'EV']),
        for (final line in rows)
          TableRow(
            decoration: BoxDecoration(
              color: line.recommended
                  ? const Color(0x403d7bff) // autoplay action — blue
                  : isGreenTie(line)
                      ? const Color(0x3343a047) // tied best EV / safest — green
                      : line.bestUkeire
                          ? const Color(0x18caa24e)
                          : null,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(3),
                child: TileFace(type: line.discard, size: TileSize.small),
              ),
              _cell(line.shanten == -1 ? 'win' : line.shanten.toString()),
              _cell(line.ukeire.toString(),
                  bold: line.bestUkeire, color: const Color(0xffffdf76)),
              _cell(
                line.expectedValue.round().toString(),
                bold: line.bestExpectedValue,
                color: const Color(0xff80cbc4),
              ),
            ],
          ),
      ],
    );
  }

  Widget _defenseTable(EfficiencyReport r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DEFENSIVE PLAY',
            style: TextStyle(
                color: Color(0xffff8a80),
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {
            0: FixedColumnWidth(34),
            1: FixedColumnWidth(42),
            2: FlexColumnWidth(),
          },
          border: TableBorder.all(color: const Color(0x33ffffff)),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            _headerRow(const ['', 'safety', 'read']),
            for (final s in r.defense.take(8))
              TableRow(
                decoration: BoxDecoration(
                  color: r.defense.isNotEmpty &&
                          s.rating == r.defense.first.rating
                      ? const Color(0x3343a047) // safest — green
                      : null,
                ),
                children: [
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: TileFace(type: s.type, size: TileSize.small),
                ),
                _cell('${s.rating}',
                    color: s.rating >= 15
                        ? const Color(0xff81c784)
                        : s.rating >= 8
                            ? const Color(0xffe9d58f)
                            : const Color(0xffff8a80)),
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(s.label,
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ),
              ]),
          ],
        ),
      ],
    );
  }

  TableRow _headerRow(List<String> labels) => TableRow(
        decoration: const BoxDecoration(color: Color(0x22ffffff)),
        children: labels
            .map((l) => Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(l,
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ))
            .toList(),
      );

  Widget _cell(String text, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.all(3),
        child: Text(
          text,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
}
