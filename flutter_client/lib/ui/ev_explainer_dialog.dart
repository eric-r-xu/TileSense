import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/efficiency_engine.dart';
import 'tile_face.dart';

/// Opens the "how is this number made" page for one discard's EV (HMR) cell:
/// the chance of finishing turn by turn, what the win pays, and how the plain
/// product of the two grows into the guide's Expected Value.
///
/// Takes the [DiscardLine] as it was when tapped. The line is immutable, so the
/// page keeps describing the cell that was clicked even if the game moves on
/// and the panel refreshes underneath it.
Future<void> showEvExplainer(
  BuildContext context,
  DiscardLine line, {
  String unit = 'points',
  bool hongKong = false,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) =>
          EvExplainerDialog(line: line, unit: unit, hongKong: hongKong),
    );

/// One bar of the Expected Value waterfall. A [total] is a level measured from
/// zero; anything else is a step up or down from the running level.
class EvStep {
  const EvStep(this.label, this.delta, {this.total = false});
  final String label;
  final double delta;
  final bool total;
}

/// The steps that carry [DiscardLine.expectedValueHmr] to
/// [DiscardLine.expectedValue]: win chance × payout, plus honba and sticks
/// (which ride on the win), the focus tilt, less each cost. Steps smaller than
/// half a point are dropped, and whatever they leave over is shown as "other"
/// so the bars always land on the number in the table.
List<EvStep> evWaterfall(DiscardLine line) {
  final steps = <EvStep>[
    EvStep('EV (HMR)', line.expectedValueHmr, total: true),
  ];
  var running = line.expectedValueHmr;
  void add(String label, double delta) {
    if (delta.abs() < 0.5) return;
    steps.add(EvStep(label, delta));
    running += delta;
  }

  add('honba + sticks', line.winProbability * line.winBonus);
  add('focus tilt', line.valueTilt);
  add('riichi lock-in', -line.riichiLockCost);
  add('deal-in risk', -line.dealInCost);
  add('turns committed', -line.commitmentCost);
  add('other', line.expectedValue - running);
  steps.add(EvStep('Expected Value', line.expectedValue, total: true));
  return steps;
}

const _panel = Color(0xff031213);
const _teal = Color(0xff80cbc4);
const _grey = Color(0xff9fb0b8);
const _gold = Color(0xffffdf76);
const _green = Color(0xff81c784);
const _red = Color(0xffff8a80);

String _pct(double v, {int? digits}) =>
    '${(v * 100).toStringAsFixed(digits ?? (v < 0.1 ? 1 : 0))}%';

/// 1234.5 -> "1,235".
String _pts(double v) {
  final n = v.round();
  final digits = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

class EvExplainerDialog extends StatefulWidget {
  const EvExplainerDialog({
    super.key,
    required this.line,
    this.unit = 'points',
    this.hongKong = false,
  });

  final DiscardLine line;
  final String unit;

  /// Hong Kong estimates the pre-ready payout from the patterns on show rather
  /// than from the riichi placeholders.
  final bool hongKong;

  @override
  State<EvExplainerDialog> createState() => _EvExplainerDialogState();
}

class _EvExplainerDialogState extends State<EvExplainerDialog> {
  /// Index into the turn series the readout describes; null shows the summary.
  int? _selected;

  DiscardLine get line => widget.line;
  WinBreakdown? get breakdown => line.winBreakdown;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      key: const Key('ev-explainer'),
      backgroundColor: _panel,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x5580cbc4)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            const Divider(height: 1, color: Color(0x33ffffff)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _formula(),
                      if (breakdown != null && breakdown!.turns.isNotEmpty) ...[
                        _winSection(breakdown!),
                        _payoutSection(),
                        _waterfallSection(),
                      ] else
                        _noWin(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            TileFace(type: line.discard, size: TileSize.small),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How EV (HMR) is made — cut ${line.discard.code}',
                      style: const TextStyle(
                          color: _teal,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const Text('A comparison figure; it never drives the pick.',
                      style: TextStyle(color: _grey, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );

  Widget _formula() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x2280cbc4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('EV (HMR)  =  chance of finishing  ×  what the win pays',
                style: TextStyle(
                    color: _teal, fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              line.averagePoints > 0
                  ? '${_pct(line.winProbability, digits: 2)}  ×  ${_pts(line.averagePoints)}'
                      '  =  ${_pts(line.expectedValueHmr)} ${widget.unit}'
                  : 'No winning hand to score on this cut yet.',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _gold),
            ),
          ],
        ),
      );

  Widget _noWin() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          line.reason.isNotEmpty
              ? line.reason
              : 'This cut leaves no hand that can win yet — no yaku, no live '
                  'wait, or a fold — so there is no win probability to chart.',
          style: const TextStyle(color: Colors.white70),
        ),
      );

  // ── 1 · chance of finishing ────────────────────────────────────────────

  Widget _winSection(WinBreakdown b) {
    final turns = b.turns;
    final cumulative = [for (final t in turns) t.cumulative];
    final hits = [for (final t in turns) t.hit];
    final reached = turns.first.reachedTenpai == null
        ? null
        : [for (final t in turns) t.reachedTenpai!];
    final maxHit = hits.fold<double>(0, math.max);
    // Fit the axis to the data — a 30% chance on a 0–100% axis is a flat line —
    // rounded up to the next 10% so the gridlines stay readable.
    final peak = math.max(
        cumulative.fold<double>(0, math.max),
        (reached ?? const <double>[]).fold<double>(0, math.max));
    final maxWin = ((peak * 1.1 * 10).ceil() / 10).clamp(0.2, 1.0);
    return _section(
      '1 · Chance of finishing',
      [
        Text(_winStory(b), style: const TextStyle(height: 1.35)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip(b.estimator == WinEstimator.tenpai
              ? '${b.width.round()} live tiles finish it'
              : '${b.width.round()} tiles advance it'),
          _chip('${b.unseen} tiles unseen'),
          _chip('${b.draws} draws left'),
          _chip('${_pct(b.survivesTurn, digits: 1)} still running each turn'),
          if (b.estimator == WinEstimator.tenpai)
            _chip(b.chancesPerTurn >= 1
                ? 'ron and tsumo'
                : 'tsumo only (${b.chancesPerTurn} shots)'),
        ]),
        const SizedBox(height: 12),
        _legend([
          ('finished by this turn', _teal, false),
          if (reached != null) ('reached tenpai', _gold, true),
        ]),
        _SeriesChart(
          key: const Key('ev-win-chart'),
          values: cumulative,
          secondary: reached,
          maxY: maxWin,
          color: _teal,
          bars: false,
          selected: _selected,
          onSelect: (i) => setState(() => _selected = i),
        ),
        const SizedBox(height: 4),
        _readout(b),
        const SizedBox(height: 12),
        const Text('Chance of finishing on each turn',
            style: TextStyle(color: _grey, fontSize: 11)),
        _SeriesChart(
          key: const Key('ev-hit-chart'),
          values: hits,
          maxY: maxHit <= 0 ? 1 : maxHit * 1.15,
          color: _green,
          bars: true,
          height: 96,
          selected: _selected,
          onSelect: (i) => setState(() => _selected = i),
        ),
      ],
    );
  }

  String _winStory(WinBreakdown b) {
    final ending = 'Each turn there is also a '
        '${_pct(1 - b.survivesTurn, digits: 1)} chance the hand ends first — '
        'another seat wins or the wall runs out — which is why the curve '
        'flattens.';
    switch (b.estimator) {
      case WinEstimator.tenpai:
        final rate = math.min(1.0, b.width / math.max(1, b.unseen));
        final shot = 1 - math.pow(1 - rate, b.chancesPerTurn).toDouble();
        return 'Ready to win. Each draw is one of the ${b.unseen} tiles you '
            'cannot see, and ${b.width.round()} of them finish the hand: '
            '${_pct(rate)} a draw'
            '${b.chancesPerTurn == 1 ? ', and a ron can land as well' : ''} → '
            '${_pct(shot)} a turn. $ending';
      case WinEstimator.shantenWalk:
        return 'Not ready yet — ${b.shanten} step${b.shanten == 1 ? '' : 's'} '
            'from tenpai. Every turn the hand may take a step closer (each '
            'step narrower than the last), and only then hit its wait. The '
            'dashed line is the chance it has reached tenpai. $ending';
      case WinEstimator.tenpaiLookahead:
        return 'One step away, with a tenpai on offer. Each improving draw is '
            'followed into the tenpai it would really reach, and that '
            "tenpai's own chance is played out over the draws still left, so "
            'reaching it late counts for less. $ending';
    }
  }

  Widget _readout(WinBreakdown b) {
    final i = _selected;
    if (i == null || i >= b.turns.length) {
      return Text(
        'Tap or hover the charts for any turn. Total: '
        '${_pct(line.winProbability)} over ${b.turns.length} turns.',
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      );
    }
    final t = b.turns[i];
    return Text(
      'Turn ${t.turn}: hand still running ${_pct(t.alive)} · finishes this '
      'turn ${_pct(t.hit)} · finished by now ${_pct(t.cumulative)}'
      '${t.reachedTenpai == null ? '' : ' · tenpai by now ${_pct(t.reachedTenpai!)}'}',
      key: const Key('ev-readout'),
      style: const TextStyle(color: _gold, fontSize: 11.5),
    );
  }

  // ── 2 · what the win pays ───────────────────────────────────────────────

  Widget _payoutSection() {
    final exact = line.shanten == 0;
    return _section('2 · What the win pays', [
      Text(
        exact
            ? 'Ready, so every live wait is scored for real (yaku, fu, han, '
                'dora) and blended across winning on a discard versus a '
                'self-draw: ${_pts(line.averagePoints)} ${widget.unit} on '
                'average${line.recommendRiichi ? ', assuming riichi' : ''}.'
            : 'Not ready, so the final hand is not known yet. This is a '
                'representative payout — ${_pts(line.averagePoints)} '
                '${widget.unit} — nudged by the dora this cut keeps.',
        style: const TextStyle(height: 1.35),
      ),
      if (!exact) ...[
        const SizedBox(height: 8),
        Text(
          widget.hongKong
              ? 'Estimated from the patterns the hand already shows: dragon '
                  'and wind pungs, a flush, staying concealed, and flowers.'
              : 'It starts from a placeholder — closed '
                  '${_pts(GuideConstants.projectedClosed)} (dealer '
                  '${_pts(GuideConstants.projectedClosedDealer)}), open '
                  '${_pts(GuideConstants.projectedOpen)} (dealer '
                  '${_pts(GuideConstants.projectedOpenDealer)}) — then '
                  'x${GuideConstants.doraValueMultiple} for each dora above the '
                  '${GuideConstants.baselineDora} a hand this shape usually '
                  'holds.',
          key: const Key('ev-payout-heuristic'),
          style: const TextStyle(color: _grey, fontSize: 11.5, height: 1.35),
        ),
      ],
    ]);
  }

  // ── 3 · from EV (HMR) to Expected Value ─────────────────────────────────

  Widget _waterfallSection() {
    final steps = evWaterfall(line);
    return _section('3 · From EV (HMR) to Expected Value', [
      const Text(
        'EV (HMR) is just the first bar. The guide then adds what riding a '
        'win collects, applies your Focus tilt, and charges what this cut '
        'risks — the last bar is the Expected Value column, and the one that '
        'picks the recommendation.',
        style: TextStyle(height: 1.35),
      ),
      const SizedBox(height: 10),
      _Waterfall(key: const Key('ev-waterfall'), steps: steps),
    ]);
  }

  // ── small pieces ────────────────────────────────────────────────────────

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: _teal, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      );

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x22ffffff),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      );

  Widget _legend(List<(String, Color, bool)> items) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Wrap(spacing: 12, children: [
          for (final (label, color, dashed) in items)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 14,
                height: 3,
                color: dashed ? null : color,
                child: dashed
                    ? Row(children: [
                        for (var i = 0; i < 3; i++)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 1),
                              color: color,
                            ),
                          ),
                      ])
                    : null,
              ),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(color: _grey, fontSize: 11)),
            ]),
        ]),
      );
}

// ── charts ────────────────────────────────────────────────────────────────

/// A small line or bar chart over the turns of a walk. Tapping, dragging or
/// hovering picks a turn ([onSelect]); the same index highlights on every chart
/// sharing [selected].
class _SeriesChart extends StatelessWidget {
  const _SeriesChart({
    super.key,
    required this.values,
    required this.maxY,
    required this.color,
    required this.bars,
    required this.selected,
    required this.onSelect,
    this.secondary,
    this.height = 150,
  });

  final List<double> values;
  final List<double>? secondary;
  final double maxY;
  final Color color;
  final bool bars;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      int? indexAt(double dx) {
        final plotW = width - _ChartPainter.leftPad - _ChartPainter.rightPad;
        if (plotW <= 0 || values.isEmpty) return null;
        final slot = plotW / values.length;
        return ((dx - _ChartPainter.leftPad) / slot)
            .floor()
            .clamp(0, values.length - 1);
      }

      return MouseRegion(
        onHover: (e) => onSelect(indexAt(e.localPosition.dx)),
        onExit: (_) => onSelect(null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onSelect(indexAt(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => onSelect(indexAt(d.localPosition.dx)),
          child: CustomPaint(
            size: Size(width, height),
            painter: _ChartPainter(
              values: values,
              secondary: secondary,
              maxY: maxY,
              color: color,
              bars: bars,
              selected: selected,
            ),
          ),
        ),
      );
    });
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.maxY,
    required this.color,
    required this.bars,
    required this.selected,
    this.secondary,
  });

  static const double leftPad = 36;
  static const double rightPad = 8;
  static const double topPad = 8;
  static const double bottomPad = 18;

  final List<double> values;
  final List<double>? secondary;
  final double maxY;
  final Color color;
  final bool bars;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );
    if (values.isEmpty || plot.width <= 0 || maxY <= 0) return;

    final grid = Paint()
      ..color = const Color(0x22ffffff)
      ..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final y = plot.bottom - plot.height * g / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(canvas, _pct(maxY * g / 2, digits: maxY < 0.1 ? 1 : 0),
          Offset(plot.left - 4, y), right: true);
    }

    final n = values.length;
    final slot = plot.width / n;
    double x(int i) => plot.left + slot * (i + 0.5);
    double y(double v) =>
        plot.bottom - plot.height * (v / maxY).clamp(0.0, 1.0);

    if (selected != null && selected! < n) {
      canvas.drawRect(
        Rect.fromLTRB(plot.left + slot * selected!, plot.top,
            plot.left + slot * (selected! + 1), plot.bottom),
        Paint()..color = const Color(0x18ffdf76),
      );
    }

    if (bars) {
      final w = slot * 0.7;
      final paint = Paint()..color = color.withAlpha(200);
      for (var i = 0; i < n; i++) {
        canvas.drawRect(
          Rect.fromLTRB(x(i) - w / 2, y(values[i]), x(i) + w / 2, plot.bottom),
          paint,
        );
      }
    } else {
      final line = Path()..moveTo(x(0), y(values[0]));
      for (var i = 1; i < n; i++) {
        line.lineTo(x(i), y(values[i]));
      }
      final area = Path.from(line)
        ..lineTo(x(n - 1), plot.bottom)
        ..lineTo(x(0), plot.bottom)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withAlpha(45));
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final second = secondary;
      if (second != null && second.length == n) {
        final dash = Paint()
          ..color = _gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        for (var i = 1; i < n; i++) {
          _dashedLine(canvas, Offset(x(i - 1), y(second[i - 1])),
              Offset(x(i), y(second[i])), dash);
        }
      }
      if (selected != null && selected! < n) {
        canvas.drawCircle(Offset(x(selected!), y(values[selected!])), 4, Paint()..color = _gold);
      }
    }

    // Turn labels: first, last and a handful between.
    final step = math.max(1, (n / 6).ceil());
    for (var i = 0; i < n; i++) {
      if (i % step != 0 && i != n - 1) continue;
      _text(canvas, '${i + 1}', Offset(x(i), plot.bottom + 3), center: true);
    }
  }

  static void _dashedLine(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash * 2) {
      c.drawLine(a + dir * d, a + dir * math.min(d + dash, total), p);
    }
  }

  static void _text(Canvas canvas, String s, Offset at,
      {bool right = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s, style: const TextStyle(color: _grey, fontSize: 9.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right
        ? at.dx - tp.width
        : center
            ? at.dx - tp.width / 2
            : at.dx;
    final dy = right ? at.dy - tp.height / 2 : at.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values ||
      old.secondary != secondary ||
      old.maxY != maxY ||
      old.bars != bars ||
      old.selected != selected ||
      old.color != color;
}

/// The Expected Value waterfall: one row per [EvStep], bars laid out on a
/// shared scale so a step's length is its size in points.
class _Waterfall extends StatelessWidget {
  const _Waterfall({super.key, required this.steps});
  final List<EvStep> steps;

  @override
  Widget build(BuildContext context) {
    // Level before and after every step, so the scale can cover all of them.
    final spans = <(double, double)>[];
    var level = 0.0;
    for (final s in steps) {
      if (s.total) {
        spans.add((0, s.delta));
        level = s.delta;
      } else {
        spans.add((level, level + s.delta));
        level += s.delta;
      }
    }
    final lo = spans.fold<double>(0, (m, s) => math.min(m, math.min(s.$1, s.$2)));
    final hi = spans.fold<double>(0, (m, s) => math.max(m, math.max(s.$1, s.$2)));
    final range = hi - lo <= 0 ? 1.0 : hi - lo;

    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(
              width: 104,
              child: Text(steps[i].label,
                  style: TextStyle(
                    color: steps[i].total ? Colors.white : Colors.white70,
                    fontSize: 11.5,
                    fontWeight:
                        steps[i].total ? FontWeight.w700 : FontWeight.normal,
                  )),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final a = math.min(spans[i].$1, spans[i].$2);
                final b = math.max(spans[i].$1, spans[i].$2);
                final left = (a - lo) / range * box.maxWidth;
                final width =
                    math.max(2.0, (b - a) / range * box.maxWidth);
                return SizedBox(
                  height: 16,
                  child: Stack(children: [
                    Positioned(
                      left: (0 - lo) / range * box.maxWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1, color: const Color(0x44ffffff)),
                    ),
                    Positioned(
                      left: left,
                      width: width,
                      top: 2,
                      bottom: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _stepColor(steps[i], i),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ]),
                );
              }),
            ),
            SizedBox(
              width: 64,
              child: Text(
                steps[i].total
                    ? _pts(steps[i].delta)
                    : '${steps[i].delta >= 0 ? '+' : '-'}${_pts(steps[i].delta.abs())}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: steps[i].total
                      ? Colors.white
                      : steps[i].delta >= 0
                          ? _green
                          : _red,
                  fontSize: 11.5,
                  fontWeight:
                      steps[i].total ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ]),
        ),
    ]);
  }

  Color _stepColor(EvStep s, int i) {
    if (s.total) return i == 0 ? _grey : _teal;
    return s.delta >= 0 ? _green : _red;
  }
}
