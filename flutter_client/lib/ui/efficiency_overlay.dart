import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/guide_host.dart';
import '../logic/efficiency_engine.dart';
import '../logic/placement_utility.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import '../main.dart' show handFocusColor, playStyleColor, strategyColor;
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
              if (!_hk) _styleDial(),
              _focusDial(),
              if (!_hk) _strategyDial(),
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
                              'Safety vs ${widget.game.seatLabel(widget.game.safetyOpponentSeat!)} '
                              '(${_hk ? 'estimated risk' : 'riichi only'})',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 9),
                            ),
                          ),
                        _efficiencyTable(r),
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

  /// The play-style dial, mirrored here from the app bar (live game) or the
  /// tool bar (scenario builder). It is not a second setting: both read and
  /// write the one [GuideHost.playStyle], so moving either moves the other.
  ///
  /// Riichi only — `GameController.setRuleset` pins [GuideHost.playStyle] to
  /// Balanced under Hong Kong rules, where it has nothing left to weigh, so
  /// callers skip this when [_hk] is true rather than show a chip that does
  /// nothing.
  Widget _styleDial() {
    final current = widget.game.playStyle;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          _dialLabel('STYLE', _styleTip()),
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
          _dialLabel('FOCUS', _focusTip()),
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

  /// The strategy dial, the third and independent axis: points a line is
  /// worth versus how it moves final placement given the scores on the table
  /// right now. Riichi only — see [GameController._preHongKongStrategy].
  Widget _strategyDial() {
    final current = widget.game.strategy;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          _dialLabel('STRATEGY', _strategyTip()),
          const SizedBox(width: 8),
          for (final strategy in Strategy.values)
            Expanded(
              child: _dialChip(
                label: strategy.label,
                colour: strategyColor(strategy),
                active: strategy == current,
                chipKey: Key('guideStrategy_${strategy.name}'),
                onTap: () => widget.game.setStrategy(strategy),
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
  static final List<InlineSpan> _evGeneral = _evGeneralFor(Ruleset.riichi);
  static final List<InlineSpan> _evGeneralHongKong =
      _evGeneralFor(Ruleset.hongKong);
  static final List<InlineSpan> _evGeneralTaiwanese =
      _evGeneralFor(Ruleset.taiwanese);

  /// [_evGeneral] for the ruleset at the table.
  List<InlineSpan> get _evGeneralCurrent => switch (widget.game.round.ruleset) {
        Ruleset.riichi => _evGeneral,
        Ruleset.hongKong => _evGeneralHongKong,
        Ruleset.taiwanese => _evGeneralTaiwanese,
      };

  static List<InlineSpan> _evGeneralFor(Ruleset ruleset) => [
        const TextSpan(text: 'TILESENSE EV\n', style: _tipTitle),
        TextSpan(
            text: 'The average ${ruleset.unit} this discard is worth to you '
                '(EV = Expected Value).\n',
            style: _tipBody),
        const TextSpan(text: '\n', style: _tipBody),
        _math('TileSense EV = chance_{finish} × payout_{win} − risk_{cut}'),
        _tipPart(
            'CHANCE OF FINISHING',
            'Odds you win before the hand ends. More live tiles and more draws '
                'left raise it.\n',
            more: 'hover Ukeire · tap the EV (HMR) number for the chart'),
        if (ruleset.isTaiwanese) ...[
          _tipPart(
              'WHAT THE WIN PAYS',
              'A flat point total, the same from every payer, plus a dealer-'
                  'streak bonus. Exact once ready; before that, estimated from '
                  'the patterns shown.\n',
              more: 'tap the EV (HMR) number for the working'),
          _tipPart(
              'WHAT THE CUT RISKS',
              'Estimated loss to an opponent with 3+ exposed sets. No tile is '
                  'fully safe.\n',
              more: 'hover Risk and Safety'),
        ] else if (ruleset.isHongKong) ...[
          _tipPart(
              'WHAT THE WIN PAYS',
              'Faan as chips. Exact once ready; before that, estimated from the '
                  'patterns shown.\n',
              more: 'tap the EV (HMR) number for the working'),
          _tipPart(
              'WHAT THE CUT RISKS',
              'Estimated loss to an opponent with 3+ exposed sets. No tile is '
                  'fully safe.\n',
              more: 'hover Risk and Safety'),
        ] else ...[
          _tipPart(
              'WHAT THE WIN PAYS',
              'Points if it lands, plus honba and riichi sticks. Exact once '
                  'tenpai; an estimate before.\n',
              more: 'tap the EV (HMR) number for the working'),
          _tipPart(
              'WHAT THE CUT RISKS',
              'The riichi stick (lost unless you win). Against a live riichi, also '
                  'how often this tile deals in and the turns it commits you to.\n',
              more: 'hover Risk and Safety'),
        ],
        _tipPart(
            'FOCUS',
            'Speed pays some payout for a better chance of finishing. Balanced '
                'adds no tilt.\n',
            more: ruleset.isChineseStyle
                ? 'hover FOCUS'
                : 'hover FOCUS · STRATEGY and Placement for the rest'),
        const TextSpan(
            text: '\nHigher is better. A dangerous, cheap cut can go negative.',
            style: _tipDim),
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
  static List<InlineSpan> _bullets(List<(String, String)> items) => [
        for (final (lead, text) in items)
          TextSpan(children: [
            const TextSpan(text: '•  ', style: _tipBody),
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
        const TextSpan(text: 'GUIDE\n', style: _tipTitle),
        ..._bullets([
          ('Green tile', 'the recommended discard'),
          ('Yellow tile', 'the tile you just drew'),
          if (widget.showGameControls) ('Esc', 'pause the game'),
        ]),
        const TextSpan(
            text: '\nHover a heading or a dial for what it means.',
            style: _tipDim),
      ];

  static List<InlineSpan> _shantenTip(bool hk) => [
        TextSpan(text: '${hk ? 'AWAY' : 'SHANTEN'}\n', style: _tipTitle),
        TextSpan(
            text: 'How many tiles you are from a ready hand '
                '(0 means ${hk ? 'ready' : 'tenpai'}).',
            style: _tipBody),
      ];

  static List<InlineSpan> _ukeireTip(bool hk) {
    final typical = GuideConstants.typicalUkeire;
    return [
      TextSpan(text: '${hk ? 'ACCEPTS' : 'UKEIRE'}\n', style: _tipTitle),
      TextSpan(
          text:
              'Live tiles that ${hk ? 'bring you closer to ready' : 'reduce shanten'}'
              ' — how many draws help.\n',
          style: _tipBody),
      const TextSpan(text: '\n', style: _tipBody),
      ..._bullets([
        (
          'Wider than ordinary',
          'steps forward faster, but never faster than an ordinary hand'
        ),
      ]),
      _tipSection('AN ORDINARY HAND HAS'),
      _tipTable(
        ['Shanten', for (var i = 0; i < typical.length; i++) '$i'],
        [
          ['Ukeire', for (final v in typical) v.round().toString()],
        ],
      ),
      const TextSpan(
          text: '\nMeans, not medians: the average ukeire of the best discard '
              'at each shanten, measured over simulated solo games by a '
              'greedy efficiency player (no defence, no calls).',
          style: _tipDim),
    ];
  }

  /// The riichi ratings this guide reports, in the order the reference table
  /// lists them, with what earns each one (see `rankSafety`).
  static const List<(int, String)> _riichiRatings = [
    (15, 'Genbutsu — already discarded by that player'),
    (13, 'Honor, 1 live'),
    (12, 'Double suji'),
    (11, 'Suji terminal'),
    (9, 'Honor, 2 live'),
    (8, 'No-chance tile'),
    (7, 'Half suji'),
    (6, 'Suji 2/3/7/8, or honor with 3 live'),
    (3, 'Non-suji 2/3/7/8'),
    (2, 'Non-suji middle tile'),
  ];

  /// Hong Kong has no furiten, so nothing is ever certainly safe (see
  /// `rankHongKongSafety`).
  static const List<(int, String)> _hongKongRatings = [
    (14, 'Honor, none unseen'),
    (11, 'Honor, 1 unseen'),
    (6, 'Honor, 2 or more unseen'),
    (5, 'Terminal'),
    (3, 'Suit tile'),
  ];

  static List<InlineSpan> _safetyTip(
      bool hk, String unit, double dealInCost, int threatSets) {
    final ratings = hk ? _hongKongRatings : _riichiRatings;
    return [
      const TextSpan(text: 'SAFETY\n', style: _tipTitle),
      TextSpan(
          text: hk
              ? 'How risky a tile is to cut against an opponent with an '
                  'exposed hand. Higher = safer.\n'
              : 'How safe a tile is to cut against a riichi. 0 = dangerous, '
                  '15 = genbutsu.\n',
          style: _tipBody),
      const TextSpan(text: '\n', style: _tipBody),
      ..._bullets(hk
          ? [
              (
                'Never certain',
                'with no furiten, a tile an opponent discarded can still win'
              ),
              (
                'Rated when',
                'an opponent shows $threatSets '
                    'or more exposed sets — otherwise the column shows —'
              ),
            ]
          : [
              (
                'Genbutsu',
                'a tile that player discarded, or that passed them after '
                    'their riichi, cannot win their hand'
              ),
              ('Suji', 'a tile three away from one they discarded is safer'),
              (
                'Rated when',
                'someone is in riichi — otherwise the column shows —'
              ),
            ]),
      _tipSection('CHANCE A CUT DEALS IN'),
      _tipTable(
        ['Rating', 'Tile', 'Deals in'],
        [
          for (final (rating, label) in ratings)
            ['$rating', label, _rate(GuideConstants.dealInRate(rating))],
        ],
        left: const {1},
      ),
      TextSpan(
          text: hk
              ? '\nA deal-in is charged '
                  '${dealInCost.round()} $unit.'
              : '\nA deal-in costs ${_pts(GuideConstants.dealInCost)} '
                  '(${_pts(GuideConstants.dealerDealInCost)} to a dealer), '
                  'plus 300 a honba.',
          style: _tipDim),
    ];
  }

  static List<InlineSpan> _riskTip(bool hk, String unit, double dealInCost) => [
        const TextSpan(text: 'RISK\n', style: _tipTitle),
        TextSpan(
            text: '${unit[0].toUpperCase()}${unit.substring(1)} taken off EV '
                'for the danger of '
                'this cut.\n',
            style: _tipBody),
        const TextSpan(text: '\n', style: _tipBody),
        ..._bullets([
          ('Deal-in chance', 'from the tile\'s Safety rating'),
          (
            'Deal-in cost',
            hk
                ? '${dealInCost.round()} $unit'
                : '${_pts(GuideConstants.dealInCost)} points '
                    '(${_pts(GuideConstants.dealerDealInCost)} to a dealer), '
                    'plus 300 a honba'
          ),
          if (!hk)
            (
              'Style weight',
              '×${PlayStyle.values.map((s) => s.riskWeight.toStringAsFixed(2)).join(' / ')} '
                  'for ${PlayStyle.values.map((s) => s.label).join(' / ')}'
            ),
          (
            'Later turns',
            '${(GuideConstants.pushCommitment * 100).round()}% of the charge '
                'again for each turn the cut commits you to'
          ),
          (
            'How long',
            hk
                ? 'the hand\'s own expected length; a tile with no risk '
                    'commits you to nothing'
                : 'as long as the riichi lasts, about '
                    '${GuideConstants.riichiPushHorizon} of your discards; a '
                    'genbutsu cut commits you to nothing'
          ),
        ]),
        _tipSection('FORMULA'),
        _math('risk = chance_{deal-in} × cost_{deal-in}'
            '${hk ? '' : ' × weight_{style}'} + charge_{later turns}'),
      ];

  static List<InlineSpan> _detailTip() => [
        const TextSpan(text: 'DETAIL\n', style: _tipTitle),
        const TextSpan(
            text: 'Why this tile has the Safety rating it does.\n',
            style: _tipBody),
        const TextSpan(text: '\n', style: _tipBody),
        ..._bullets(const [
          ('Shows', 'genbutsu, suji, honor with copies left, and so on'),
          (
            'Empty',
            'nobody is being defended against, so there is nothing '
                'to explain'
          ),
        ]),
      ];

  /// The four situations the Placement tooltip works +/-8,000 through: the
  /// table's scores (mine first), and how many hands are left.
  static const List<(String, List<int>, int)> _placementScenes = [
    ('Even table', [25000, 25000, 25000, 25000], 8),
    ('Big lead', [45000, 20000, 18000, 17000], 8),
    ('Far behind', [8000, 30000, 32000, 30000], 8),
    ('Even table, last hand', [25000, 25000, 25000, 25000], 1),
    ('Big lead, last hand', [45000, 20000, 18000, 17000], 1),
  ];

  static List<InlineSpan> _placementTip() {
    double gain(List<int> table, int hands, double points) =>
        PlacementUtility(tablePoints: table, mySeat: 0, handsRemaining: hands)
            .valueOf(points);
    return [
      const TextSpan(text: 'PLACEMENT\n', style: _tipTitle),
      const TextSpan(
          text: 'How a line moves your chance of finishing above the other '
              'three seats.\n',
          style: _tipBody),
      const TextSpan(text: '\n', style: _tipBody),
      ..._bullets(const [
        ('Uses', 'the scores on the table and the hands left right now'),
        (
          'Not points',
          'scaled up ×1,000 so it reads at a glance; only its order '
              'against the other lines means anything'
        ),
        ('A heuristic', 'not a simulation'),
      ]),
      _tipSection('WHAT 8,000 POINTS IS WORTH'),
      _tipTable(
        ['Situation', 'Hands left', '+8,000', '−8,000'],
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
      const TextSpan(
          text: '\nPoints matter most in a close race and late in the game, '
              'and least when you are comfortably ahead.\n',
          style: _tipDim),
      _tipSection('FORMULA'),
      _math('worth(gain) = u(score + gain) − u(score)'),
      _math('u(score) = Σ_{3 other seats} logistic((score − score_{theirs}) '
          '/ spread)'),
      _math('spread = ${_pts(PlacementUtility.baseSpread)} × '
          '√(hands left)'),
    ];
  }

  List<InlineSpan> _styleTip() {
    final dealer = GuideConstants.dealerDamatenMinPoints;
    final normal = GuideConstants.damatenMinPoints;
    return [
      const TextSpan(text: 'STYLE\n', style: _tipTitle),
      const TextSpan(
          text: 'How much danger the guide will take on.\n', style: _tipBody),
      const TextSpan(text: '\n', style: _tipBody),
      ..._bullets(const [
        ('Defensive', 'folds sooner, and stays quiet on cheaper hands'),
        ('Balanced', 'the reference setting'),
        ('Aggressive', 'pushes further, and declares riichi more often'),
      ]),
      _tipSection('THE NUMBERS'),
      _tipTable(
        ['Style', 'Risk weight', 'Damaten bar', 'Stays quiet from'],
        [
          for (final st in PlayStyle.values)
            [
              st.label,
              '×${st.riskWeight.toStringAsFixed(2)}',
              '×${st.damatenBar.toStringAsFixed(2)}',
              '${_pts(normal * st.damatenBar)} '
                  '(${_pts(dealer * st.damatenBar)} dealer)',
            ],
        ],
        left: const {0},
      ),
      const TextSpan(text: '\n', style: _tipBody),
      ..._bullets(const [
        (
          'Risk weight',
          'multiplies every deal-in and commitment charge in Risk'
        ),
        (
          'Damaten bar',
          'scales the least a hand must pay to stay quiet instead of '
              'declaring riichi'
        ),
        (
          'Hong Kong',
          'this dial is hidden and pinned to Balanced — there is '
              'no riichi to weigh'
        ),
      ]),
    ];
  }

  List<InlineSpan> _focusTip() {
    final hk = _hk;
    const speed = HandFocus.speed;
    final ruleset = widget.game.round.ruleset;
    final pivot = hk
        ? GuideConstants.focusHongKongPointsPivot
        : GuideConstants.focusPointsPivot;
    final chance = GuideConstants.focusChancePivot;
    final unit = ruleset.unit;
    String n(double v) => v == v.roundToDouble() ? _pts(v) : v.toString();
    final payouts = hk
        ? const [8.0, 16.0, 32.0, 64.0]
        : const [2000.0, 5000.0, 8000.0, 16000.0];
    const chances = [0.05, 0.15, 0.25, 0.5];
    return [
      const TextSpan(text: 'FOCUS\n', style: _tipTitle),
      const TextSpan(
          text: 'Which hand to chase when two lines are close.\n',
          style: _tipBody),
      const TextSpan(text: '\n', style: _tipBody),
      ..._bullets(const [
        (
          'Speed',
          'prefers the likelier cheap hand over the unlikelier big one'
        ),
        ('Balanced', 'no tilt: plain chance × payout'),
      ]),
      _tipSection('WHAT SPEED DOES'),
      TextSpan(
          text: 'Big payouts count for less than face value and small ones '
              'for more; likely chances count for more and unlikely ones '
              'for less. Nothing moves at exactly ${n(pivot)} $unit or '
              '${(chance * 100).round()}%.\n',
          style: _tipBody),
      _tipTable(
        ['Payout', 'Counts as', 'Chance', 'Counts as'],
        [
          for (var i = 0; i < payouts.length; i++)
            [
              n(payouts[i]),
              n(speed.worth(payouts[i], ruleset: ruleset).roundToDouble()),
              '${(chances[i] * 100).round()}%',
              _rate(speed.chanceWorth(chances[i])),
            ],
        ],
        left: const {},
      ),
      _tipSection('FORMULA'),
      _math('payout_{worth} = ${n(pivot)} × (payout / ${n(pivot)})'
          '^{${speed.curve}}'),
      _math('chance_{worth} = $chance × (chance / $chance)'
          '^{${(2 - speed.curve).toStringAsFixed(2)}}'),
      const TextSpan(
          text: '\nThe "Speed tilt" row in a TileSense EV tooltip is the '
              'difference this makes.',
          style: _tipDim),
    ];
  }

  List<InlineSpan> _strategyTip() => [
        const TextSpan(text: 'STRATEGY\n', style: _tipTitle),
        const TextSpan(
            text: 'What a line\'s "worth" means.\n', style: _tipBody),
        _tipTable(
          ['Strategy', 'A line is worth'],
          const [
            ['Points', 'what it pays, on average'],
            [
              'Placement',
              'what it does to your chance of finishing above each other '
                  'seat, given the scores and hands left'
            ],
          ],
          left: const {0, 1},
        ),
        ..._bullets(const [
          ('Style and Focus', 'still apply under either'),
          ('Hong Kong', 'always Points — this dial is hidden'),
          ('The working', 'hover Placement in the table'),
        ]),
      ];

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
  static List<InlineSpan> _evWorked(DiscardLine line, HandFocus focus) {
    final gross = line.winProbability * (line.averagePoints + line.winBonus);
    final chance = _chance(line.winProbability);
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
                _row('TileSense EV', _pts(line.expectedValue)),
            style: _tipMath));
      }
      return spans;
    }

    final buf = StringBuffer()
      ..write(_row('chance of finishing', chance))
      ..write(_row('what the win pays', _pts(line.averagePoints)));
    if (line.winBonus > 0) {
      buf.write(_row('honba and sticks', '+${_pts(line.winBonus)}'));
    }
    buf.write(_row('so on average', _pts(gross)));
    // The multiplication behind that row, so it can be checked by eye.
    buf.write('    = $chance × '
        '${line.winBonus > 0 ? '(${_pts(line.averagePoints)} + ${_pts(line.winBonus)})' : _pts(line.averagePoints)}\n');
    if (line.valueTilt.abs() > 0.5) {
      final sign = line.valueTilt > 0 ? '+' : '-';
      buf.write(_row('${focus.label.toLowerCase()} tilt',
          '$sign${_pts(line.valueTilt.abs())}'));
    }
    if (line.riichiLockCost > 0.5) {
      buf.write(_row('less riichi lock-in', '-${_pts(line.riichiLockCost)}'));
    }
    if (line.dealInCost > 0.5) {
      buf.write(_row('less deal-in risk', '-${_pts(line.dealInCost)}'));
    }
    if (line.commitmentCost > 0.5) {
      buf.write(_row('less turns committed', '-${_pts(line.commitmentCost)}'));
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
  static final List<InlineSpan> _evHmrGeneral = [
    TextSpan(text: 'EV (HMR)\n', style: _tipTitle),
    TextSpan(
        text: 'A plain comparison figure — it never changes the '
            'recommendation.\n',
        style: _tipBody),
    const TextSpan(text: '\n', style: _tipBody),
    _math('EV_{HMR} = chance_{finish} × payout_{win}'),
    TextSpan(
        text: '\nNo honba or sticks, no risk costs, no Style or Focus tilt.\n',
        style: _tipBody),
    TextSpan(style: _tipDim, children: [
      const TextSpan(text: '\nMirrors the "E.V." stat in '),
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
      const TextSpan(
          text: ', a solo tsumo-only trainer: points won ÷ hands played, '
              'which is win rate × average win.'),
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
  static List<InlineSpan> _evHmrWorked(DiscardLine line) {
    final spans = <InlineSpan>[
      const TextSpan(text: '\n', style: _tipDim),
      TextSpan(text: '\nTHIS CUT — ${line.discard.code}\n', style: _tipTitle),
    ];
    if (line.averagePoints <= 0) {
      spans.add(const TextSpan(
        text: 'This line has no winning hand to score yet.\n',
        style: _tipBody,
      ));
      return spans;
    }
    final buf = StringBuffer()
      ..write(_row('chance of finishing', _chance(line.winProbability)))
      ..write(_row('what the win pays', _pts(line.averagePoints)))
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
    const evHmrCol = 3;
    const evCol = 4;
    final placementCol = evCol + 1;
    final firstSafetyCol = placementCol + (showPlacement ? 1 : 0);
    return Table(
      columnWidths: {
        0: const FixedColumnWidth(34),
        1: const FixedColumnWidth(52),
        2: const FixedColumnWidth(48),
        evHmrCol: const FixedColumnWidth(50),
        // Wide enough for "TileSense" on one line at the 9px heading size.
        evCol: const FixedColumnWidth(58),
        // Wide enough for the header word "Placement" on one line — at 50 it
        // wrapped mid-word ("Placemen" / "t").
        if (showPlacement) placementCol: const FixedColumnWidth(66),
        // 80 rather than the old 92 for Detail: with all three always shown
        // the table has to fit the panel's 456px inside its padding.
        firstSafetyCol: const FixedColumnWidth(34),
        firstSafetyCol + 1: const FixedColumnWidth(40),
        firstSafetyCol + 2: const FixedColumnWidth(72),
      },
      border: TableBorder.all(color: const Color(0x33ffffff)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow([
          '',
          _hk ? 'Away' : 'Shanten',
          _hk ? 'Accepts' : 'Ukeire',
          'EV (HMR)',
          'TileSense EV',
          if (showPlacement) 'Placement',
          'Safety',
          'Risk',
          'Detail',
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
  }

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
  List<InlineSpan> _rankingNote(String label) {
    final ranking = _rankingColumns();
    final (_, higher) = ranking.firstWhere((c) => c.$1 == label);
    final order = [
      for (final (name, up) in ranking)
        '$name (${up ? 'higher' : 'lower'} first)'
    ];
    return [
      TextSpan(
          text: '\n\n${higher ? 'Higher' : 'Lower'} is better — '
              'the arrow on the heading. ',
          style: _tipBody),
      TextSpan(
          text: 'Discards are ranked by ${order[0]}, then ${order[1]}, then '
              '${order[2]}; values count as equal when they show the same '
              'number. The green tile is the top of that order, and every '
              'tile equal to it on all three is green too.',
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
            _ => null,
          };
          // A ranking column's arrow: up where higher is better, down where
          // lower is. An icon rather than an arrow glyph, which not every
          // font the web build falls back on draws.
          final higher = _rankingColumns()
              .where((c) => c.$1 == l)
              .map((c) => c.$2)
              .firstOrNull;
          final colour = l == 'TileSense EV'
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
