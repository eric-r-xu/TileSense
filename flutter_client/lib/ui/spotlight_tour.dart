/// The spotlight walkthrough both tours share: a dimmed screen with one real
/// widget lit at a time and a card beside it that explains it.
///
/// The table tour (over a first game) and the Hand Builder tour (over a first
/// visit to the builder) differ only in their steps, so each builds a list of
/// [TourStep]s and hands it to [SpotlightTour]. [SeenOnce] is the matching
/// "has this device seen it" flag.
library;

import 'e2e_id.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../telemetry/src/platform_web.dart'
    if (dart.library.io) '../telemetry/src/platform_stub.dart' as platform;
import 'theme.dart';

/// Whether a tour has been seen on this device: remembered in localStorage on
/// the web, and for the session elsewhere.
class SeenOnce {
  SeenOnce(this.storageKey);

  final String storageKey;

  /// Whether a first visit opens the tour. Off in tests (see
  /// `flutter_test_config.dart`) unless a test turns it on.
  bool autoShow = true;

  // Off the web there is no localStorage, so remember it for the session.
  bool _seenThisSession = false;

  bool get shouldAutoShow =>
      autoShow &&
      !_seenThisSession &&
      platform.localStorageGet(storageKey) != '1';

  void markSeen() {
    _seenThisSession = true;
    platform.localStorageSet(storageKey, '1');
  }

  /// Forgets that the tour was seen (for tests).
  void reset() => _seenThisSession = false;
}

/// One stop on a tour.
class TourStep {
  const TourStep({
    required this.target,
    required this.title,
    required this.body,
    this.extra,
  });

  /// The widget to light. When it is not on screen the card shows alone,
  /// centred.
  final GlobalKey target;
  final String title;
  final String body;

  /// Anything the step shows under its text: a legend, or a button that does
  /// the thing the step describes.
  final Widget? extra;
}

/// A tour over the whole screen. [onDone] runs on the last step's button and
/// on Skip; either way [seen] is marked.
///
/// [keyPrefix] names the keys tests and the screen find it by: the root is
/// `Key(keyPrefix)`, then `${keyPrefix}Step_N`, `${keyPrefix}Next` and
/// `${keyPrefix}Skip`.
class SpotlightTour extends StatefulWidget {
  const SpotlightTour({
    super.key,
    required this.keyPrefix,
    required this.steps,
    required this.seen,
    required this.onDone,
    required this.doneLabel,
  });

  final String keyPrefix;
  final List<TourStep> steps;
  final SeenOnce seen;
  final VoidCallback onDone;

  /// The last step's button, in place of Next.
  final String doneLabel;

  @override
  State<SpotlightTour> createState() => _SpotlightTourState();
}

class _SpotlightTourState extends State<SpotlightTour> {
  int _step = 0;

  int get _count => widget.steps.length;

  void _finish() {
    widget.seen.markSeen();
    widget.onDone();
  }

  void _next() {
    if (_step == _count - 1) {
      _finish();
    } else {
      setState(() => _step++);
    }
  }

  /// Where [key]'s widget sits in this overlay, or null when it is not on
  /// screen (the step then shows its card alone, centred).
  Rect? _rectOf(GlobalKey key) {
    final target = key.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (target is! RenderBox || me is! RenderBox || !target.attached) {
      return null;
    }
    final topLeft = me.globalToLocal(target.localToGlobal(Offset.zero));
    return (topLeft & target.size).inflate(6);
  }

  static const double _cardWidth = 560;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_step];
    final last = _step == _count - 1;
    return LayoutBuilder(builder: (context, c) {
      // Measured after layout, so the spotlight follows the real widgets.
      final hole = _rectOf(step.target);
      final card = _card(step, last);
      return Stack(
        key: Key(widget.keyPrefix),
        children: [
          // Swallows every tap: the screen waits until the tour is done.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(painter: _SpotlightPainter(hole)),
            ),
          ),
          if (hole == null)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: c.maxHeight - 32),
                child: card,
              ),
            )
          else
            // Placed from the card's own size, so it stays fully on screen
            // even beside a target too big to leave room above or below.
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _CardLayout(hole),
                child: card,
              ),
            ),
        ],
      );
    });
  }

  Widget _card(TourStep step, bool last) {
    final l10n = context.l10n;
    return Material(
      key: Key('${widget.keyPrefix}Step_$_step'),
      color: AppColors.sheet,
      borderRadius: BorderRadius.circular(14),
      elevation: 8,
      child: Container(
        width: _cardWidth,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The text scrolls if the card is ever taller than the screen (a
            // phone's boosted text), so the buttons below it stay in reach.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.tourStepOf(_step + 1, _count),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(step.title,
                        style: const TextStyle(
                            color: AppColors.goldText,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(step.body,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 17, height: 1.4)),
                    if (step.extra != null) ...[
                      const SizedBox(height: 10),
                      step.extra!,
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!last)
                  e2eId(
                    '${widget.keyPrefix}Skip',
                    TextButton(
                      key: Key('${widget.keyPrefix}Skip'),
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          minimumSize: const Size(88, 48)),
                      child: Text(l10n.tourSkip,
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                const SizedBox(width: 8),
                e2eId(
                  '${widget.keyPrefix}Next',
                  ElevatedButton(
                    key: Key('${widget.keyPrefix}Next'),
                    onPressed: _next,
                    style: AppButtons.primary(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                    ),
                    child: Text(last ? widget.doneLabel : l10n.tourNext,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Puts the card beside [hole]: on whichever side has more room, or the other
/// if only that one fits the card, and kept on screen either way (over the lit
/// widget itself when it is too big to leave room).
class _CardLayout extends SingleChildLayoutDelegate {
  _CardLayout(this.hole);

  final Rect hole;

  static const double _gap = 16;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(
          constraints.maxWidth - 2 * _gap, constraints.maxHeight - 2 * _gap));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final below = size.height - hole.bottom - _gap;
    final above = hole.top - _gap;
    var useAbove = hole.center.dy > size.height / 2;
    if (useAbove && above < child.height && below >= child.height) {
      useAbove = false;
    } else if (!useAbove && below < child.height && above >= child.height) {
      useAbove = true;
    }
    final top = useAbove ? hole.top - _gap - child.height : hole.bottom + _gap;
    double within(double v, double extent, double childExtent) =>
        v.clamp(_gap, (extent - childExtent - _gap).clamp(_gap, extent));
    return Offset(
      within(hole.center.dx - child.width / 2, size.width, child.width),
      within(top, size.height, child.height),
    );
  }

  @override
  bool shouldRelayout(_CardLayout old) => old.hole != hole;
}

/// Dims everything but [hole], and rings the hole in gold.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.hole);

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h != null) {
      final cut = Path()
        ..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(12)));
      canvas.drawPath(Path.combine(PathOperation.difference, dim, cut),
          Paint()..color = const Color(0xb3000000));
      canvas.drawRRect(
          RRect.fromRectAndRadius(h, const Radius.circular(12)),
          Paint()
            ..color = AppColors.gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    } else {
      canvas.drawPath(dim, Paint()..color = const Color(0xb3000000));
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
