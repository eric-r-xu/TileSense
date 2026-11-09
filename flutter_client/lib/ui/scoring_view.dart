import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mahjong_core/game_timing.dart';

import '../game/call_callout.dart';
import '../game/guide_host.dart';
import '../game/sfx.dart' show Character, kCharacterPortrait;
import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/scoring.dart';
import 'package:mahjong_core/sichuan/sichuan_ledger.dart';
import 'package:mahjong_core/tile.dart';
import 'score_text.dart';
import 'tile_face.dart';
import 'theme.dart';

/// The between-round result panel: outcome, winning hand(s) + yaku + han/fu, and
/// the point transfers. On a multiple ron the winners' hands are paged through
/// with a "Next" button before the final "Continue".
class ScoringView extends StatefulWidget {
  const ScoringView({
    super.key,
    required this.game,
    this.onGameEnd,
    this.continueLock = Duration.zero,
  });
  final TableGameHost game;

  /// How long Continue stays disabled once the panel shows. Online, any
  /// player's Continue deals the next hand for everyone, so this gives the
  /// whole table time to read the scores (the server holds early presses
  /// too). Zero offline, where you are the only one reading.
  final Duration continueLock;

  /// Called instead of `game.newGame()` when the "New Game" button is pressed
  /// at game end — online play has no local restart, only "leave room".
  final VoidCallback? onGameEnd;

  @override
  State<ScoringView> createState() => _ScoringViewState();
}

class _ScoringViewState extends State<ScoringView> {
  static final int _autoContinueSeconds = kScorePageDelay.inSeconds;

  /// Every tile in this panel renders 40% larger than its shared [TileSize]
  /// step: the panel is up to 1380 wide, so the dora, tenpai and wait rows can
  /// afford it, and the `FittedBox`/`Wrap` wrappers each row sits in absorb
  /// the rest on a narrow panel instead of letting it overflow.
  static const double _tileScale = 1.4;

  /// The winner's own hand is the answer to "who won", so it renders larger
  /// than the other tile rows (a 14-tile hand is about 850 wide at this size);
  /// its `FittedBox` scales it back down on a narrow panel rather than
  /// overflowing.
  static const double _winnerTileScale = 1.75;

  /// Matches the "recommended" green used elsewhere (the guide's top-discard
  /// highlight, the efficiency dial) so a winning tile reads the same way.
  static const Color _winGreen = AppColors.right;

  /// The panel's border gold, shared by its two buttons.

  /// Continue and Pause match, and each clears a phone thumb.
  static const Size _buttonSize = Size(150, 52);

  int _page = 0;
  bool _autoEnabled = true;
  // When true the panel drops to 25% opacity (and its scrim clears) so the
  // player can read the table behind it.
  bool _dimmed = false;
  int _secondsLeft = _autoContinueSeconds;
  Timer? _timer;

  /// Whole seconds until Continue unlocks — see [ScoringView.continueLock].
  late int _lockLeft = (widget.continueLock.inMilliseconds / 1000).ceil();
  Timer? _lockTimer;

  TableGameHost get game => widget.game;

  // A tsumo / ron bubble may still be flashing on the table; hold the panel
  // back until it has gone so it isn't hidden behind the scrim — and on a
  // win, [kWinScorePause] longer, so the winning hand can be seen first.
  bool _revealed = true;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    final win = game.round.result?.winners.isNotEmpty ?? false;
    final wait =
        CallCallout.i.remaining + (win ? kWinScorePause : Duration.zero);
    if (wait > Duration.zero) {
      _revealed = false;
      _revealTimer = Timer(wait, () {
        if (!mounted) return;
        setState(() => _revealed = true);
        _startCountdown();
        _startLock();
      });
    } else {
      _startCountdown();
      _startLock();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _timer?.cancel();
    _lockTimer?.cancel();
    super.dispose();
  }

  /// Counts [_lockLeft] down from the moment the panel is on screen.
  void _startLock() {
    if (_lockLeft <= 0) return;
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _lockLeft--);
      if (_lockLeft <= 0) t.cancel();
    });
  }

  void _startCountdown({bool keepRemaining = false}) {
    _timer?.cancel();
    if (!_autoEnabled || game.phase == GamePhase.gameEnd) return;
    if (!keepRemaining || _secondsLeft <= 0) {
      _secondsLeft = _autoContinueSeconds;
    }
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
      // Resume from where Pause stopped it, not back at the full wait.
      _startCountdown(keepRemaining: true);
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) => GoldScope(
        types: game.round.goldTypes,
        child: _buildScore(context),
      );

  Widget _buildScore(BuildContext context) {
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
    // Only the button that deals the next hand for everyone is locked; Next
    // just turns your own page, and the game is over at game end.
    final locked = !gameOver && !hasMore && _lockLeft > 0;
    final l10n = context.l10n;
    final label = gameOver
        ? l10n.scoreNewGame
        : hasMore
            ? l10n.scoreNext
            : locked
                ? l10n.scoreContinueLocked(_lockLeft)
                : l10n.scoreContinue;
    final title = l10n.resultLabel(r.label, round.ruleset);

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
                    padding: const EdgeInsets.all(28),
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 1380),
                    decoration: BoxDecoration(
                      color: const Color(0xff0b2f2f),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          multi
                              ? '$title  (${page + 1} / ${winners.length})'
                              : title,
                          style: const TextStyle(
                              color: AppColors.goldBright,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        if (winners.isNotEmpty &&
                            scoreFor(page) != null &&
                            scoreFor(page)!.valid)
                          _handBlock(round, winners[page], scoreFor(page)!,
                              r.winTiles[winners[page]]),
                        if (r.kind == RoundEndKind.exhaustiveDraw)
                          _tenpaiReveal(round, r),
                        const SizedBox(height: 16),
                        _details(
                            round,
                            r,
                            winners.isNotEmpty &&
                                    scoreFor(page) != null &&
                                    scoreFor(page)!.valid
                                ? scoreFor(page)
                                : null),
                        const SizedBox(height: 20),
                        // Continue on the left, Pause on the right, the same
                        // size and gold; the countdown they control sits
                        // underneath both.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              key: const Key('scoreContinue'),
                              style: AppButtons.primary(
                                minimumSize: _buttonSize,
                              ),
                              onPressed: locked
                                  ? null
                                  : () {
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
                              child: Text(label,
                                  style: const TextStyle(fontSize: 18)),
                            ),
                            if (!gameOver) ...[
                              const SizedBox(width: 16),
                              OutlinedButton(
                                key: const Key('scorePause'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.gold,
                                  side: const BorderSide(color: AppColors.gold),
                                  minimumSize: _buttonSize,
                                ),
                                onPressed: _toggleAuto,
                                child: Text(
                                    _autoEnabled ? l10n.pause : l10n.resume,
                                    style: const TextStyle(fontSize: 18)),
                              ),
                            ],
                          ],
                        ),
                        if (!gameOver)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              !_autoEnabled
                                  ? l10n.autoContinuePaused
                                  : game.paused
                                      ? l10n.autoContinueHeld
                                      : l10n.autoContinueIn(_secondsLeft.clamp(
                                          0, _autoContinueSeconds)),
                              key: const Key('scoreCountdown'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 15),
                            ),
                          ),
                        if (gameOver)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _standings(game),
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
      message: _dimmed ? context.l10n.showPanel : context.l10n.seeThroughPanel,
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
              color: AppColors.gold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _handBlock(Round round, int seat, HandScore score, Tile? winTile) {
    final w = round.seats[seat];
    final hk = round.ruleset.isChineseStyle;
    // The dora indicators always show; ura only counts (and only shows) for a
    // hand that won in riichi.
    final doraInd = round.wall.doraIndicators();
    final uraInd =
        w.riichi ? round.wall.uraDoraIndicators() : const <TileType>[];
    return Column(
      children: [
        // The winner's portrait, so who won reads at a glance. Only wins get
        // here — a draw has no winner to show.
        Container(
          key: const Key('scoreWinnerPortrait'),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xff0c4747),
            border: Border.all(color: AppColors.goldBright, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            kCharacterPortrait[game.characterForSeat(seat)]!,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${w.wind.kanji} ${game.seatLabel(seat)}',
          style: const TextStyle(color: Colors.white70, fontSize: 17),
        ),
        const SizedBox(height: 8),
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
                      tile: t, size: TileSize.normal, scale: _winnerTileScale),
                ),
              if (winTile != null) ...[
                const SizedBox(width: 8),
                TileFace(
                  tile: winTile,
                  size: TileSize.normal,
                  scale: _winnerTileScale,
                  highlightColor: _winGreen,
                ),
              ],
              for (final m in w.melds) ...[
                const SizedBox(width: 8),
                for (final ty in m.types)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: TileFace(
                        type: ty,
                        size: TileSize.normal,
                        scale: _winnerTileScale),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (round.ruleset.isSichuan)
          const SizedBox.shrink()
        else if (hk) ...[
          _indicatorRow(context.l10n.flowersSeasons,
              w.flowers.map((t) => t.type).toList(),
              indicators: false),
          // Fuzhou: the tile that made the Gold wild this hand.
          if (round.goldIndicator != null)
            _indicatorRow(context.l10n.fzGold, [round.goldIndicator!.type],
                indicators: false),
        ] else ...[
          _indicatorRow(context.l10n.yakuDora, doraInd),
          if (uraInd.isNotEmpty)
            _indicatorRow(context.l10n.yakuUraDora, uraInd),
        ],
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
              indicators
                  ? (tiles.length > 1
                      ? context.l10n.indicatorRowMany(label)
                      : context.l10n.indicatorRowOne(label))
                  : context.l10n.plainRow(label),
              style: const TextStyle(color: Colors.white60, fontSize: 16)),
          const SizedBox(width: 4),
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
              ? context.l10n.wallExhaustedNoPayments
              : seats.isEmpty
                  ? context.l10n.allNoten
                  : context.l10n.tenpaiRevealed,
          style: const TextStyle(
              color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        for (final seat in seats) ...[
          const SizedBox(height: 10),
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
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 4),
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
              const SizedBox(width: 10),
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
                Text(context.l10n.waits,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(width: 4),
                for (final wt in waits)
                  TileFace(type: wt, size: TileSize.small, scale: _tileScale),
              ],
            ),
          ),
      ],
    );
  }

  /// Below this the yaku and the payments stack instead of sitting side by
  /// side: each card then has the whole panel's width to itself.
  static const double _sideBySide = 820;

  /// The hand's itemized score beside where the points went. A draw has no
  /// hand to itemize, so its payments get the stage alone.
  Widget _details(Round round, RoundResult r, HandScore? score) {
    return LayoutBuilder(builder: (context, c) {
      final payments = _card(
        key: const Key('scorePayments'),
        children: [
          _transfers(round, r),
          if (round.ruleset.isSichuan) _sichuanPayments(round, r),
        ],
      );
      if (score == null) {
        return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720), child: payments);
      }
      final breakdown = _breakdown(round, score);
      if (c.maxWidth < _sideBySide) {
        return Column(
            children: [breakdown, const SizedBox(height: 14), payments]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: breakdown),
          const SizedBox(width: 20),
          Expanded(child: payments),
        ],
      );
    });
  }

  /// A subtly raised block, so the itemized rows read as one unit.
  Widget _card({Key? key, required List<Widget> children}) => Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0x14ffffff),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  /// One line per yaku with what it is worth in a column of its own, then the
  /// hand's total underneath. The names and the values are the same strings the
  /// one-line form uses, so every language and ruleset reads as it always did.
  Widget _breakdown(Round round, HandScore score) {
    final l10n = context.l10n;
    final ruleset = round.ruleset;
    return _card(
      key: const Key('scoreBreakdown'),
      children: [
        for (final y in score.yaku)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(l10n.scoringName(y.name, ruleset),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 19)),
                ),
                const SizedBox(width: 12),
                Text(yakuValue(l10n, y, ruleset),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.goldText,
                        fontSize: 19,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          scoreTotalLine(l10n, score, ruleset),
          key: const Key('scoreTotal'),
          style: const TextStyle(
              color: AppColors.goldBright,
              fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Every seat's score before and after the hand, and what it gained or
  /// lost: who paid, who was paid, and by how much. The winner is picked out;
  /// a seat that neither paid nor won shows an unchanged score.
  Widget _transfers(Round round, RoundResult r) {
    return Column(
      children: [
        // Sanma's empty seat has nothing to show.
        for (final i in round.ruleset.activeSeats)
          _transferRow(
            label: '${round.seats[i].wind.kanji} ${game.seatLabel(i)}',
            winner: r.winners.contains(i),
            after: round.seats[i].points,
            delta: r.pointDeltas[i] ?? 0,
          ),
      ],
    );
  }

  Widget _transferRow({
    required String label,
    required bool winner,
    required int after,
    required int delta,
  }) {
    final change =
        delta >= 0 ? const Color(0xff81c784) : const Color(0xffff8a80);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            // Only the winner's name is picked out; the row stays plain.
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: winner
                  ? const TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 19,
                      fontWeight: FontWeight.bold)
                  : const TextStyle(color: Colors.white, fontSize: 19),
            ),
          ),
          Text('${after - delta}',
              style: const TextStyle(color: Colors.white54, fontSize: 17)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 16, color: Colors.white38),
          ),
          Text('$after',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold)),
          SizedBox(
            width: 104,
            child: Text(_delta(delta),
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: change, fontSize: 19, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _delta(int n) => n >= 0 ? '+$n' : '$n';

  /// Sichuan: where the points came from, grouped by what paid them — Hu,
  /// kong, unready-pays-ready and the void-suit penalty — one line per payer
  /// and payee, so a hand that kept going after its first win can still be
  /// read at a glance.
  Widget _sichuanPayments(Round round, RoundResult r) {
    final l10n = context.l10n;
    String kindName(SichuanPaymentKind k) => switch (k) {
          SichuanPaymentKind.hu => l10n.sichuanPayHu,
          SichuanPaymentKind.kong => l10n.sichuanPayKong,
          SichuanPaymentKind.ready => l10n.sichuanPayReady,
          SichuanPaymentKind.penalty => l10n.sichuanPayPenalty,
        };
    // Sum repeated lines (three kongs by one seat from the same payer).
    final sums = <(SichuanPaymentKind, int, int), int>{};
    for (final p in r.sichuanPayments) {
      final key = (p.kind, p.from, p.to);
      sums[key] = (sums[key] ?? 0) + p.points;
    }
    if (sums.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        key: const Key('sichuanPayments'),
        children: [
          for (final e in sums.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${kindName(e.key.$1)}: ${game.seatLabel(e.key.$2)} → '
                      '${game.seatLabel(e.key.$3)}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  Text('${e.value}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Final placements, best first: rank, the player's portrait, name and
  /// score. Entries wrap onto a second line on a narrow panel rather than
  /// shrinking or being cut off.
  Widget _standings(TableGameHost game) {
    final seats = [...game.round.ruleset.activeSeats]
      ..sort((a, b) => game.tablePoints[b].compareTo(game.tablePoints[a]));
    const style = TextStyle(color: Colors.white70, fontSize: 17);
    // Everyone level on the top score shares first.
    final top = game.tablePoints[seats.first];
    bool isWinner(int seat) => game.tablePoints[seat] == top;
    return Wrap(
      key: const Key('scoreStandings'),
      alignment: WrapAlignment.center,
      spacing: 22,
      runSpacing: 8,
      children: [
        for (var i = 0; i < seats.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isWinner(seats[i]) ? '\u{1F451}' : '#${i + 1}',
                  style: style.copyWith(
                      color: isWinner(seats[i]) ? AppColors.goldBright : null,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              _standingsAvatar(game.characterForSeat(seats[i]),
                  first: isWinner(seats[i])),
              const SizedBox(width: 6),
              Text(
                  '${game.seatLabel(seats[i])}: '
                  '${game.tablePoints[seats[i]]}',
                  style: isWinner(seats[i])
                      ? style.copyWith(
                          color: AppColors.goldBright,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)
                      : style),
            ],
          ),
      ],
    );
  }

  Widget _standingsAvatar(Character character, {required bool first}) {
    final image = Image.asset(
      kCharacterPortrait[character]!,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    if (first) return _WinnerAvatar(child: image);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff0c4747),
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}

/// The match winner's portrait: sits at the standings size, then after
/// [kMatchWinnerReveal] grows with a gold glow. Skips the wait and the growth
/// when the platform asks for reduced motion.
class _WinnerAvatar extends StatefulWidget {
  const _WinnerAvatar({required this.child});
  final Widget child;

  @override
  State<_WinnerAvatar> createState() => _WinnerAvatarState();
}

class _WinnerAvatarState extends State<_WinnerAvatar> {
  static const double _small = 26;
  static const double _big = 88;

  bool _grown = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_grown || _timer != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _grown = true;
      return;
    }
    _timer = Timer(kMatchWinnerReveal, () {
      if (mounted) setState(() => _grown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final size = _grown ? _big : _small;
    return AnimatedContainer(
      key: const Key('scoreWinnerAvatar'),
      duration: still ? Duration.zero : const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff0c4747),
        border:
            Border.all(color: AppColors.goldBright, width: _grown ? 3 : 1.5),
        boxShadow: _grown
            ? [
                BoxShadow(
                    color: AppColors.goldBright.withValues(alpha: 0.55),
                    blurRadius: 18,
                    spreadRadius: 2),
              ]
            : const [],
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.child,
    );
  }
}
