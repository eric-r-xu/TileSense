import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/efficiency_engine.dart';
import '../logic/round.dart';
import 'tile_face.dart';

/// The translucent top-left training panel: an "expected value / efficiency"
/// table, a defensive safety table when an opponent is in riichi, and — when a
/// call is on offer — the recommended response.
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
    final panelWidth =
        (MediaQuery.sizeOf(context).width - 16).clamp(260.0, 340.0).toDouble();
    return Material(
      color: const Color(0xdd031213),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: panelWidth,
        constraints: const BoxConstraints(maxHeight: 460),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(r),
            if (!_minimized) ...[
              const SizedBox(height: 6),
              if (widget.game.awaitingHumanCall) _callAdvice(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      _glossary(),
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
          // tilesense wordmark, sized to the text height, to the left.
          Image.asset('assets/tilesense.png',
              height: 15,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _minimized ? 'GUIDE — Tap to expand' : 'GUIDE — Tap to minimize',
              style: const TextStyle(
                color: Color(0xffe9d58f),
                fontWeight: FontWeight.w600,
                fontSize: 12,
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

  /// Shown while a call (pon/kan/ron) is on offer to the human: the tile that
  /// was cut and the response the guide recommends.
  Widget _callAdvice() {
    final opt = widget.game.humanCallOption;
    final tile = widget.game.round.pendingDiscard;
    if (opt == null || tile == null) return const SizedBox.shrink();
    final rec = widget.game.recommendedCall ?? CallType.none;
    final recLabel = switch (rec) {
      CallType.pon => 'PON',
      CallType.kan => 'KAN',
      CallType.ron => 'RON',
      CallType.none => 'PASS',
    };
    final offered = [
      for (final t in [CallType.ron, CallType.kan, CallType.pon])
        if (opt.types.contains(t)) t.name.toUpperCase(),
      'PASS',
    ].join(' · ');
    final act = rec != CallType.none;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: act ? const Color(0x3343a047) : const Color(0x22ffffff),
        border: Border.all(
            color: act ? const Color(0xff43a047) : const Color(0x44ffffff)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TileFace(type: tile.type, size: TileSize.small),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CALL DECISION',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                    Text('Recommended: $recLabel',
                        style: TextStyle(
                            color: act
                                ? const Color(0xff9ccc65)
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Options: $offered',
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          if (widget.game.recommendedCallReason case final why?
              when why.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(why,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10, height: 1.3)),
          ],
        ],
      ),
    );
  }

  /// One-line glossary, bulleted, with every column term spelled out.
  Widget _glossary() {
    const style = TextStyle(color: Colors.white38, fontSize: 10, height: 1.35);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• Shanten — tiles away from a ready hand (0 = tenpai)',
            style: style),
        Text('• Ukeire — live tiles that reduce shanten', style: style),
        Text('• Expected Value — probability-weighted points', style: style),
        Text('• Safety 15 — genbutsu (fully safe discard)', style: style),
      ],
    );
  }

  Widget _efficiencyTable(EfficiencyReport r) {
    final rows = r.lines.take(8).toList();
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(34),
        1: FixedColumnWidth(52),
        2: FixedColumnWidth(48),
        3: FixedColumnWidth(50),
      },
      border: TableBorder.all(color: const Color(0x33ffffff)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(const ['', 'Shanten', 'Ukeire', 'Expected Value']),
        for (final line in rows)
          TableRow(
            decoration: BoxDecoration(
              color: line.recommended
                  ? const Color(0x3343a047)
                  : line.bestUkeire
                      ? const Color(0x22caa24e)
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
              TableRow(children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  child: Text(l,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          height: 1.15,
                          fontWeight: FontWeight.w700)),
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
