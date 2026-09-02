import 'package:flutter/material.dart';

import '../logic/efficiency_engine.dart';
import 'tile_face.dart';

/// The translucent bottom-left training panel. Mirrors the Vala client's
/// `TileEfficiencyOverlay`: an "expected value / efficiency" table plus, when an
/// opponent is in riichi, a defensive safety table.
class EfficiencyOverlay extends StatefulWidget {
  const EfficiencyOverlay({super.key, required this.report});
  final EfficiencyReport report;

  @override
  State<EfficiencyOverlay> createState() => _EfficiencyOverlayState();
}

class _EfficiencyOverlayState extends State<EfficiencyOverlay> {
  bool _minimized = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Material(
      color: const Color(0xdd031213),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 340,
        constraints: const BoxConstraints(maxHeight: 460),
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
              _minimized
                  ? 'EFFICIENCY GUIDE — tap to expand'
                  : (r.headline ?? 'EFFICIENCY GUIDE'),
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

  Widget _efficiencyTable(EfficiencyReport r) {
    final rows = r.lines.take(8).toList();
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(34),
        1: FixedColumnWidth(64),
        2: FixedColumnWidth(48),
        3: FlexColumnWidth(),
      },
      border: TableBorder.all(color: const Color(0x33ffffff)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(const ['', 'shanten', 'ukeire', 'accepts']),
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
              Padding(
                padding: const EdgeInsets.all(3),
                child: Wrap(
                  spacing: 1,
                  runSpacing: 1,
                  children: line.accepts
                      .take(9)
                      .map((t) => TileFace(type: t, size: TileSize.tiny))
                      .toList(),
                ),
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
