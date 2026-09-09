import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../logic/efficiency_engine.dart';
import '../logic/round.dart';
import 'tile_face.dart';

/// The translucent top-left training panel: an "expected value / efficiency"
/// table — with two extra safety columns folded in while an opponent is in
/// riichi — and, when a call is on offer, the recommended response.
class EfficiencyOverlay extends StatefulWidget {
  const EfficiencyOverlay(
      {super.key,
      required this.game,
      required this.report,
      this.maxHeight = 628});
  final GameController game;
  final EfficiencyReport report;

  /// How far the panel may run down the screen before its inner ScrollView
  /// takes over. Callers pass the space actually available above the hand bar;
  /// the default matches the 820px design canvas.
  final double maxHeight;

  @override
  State<EfficiencyOverlay> createState() => _EfficiencyOverlayState();
}

class _EfficiencyOverlayState extends State<EfficiencyOverlay> {
  bool _minimized = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final panelWidth =
        (MediaQuery.sizeOf(context).width - 16).clamp(260.0, 380.0).toDouble();
    return Material(
      color: const Color(0xdd031213),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: panelWidth,
        // Runs down to just above the hand bar, whatever the window height —
        // the inner ScrollView still handles anything taller than that.
        constraints:
            BoxConstraints(maxHeight: widget.maxHeight.clamp(200.0, 4000.0)),
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
                      _kanReason(),
                      if (r.lines.isEmpty)
                        Text(r.headline ?? 'Waiting…',
                            style: const TextStyle(color: Colors.white70))
                      else ...[
                        if (r.tenpai) _planReason(r.lines.first),
                        if (r.defending &&
                            widget.game.safetyOpponentSeat != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Safety vs ${seatDisplayName(widget.game.safetyOpponentSeat!)} (riichi only)',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 9),
                            ),
                          ),
                        _efficiencyTable(r),
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

  /// The recommended line's plan ('RIICHI', 'DAMATEN', ...) once tenpai, for
  /// the header badge — null before tenpai or with nothing to recommend.
  String? _topPlan(EfficiencyReport r) =>
      r.tenpai && r.lines.isNotEmpty ? r.lines.first.valuePlan : null;

  /// Why the recommended tenpai line is riichi, damaten, or otherwise — the
  /// same reasoning [GameController.recommendedCallReason] gives for calls,
  /// just for the riichi/damaten decision instead.
  Widget _planReason(DiscardLine top) {
    if (top.reason.isEmpty) return const SizedBox.shrink();
    final act = top.valuePlan == 'RIICHI' || top.valuePlan == 'DAMATEN';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: act ? const Color(0x3343a047) : const Color(0x22ffffff),
        border: Border.all(
            color: act ? const Color(0xff43a047) : const Color(0x44ffffff)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(top.valuePlan,
              style: TextStyle(
                  color: act ? const Color(0xff9ccc65) : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(top.reason,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 10, height: 1.3)),
        ],
      ),
    );
  }

  /// Whether to declare the closed/added kan available on the human's turn
  /// right now, and why — the same treatment as [_planReason], just for the
  /// kan decision, which (unlike riichi/damaten) can come up on any turn.
  Widget _kanReason() {
    final k = widget.game.kanAdvice;
    if (k == null || k.advice.reason.isEmpty) return const SizedBox.shrink();
    final act = k.advice.eligible;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: act ? const Color(0x334527a0) : const Color(0x22ffffff),
        border: Border.all(
            color: act ? const Color(0xff7e57c2) : const Color(0x44ffffff)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KAN ${k.type.code} — ${act ? 'take it' : 'skip it'}',
              style: TextStyle(
                  color: act ? const Color(0xffb39ddb) : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(k.advice.reason,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 10, height: 1.3)),
        ],
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
          if (_topPlan(r) == 'DAMATEN' && !_minimized)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xff33691e),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('DAMATEN',
                  style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          if ((widget.game.kanAdvice?.advice.eligible ?? false) && !_minimized)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xff4527a0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('KAN',
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
      CallType.chi => 'CHI',
      CallType.pon => 'PON',
      CallType.kan => 'KAN',
      CallType.ron => 'RON',
      CallType.none => 'PASS',
    };
    final offered = [
      for (final t in [CallType.ron, CallType.kan, CallType.pon, CallType.chi])
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
                            color: act ? const Color(0xff9ccc65) : Colors.white,
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

  /// Succinct bulleted glossary: controls, column terms, and the tile-
  /// highlight legend, all in one small white footnote block.
  Widget _glossary() {
    const style = TextStyle(color: Colors.white70, fontSize: 9, height: 1.35);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• Esc — pause the game', style: style),
        Text('• Shanten — tiles away from a ready hand (0 = tenpai)',
            style: style),
        Text('• Ukeire — live tiles that reduce shanten', style: style),
        Text('• Expected Value — probability-weighted points', style: style),
        Text('• Safety — 0 (dangerous) to 15 (genbutsu); riichi opponent only',
            style: style),
        Text(
            '• Genbutsu — their own discards, or others passed after their riichi',
            style: style),
        Text('• Green tile — the guide\'s recommended discard', style: style),
        Text('• Yellow tile — the tile you just drew', style: style),
      ],
    );
  }

  /// The efficiency table — every distinct discard in hand, recommended line
  /// always first (see [EfficiencyEngine.analyze]). While defending against a
  /// riichi, two more (narrow) columns fold the safety ranking in rather than
  /// showing it as a second table.
  Widget _efficiencyTable(EfficiencyReport r) {
    return Table(
      columnWidths: {
        0: const FixedColumnWidth(34),
        1: const FixedColumnWidth(52),
        2: const FixedColumnWidth(48),
        3: const FixedColumnWidth(50),
        if (r.defending) ...{
          4: const FixedColumnWidth(34),
          5: const FixedColumnWidth(92),
        },
      },
      border: TableBorder.all(color: const Color(0x33ffffff)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow([
          '',
          'Shanten',
          'Ukeire',
          'Expected Value',
          if (r.defending) ...['Safety', 'Detail'],
        ]),
        for (final line in r.lines)
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
              if (r.defending) ...[
                _cell(
                  line.safety == null ? '—' : '${line.safety!.rating}',
                  color: switch (line.safety?.rating) {
                    null => Colors.white38,
                    >= 15 => const Color(0xff81c784),
                    >= 8 => const Color(0xffe9d58f),
                    _ => const Color(0xffff8a80),
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(
                    line.safety?.label ?? '—',
                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  TableRow _headerRow(List<String> labels) => TableRow(
        decoration: const BoxDecoration(color: Color(0x22ffffff)),
        children: labels
            .map((l) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
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
