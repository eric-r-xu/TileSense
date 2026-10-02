import 'dart:math' as math;

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:url_launcher/url_launcher.dart';

import '../game/guide_host.dart';
import '../l10n/l10n.dart';
import '../l10n/guide_terms.dart';
import '../game/mortal_advisor.dart';
import '../logic/efficiency_engine.dart';
import '../logic/placement_utility.dart';
import 'package:mahjong_core/mjai.dart' show mjaiTile;
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import '../main.dart' show brainColor;
import 'ev_explainer_dialog.dart';
import 'tile_face.dart';

/// The translucent top-left training panel: an "expected value / efficiency"
/// table — with two extra safety columns folded in while an opponent is in
/// riichi — and, when a call is on offer, the recommended response.
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

  /// The row the yaku section describes, once a row's tile is tapped.
  TileType? _yakuDiscard;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    // 380 was wide enough for the table before the Placement column; with it
    // (and especially with it alongside the defending-only Safety/Risk/Detail
    // columns) the table ran wider than the panel and spilled past its
    // rounded border onto the green felt behind it.
    final panelWidth =
        (MediaQuery.sizeOf(context).width - 16).clamp(260.0, 480.0).toDouble();
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
              if (widget.game case final TableGameHost game
                  when game.mortalAvailable)
                _brainRow(game),
              const SizedBox(height: 8),
              if (widget.game.awaitingHumanCall) _callAdvice(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kanReason(),
                      if (!widget.game.awaitingHumanCall) _mortalLine(),
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
                              'Safety vs ${widget.game.seatLabel(widget.game.safetyOpponentSeat!)} '
                              '(${_hk ? 'estimated risk' : 'riichi only'})',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 9),
                            ),
                          ),
                        _efficiencyTable(r),
                        if (!_hk) _yakuSection(r),
                      ],
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

  /// Who Auto-Play follows, mirrored here from the app bar and the phone
  /// menu: all read and write the one [TableGameHost.autoplayBrain].
  Widget _brainRow(TableGameHost game) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _dialLabel('AUTO-PLAY', _brainTip),
          const SizedBox(width: 8),
          for (final brain in AutoplayBrain.values)
            Expanded(
              child: _dialChip(
                label:
                    brain == AutoplayBrain.mortal ? 'Mortal bot' : 'TileSense',
                colour: brainColor(brain),
                active: game.autoplayBrain == brain,
                chipKey: Key('guideBrain_${brain.name}'),
                onTap: () => game.setAutoplayBrain(brain),
              ),
            ),
        ],
      ),
    );
  }

  List<InlineSpan> get _brainTip => <InlineSpan>[
        TextSpan(text: context.l10n.tipAutoTitle, style: _tipTitle),
        TextSpan(text: context.l10n.tipAutoBody, style: _tipBody),
        TextSpan(text: context.l10n.tipAutoChoices, style: _tipBody),
      ];

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

  // Named for Hong Kong, the first Chinese-style ruleset this app had, but
  // true for Taiwanese too — see [Ruleset.isChineseStyle].
  bool get _hk => widget.game.round.ruleset.isChineseStyle;

  /// The recommended line's plan ('RIICHI', 'DAMATEN', ...) once tenpai, for
  /// the header badge — null before tenpai or with nothing to recommend.
  String? _topPlan(EfficiencyReport r) =>
      r.tenpai && r.lines.isNotEmpty ? r.lines.first.valuePlan : null;

  /// Why the recommended tenpai line is riichi, damaten, or otherwise — the
  /// same reasoning `GuideHost.recommendedCallReason` gives for calls,
  /// just for the riichi/damaten decision instead.
  Widget _planReason(DiscardLine top) {
    if (top.reason.isEmpty) return const SizedBox.shrink();
    final act = top.valuePlan == 'RIICHI' ||
        top.valuePlan == 'DAMATEN' ||
        top.valuePlan == 'READY';
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
          Text(
              '${widget.game.round.ruleset.kanLabel.toUpperCase()} '
              '${k.type.code} — ${act ? 'take it' : 'skip it'}',
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
            child: _tipBox(
              Text(
                _minimized
                    ? 'GUIDE — Tap to expand'
                    : 'GUIDE — Tap to minimize',
                style: const TextStyle(
                  color: Color(0xffe9d58f),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              _guideTip(),
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
              child: Text(widget.game.round.ruleset.kanLabel.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
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
    final ruleset = widget.game.round.ruleset;
    String callLabel(CallType t) => switch (t) {
          CallType.chi => ruleset.chiLabel.toUpperCase(),
          CallType.pon => ruleset.ponLabel.toUpperCase(),
          CallType.kan => ruleset.kanLabel.toUpperCase(),
          CallType.ron => ruleset.ronLabel.toUpperCase(),
          CallType.none => 'PASS',
        };
    final recLabel = callLabel(rec);
    final offered = [
      for (final t in [CallType.ron, CallType.kan, CallType.pon, CallType.chi])
        if (opt.types.contains(t)) callLabel(t),
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
          _mortalLine(),
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

  /// Text styles for the TileSense EV tooltip. Deliberately larger than the
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
  static const _tipEquation = TextStyle(
    color: Color(0xff9fe0d8),
    fontSize: 13.5,
    height: 1.5,
    fontStyle: FontStyle.italic,
  );
  static const _tipDim =
      TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.5);

  /// One equation on one line, with real subscripts and superscripts: write
  /// `_{sub}` and `^{sup}` in [src]. Never wraps — a line too wide for the
  /// tooltip is scaled down to fit instead — and ends the line itself.
  static InlineSpan _math(String src) {
    const small = 0.72;
    final base = _tipEquation.fontSize!;
    final parts = <InlineSpan>[];
    final token = RegExp(r'([_^])\{([^}]*)\}');
    var at = 0;
    void plain(String t) {
      if (t.isNotEmpty) parts.add(TextSpan(text: t));
    }

    for (final m in token.allMatches(src)) {
      plain(src.substring(at, m.start));
      final up = m.group(1) == '^';
      parts.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Transform.translate(
          offset: Offset(0, base * (up ? -0.42 : 0.24)),
          child: Text(m.group(2)!,
              softWrap: false,
              style: _tipEquation.copyWith(fontSize: base * small)),
        ),
      ));
      at = m.end;
    }
    plain(src.substring(at));
    return TextSpan(children: [
      const TextSpan(text: '  ', style: _tipBody),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: parts),
            softWrap: false,
            style: _tipEquation,
          ),
        ),
      ),
      const TextSpan(text: '\n', style: _tipBody),
    ]);
  }

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
  static TextSpan _tipPart(String heading, String body, {String? more}) =>
      TextSpan(children: [
        TextSpan(text: '\n$heading\n', style: _tipHead),
        TextSpan(text: body, style: _tipBody),
        if (more != null) TextSpan(text: '→ $more\n', style: _tipDim),
      ]);

  /// What the TileSense EV column means, in general terms — the same answer
  /// whether the hand is ready or five tiles away, and whether or not anyone
  /// is in riichi. The exact coefficients live in the README; what matters
  /// here is which way each part pushes the number.
  List<InlineSpan> get _evGeneralCurrent =>
      _evGeneralFor(widget.game.round.ruleset);

  String get _unit => widget.game.round.ruleset.isHongKong
      ? context.l10n.tipChipsUnit
      : context.l10n.tipPointsUnit;

  List<InlineSpan> _evGeneralFor(Ruleset ruleset) => [
        TextSpan(text: context.l10n.tipEvTitle, style: _tipTitle),
        TextSpan(text: context.l10n.tipEvAverage(_unit), style: _tipBody),
        TextSpan(text: '\n', style: _tipBody),
        _math(
            'TileSense EV = ${context.l10n.mathChance}_{${context.l10n.mathFinish}} × ${context.l10n.mathPayout}_{${context.l10n.mathWin}} − ${context.l10n.mathRisk}_{${context.l10n.mathCut}}'),
        _tipPart(context.l10n.tipFinishTitle, context.l10n.tipFinishBody,
            more: context.l10n.tipFinishMore),
        if (ruleset.isTaiwanese) ...[
          _tipPart(context.l10n.tipPayoutTitle, context.l10n.tipPayoutTw,
              more: context.l10n.tipPayoutMore),
          _tipPart(context.l10n.tipCutTitle, context.l10n.tipCutChinese,
              more: context.l10n.tipCutMore),
        ] else if (ruleset.isHongKong) ...[
          _tipPart(context.l10n.tipPayoutTitle, context.l10n.tipPayoutHk,
              more: context.l10n.tipPayoutMore),
          _tipPart(context.l10n.tipCutTitle, context.l10n.tipCutChinese,
              more: context.l10n.tipCutMore),
        ] else ...[
          _tipPart(context.l10n.tipPayoutTitle, context.l10n.tipPayoutRiichi,
              more: context.l10n.tipPayoutMore),
          _tipPart(context.l10n.tipCutTitle, context.l10n.tipCutRiichi,
              more: context.l10n.tipCutMore),
        ],
        _tipPart(context.l10n.tipFocusTitle, context.l10n.tipFocusBody,
            more: ruleset.isChineseStyle
                ? context.l10n.tipFocusMore
                : context.l10n.tipFocusPlacementMore),
        TextSpan(text: context.l10n.tipEvHigher, style: _tipDim),
      ];

  // ── Explainers for the headings and dials ─────────────────────────────────
  //
  // Each one replaces a line of the old glossary under the table, and carries
  // the tuned numbers behind its concept. Those are read from the engine
  // ([GuideConstants], [PlayStyle], [HandFocus], [PlacementUtility]) so a
  // retune shows up here without anyone remembering to edit the text.
  //
  // The layout is the same throughout: a one-line answer, bullets for the
  // ideas, a real table wherever a reference table is in play, and the formula
  // last for anyone who wants it.

  /// 0.07 -> "7.0%".
  static String _rate(double v) => '${(v * 100).toStringAsFixed(1)}%';

  /// 0.4132 -> "+0.41", -0.2371 -> "−0.24".
  static String _signed(double v) =>
      '${v < 0 ? '−' : '+'}${v.abs().toStringAsFixed(2)}';

  /// A bulleted list: a bold lead-in, then the sentence it introduces.
  List<InlineSpan> _bullets(List<(String, String)> items) => [
        for (final (lead, text) in items)
          TextSpan(children: [
            TextSpan(text: '•  ', style: _tipBody),
            TextSpan(
                text: lead,
                style: _tipBody.copyWith(fontWeight: FontWeight.w700)),
            TextSpan(text: text.isEmpty ? '\n' : ' — $text\n', style: _tipBody),
          ]),
      ];

  /// A small heading over a table or list inside a tooltip.
  static TextSpan _tipSection(String heading) =>
      TextSpan(text: '\n$heading\n', style: _tipHead);

  /// A reference table inside a tooltip. Real cells rather than padded text,
  /// so the columns line up in any font; [left] names the columns that read as
  /// words (the rest are numbers and sit on the right).
  static InlineSpan _tipTable(
    List<String> head,
    List<List<String>> rows, {
    Set<int> left = const {0},
  }) {
    Widget cell(String text, int col, {bool header = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            text,
            textAlign: left.contains(col) ? TextAlign.left : TextAlign.right,
            style: header
                ? const TextStyle(
                    color: Color(0xff9fe0d8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3)
                : const TextStyle(color: Colors.white, fontSize: 11.5),
          ),
        );
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: const TableBorder(
            top: BorderSide(color: Color(0x5580cbc4)),
            bottom: BorderSide(color: Color(0x5580cbc4)),
            horizontalInside: BorderSide(color: Color(0x22ffffff)),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0x2280cbc4)),
              children: [
                for (var c = 0; c < head.length; c++)
                  cell(head[c], c, header: true),
              ],
            ),
            for (final row in rows)
              TableRow(children: [
                for (var c = 0; c < row.length; c++) cell(row[c], c),
              ]),
          ],
        ),
      ),
    );
  }

  /// A dial's name, underlined the way the headings are so it reads as
  /// something to hover.
  Widget _dialLabel(String text, List<InlineSpan> tip) => _tipBox(
        Text(
          text,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: Color(0x8880cbc4),
          ),
        ),
        tip,
      );

  /// What has no heading of its own: the tile colours and the pause key.
  List<InlineSpan> _guideTip() => [
        TextSpan(text: context.l10n.guideTipTitle, style: _tipTitle),
        ..._bullets([
          (context.l10n.guideGreen, context.l10n.guideGreenBody),
          (context.l10n.guideYellow, context.l10n.guideYellowBody),
          if (widget.showGameControls) ('Esc', context.l10n.guidePause),
        ]),
        TextSpan(text: context.l10n.guideHover, style: _tipDim),
      ];

  List<InlineSpan> _shantenTip(bool hk) => [
        TextSpan(
            text:
                '${(hk ? context.l10n.tipAwayLabel : context.l10n.tipShantenLabel).toUpperCase()}\n',
            style: _tipTitle),
        TextSpan(
            text: context.l10n.tipShantenBody(
                hk ? context.l10n.tipReady : context.l10n.tipTenpai),
            style: _tipBody),
      ];

  List<InlineSpan> _ukeireTip(bool hk) {
    final typical = GuideConstants.typicalUkeire;
    return [
      TextSpan(
          text:
              '${(hk ? context.l10n.tipAcceptsLabel : context.l10n.tipUkeireLabel).toUpperCase()}\n',
          style: _tipTitle),
      TextSpan(
          text: context.l10n.tipUkeireBody(
              hk ? context.l10n.tipCloser : context.l10n.tipReduce),
          style: _tipBody),
      TextSpan(text: '\n', style: _tipBody),
      ..._bullets([
        (context.l10n.tipOrdinaryWide, context.l10n.tipOrdinaryWideBody),
      ]),
      _tipSection(context.l10n.tipOrdinaryTitle),
      _tipTable(
        [
          context.l10n.tipShantenLabel,
          for (var i = 0; i < typical.length; i++) '$i'
        ],
        [
          [
            context.l10n.tipUkeireLabel,
            for (final v in typical) v.round().toString()
          ],
        ],
      ),
      TextSpan(text: context.l10n.tipOrdinaryNote, style: _tipDim),
    ];
  }

  /// The riichi ratings this guide reports, in the order the reference table
  /// lists them, with what earns each one (see `rankSafety`).
  List<(int, String)> get _riichiRatings => [
        (15, context.l10n.tipRating15),
        (13, context.l10n.tipRating13),
        (12, context.l10n.tipRating12),
        (11, context.l10n.tipRating11),
        (9, context.l10n.tipRating9),
        (8, context.l10n.tipRating8),
        (7, context.l10n.tipRating7),
        (6, context.l10n.tipRating6),
        (3, context.l10n.tipRating3),
        (2, context.l10n.tipRating2),
      ];

  /// Hong Kong has no furiten, so nothing is ever certainly safe (see
  /// `rankHongKongSafety`).
  List<(int, String)> get _hongKongRatings => [
        (14, context.l10n.tipHkRating14),
        (11, context.l10n.tipHkRating11),
        (6, context.l10n.tipHkRating6),
        (5, context.l10n.tipHkRating5),
        (3, context.l10n.tipHkRating3),
      ];

  List<InlineSpan> _safetyTip(
      bool hk, String unit, double dealInCost, int threatSets) {
    final ratings = hk ? _hongKongRatings : _riichiRatings;
    return [
      TextSpan(text: context.l10n.tipSafetyTitle, style: _tipTitle),
      TextSpan(
          text:
              hk ? context.l10n.tipSafetyChinese : context.l10n.tipSafetyRiichi,
          style: _tipBody),
      TextSpan(text: '\n', style: _tipBody),
      ..._bullets(hk
          ? [
              (context.l10n.tipNeverCertain, context.l10n.tipNeverCertainBody),
              (
                context.l10n.tipRatedWhen,
                context.l10n.tipThreatSets(threatSets.toString())
              ),
            ]
          : [
              (context.l10n.tipGenbutsu, context.l10n.tipGenbutsuBody),
              (context.l10n.tipSuji, context.l10n.tipSujiBody),
              (context.l10n.tipRatedWhen, context.l10n.tipRatedRiichi),
            ]),
      _tipSection(context.l10n.tipDealInTitle),
      _tipTable(
        [context.l10n.tipRating, context.l10n.tipTile, context.l10n.tipDealsIn],
        [
          for (final (rating, label) in ratings)
            ['$rating', label, _rate(GuideConstants.dealInRate(rating))],
        ],
        left: const {1},
      ),
      TextSpan(
          text: hk
              ? context.l10n
                  .tipChineseCost(dealInCost.round().toString(), _unit)
              : context.l10n.tipRiichiCostNote(_pts(GuideConstants.dealInCost),
                  _pts(GuideConstants.dealerDealInCost)),
          style: _tipDim),
    ];
  }

  List<InlineSpan> _riskTip(bool hk, String unit, double dealInCost) => [
        TextSpan(text: context.l10n.tipRiskTitle, style: _tipTitle),
        TextSpan(
            text: context.l10n
                .tipRiskBody('${_unit[0].toUpperCase()}${_unit.substring(1)}'),
            style: _tipBody),
        TextSpan(text: '\n', style: _tipBody),
        ..._bullets([
          (context.l10n.tipDealInChance, context.l10n.tipDealInChanceBody),
          (
            context.l10n.tipDealInCost,
            hk
                ? '${dealInCost.round()} $_unit'
                : context.l10n.tipRiichiCost(_pts(GuideConstants.dealInCost),
                    _pts(GuideConstants.dealerDealInCost))
          ),
          if (!hk)
            (
              context.l10n.tipStyleWeight,
              context.l10n.tipStyleWeights(
                  PlayStyle.values
                      .map((s) => s.riskWeight.toStringAsFixed(2))
                      .join(' / '),
                  PlayStyle.values.map(context.l10n.playStyleName).join(' / '))
            ),
          (
            context.l10n.tipLaterTurns,
            context.l10n.tipCommitPercent(
                (GuideConstants.pushCommitment * 100).round().toString())
          ),
          (
            context.l10n.tipHowLong,
            hk
                ? context.l10n.tipChineseHorizon
                : context.l10n.tipRiichiHorizon(
                    GuideConstants.riichiPushHorizon.toString())
          ),
        ]),
        _tipSection(context.l10n.tipFormula),
        _math(
            '${context.l10n.mathRisk} = ${context.l10n.mathChance}_{${context.l10n.mathDealIn}} × ${context.l10n.mathCost}_{${context.l10n.mathDealIn}}'
            '${hk ? '' : ' × ${context.l10n.mathWeight}_{${context.l10n.mathStyle}}'} + ${context.l10n.mathCharge}_{${context.l10n.mathLaterTurns}}'),
      ];

  List<InlineSpan> _detailTip() => [
        TextSpan(text: context.l10n.tipDetailTitle, style: _tipTitle),
        TextSpan(text: context.l10n.tipDetailBody, style: _tipBody),
        TextSpan(text: '\n', style: _tipBody),
        ..._bullets([
          (context.l10n.tipShows, context.l10n.tipShowsBody),
          (context.l10n.tipEmpty, context.l10n.tipEmptyBody),
        ]),
      ];

  /// The four situations the Placement tooltip works +/-8,000 through: the
  /// table's scores (mine first), and how many hands are left.
  List<(String, List<int>, int)> get _placementScenes => [
        (context.l10n.tipEven, [25000, 25000, 25000, 25000], 8),
        (context.l10n.tipLead, [45000, 20000, 18000, 17000], 8),
        (context.l10n.tipBehind, [8000, 30000, 32000, 30000], 8),
        (context.l10n.tipEvenLast, [25000, 25000, 25000, 25000], 1),
        (context.l10n.tipLeadLast, [45000, 20000, 18000, 17000], 1),
      ];

  List<InlineSpan> _placementTip() {
    double gain(List<int> table, int hands, double points) =>
        PlacementUtility(tablePoints: table, mySeat: 0, handsRemaining: hands)
            .valueOf(points);
    return [
      TextSpan(text: context.l10n.tipPlacementTitle, style: _tipTitle),
      TextSpan(text: context.l10n.tipPlacementBody, style: _tipBody),
      TextSpan(text: '\n', style: _tipBody),
      ..._bullets([
        (context.l10n.tipUses, context.l10n.tipUsesBody),
        (context.l10n.tipNotPoints, context.l10n.tipNotPointsBody),
        (context.l10n.tipHeuristic, context.l10n.tipHeuristicBody),
      ]),
      _tipSection(context.l10n.tipWorthTitle),
      _tipTable(
        [
          context.l10n.tipSituation,
          context.l10n.tipHandsLeft,
          '+8,000',
          '−8,000'
        ],
        [
          for (final (label, table, hands) in _placementScenes)
            [
              label,
              '$hands',
              _signed(gain(table, hands, 8000)),
              _signed(gain(table, hands, -8000)),
            ],
        ],
      ),
      TextSpan(text: context.l10n.tipPlacementNote, style: _tipDim),
      _tipSection(context.l10n.tipFormula),
      _math(
          '${context.l10n.mathWorth}(${context.l10n.mathGain}) = u(${context.l10n.mathScore} + ${context.l10n.mathGain}) − u(${context.l10n.mathScore})'),
      _math(
          'u(${context.l10n.mathScore}) = Σ_{${context.l10n.mathOthers}} ${context.l10n.mathLogistic}((${context.l10n.mathScore} − ${context.l10n.mathScore}_{${context.l10n.mathTheirs}}) '
          '/ ${context.l10n.mathSpread})'),
      _math(
          '${context.l10n.mathSpread} = ${_pts(PlacementUtility.baseSpread)} × '
          '√(${context.l10n.mathHandsLeft})'),
    ];
  }

  /// 0.4632 -> "46.32%". Two decimals so two cuts a hair apart still read
  /// differently in the tooltip.
  static String _chance(double p) => '${(p * 100).toStringAsFixed(2)}%';

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
  List<InlineSpan> _evWorked(DiscardLine line, HandFocus focus) {
    final gross = line.winProbability * (line.averagePoints + line.winBonus);
    final chance = _chance(line.winProbability);
    final spans = <InlineSpan>[
      TextSpan(text: '\n', style: _tipDim),
      TextSpan(
          text: context.l10n.tipThisCut(line.discard.code), style: _tipTitle),
    ];

    if (line.averagePoints <= 0) {
      spans.add(TextSpan(
          text: context.l10n.localeName == 'en' && line.reason.isNotEmpty
              ? '${line.reason}\n'
              : context.l10n.tipNoWin,
          style: _tipBody));
      if (line.riskCost > 0.5) {
        spans.add(TextSpan(
            text: _row(context.l10n.tipRiskRow, '-${_pts(line.riskCost)}') +
                _row('TileSense EV', _pts(line.expectedValue)),
            style: _tipMath));
      }
      return spans;
    }

    final buf = StringBuffer()
      ..write(_row(context.l10n.tipFinishRow, chance))
      ..write(_row(context.l10n.tipPayoutRow, _pts(line.averagePoints)));
    if (line.winBonus > 0) {
      buf.write(_row(context.l10n.tipSticksRow, '+${_pts(line.winBonus)}'));
    }
    buf.write(_row(context.l10n.tipAverageRow, _pts(gross)));
    // The multiplication behind that row, so it can be checked by eye.
    buf.write('    = $chance × '
        '${line.winBonus > 0 ? '(${_pts(line.averagePoints)} + ${_pts(line.winBonus)})' : _pts(line.averagePoints)}\n');
    if (line.valueTilt.abs() > 0.5) {
      final sign = line.valueTilt > 0 ? '+' : '-';
      buf.write(_row(
          context.l10n
              .tipFocusTilt(context.l10n.handFocusName(focus).toLowerCase()),
          '$sign${_pts(line.valueTilt.abs())}'));
    }
    if (line.riichiLockCost > 0.5) {
      buf.write(_row(context.l10n.tipLockRow, '-${_pts(line.riichiLockCost)}'));
    }
    if (line.dealInCost > 0.5) {
      buf.write(_row(context.l10n.tipDealInRow, '-${_pts(line.dealInCost)}'));
    }
    if (line.commitmentCost > 0.5) {
      buf.write(
          _row(context.l10n.tipCommitRow, '-${_pts(line.commitmentCost)}'));
    }
    buf.write('  ${'-' * 31}\n');
    buf.write(_row('TileSense EV', _pts(line.expectedValue)));
    spans.add(TextSpan(text: buf.toString(), style: _tipMath));
    return spans;
  }

  /// Wrap any mention of TileSense EV so hovering it explains the number.
  /// Pass [line] on a table cell to append that row's own arithmetic.
  Widget _evTooltip(Widget child, {DiscardLine? line}) => _tipBox(child, [
        ..._evGeneralCurrent,
        if (line != null) ..._evWorked(line, widget.game.handFocus),
      ]);

  /// What the "EV (HMR)" column means — a standalone comparison column, not
  /// part of the guide's own recommendation. See
  /// [DiscardLine.expectedValueHmr] for the exact definition and where it
  /// comes from.
  List<InlineSpan> get _evHmrGeneral => [
        TextSpan(text: 'EV (HMR)\n', style: _tipTitle),
        TextSpan(text: context.l10n.tipHmrBody, style: _tipBody),
        TextSpan(text: '\n', style: _tipBody),
        _math(
            'EV_{HMR} = ${context.l10n.mathChance}_{${context.l10n.mathFinish}} × ${context.l10n.mathPayout}_{${context.l10n.mathWin}}'),
        TextSpan(text: context.l10n.tipHmrExcludes, style: _tipBody),
        TextSpan(style: _tipDim, children: [
          TextSpan(text: context.l10n.tipHmrSource),
          TextSpan(
            text: 'HMR (Hitori Mahjong Renshuuki)',
            style: const TextStyle(
              color: Color(0xff80cbc4),
              decoration: TextDecoration.underline,
              decorationColor: Color(0xff80cbc4),
            ),
            recognizer: _hmrLink,
            mouseCursor: SystemMouseCursors.click,
          ),
          TextSpan(text: context.l10n.tipHmrSourceBody),
        ]),
      ];

  /// Where HMR is written up. One recognizer for the life of the app: the
  /// tooltip's text is static, so there is nothing to dispose of.
  static final TapGestureRecognizer _hmrLink = TapGestureRecognizer()
    ..onTap = () => launchUrl(Uri.parse(_hmrUrl));
  static const _hmrUrl =
      'https://pathofhouou.blogspot.com/2019/05/training-tool-hitori-mahjong-simulator.html';

  /// This line's own [DiscardLine.expectedValueHmr] arithmetic, matching the
  /// worked example [_evWorked] gives for TileSense EV.
  List<InlineSpan> _evHmrWorked(DiscardLine line) {
    final spans = <InlineSpan>[
      TextSpan(text: '\n', style: _tipDim),
      TextSpan(
          text: context.l10n.tipThisCut(line.discard.code), style: _tipTitle),
    ];
    if (line.averagePoints <= 0) {
      spans.add(TextSpan(
        text: context.l10n.tipNoWin,
        style: _tipBody,
      ));
      return spans;
    }
    final buf = StringBuffer()
      ..write(_row(context.l10n.tipFinishRow, _chance(line.winProbability)))
      ..write(_row(context.l10n.tipPayoutRow, _pts(line.averagePoints)))
      ..write('  ${'-' * 31}\n')
      ..write(_row('EV (HMR)', _pts(line.expectedValueHmr)));
    spans.add(TextSpan(text: buf.toString(), style: _tipMath));
    return spans;
  }

  /// Wrap any mention of the EV (HMR) column so hovering it explains the
  /// number. Pass [line] on a table cell to append that row's own
  /// arithmetic.
  Widget _evHmrTooltip(Widget child, {DiscardLine? line}) => _tipBox(child, [
        ..._evHmrGeneral,
        if (line != null) ..._evHmrWorked(line),
      ]);

  /// The panel's dark tooltip around [child] — one look for every explainer,
  /// whether it sits on a column heading, a dial label or a table cell.
  Widget _tipBox(Widget child, List<InlineSpan> body) => Tooltip(
        richMessage: TextSpan(children: body),
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

  /// See [kPlacementDisplayScale].
  static const int _placementDisplayScale = kPlacementDisplayScale;

  /// Wrap the Placement heading and cells so hovering explains what the number
  /// is — and, plainly, what it isn't. See [_placementTip].
  Widget _placementTooltip(Widget child) => _tipBox(child, _placementTip());

  /// The efficiency table — every distinct discard in hand, recommended line
  /// always first (see [EfficiencyEngine.analyze]). While defending against a
  /// riichi, two more (narrow) columns fold the safety ranking in rather than
  /// showing it as a second table.
  Widget _efficiencyTable(EfficiencyReport r) {
    // Placement isn't wired up for Hong Kong yet (see [Strategy]), so the
    // column that shows it is riichi-only, same as the dial that picks it.
    final showPlacement = !_hk;
    // Fixed leading columns (tile, shanten/away, ukeire/accepts), then the
    // standalone EV (HMR) comparison column and TileSense EV — HMR first, so
    // the plain product reads before the figure built up from it — then
    // Placement and the safety columns.
    //
    // The safety columns are always there, even with nobody to defend against
    // (their cells then read "—"): the headings are where Safety, Risk and
    // Detail are explained, so they must be reachable on any turn.
    // Mortal's column sits right after the tile, so it stays in view when the
    // wider table scrolls sideways.
    final mortal = widget.game.mortalAdvice;
    final m = mortal == null ? 0 : 1;
    // Rows follow whoever Auto-Play follows: the guide's order by default,
    // Mortal's order of preference (its pick on top) with the Mortal bot
    // chosen and its answer in; otherwise the guide's order is the fallback.
    // The green tile is always the guide's own recommendation.
    final lines = [...r.lines];
    final yakuPick = _hk ? null : _yakuLine(r).discard;
    final host = widget.game;
    final byMortal =
        host is TableGameHost && host.autoplayBrain == AutoplayBrain.mortal;
    if (byMortal && mortal?.status == MortalStatus.ready) {
      // Unranked rows keep the guide's order below the ranked ones.
      int rank(DiscardLine l) =>
          mortal!.rankOf(l.discard) ?? 99 + r.lines.indexOf(l);
      lines.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    final evHmrCol = 3 + m;
    final evCol = 4 + m;
    final placementCol = evCol + 1;
    final firstSafetyCol = placementCol + (showPlacement ? 1 : 0);
    // Never narrower than a heading's widest word at the text size in use: a
    // phone boosts text up to 1.35x, and a word too wide for its column is
    // broken mid-word. Where that widens the table, it scrolls sideways.
    final scaler = MediaQuery.textScalerOf(context);
    final headingStyle = DefaultTextStyle.of(context).style.merge(
        const TextStyle(
            fontSize: 9, height: 1.15, fontWeight: FontWeight.w700));
    FixedColumnWidth fit(String heading, double authored) {
      var widest = 0.0;
      for (final word in heading.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: headingStyle),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
      // The header cell's 3px padding either side.
      return FixedColumnWidth(math.max(authored, widest.ceilToDouble() + 6));
    }

    final table = Table(
      columnWidths: {
        0: const FixedColumnWidth(34),
        if (mortal != null) 1: fit('Mortal bot', 50),
        1 + m: fit(_hk ? 'Away' : 'Shanten', 52),
        2 + m: fit(_hk ? 'Accepts' : 'Ukeire', 48),
        evHmrCol: fit('EV (HMR)', 50),
        evCol: fit('TileSense EV', 58),
        if (showPlacement) placementCol: fit('Placement', 66),
        // 80 rather than the old 92 for Detail: with all three always shown
        // the table has to fit the panel's 456px inside its padding.
        firstSafetyCol: fit('Safety', 34),
        firstSafetyCol + 1: fit('Risk', 40),
        firstSafetyCol + 2: fit('Detail', 72),
      },
      border: TableBorder.all(color: const Color(0x33ffffff)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow([
          '',
          if (mortal != null) 'Mortal bot',
          _hk ? 'Away' : 'Shanten',
          _hk ? 'Accepts' : 'Ukeire',
          'EV (HMR)',
          'TileSense EV',
          if (showPlacement) 'Placement',
          'Safety',
          'Risk',
          'Detail',
        ]),
        for (final line in lines)
          TableRow(
            // The guide's pick filled green, Mortal's outlined in its
            // column's red, and both when they pick the same tile.
            decoration: _pickFill(
                  guide: line.recommended,
                  mortal: _isMortalPick(mortal, line.discard),
                ) ??
                BoxDecoration(
                  color: line.bestUkeire ? const Color(0x22caa24e) : null,
                  // A row picked for the yaku section, when it isn't
                  // already marked as the guide's or Mortal's pick.
                  border: line.discard == yakuPick && !line.recommended
                      ? Border.all(color: const Color(0xff80cbc4), width: 2)
                      : null,
                ),
            children: [
              GestureDetector(
                key: ValueKey('yaku-pick-${line.discard.code}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _yakuDiscard = line.discard),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: TileFace(type: line.discard, size: TileSize.small),
                ),
              ),
              if (mortal != null) _mortalCell(mortal, line.discard),
              _cell(line.shanten == -1 ? 'win' : line.shanten.toString()),
              _cell(line.ukeire.toString(),
                  bold: line.bestUkeire, color: const Color(0xffffdf76)),
              // Standalone comparison column — see [DiscardLine.expectedValueHmr].
              // Never bold: it doesn't drive the recommendation, so it never
              // needs to draw the eye the way TileSense EV's winner does.
              // Tap opens the charts behind the number ([showEvExplainer]);
              // the tooltip keeps explaining it on hover / long-press.
              _evHmrTooltip(
                _tappableCell(
                  line.expectedValueHmr.round().toString(),
                  color: const Color(0xff9fb0b8),
                  onTap: () => showEvExplainer(context, line,
                      unit: widget.game.round.ruleset.unit, hongKong: _hk),
                  key: ValueKey('ev-hmr-${line.discard.code}'),
                ),
                line: line,
              ),
              // Each cell explains its own number, not just the column.
              _evTooltip(
                _cell(
                  line.expectedValue.round().toString(),
                  bold: line.bestExpectedValue &&
                      widget.game.strategy != Strategy.placement,
                  color: const Color(0xff80cbc4),
                ),
                line: line,
              ),
              // Kept visible whichever strategy is driving the recommendation
              // — a heuristic read of how this line moves final placement
              // given the scores on the table right now, not a simulation of
              // it. Bold only while Placement is the active strategy, so the
              // bold column always matches what [line.recommended] is
              // actually recommending.
              if (showPlacement)
                _placementTooltip(
                  _cell(
                    (line.placementExpectedValue * _placementDisplayScale)
                        .round()
                        .toString(),
                    bold: line.bestExpectedValue &&
                        widget.game.strategy == Strategy.placement,
                    color: const Color(0xffce93d8),
                  ),
                ),
              ...[
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
    // The table already fills the panel; Mortal's column, or headings widened
    // for a phone's larger text, scroll it sideways rather than squeezing it.
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal, child: table);
  }

  static const _mortalColour = Color(0xffffab91);

  DiscardLine _yakuLine(EfficiencyReport r) =>
      r.lines.where((l) => l.discard == _yakuDiscard).firstOrNull ??
      r.lines.firstWhere((l) => l.recommended, orElse: () => r.lines.first);

  /// The yaku the chosen row's wins score, and how often each.
  Widget _yakuSection(EfficiencyReport r) {
    final line = _yakuLine(r);
    // Worked on between frames, so it stops once no frames are drawn.
    final later =
        line.yakuOddsLater(() => SchedulerBinding.instance.endOfFrame);
    if (later == null) {
      return _yakuBody(line, line.yakuOdds, line.doraPerWin);
    }
    return FutureBuilder(
      future: later,
      builder: (context, snapshot) => _yakuBody(
          line, snapshot.data?.yaku ?? const {}, snapshot.data?.dora ?? 0,
          working: !snapshot.hasData),
    );
  }

  Widget _yakuBody(DiscardLine line,
      Map<String, ({double chance, int han, int yakuman})> yaku, double dora,
      {bool working = false}) {
    final odds = yaku.entries.toList()
      ..sort((a, b) => b.value.chance.compareTo(a.value.chance));
    const muted = TextStyle(color: Colors.white54, fontSize: 9);
    // Short of tenpai, the odds are over the tenpais its draws reach.
    final estimate = line.shanten > 0;
    String pct(double p) => '${estimate ? '≈' : ''}${(p * 100).round()}%';
    final doraText = dora == 0
        ? null
        : 'Dora: about +${dora == dora.roundToDouble() ? dora.round() : dora.toStringAsFixed(1)}'
            ' han per winning hand';
    return Padding(
      key: const ValueKey('yaku-section'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _dialLabel('YAKU', _yakuTip),
            Flexible(
              child: Text(
                  ' · cut ${line.discard.code}'
                  '${odds.isEmpty ? '' : ' · ${switch (line.shanten) {
                      0 => line.valuePlan.toLowerCase(),
                      1 => 'estimate: 1 tile from tenpai',
                      final n => 'estimate: $n tiles from tenpai',
                    }} · ${pct(line.winProbability)} chance to win'}',
                  style: muted),
            ),
          ]),
          const SizedBox(height: 4),
          if (odds.isEmpty)
            Text(
                working
                    ? '≈ …'
                    : line.shanten > 3
                        ? 'Yaku show once this line is within three steps '
                            'of tenpai.'
                        : 'No win to score on this line.',
                style: muted)
          else ...[
            const Text('When you win, how often each yaku is in the hand',
                style: muted),
            const SizedBox(height: 2),
            for (final MapEntry(key: name, value: y) in odds)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(children: [
                  SizedBox(
                    width: 110,
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: y.chance,
                        minHeight: 6,
                        backgroundColor: const Color(0x22ffffff),
                        color: y.yakuman > 0
                            ? const Color(0xffcaa24e)
                            : const Color(0xff80cbc4),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(pct(y.chance),
                        textAlign: TextAlign.right,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(y.yakuman > 0 ? 'yakuman' : '${y.han} han',
                        textAlign: TextAlign.right, style: muted),
                  ),
                ]),
              ),
          ],
          const SizedBox(height: 4),
          if (doraText != null) Text(doraText, style: muted),
          const Text('Tap a tile in the table to see its yaku.', style: muted),
        ],
      ),
    );
  }

  List<InlineSpan> get _yakuTip => <InlineSpan>[
        TextSpan(text: context.l10n.tipYakuTitle, style: _tipTitle),
        TextSpan(text: context.l10n.tipYakuBody, style: _tipBody),
      ];

  /// A pick's highlight: the guide's green fill, Mortal's red outline (the
  /// Mortal column's hue), or both when they agree. Null when neither picked
  /// it.
  static Decoration? _pickFill({required bool guide, required bool mortal}) {
    if (!guide && !mortal) return null;
    return BoxDecoration(
      color: guide ? const Color(0x3343a047) : null,
      border: mortal ? Border.all(color: _mortalColour, width: 2) : null,
    );
  }

  /// Whether the guide recommends the move Mortal's action line names: the
  /// same call, the same riichi discard, a kan it would take, or a win (which
  /// the guide always takes).
  bool _guideAgrees(MortalAdvice a) {
    final game = widget.game;
    if (game.awaitingHumanCall) {
      final guide = game.recommendedCall ?? CallType.none;
      final mortal = switch (a.action) {
        'PASS' => CallType.none,
        'PON' => CallType.pon,
        'KAN' => CallType.kan,
        'RON' => CallType.ron,
        final chi? when chi.startsWith('CHI') => CallType.chi,
        _ => null,
      };
      return mortal == guide;
    }
    if (a.riichi) {
      final top = widget.report.lines.where((l) => l.recommended).firstOrNull;
      return top != null &&
          top.recommendRiichi &&
          mjaiTile(Tile(-1, top.discard)) == a.discard;
    }
    return switch (a.action) {
      'TSUMO' => true,
      'KAN' => game.kanAdvice?.advice.eligible ?? false,
      _ => false,
    };
  }

  static bool _isMortalPick(MortalAdvice? a, TileType type) =>
      a?.status == MortalStatus.ready &&
      a!.discard != null &&
      a.discard == mjaiTile(Tile(-1, type));

  /// ★ on Mortal's discard (★R: after declaring riichi), otherwise its order
  /// of preference; … while it thinks, — when it has nothing to say.
  Widget _mortalCell(MortalAdvice a, TileType type) {
    final rank = a.status == MortalStatus.ready ? a.rankOf(type) : null;
    final picked = rank != null && a.discard == mjaiTile(Tile(-1, type));
    return _cell(
      picked
          ? (a.riichi ? '★R' : '★')
          : rank?.toString() ?? (a.status == MortalStatus.thinking ? '…' : '—'),
      bold: picked,
      color: rank == null ? Colors.white38 : _mortalColour,
    );
  }

  /// Mortal's move when it is more than a discard the column can star — a
  /// win, call, pass, kan, riichi or nine terminals — or its state while
  /// there is nothing to star yet.
  Widget _mortalLine() {
    final a = widget.game.mortalAdvice;
    final text = switch (a?.status) {
      MortalStatus.thinking => 'thinking…',
      MortalStatus.failed => 'unavailable',
      MortalStatus.ready when a!.riichi => 'RIICHI, cut ${a.discard}',
      MortalStatus.ready => a!.action,
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    final picked = a!.status == MortalStatus.ready;
    return _tipBox(
      Container(
        key: const ValueKey('mortal-line-box'),
        margin: const EdgeInsets.only(top: 3, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        // Mortal's chosen action outlined in its red, like its row; filled
        // with the guide's green when the guide recommends the same move.
        decoration:
            picked ? _pickFill(guide: _guideAgrees(a), mortal: true) : null,
        child: Text('Mortal: $text',
            key: const ValueKey('mortal-line'),
            style: TextStyle(
                color: picked ? Colors.white : _mortalColour,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ),
      _mortalTip,
    );
  }

  List<InlineSpan> get _mortalTip => <InlineSpan>[
        TextSpan(text: '${context.l10n.mortalBot}\n', style: _tipTitle),
        TextSpan(text: context.l10n.tipMortalBody, style: _tipBody),
        TextSpan(text: context.l10n.tipMortalAuto, style: _tipBody),
        TextSpan(text: context.l10n.tipMortalSource, style: _tipDim),
      ];

  /// The columns that rank the discards, in the order they are compared, each
  /// with whether higher (true) or lower (false) is better: the value column
  /// the active strategy ranks by, then shanten, then ukeire. See
  /// [EfficiencyEngine.analyze].
  List<(String, bool)> _rankingColumns() => [
        (
          widget.game.strategy == Strategy.placement && !_hk
              ? 'Placement'
              : 'TileSense EV',
          true
        ),
        (_hk ? 'Away' : 'Shanten', false),
        (_hk ? 'Accepts' : 'Ukeire', true),
      ];

  /// Added to a ranking column's heading tip: which way is better, and where
  /// the column sits in the order that picks the green tile.
  String _rankingLabel(String label) => switch (label) {
        'Placement' => context.l10n.tipPlacementLabel,
        'Shanten' => context.l10n.tipShantenLabel,
        'Away' => context.l10n.tipAwayLabel,
        'Ukeire' => context.l10n.tipUkeireLabel,
        'Accepts' => context.l10n.tipAcceptsLabel,
        _ => label,
      };

  List<InlineSpan> _rankingNote(String label) {
    final ranking = _rankingColumns();
    final (_, higher) = ranking.firstWhere((c) => c.$1 == label);
    final order = [
      for (final (name, up) in ranking)
        context.l10n.tipRankOrder(_rankingLabel(name),
            up ? context.l10n.tipHigherFirst : context.l10n.tipLowerFirst)
    ];
    return [
      TextSpan(
          text: context.l10n.tipRankDirection(
              higher ? context.l10n.tipHigher : context.l10n.tipLower),
          style: _tipBody),
      TextSpan(
          text: context.l10n.tipRankBody(order[0], order[1], order[2]),
          style: _tipDim),
    ];
  }

  TableRow _headerRow(List<String> labels) => TableRow(
        decoration: const BoxDecoration(color: Color(0x22ffffff)),
        children: labels.map((l) {
          // Every heading that names a concept carries its own explainer, in
          // place of a glossary underneath the table.
          final tip = switch (l) {
            'TileSense EV' => _evGeneralCurrent,
            'EV (HMR)' => _evHmrGeneral,
            'Shanten' || 'Away' => _shantenTip(_hk),
            'Ukeire' || 'Accepts' => _ukeireTip(_hk),
            'Placement' => _placementTip(),
            'Safety' => _safetyTip(
                _hk,
                widget.game.round.ruleset.unit,
                GuideConstants.chineseStyleDealInCost(
                    widget.game.round.ruleset),
                HongKongGuideTuning.threatSetsFor(widget.game.round.ruleset)),
            'Risk' => _riskTip(
                _hk,
                widget.game.round.ruleset.unit,
                GuideConstants.chineseStyleDealInCost(
                    widget.game.round.ruleset)),
            'Detail' => _detailTip(),
            'Mortal bot' => _mortalTip,
            _ => null,
          };
          // A ranking column's arrow: up where higher is better, down where
          // lower is. An icon rather than an arrow glyph, which not every
          // font the web build falls back on draws.
          final higher = _rankingColumns()
              .where((c) => c.$1 == l)
              .map((c) => c.$2)
              .firstOrNull;
          final colour = l == 'Mortal bot'
              ? _mortalColour
              : l == 'TileSense EV'
                  ? const Color(0xffbfe6e0)
                  : l == 'EV (HMR)'
                      ? const Color(0xff9fb0b8)
                      : Colors.white70;
          final label = Text(l,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colour,
                fontSize: 9,
                height: 1.15,
                fontWeight: FontWeight.w700,
                decoration: tip == null ? null : TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: const Color(0x8880cbc4),
              ));
          // A Wrap, so a heading with no room left for its arrow drops it
          // under the word rather than breaking the word.
          final cell = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            child: higher == null
                ? label
                : Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      label,
                      Icon(
                        higher ? Icons.arrow_upward : Icons.arrow_downward,
                        key: ValueKey('rankArrow-$l'),
                        size: 10,
                        color: const Color(0xffffdf76),
                      ),
                    ],
                  ),
          );
          final body = tip == null
              ? null
              : [...tip, if (higher != null) ..._rankingNote(l)];
          return body == null ? cell : _tipBox(cell, body);
        }).toList(),
      );

  /// A [_cell] that opens something when tapped — underlined the way the
  /// column headings are, so it reads as clickable.
  Widget _tappableCell(String text,
          {required VoidCallback onTap, Color? color, Key? key}) =>
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Text(
              text,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 11,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: const Color(0x8880cbc4),
              ),
            ),
          ),
        ),
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
