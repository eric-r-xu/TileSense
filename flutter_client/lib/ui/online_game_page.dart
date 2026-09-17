/// The online table: the same `TableView`/`HandView`/`ScoringView` widgets
/// the offline game uses, composed against an [OnlineGameController] instead
/// of a [GameController]. No TileSense guide here — see [HandView] — and the
/// app bar is deliberately smaller than the offline one: no ruleset/hanchan/
/// fast-mode toggle and no pause, all single-player-only concepts — just the
/// room code and Leave Room.
library;

import 'package:flutter/material.dart';

import '../game/guide_host.dart' show GamePhase;
import '../game/online_game_controller.dart';
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
  int? _lastShownTakeoverSeat;
  String? _lastShownError;

  OnlineGameController get game => widget.controller;

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
                // No TileSense here — see the module doc — but a dimmed,
                // inert clefairy still marks where it would be, so the
                // tooltip can point back to offline play instead of the
                // guide just silently vanishing.
                Tooltip(
                  message:
                      'No TileSense guide in multiplayer — play offline for it.',
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.asset(
                      'assets/clefairy.png',
                      height: 28,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const Icon(Icons.school,
                          size: 28, color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                    HandView(game: game),
                  ],
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
