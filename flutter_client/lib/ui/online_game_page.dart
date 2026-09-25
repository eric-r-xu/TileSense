/// The online table: the same `TableView`/`HandView`/`ScoringView` widgets
/// the offline game uses, composed against an [OnlineGameController] instead
/// of a [GameController]. No TileSense guide here — see [HandView] — and the
/// app bar is deliberately smaller than the offline one: no ruleset/hanchan/
/// fast-mode toggle and no pause, all single-player-only concepts — just the
/// room code and Leave Room. The personal (client-side only) riichi
/// auto-discard toggle lives in [HandView], beside the Sort chip.
library;

import 'package:flutter/material.dart';

import '../game/guide_host.dart' show GamePhase;
import '../game/online_game_controller.dart';
import 'client_id_text.dart';
import 'hand_view.dart';
import 'scoring_view.dart';
import 'table_view.dart';
import 'tilesensor.dart';

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
          SnackBar(
              content: Text('${game.seatLabel(seat)} is now bot-controlled')),
        );
      });
    }
    if (game.lastError != null && game.lastError != _lastShownError) {
      _lastShownError = game.lastError;
      final message = game.lastError!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
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
            leadingWidth: 300,
            // The client id sits right after the back arrow, top-left, in white.
            leading: Row(
              children: [
                IconButton(
                  tooltip: 'Leave room',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _leave,
                ),
                const Expanded(child: ClientIdText()),
              ],
            ),
            // The room's own details on the left, then the across seat — up
            // here rather than on the felt, so the ponds get that row's height.
            title: TableBarTitle(
              game: game,
              titleStart: 300 + 12, // leadingWidth + titleSpacing
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // No TileSense here — see the module doc — but a dimmed,
                  // inert TileSensor still marks where it would be, so the
                  // tooltip can point back to offline play instead of the
                  // guide just silently vanishing.
                  Tooltip(
                    message: 'TileSensor sits out multiplayer, so no seat gets '
                        'a guide the others lack.\n'
                        'Play single player to have me along!',
                    child: Opacity(
                      opacity: 0.35,
                      child: Image.asset(
                        kTileSensorAsset,
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
                      child: Icon(Icons.wifi_off,
                          color: Colors.redAccent, size: 20),
                    ),
                  ],
                ],
              ),
            ),
            // Sound sits top-right, where the solo table keeps its game
            // controls too.
            actions: [
              IconButton(
                key: const Key('soundToggle'),
                tooltip: game.soundOn
                    ? 'Sound on — tap to mute'
                    : 'Sound off — tap to unmute',
                iconSize: 24,
                icon: Icon(game.soundOn ? Icons.volume_up : Icons.volume_off),
                color: game.soundOn ? const Color(0xffe9d58f) : Colors.white38,
                onPressed: () => game.setSoundOn(!game.soundOn),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // No other place on this screen names the ruleset, so
                    // the centre status does.
                    Expanded(
                        child: TableView(
                            game: game,
                            showRulesetInStatus: true,
                            acrossInBar: true)),
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
