/// Owns the [OnlineGameController] for one online-play session and switches
/// between the lobby and the table as `roomPhase` moves from `lobby` to
/// `playing` — the online analogue of how `_GamePageState` in `main.dart`
/// switches between the welcome screen, the builder and the live game.
library;

import 'package:flutter/material.dart';

import 'package:mahjong_core/ruleset.dart';

import '../game/online_game_controller.dart';
import 'online_game_page.dart';
import 'online_lobby_page.dart';

class OnlinePage extends StatefulWidget {
  const OnlinePage({
    super.key,
    required this.initialRuleset,
    required this.onExit,
    this.initialJoinCode,
  });

  final Ruleset initialRuleset;
  final VoidCallback onExit;
  final String? initialJoinCode;

  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  late final OnlineGameController _controller = OnlineGameController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.roomPhase == RoomLifecycle.lobby) {
          return OnlineLobbyPage(
            controller: _controller,
            initialRuleset: widget.initialRuleset,
            initialJoinCode: widget.initialJoinCode,
            onExit: widget.onExit,
          );
        }
        return OnlineGamePage(controller: _controller, onExit: widget.onExit);
      },
    );
  }
}
