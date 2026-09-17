/// The online table: the same `TableView`/`HandView`/`EfficiencyOverlay`/
/// `ScoringView` widgets the offline game uses, composed against an
/// [OnlineGameController] instead of a [GameController]. The app bar is
/// deliberately smaller than the offline one — no ruleset/hanchan/fast-mode
/// toggle and no pause, all single-player-only concepts — just the guide
/// toggle (mirrored from the hand bar's own button), the room code, and
/// Leave Room.
library;

import 'package:flutter/material.dart';

import '../game/guide_host.dart' show GamePhase;
import '../game/online_game_controller.dart';
import 'efficiency_overlay.dart';
import 'hand_view.dart';
import 'scoring_view.dart';
import 'table_view.dart';

class OnlineGamePage extends StatefulWidget {
  const OnlineGamePage({
    super.key,
    required this.controller,
    required this.onExit,
  });

  final OnlineGameController controller;

  /// Leaves the room and returns to the main menu — used both by the app
  /// bar's Leave Room button and by the score panel's game-over button.
  final VoidCallback onExit;

  @override
  State<OnlineGamePage> createState() => _OnlineGamePageState();
}

class _OnlineGamePageState extends State<OnlineGamePage> {
  bool _showGuide = false;
  int? _lastShownTakeoverSeat;
  String? _lastShownError;

  OnlineGameController get game => widget.controller;

  void _toggleGuide() => setState(() => _showGuide = !_showGuide);

  void _leave() {
    game.leaveRoom();
    widget.onExit();
  }

  void _maybeNotify(BuildContext context) {
    if (game.lastBotTakeoverSeat != null &&
        game.lastBotTakeoverSeat != _lastShownTakeoverSeat) {
      _lastShownTakeoverSeat = game.lastBotTakeoverSeat;
      final seat = _lastShownTakeoverSeat!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${game.seatLabel(seat)} is now bot-controlled')),
        );
      });
    }
    if (game.lastError != null && game.lastError != _lastShownError) {
      _lastShownError = game.lastError;
      final message = game.lastError!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        _maybeNotify(context);
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 50,
            titleSpacing: 12,
            leading: IconButton(
              tooltip: 'Leave room',
              icon: const Icon(Icons.arrow_back),
              onPressed: _leave,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('guideToggle'),
                  tooltip: _showGuide
                      ? 'TileSense — hide guide'
                      : 'TileSense — show guide',
                  iconSize: 32,
                  padding: EdgeInsets.zero,
                  onPressed: _toggleGuide,
                  icon: Opacity(
                    opacity: _showGuide ? 1.0 : 0.4,
                    child: Image.asset(
                      'assets/clefairy.png',
                      height: 32,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.school, size: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Room ${game.roomCode}'),
                if (game.connectionLost) ...[
                  const SizedBox(width: 10),
                  const Tooltip(
                    message: 'Connection lost — reconnecting…',
                    child: Icon(Icons.wifi_off, color: Colors.redAccent, size: 20),
                  ),
                ],
              ],
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: TableView(game: game)),
                    HandView(
                      game: game,
                      showGuide: _showGuide,
                      onToggleGuide: _toggleGuide,
                    ),
                  ],
                ),
                if (_showGuide)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        children: [
                          Positioned(
                            left: 8,
                            top: 8,
                            child: EfficiencyOverlay(
                              game: game,
                              report: game.report,
                              maxHeight:
                                  c.maxHeight - HandView.tileRowBandHeight - 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (game.phase != GamePhase.playing)
                  ScoringView(game: game, onGameEnd: _leave),
              ],
            ),
          ),
        );
      },
    );
  }
}
