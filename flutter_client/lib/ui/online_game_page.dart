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
import '../main.dart' show isPhoneLayout;
import 'client_id_text.dart';
import 'hand_view.dart';
import 'phone_menu.dart';
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

  /// Leave from the bar or a phone's Menu: asks first while the game is
  /// still on, since a bot then plays your seat for the rest of it.
  Future<void> _confirmLeave() async {
    if (game.phase == GamePhase.playing) {
      final go = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Leave this game?'),
          content: const Text('A bot plays your seat for the rest of it.'),
          actions: [
            TextButton(
              key: const Key('leaveStay'),
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              key: const Key('leaveConfirm'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (!(go ?? false) || !mounted) return;
    }
    _leave();
  }

  /// A phone's Menu, under the right thumb as in the offline game: the bar's
  /// controls at full size — see [showPhoneMenu].
  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff0c3030),
      builder: (sheet) {
        // Closes the sheet first, so whatever the action opens isn't under it.
        VoidCallback closeThen(VoidCallback action) => () {
              Navigator.pop(sheet);
              action();
            };
        return SafeArea(
          child: AnimatedBuilder(
            animation: game,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Menu',
                          style: TextStyle(
                              color: Color(0xffe9d58f),
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        key: const Key('onlineMenuDone'),
                        onPressed: () => Navigator.pop(sheet),
                        child:
                            const Text('Done', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                  phoneMenuRows([
                    [
                      phoneMenuAction(
                        key: const Key('onlineMenuLeave'),
                        icon: Icons.arrow_back,
                        label: 'Leave room',
                        onTap: closeThen(() => _confirmLeave()),
                      ),
                      phoneMenuAction(
                        key: const Key('onlineMenuSound'),
                        icon: game.soundOn ? Icons.volume_up : Icons.volume_off,
                        label: game.soundOn ? 'Sound on' : 'Sound off',
                        on: game.soundOn,
                        onTap: () => game.setSoundOn(!game.soundOn),
                      ),
                      phoneMenuAction(
                        key: const Key('onlineMenuClientId'),
                        icon: Icons.badge_outlined,
                        label: 'Client ID',
                        onTap: closeThen(() => showClientIdDialog(context)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
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
        // On a phone every control in this bar is too small to tap, so, as
        // in the offline game, the bar keeps only its information and the
        // controls move to one Menu button under the right thumb.
        final phone = isPhoneLayout(context);
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 50,
            titleSpacing: 12,
            leadingWidth: 132,
            // A labelled Leave with nothing beside it to mis-tap: the client
            // id is behind the ID chip at the other end of the bar.
            leading: phone
                ? null
                : Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                    child: Tooltip(
                      message: 'Leave room',
                      child: TextButton.icon(
                        key: const Key('onlineLeave'),
                        onPressed: _confirmLeave,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Leave'),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white),
                      ),
                    ),
                  ),
            // The room's own details on the left, then the across seat — up
            // here rather than on the felt, so the ponds get that row's height.
            title: TableBarTitle(
              game: game,
              // leadingWidth, when there is a leading, + titleSpacing.
              titleStart: phone ? 12 : 132 + 12,
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
            // The client id and sound sit top-right, where the solo table
            // keeps its game controls too.
            actions: phone ? const [] : [
              const ClientIdButton(),
              const SizedBox(width: 8),
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
                    HandView(game: game, onMenu: phone ? _showMenu : null),
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
