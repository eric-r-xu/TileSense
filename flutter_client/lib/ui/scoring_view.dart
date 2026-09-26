import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mahjong_core/game_timing.dart';

import '../game/call_callout.dart';
import '../game/guide_host.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/scoring.dart';
import 'package:mahjong_core/tile.dart';
import 'tile_face.dart';

/// The between-round result panel: outcome, winning hand(s) + yaku + han/fu, and
/// the point transfers. On a multiple ron the winners' hands are paged through
/// with a "Next" button before the final "Continue".
class ScoringView extends StatefulWidget {
  const ScoringView({super.key, required this.game, this.onGameEnd});
  final TableGameHost game;

  /// Called instead of `game.newGame()` when the "New Game" button is pressed
  /// at game end — online play has no local restart, only "leave room".
  final VoidCallback? onGameEnd;

  @override
  State<ScoringView> createState() => _ScoringViewState();
}

class _ScoringViewState extends State<ScoringView> {
  static final int _autoContinueSeconds = kScorePageDelay.inSeconds;

  /// Every tile in this panel renders 8% larger than its shared [TileSize]
  /// step (within the 5–10% the panel can afford — see the `FittedBox`/`Wrap`
  /// wrappers each row already sits in, which absorb the extra size instead
  /// of letting it overflow the panel).
  static const double _tileScale = 1.08;

  /// Matches the "recommended" green used elsewhere (the guide's top-discard
  /// highlight, the efficiency dial) so a winning tile reads the same way.
  static const Color _winGreen = Color(0xff43a047);

  int _page = 0;
  bool _autoEnabled = true;
  // When true the panel drops to 25% opacity (and its scrim clears) so the
  // player can read the table behind it.
  bool _dimmed = false;
  int _secondsLeft = _autoContinueSeconds;
  Timer? _timer;

  TableGameHost get game => widget.game;

  // A tsumo / ron bubble may still be flashing on the table; hold the panel
  // back until it has gone so it isn't hidden behind the scrim.
  bool _revealed = true;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    final wait = CallCallout.i.remaining;
    if (wait > Duration.zero) {
      _revealed = false;
      _revealTimer = Timer(wait, () {
        if (!mounted) return;
        setState(() => _revealed = true);
        _startCountdown();
      });
    } else {
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    if (!_autoEnabled || game.phase == GamePhase.gameEnd) return;
    _secondsLeft = _autoContinueSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Freeze the countdown while the game is paused — pausing on the score
      // screen must not let it auto-continue out from under you. It resumes
      // ticking from where it left off once unpaused.
      if (game.paused) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _advance();
      }
    });
  }

  /// Runs the same step the Continue / Next button performs, then re-arms the
  /// countdown if there are more result pages to page through.
  void _advance() {
    final winners = game.round.result!.winners;
    final page = _page.clamp(0, winners.isEmpty ? 0 : winners.length - 1);
    final hasMore = winners.length > 1 && page < winners.length - 1;
    if (hasMore) {
      setState(() => _page = page + 1);
      _startCountdown();
    } else {
      game.continueFromRoundEnd();
    }
  }

  void _toggleAuto() {
    setState(() => _autoEnabled = !_autoEnabled);
    if (_autoEnabled) {
      _startCountdown();
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_revealed) return const SizedBox.shrink();
    final round = game.round;
    final r = round.result!;
    final gameOver = game.phase == GamePhase.gameEnd;
    final winners = r.winners;
    final multi = winners.length > 1;
    final page = _page.clamp(0, winners.isEmpty ? 0 : winners.length - 1);

    HandScore? scoreFor(int idx) {
      if (idx < r.scores.length) return r.scores[idx];
      return r.score;
    }

    final hasMore = multi && page < winners.length - 1;
    final label = gameOver
        ? 'New Game'
        : hasMore
            ? 'Next'
            : 'Continue';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Scrim behind the panel — cleared while "see through" is on so the
        // table reads clearly through the faded panel.
        IgnorePointer(
          child: ColoredBox(
            color: _dimmed ? Colors.transparent : const Color(0xcc021617),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: _dimmed ? 0.25 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    constraints: const BoxConstraints(maxWidth: 880),
                    decoration: BoxDecoration(
                      color: const Color(0xff0b2f2f),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xffcaa24e)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          multi
                              ? '${r.label}  (${page + 1} / ${winners.length})'
                              : r.label,
                          style: const TextStyle(
                              color: Color(0xffffdf76),
                              fontSize: 26,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (winners.isNotEmpty &&
                            scoreFor(page) != null &&
                            scoreFor(page)!.valid)
                          _handBlock(round, winners[page], scoreFor(page)!,
                              r.winTiles[winners[page]]),
                        if (r.kind == RoundEndKind.exhaustiveDraw)
                          _tenpaiReveal(round, r),
                        const SizedBox(height: 12),
                        _transfers(round, r),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffcaa24e),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            _timer?.cancel();
                            if (hasMore) {
                              setState(() => _page = page + 1);
                              _startCountdown();
                            } else if (gameOver) {
                              (widget.onGameEnd ?? game.newGame)();
                            } else {
                              game.continueFromRoundEnd();
                            }
                          },
                          child: Text(label),
                        ),
                        if (!gameOver)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextButton(
                              onPressed: _toggleAuto,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                              ),
                              child: Text(
                                !_autoEnabled
                                    ? 'Auto Continue paused  ·  tap to resume'
                                    : game.paused
                                        ? 'Auto Continue held — game paused'
                                        : 'Auto Continue in ${_secondsLeft.clamp(0, _autoContinueSeconds)}s  ·  tap to pause',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        if (gameOver)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            // One line: the final standings scale down to fit rather
                            // than wrapping.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _standings(game),
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _transparencyToggle(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Toggles the panel to 25% opacity (with the scrim cleared) so the table
  /// behind it is readable, and back. Sits outside the [Opacity] so it stays
  /// fully visible either way.
  Widget _transparencyToggle() {
    return Tooltip(
      message: _dimmed ? 'Show panel' : 'See through panel',
      child: Material(
        color: const Color(0xff0b2f2f),
        shape: const CircleBorder(
            side: BorderSide(color: Color(0x66caa24e), width: 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _dimmed = !_dimmed),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              _dimmed
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: const Color(0xffcaa24e),
            ),
          ),
        ),
      ),
    );
  }

  Widget _handBlock(Round round, int seat, HandScore score, Tile? winTile) {
    final w = round.seats[seat];
    final hk = round.ruleset.isChineseStyle;
    final taiwanese = round.ruleset.isTaiwanese;
    // The dora indicators always show; ura only counts (and only shows) for a
    // hand that won in riichi.
    final doraInd = round.wall.doraIndicators();
    final uraInd =
        w.riichi ? round.wall.uraDoraIndicators() : const <TileType>[];
    return Column(
      children: [
        Text(
          '${w.wind.kanji} ${game.seatLabel(seat)}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        // Always one row: the panel is wide enough for a full hand at native
        // size, and FittedBox shrinks (never wraps) the rare over-wide hand
        // with open melds.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A self-draw (tsumo) win keeps the winning tile in hand — it
              // is shown separately, highlighted, right after this loop, so
              // it must not also render here or it doubles up. A ron's
              // winning tile is never part of `w.hand` to begin with (it
              // came from another seat's discard), so this filter is a
              // no-op for it either way.
              for (final t in sortByType(w.hand.where((t) => t != winTile)))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: TileFace(
                      tile: t, size: TileSize.normal, scale: _tileScale),
                ),
              if (winTile != null) ...[
                const SizedBox(width: 8),
                TileFace(
                  tile: winTile,
                  size: TileSize.normal,
                  scale: _tileScale,
                  highlightColor: _winGreen,
                ),
              ],
              for (final m in w.melds) ...[
                const SizedBox(width: 8),
                for (final ty in m.types)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: TileFace(
                        type: ty, size: TileSize.normal, scale: _tileScale),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (hk)
          _indicatorRow(
              'Flowers / seasons', w.flowers.map((t) => t.type).toList(),
              indicators: false)
        else ...[
          _indicatorRow('Dora', doraInd),
          if (uraInd.isNotEmpty) _indicatorRow('Ura Dora', uraInd),
        ],
        const SizedBox(height: 2),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            for (final y in score.yaku)
              Text(
                  taiwanese
                      ? '${y.name}  ${y.faan} pt${y.faan == 1 ? '' : 's'}'
                      : hk
                          ? '${y.name}  ${y.faan} faan'
                          : '${y.name}  ${y.yakuman > 0 ? 'yakuman' : '${y.han}'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          // Taiwanese's pattern total and payout are the same flat number —
          // see taiwanese_scoring.dart — so there is nothing to show twice
          // the way "faan — chips" or "han fu — points" show two different
          // scales.
          taiwanese
              ? '${score.points} point${score.points == 1 ? '' : 's'}'
              : hk
                  ? '${score.faan} faan — ${score.points} chips'
                      '${score.limitName.isEmpty ? '' : '  (${score.limitName})'}'
                  : score.yakuman > 0
                      ? '${score.limitName} — ${score.points}'
                      : '${score.han} han ${score.fu} fu'
                          '${score.limitName.isNotEmpty ? '  (${score.limitName})' : ''}'
                          ' — ${score.points}',
          style: const TextStyle(
              color: Color(0xffffdf76), fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// One line of dora / ura-dora indicator tiles, labelled. Empty when there
  /// are no indicators to show yet (never happens for dora; ura only when the
  /// hand didn't win in riichi, in which case the caller skips it).
  /// [indicators] false labels the row plainly, for tiles that are not dora
  /// indicators (Hong Kong's flowers).
  Widget _indicatorRow(String label, List<TileType> tiles,
      {bool indicators = true}) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 3,
        children: [
          Text(
              indicators
                  ? '$label indicator${tiles.length > 1 ? 's' : ''}:'
                  : '$label:',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 2),
          for (final ty in tiles)
            TileFace(type: ty, size: TileSize.normal, scale: _tileScale),
        ],
      ),
    );
  }

  /// On an exhaustive draw every tenpai seat opens its hand (as at a real
  /// ryuukyoku), with its waits spelled out beneath.
  Widget _tenpaiReveal(Round round, RoundResult r) {
    final seats = r.tenpaiAtDraw;
    return Column(
      children: [
        Text(
          round.ruleset.isChineseStyle
              ? 'Wall exhausted — no payments'
              : seats.isEmpty
                  ? 'All players noten'
                  : 'Tenpai hands revealed',
          style: const TextStyle(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        for (final seat in seats) ...[
          const SizedBox(height: 6),
          _tenpaiHandRow(round, seat),
        ],
      ],
    );
  }

  Widget _tenpaiHandRow(Round round, int seat) {
    final s = round.seats[seat];
    final waits = round.waitsFor(seat);
    return Column(
      children: [
        Text(
          '${s.wind.kanji} ${game.seatLabel(seat)}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 3),
        // Normal rather than small: a tenpai reveal is read closely, tile by
        // tile, so it gets the same size as the winning hand above it. The
        // surrounding Wrap + the panel's own SingleChildScrollView (see
        // [build]) absorb the extra size by wrapping to more rows and
        // scrolling, rather than letting it overflow.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 2,
          runSpacing: 2,
          children: [
            for (final t in sortByType(s.hand))
              TileFace(tile: t, size: TileSize.normal, scale: _tileScale),
            for (final m in s.melds) ...[
              const SizedBox(width: 6),
              for (final ty in m.types)
                TileFace(type: ty, size: TileSize.normal, scale: _tileScale),
            ],
          ],
        ),
        if (waits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 2,
              runSpacing: 1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('waits',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(width: 2),
                for (final wt in waits)
                  TileFace(type: wt, size: TileSize.small, scale: _tileScale),
              ],
            ),
          ),
      ],
    );
  }

  Widget _transfers(Round round, RoundResult r) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${round.seats[i].wind.kanji} ${game.seatLabel(i)}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  '${round.seats[i].points}'
                  '   (${_delta(r.pointDeltas[i] ?? 0)})',
                  style: TextStyle(
                    color: (r.pointDeltas[i] ?? 0) >= 0
                        ? const Color(0xff81c784)
                        : const Color(0xffff8a80),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _delta(int n) => n >= 0 ? '+$n' : '$n';

  String _standings(TableGameHost game) {
    final entries = [
      for (var i = 0; i < 4; i++) (game.seatLabel(i), game.tablePoints[i])
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (var i = 0; i < entries.length; i++)
        '#${i + 1}  ${entries[i].$1}: ${entries[i].$2}'
    ].join('     ');
  }
}
