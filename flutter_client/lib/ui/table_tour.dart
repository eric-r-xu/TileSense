/// The table tour: a short, one-time walk through the single-player table's
/// controls, shown over the first hand a newcomer plays. It spotlights the real
/// widgets one at a time — the hand, the buttons beside it, TileSensor (the
/// guide) and the menu — so each control is explained where it lives, and
/// then gets out of the way for good. It can be replayed from the Learn popup
/// and, on a phone, from the menu sheet.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../telemetry/src/platform_web.dart'
    if (dart.library.io) '../telemetry/src/platform_stub.dart' as platform;
import 'theme.dart';

/// Whether the tour has been seen on this device; the same pattern as
/// `LearnToPlay`.
abstract final class TableTour {
  static const storageKey = 'ts_table_tour_seen';

  /// Whether a first hand opens the tour. Off in tests (see
  /// `flutter_test_config.dart`) unless a test turns it on.
  static bool autoShow = true;

  // Off the web there is no localStorage, so remember it for the session.
  static bool _seenThisSession = false;

  static bool get shouldAutoShow =>
      autoShow &&
      !_seenThisSession &&
      platform.localStorageGet(storageKey) != '1';

  static void markSeen() {
    _seenThisSession = true;
    platform.localStorageSet(storageKey, '1');
  }

  /// Forgets that the tour was seen (for tests).
  static void reset() => _seenThisSession = false;
}

/// The widgets the tour points at, keyed so it can find them on screen.
class TableTourTargets {
  final hand = GlobalKey(debugLabel: 'tourHand');
  final toggles = GlobalKey(debugLabel: 'tourToggles');
  final guide = GlobalKey(debugLabel: 'tourGuide');
  final menu = GlobalKey(debugLabel: 'tourMenu');
}

/// The tour over the whole table. [onDone] runs on the last step's button and
/// on Skip; either way the tour is marked seen.
class TableTourOverlay extends StatefulWidget {
  const TableTourOverlay({
    super.key,
    required this.targets,
    required this.onDone,
    required this.phone,
  });

  final TableTourTargets targets;

  /// On a phone the menu is the Menu button beside your hand; elsewhere the
  /// settings are along the top bar.
  final bool phone;
  final VoidCallback onDone;

  @override
  State<TableTourOverlay> createState() => _TableTourOverlayState();
}

class _TableTourOverlayState extends State<TableTourOverlay> {
  static const _steps = 4;
  int _step = 0;

  void _finish() {
    TableTour.markSeen();
    widget.onDone();
  }

  void _next() {
    if (_step == _steps - 1) {
      _finish();
    } else {
      setState(() => _step++);
    }
  }

  GlobalKey get _target => switch (_step) {
        0 => widget.targets.hand,
        1 => widget.targets.toggles,
        2 => widget.targets.guide,
        _ => widget.targets.menu,
      };

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, body) = switch (_step) {
      0 => (l10n.tourHandTitle, l10n.tourHandBody),
      1 => (l10n.tourButtonsTitle, l10n.tourButtonsBody),
      2 => (l10n.tourGuideTitle, l10n.tourGuideBody),
      _ => (
          l10n.tourMenuTitle,
          widget.phone ? l10n.tourMenuBodyPhone : l10n.tourMenuBodyDesktop
        ),
    };
    final last = _step == _steps - 1;
    return LayoutBuilder(builder: (context, c) {
      // Measured after layout, so the spotlight follows the real widgets.
      final hole = _rectOf(_target);
      final card = _card(
        title: title,
        body: body,
        legend: _step == 1 ? _legend(l10n) : null,
        last: last,
      );
      // The card sits on whichever side of the spotlight has more room.
      final above = hole != null && hole.center.dy > c.maxHeight / 2;
      return Stack(
        key: const Key('tableTour'),
        children: [
          // Swallows every tap: the table waits until the tour is done.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(painter: _SpotlightPainter(hole)),
            ),
          ),
          if (hole == null)
            Center(child: card)
          else
            Positioned(
              left: (hole.center.dx - _cardWidth / 2)
                  .clamp(16.0, c.maxWidth - _cardWidth - 16),
              top: above ? null : hole.bottom + 16,
              bottom: above ? c.maxHeight - hole.top + 16 : null,
              child: card,
            ),
        ],
      );
    });
  }

  static const double _cardWidth = 560;

  Widget _card({
    required String title,
    required String body,
    required bool last,
    Widget? legend,
  }) {
    final l10n = context.l10n;
    return Material(
      key: Key('tableTourStep_$_step'),
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
            Text(l10n.tourStepOf(_step + 1, _steps),
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(
                    color: AppColors.goldText,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(body,
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, height: 1.4)),
            if (legend != null) ...[const SizedBox(height: 10), legend],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!last)
                  TextButton(
                    key: const Key('tableTourSkip'),
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.white60,
                        minimumSize: const Size(88, 48)),
                    child: Text(l10n.tourSkip,
                        style: const TextStyle(fontSize: 16)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: const Key('tableTourNext'),
                  onPressed: _next,
                  style: AppButtons.primary(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                  ),
                  child: Text(last ? l10n.tourDone : l10n.tourNext,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The four buttons beside the hand, by the icons they show: on a phone the
  /// buttons are icons alone, so this is where their names are spelled out.
  Widget _legend(AppLocalizations l10n) {
    Widget row(IconData icon, String name, String what) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.goldText),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$name  ',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: what),
                  ]),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 15, height: 1.35),
                ),
              ),
            ],
          ),
        );
    return Column(
      key: const Key('tableTourLegend'),
      children: [
        // The same icons the buttons show (Discard's is a pointing hand).
        row(Icons.sort, l10n.sortCaption, l10n.tourLegendSortBody),
        row(Icons.touch_app, l10n.discardCaption, l10n.tourLegendDiscardBody),
        row(Icons.emoji_events, l10n.autoWinCaption,
            l10n.tourLegendAutoWinBody),
        row(Icons.skip_next, l10n.autoPassCaption,
            l10n.tourLegendAutoPassBody),
      ],
    );
  }
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
