import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/guide_host.dart';
import '../logic/efficiency_engine.dart';
import '../logic/round.dart';
import '../main.dart' show handFocusColor, playStyleColor;
import 'tile_face.dart';

class EfficiencyOverlay extends StatefulWidget {
  const EfficiencyOverlay(
      {super.key,
      required this.game,
      required this.report,
      this.maxHeight = 628,
      this.showGameControls = true});
  final GuideHost game;
  final EfficiencyReport report;

  /// How far the panel may run down the screen before its inner ScrollView
  /// takes over. Callers pass the space actually available above the hand bar;
  /// the default matches the 820px design canvas.
  final double maxHeight;

  /// False in the scenario builder, which has no pause key and no turn loop —
  /// it drops the glossary's game-control line.
  final bool showGameControls;

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
              _styleDial(),
              _focusDial(),
              const SizedBox(height: 8),
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
                              'Safety vs ${seatDisplayName(widget.game.safetyOpponentSeat!)} (estimated risk)',
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

  /// The play-style dial, mirrored here from the app bar (live game) or the
  /// tool bar (scenario builder). It is not a second setting: both read and
  /// write the one [GuideHost.playStyle], so moving either moves the other.
  Widget _styleDial() {
    final current = widget.game.playStyle;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Text(
            'STYLE',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          for (final style in PlayStyle.values)
            Expanded(child: _styleChip(style, style == current)),
        ],
      ),
    );
  }

  /// The hand-focus dial, the second and independent axis: [_styleDial] says
  /// how much danger is worth taking, this says which hand to take it for.
  Widget _focusDial() {
    final current = widget.game.handFocus;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Text(
            'FOCUS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          for (final focus in HandFocus.values)
            Expanded(
              child: _dialChip(
                label: focus.label,
                colour: handFocusColor(focus),
                active: focus == current,
                chipKey: Key('guideHandFocus_${focus.name}'),
                onTap: () => widget.game.setHandFocus(focus),
              ),
            ),
        ],
      ),
    );
  }

  Widget _styleChip(PlayStyle style, bool active) => _dialChip(
        label: style.label,
        colour: playStyleColor(style),
        active: active,
        chipKey: Key('guidePlayStyle_${style.name}'),
        onTap: () => widget.game.setPlayStyle(style),
      );

  /// One chip of either dial — same shape, same hit target, so the two rows
  /// read as two settings of a kind rather than two different controls.
  Widget _dialChip({
    required String label,
    required Color colour,
    required bool active,
    required Key chipKey,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        key: chipKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: active
                ? colour.withValues(alpha: 0.22)
                : const Color(0x14ffffff),
            border:
                Border.all(color: active ? colour : const Color(0x33ffffff)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? colour : Colors.white54,
              fontSize: 9,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  String? _topPlan(EfficiencyReport r) =>
      r.tenpai && r.lines.isNotEmpty ? r.lines.first.valuePlan : null;

  Widget _planReason(DiscardLine top) {
    if (top.reason.isEmpty) return const SizedBox.shrink();
    final act = top.valuePlan == 'READY';
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
          if (_topPlan(r) == 'READY' && !_minimized)
            const Text('READY',
                style: TextStyle(color: Color(0xff9ccc65), fontSize: 10)),
          if ((widget.game.kanAdvice?.advice.eligible ?? false) && !_minimized)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xff4527a0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('KONG',
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
      CallType.chi => 'CHOW',
      CallType.pon => 'PUNG',
      CallType.kan => 'KONG',
      CallType.ron => 'WIN',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showGameControls)
          const Text('• Esc — pause the game', style: style),
        Text('• Shanten — tiles away from a ready hand (0 = tenpai)',
            style: style),
        Text('• Ukeire — live tiles that reduce shanten', style: style),
        _evTooltip(
          Text(
            '• Expected Value — chance of finishing x what the win '
            'pays, less what the cut risks',
            style: style.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: const Color(0x8880cbc4),
            ),
          ),
        ),
        Text(
            '• Safety — higher means lower estimated risk; no discard immunity',
            style: style),
        Text('• Risk — points taken off EV for the danger of this cut',
            style: style),
        Text('• Style — how much danger the guide will take on', style: style),
        Text(
            '• Focus — what it will take that danger for: a quicker hand '
            'or a bigger one',
            style: style),
        Text('• Green tile — the guide\'s recommended discard', style: style),
        Text('• Yellow tile — the tile you just drew', style: style),
      ],
    );
  }

  /// Text styles for the Expected Value tooltip. Deliberately larger than the
  /// 9px panel body — the panel is a dense table you scan, the tooltip is
  /// something you stop and read.
  static const _tipTitle = TextStyle(
      color: Color(0xffe9d58f),
      fontSize: 13,
      height: 1.6,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4);
  static const _tipBody =
      TextStyle(color: Colors.white, fontSize: 12.5, height: 1.55);
  static const _tipMath = TextStyle(
    color: Color(0xff9fe0d8),
    fontSize: 12.5,
    height: 1.6,
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New', 'monospace'],
  );
  static const _tipDim =
      TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.5);
  static const _tipHead = TextStyle(
      color: Color(0xff9fe0d8),
      fontSize: 10,
      height: 1.9,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5);

  /// A heading inside the tooltip. The panel reads as a stack of short
  /// labelled parts rather than one block of prose, and each heading is the
  /// same phrase the worked example below uses for that row — so a reader can
  /// go straight from a number to the sentence explaining it.
  static TextSpan _tipPart(String heading, String body) => TextSpan(children: [
        TextSpan(text: '\n$heading\n', style: _tipHead),
        TextSpan(text: body, style: _tipBody),
      ]);

  static final List<InlineSpan> _evGeneral = [
    const TextSpan(text: 'EXPECTED VALUE\n', style: _tipTitle),
    const TextSpan(
        text: 'The average points this discard is worth to you.\n',
        style: _tipBody),
    const TextSpan(
        text: '\n  EV  =  chance of finishing\n'
            '         x  what the win pays\n'
            '         -  what the cut risks\n',
        style: _tipMath),
    _tipPart(
        'CHANCE OF FINISHING',
        'Winning once you are ready, and getting there first. Rises with more '
            'useful tiles still live and more draws left to find them.\n'),
    _tipPart(
        'WHAT THE WIN PAYS',
        'Hong Kong faan converted to chips. Ready hands use exact scoring; '
            'unfinished hands use an estimate of their visible patterns.\n'),
    _tipPart(
        'WHAT THE CUT RISKS',
        'Estimated loss against an opponent with two or more exposed sets. '
            'A previously discarded tile can still win; no tile is guaranteed safe.\n'),
    _tipPart(
        'FOCUS',
        'Speed and Value tilt the trade between the first two terms — Speed '
            'pays points for a better chance of getting there, Value does the '
            'reverse. Balanced leaves it alone, and shows no tilt line below.\n'),
    const TextSpan(
        text: '\nHigher is better, and it can go negative: a dangerous cut on '
            'a cheap hand loses points on average.',
        style: _tipDim),
  ];

  /// 1234.5 -> "1,235".
  static String _pts(double v) {
    final n = v.round();
    final digits = n.abs().toString();
    final buf = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// One right-aligned `label ....... value` row of the worked example.
  static String _row(String label, String value) =>
      '  ${label.padRight(22)}${value.padLeft(9)}\n';

  /// This line's own arithmetic, so the number in the cell can be checked by
  /// eye. Reconstructs exactly what the engine did — see [DiscardLine]. Every
  /// row is labelled with the phrase the section above uses for it.
  static List<InlineSpan> _evWorked(DiscardLine line, HandFocus focus) {
    final gross = line.winProbability * (line.averagePoints + line.winBonus);
    final pct = (line.winProbability * 100)
        .toStringAsFixed(line.winProbability < 0.1 ? 1 : 0);
    final spans = <InlineSpan>[
      const TextSpan(text: '\n', style: _tipDim),
      TextSpan(text: '\nTHIS CUT — ${line.discard.code}\n', style: _tipTitle),
    ];

    if (line.averagePoints <= 0) {
      spans.add(TextSpan(
          text: line.reason.isNotEmpty
              ? '${line.reason}\n'
              : 'This line has no winning hand to score yet.\n',
          style: _tipBody));
      if (line.riskCost > 0.5) {
        spans.add(TextSpan(
            text: _row('risk of this cut', '-${_pts(line.riskCost)}') +
                _row('expected value', _pts(line.expectedValue)),
            style: _tipMath));
      }
      return spans;
    }

    final buf = StringBuffer()
      ..write(_row('chance of finishing', '$pct%'))
      ..write(_row('what the win pays', _pts(line.averagePoints)));
    buf.write(_row('so on average', _pts(gross)));
    if (line.valueTilt.abs() > 0.5) {
      final sign = line.valueTilt > 0 ? '+' : '-';
      buf.write(_row('${focus.label.toLowerCase()} tilt',
          '$sign${_pts(line.valueTilt.abs())}'));
    }

    if (line.dealInCost > 0.5) {
      buf.write(_row('less deal-in risk', '-${_pts(line.dealInCost)}'));
    }
    if (line.commitmentCost > 0.5) {
      buf.write(_row('less turns committed', '-${_pts(line.commitmentCost)}'));
    }
    buf.write('  ${'-' * 31}\n');
    buf.write(_row('expected value', _pts(line.expectedValue)));
    spans.add(TextSpan(text: buf.toString(), style: _tipMath));
    return spans;
  }

  /// Wrap any mention of Expected Value so hovering it explains the number.
  /// Pass [line] on a table cell to append that row's own arithmetic.
  Widget _evTooltip(Widget child, {DiscardLine? line}) => Tooltip(
        richMessage: TextSpan(children: [
          ..._evGeneral,
          if (line != null) ..._evWorked(line, widget.game.handFocus),
        ]),
        waitDuration: const Duration(milliseconds: 250),
        showDuration: const Duration(seconds: 30),
        preferBelow: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: const Color(0xf5041c1d),
          border: Border.all(color: const Color(0x5580cbc4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );

  Widget _efficiencyTable(EfficiencyReport r) {
    return Table(
      columnWidths: {
        0: const FixedColumnWidth(34),
        1: const FixedColumnWidth(52),
        2: const FixedColumnWidth(48),
        3: const FixedColumnWidth(50),
        if (r.defending) ...{
          4: const FixedColumnWidth(34),
          5: const FixedColumnWidth(40),
          6: const FixedColumnWidth(92),
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
          if (r.defending) ...['Safety', 'Risk', 'Detail'],
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
              // Each cell explains its own number, not just the column.
              _evTooltip(
                _cell(
                  line.expectedValue.round().toString(),
                  bold: line.bestExpectedValue,
                  color: const Color(0xff80cbc4),
                ),
                line: line,
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
                // What this cut's deal-in chance already took off the
                // expected value beside it.
                _cell(
                  line.riskCost < 0.5 ? '—' : '-${line.riskCost.round()}',
                  color: line.riskCost < 0.5
                      ? Colors.white38
                      : const Color(0xffff8a80),
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
        children: labels.map((l) {
          // The Expected Value heading carries the formula behind the column.
          final isEv = l == 'Expected Value';
          final cell = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            child: Text(l,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isEv ? const Color(0xffbfe6e0) : Colors.white70,
                  fontSize: 9,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  decoration: isEv ? TextDecoration.underline : null,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationColor: const Color(0x8880cbc4),
                )),
          );
          return isEv ? _evTooltip(cell) : cell;
        }).toList(),
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
