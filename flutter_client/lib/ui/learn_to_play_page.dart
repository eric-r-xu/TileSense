/// A short first-run lesson for someone new to mahjong: the goal, the tiles,
/// sets and calls, and how a hand wins. Shown once before the first offline
/// game, and again from the welcome screen's "Learn to play" link.
library;

import 'package:flutter/material.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import '../main.dart' show openRules;
import '../telemetry/src/platform_web.dart'
    if (dart.library.io) '../telemetry/src/platform_stub.dart' as platform;
import 'screen_scaffold.dart';
import 'tile_face.dart';
import 'theme.dart';

/// Whether the lesson has been seen on this device.
abstract final class LearnToPlay {
  static const storageKey = 'ts_learn_seen';

  /// Whether the first Start opens the lesson. Tests that walk through Start
  /// turn this off.
  static bool autoShow = true;

  // Off the web there is no localStorage, so remember it for the session.
  static bool _seenThisSession = false;

  /// True until the lesson has been finished or skipped once.
  static bool get shouldAutoShow =>
      autoShow &&
      !_seenThisSession &&
      platform.localStorageGet(storageKey) != '1';

  static void markSeen() {
    _seenThisSession = true;
    platform.localStorageSet(storageKey, '1');
  }

  /// Forgets that the lesson was seen (for tests).
  static void reset() => _seenThisSession = false;
}

/// The lesson's four cards, one at a time. [onFinish] runs on the last card's
/// button and on Skip; [onBack] on Back from the first card.
class LearnToPlayPage extends StatefulWidget {
  const LearnToPlayPage({
    super.key,
    required this.ruleset,
    required this.onFinish,
    required this.onBack,
  });

  final Ruleset ruleset;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  @override
  State<LearnToPlayPage> createState() => _LearnToPlayPageState();
}

class _LearnToPlayPageState extends State<LearnToPlayPage> {
  static const _steps = 4;
  int _step = 0;

  static const _winningHand = [
    TileType.man1,
    TileType.man2,
    TileType.man3,
    TileType.pin4,
    TileType.pin5,
    TileType.pin6,
    TileType.sou7,
    TileType.sou8,
    TileType.sou9,
    TileType.ton,
    TileType.ton,
    TileType.ton,
    TileType.haku,
    TileType.haku,
  ];

  /// Groups of tiles to draw for card [step]; the gaps between groups show
  /// where one set ends and the next begins.
  List<List<TileType>> _tiles(int step) => switch (step) {
        0 => [
            for (var i = 0; i < 12; i += 3) _winningHand.sublist(i, i + 3),
            _winningHand.sublist(12),
          ],
        1 => const [
            [TileType.man1, TileType.man5, TileType.man9],
            [TileType.pin1, TileType.pin5, TileType.pin9],
            [TileType.sou1, TileType.sou5, TileType.sou9],
            [TileType.ton, TileType.nan, TileType.shaa, TileType.pei],
            [TileType.haku, TileType.hatsu, TileType.chun],
            [TileType.plum, TileType.chrysanthemum],
          ],
        2 => const [
            [TileType.pin3, TileType.pin4, TileType.pin5],
            [TileType.sou7, TileType.sou7, TileType.sou7],
            [TileType.man9, TileType.man9, TileType.man9, TileType.man9],
          ],
        _ => [
            for (var i = 0; i < 12; i += 3) _winningHand.sublist(i, i + 3),
            _winningHand.sublist(12),
          ],
      };

  (String, String) _text(AppLocalizations l10n) => switch (_step) {
        0 => (l10n.learnGoalTitle, l10n.learnGoalBody),
        1 => (l10n.learnTilesTitle, l10n.learnTilesBody),
        2 => (l10n.learnSetsTitle, l10n.learnSetsBody),
        _ => (
            l10n.learnWinTitle,
            widget.ruleset == Ruleset.hongKong
                ? l10n.learnWinBodyHongKong
                : l10n.learnWinBodyOther(l10n.rulesetName(widget.ruleset)),
          ),
      };

  void _next() {
    if (_step == _steps - 1) {
      widget.onFinish();
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step == 0) {
      widget.onBack();
    } else {
      setState(() => _step--);
    }
  }

  /// The card's tiles at the in-game hand's size, grown on a phone so a
  /// newcomer can make them out. The tile tour (card 2) splits into two rows:
  /// the three suits, then the honors and flowers.
  Widget _tileRow() {
    final isWin = _step == _steps - 1;
    final groups = _tiles(_step);
    final twoRows = _step == 1;
    final rows = twoRows ? [groups.sublist(0, 3), groups.sublist(3)] : [groups];
    // Two rows take a little off each tile, so the card's buttons still fit
    // on a phone without scrolling.
    final scale = teachingTileScale(context) * (twoRows ? 0.8 : 1);
    Widget row(List<List<TileType>> groups) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (g, group) in groups.indexed) ...[
              if (g > 0) const SizedBox(width: 22),
              for (final t in group)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: TileFace(
                    type: t,
                    size: TileSize.large,
                    scale: scale,
                    highlightColor: isWin ? const Color(0xff4caf50) : null,
                  ),
                ),
            ],
          ],
        );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        key: Key('learnTiles_$_step'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            row(r),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, body) = _text(l10n);
    final last = _step == _steps - 1;
    return ScreenScaffold(
      backKey: const Key('learnBack'),
      onBack: _back,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.learnToPlay,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.learnStepOf(_step + 1, _steps),
            key: const Key('learnStep'),
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            key: const Key('learnTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.goldText,
              fontSize: 38,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          _tileRow(),
          const SizedBox(height: 26),
          SizedBox(
            width: 760,
            child: Text(
              body,
              key: const Key('learnBody'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.45,
              ),
            ),
          ),
          if (last)
            TextButton.icon(
              key: const Key('learnRulesPdf'),
              onPressed: () => openRules(widget.ruleset),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: Text(l10n.rulesLinkLabel(widget.ruleset)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.link,
                textStyle: const TextStyle(
                    fontSize: 14, decoration: TextDecoration.underline),
              ),
            ),
          const SizedBox(height: 26),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!last) ...[
                TextButton(
                  key: const Key('learnSkip'),
                  onPressed: widget.onFinish,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  child: Text(l10n.learnSkip,
                      style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 16),
              ],
              ElevatedButton(
                key: Key(last ? 'learnDone' : 'learnNext'),
                onPressed: _next,
                style: AppButtons.primary(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
                child: Text(
                  last ? l10n.learnDone : l10n.learnNext,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
