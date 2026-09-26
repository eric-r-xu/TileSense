/// Create-or-join screen for online multiplayer: name, ruleset + hanchan
/// picker, a room code to share, and the seat roster while waiting to start.
/// Rendered by `OnlinePage` whenever `OnlineGameController.roomPhase` is
/// still `lobby`; `OnlineGamePage` takes over once the host starts the game.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mahjong_core/hong_kong/hong_kong_rules.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/taiwanese/taiwanese_rules.dart';

import '../game/online_game_controller.dart';
import '../game/sfx.dart'
    show Character, kCharacterName, kCharacterPortrait, kSelectableCharacters;
import '../main.dart' show isPhoneLayout, kLetterboxColor;
import 'character_picker.dart';
import 'client_id_text.dart';

class OnlineLobbyPage extends StatefulWidget {
  const OnlineLobbyPage({
    super.key,
    required this.controller,
    required this.initialRuleset,
    required this.onExit,
    this.initialJoinCode,
  });

  final OnlineGameController controller;
  final Ruleset initialRuleset;
  final VoidCallback onExit;

  /// Prefills the join-code field — set from a shared `?join=CODE` link.
  final String? initialJoinCode;

  @override
  State<OnlineLobbyPage> createState() => _OnlineLobbyPageState();
}

class _OnlineLobbyPageState extends State<OnlineLobbyPage> {
  late final TextEditingController _nameCtl = TextEditingController(
      text: _isDefaultName(widget.controller.displayName)
          ? kCharacterName[widget.controller.myCharacter]
          : widget.controller.displayName);
  late final TextEditingController _joinCtl =
      TextEditingController(text: widget.initialJoinCode ?? '');
  late Ruleset _ruleset = widget.initialRuleset;
  bool _hanchan = true;
  int _timerSeconds = OnlineGameController.timerChoices.first;
  int _minimumFaan = HongKongRules.defaultMinimumFaan;
  int _minimumPoints = TaiwaneseRules.defaultMinimumPoints;
  late Character _character = widget.controller.myCharacter;
  String? _shownError;

  OnlineGameController get game => widget.controller;

  /// A blank name, or one that is just some character's name, is a default
  /// rather than something the player typed — it follows the chosen character.
  static bool _isDefaultName(String name) =>
      name.trim().isEmpty || kCharacterName.containsValue(name.trim());

  @override
  void dispose() {
    _nameCtl.dispose();
    _joinCtl.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _nameCtl.text.trim();
    if (name.isNotEmpty) game.setDisplayName(name);
  }

  void _create() {
    _saveName();
    game.setMyCharacter(_character);
    game.createRoom(
        ruleset: _ruleset,
        hanchan: _hanchan,
        timerSeconds: _timerSeconds,
        minimumFaan: _minimumFaan,
        minimumPoints: _minimumPoints);
  }

  void _join() {
    _saveName();
    game.setMyCharacter(_character);
    final code = _joinCtl.text.trim();
    if (code.isNotEmpty) game.joinRoom(code);
  }

  @override
  Widget build(BuildContext context) {
    // Surface a fresh error once, as a snackbar, without re-showing it every
    // rebuild (the controller keeps the last error around for the lobby to
    // read at any time, not just the moment it happened).
    if (game.lastError != null && game.lastError != _shownError) {
      _shownError = game.lastError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(game.lastError!)),
        );
      });
    }

    // On a phone the whole bar is drawn at about half size, so it is taller
    // there: Back and the ID chip, 8 short of it, then clear 44pt each way
    // for a thumb at a landscape iPhone's ~0.48×.
    final barHeight = isPhoneLayout(context) ? 100.0 : kToolbarHeight;
    return Scaffold(
      backgroundColor: kLetterboxColor,
      appBar: AppBar(
        backgroundColor: kLetterboxColor,
        toolbarHeight: barHeight,
        leadingWidth: 132,
        // A labelled Back, the bar's full height, with nothing beside it to
        // mis-tap: the client id is behind the ID chip at the other end.
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Tooltip(
            message: 'Back to menu',
            child: TextButton.icon(
              key: const Key('onlineBack'),
              onPressed: () {
                if (game.roomCode.isNotEmpty) game.leaveRoom();
                widget.onExit();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Menu'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
        ),
        title: const Text('Play Online'),
        actions: [
          ClientIdButton(height: barHeight - 8),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          if (game.connectionLost) _connectionBanner(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                // The setup screen runs two columns side by side (name +
                // create on the left, character + join on the right) so it
                // fits in kDesignSize's 820px height without scrolling; the
                // waiting-room screen is a single narrow column, unchanged.
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: game.roomCode.isEmpty ? 1100 : 520),
                  child: game.roomCode.isEmpty ? _setupCard() : _roomCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xff5d1a1a),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              "Can't reach the multiplayer server — retrying…",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- before a room exists: name, ruleset/hanchan, create or join --------

  /// Two columns side by side rather than one long stack, so the whole setup
  /// screen fits in kDesignSize's 820px height without scrolling: name and
  /// room creation on the left (what a host fills in), character and joining
  /// on the right (what a joiner fills in) — the two things nobody needs to
  /// see at once, so splitting them costs nothing.
  Widget _setupCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Multiplayer has no TileSense guide — play single player for it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  TextField(
                    controller: _nameCtl,
                    maxLength: 24,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      helperText: 'Defaults to your character — edit to '
                          'use your own',
                      counterText: '',
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  _card(
                    title: 'Create a room',
                    // A house: a new room of your own.
                    emoji: const Text('🏠',
                        key: Key('createRoomEmoji'),
                        style: TextStyle(fontSize: 18)),
                    child: Column(
                      children: [
                        _rulesetPicker(),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title:
                              const Text('Full game — hanchan/半庄 (8+ hands)'),
                          subtitle: Text(_hanchan
                              ? 'Off switches to East-only/东风战 (4+ hands)'
                              : 'East-only/东风战 — 4+ hands'),
                          value: _hanchan,
                          onChanged: (v) => setState(() => _hanchan = v),
                        ),
                        const SizedBox(height: 10),
                        // Side by side rather than stacked, so the minimum
                        // picker costs no height on this screen.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _timerPicker()),
                            if (_ruleset.isHongKong) ...[
                              const SizedBox(width: 16),
                              Expanded(child: _minimumFaanPicker()),
                            ],
                            if (_ruleset.isTaiwanese) ...[
                              const SizedBox(width: 16),
                              Expanded(child: _minimumPointsPicker()),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const Key('createRoom'),
                            onPressed: _create,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffcaa24e),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Create Room'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _characterPicker(),
                  const SizedBox(height: 20),
                  _card(
                    title: 'Join a room',
                    // A door: into someone else's room.
                    emoji: const Text('🚪',
                        key: Key('joinRoomEmoji'),
                        style: TextStyle(fontSize: 18)),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('joinCode'),
                            controller: _joinCtl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 8,
                            decoration: const InputDecoration(
                              labelText: 'Room code',
                              counterText: '',
                            ),
                            style: const TextStyle(
                                color: Colors.white, letterSpacing: 2),
                            onSubmitted: (_) => _join(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          key: const Key('joinRoom'),
                          onPressed: _join,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff00695c),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                          ),
                          child: const Text('Join'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Who you play as — sent with create/join and shown to every other player
  /// at the table, so their reserved seat in the roster below always matches
  /// what's rendered once the game starts (see `Room.resolveCharacter` on
  /// the multiplayer server, which resolves a collision if someone else at
  /// the table already picked the same one).
  Widget _characterPicker() {
    return _card(
      title: 'Choose your character',
      // All nine in the one row the right column is wide enough for, rather
      // than [CharacterRow]'s default four-per-row wrap — that's most of the
      // height this rework saves.
      child: CharacterRow(
        options: kSelectableCharacters,
        columns: kSelectableCharacters.length,
        selected: _character,
        onSelect: (c) => setState(() {
          _character = c;
          if (_isDefaultName(_nameCtl.text)) {
            _nameCtl.text = kCharacterName[c]!;
          }
        }),
      ),
    );
  }

  /// Seconds per discard and per call offer for the room you create — 30 by
  /// default, or 60. Applies to the whole table, so it is the host's call;
  /// joining a room uses whatever its host picked.
  Widget _timerPicker() {
    Widget option(int seconds) {
      final selected = _timerSeconds == seconds;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
            key: Key('timer_$seconds'),
            onPressed: () => setState(() => _timerSeconds = seconds),
            style: OutlinedButton.styleFrom(
              backgroundColor: selected ? const Color(0x33caa24e) : null,
              foregroundColor:
                  selected ? const Color(0xffffdf76) : Colors.white54,
              side: BorderSide(
                color: selected ? const Color(0xffcaa24e) : Colors.white24,
                width: selected ? 2 : 1,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text('${seconds}s'),
          ),
        ),
      );
    }

    return Column(
      children: [
        const Text('Turn & call timer (room you create)',
            style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: [
          for (final t in OnlineGameController.timerChoices) option(t)
        ]),
      ],
    );
  }

  /// The minimum to win for the room you create: Hong Kong's faan (0 to 3)
  /// or Taiwanese's tai (1, 3 or 5).
  Widget _minimumPicker({
    required String label,
    required String keyPrefix,
    required List<int> choices,
    required int current,
    required ValueChanged<int> onChange,
  }) {
    Widget option(int n) {
      final selected = current == n;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
            key: Key('${keyPrefix}_$n'),
            onPressed: () => onChange(n),
            style: OutlinedButton.styleFrom(
              backgroundColor: selected ? const Color(0x33caa24e) : null,
              foregroundColor:
                  selected ? const Color(0xffffdf76) : Colors.white54,
              side: BorderSide(
                color: selected ? const Color(0xffcaa24e) : Colors.white24,
                width: selected ? 2 : 1,
              ),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text('$n'),
          ),
        ),
      );
    }

    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: [for (final n in choices) option(n)]),
      ],
    );
  }

  Widget _minimumFaanPicker() => _minimumPicker(
        label: 'Minimum faan to win',
        keyPrefix: 'onlineMinimumFaan',
        choices: HongKongRules.minimumFaanChoices,
        current: _minimumFaan,
        onChange: (n) => setState(() => _minimumFaan = n),
      );

  Widget _minimumPointsPicker() => _minimumPicker(
        label: 'Minimum tai to win',
        keyPrefix: 'onlineMinimumPoints',
        choices: TaiwaneseRules.minimumPointsChoices,
        current: _minimumPoints,
        onChange: (n) => setState(() => _minimumPoints = n),
      );

  Widget _rulesetPicker() {
    Widget option(Ruleset value) {
      final selected = _ruleset == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
            key: Key('onlineRuleset_${value.name}'),
            onPressed: () => setState(() => _ruleset = value),
            style: OutlinedButton.styleFrom(
              backgroundColor: selected ? const Color(0x33caa24e) : null,
              foregroundColor:
                  selected ? const Color(0xffffdf76) : Colors.white54,
              side: BorderSide(
                color: selected ? const Color(0xffcaa24e) : Colors.white24,
                width: selected ? 2 : 1,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(value.flagLabel),
          ),
        ),
      );
    }

    return Row(children: [
      option(Ruleset.riichi),
      option(Ruleset.hongKong),
      option(Ruleset.taiwanese),
    ]);
  }

  // --- a room exists: code + roster ----------------------------------------

  Widget _roomCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _card(
          title: 'Room code — share this with the other players',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                game.roomCode,
                style: const TextStyle(
                  color: Color(0xffffdf76),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy, color: Colors.white70),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: game.roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Room code copied')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          title: '${game.ruleset.flagLabel} · '
              '${game.ruleset.isHongKong ? game.minimumFaanLabel : ''}'
              '${game.ruleset.isTaiwanese ? game.minimumPointsLabel : ''}'
              '${game.hanchan ? "full game" : "East-only"} · '
              '${game.timerSeconds}s timer',
          child: Column(
            children: [
              for (final seat in game.lobbySeats) _seatRow(seat),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (game.isHost)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('startGame'),
              onPressed: game.startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffcaa24e),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Start Game — bots fill any empty seats'),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Waiting for the host to start…',
                style: TextStyle(color: Colors.white54)),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => game.leaveRoom(),
          child: const Text('Leave Room'),
        ),
      ],
    );
  }

  Widget _seatRow(LobbySeat seat) {
    final label = seat.name ?? 'Empty seat';
    final character = seat.character;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          character == null
              ? const Icon(Icons.person_outline,
                  color: Colors.white30, size: 20)
              : _seatAvatar(character),
          const SizedBox(width: 8),
          if (seat.isBot) ...[
            const Icon(Icons.smart_toy, color: Colors.white54, size: 14),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: seat.isOpen ? Colors.white38 : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (seat.isHost)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Chip(
                label: Text('HOST', style: TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          if (!seat.isOpen && !seat.isBot)
            Icon(
              seat.connected ? Icons.wifi : Icons.wifi_off,
              size: 16,
              color: seat.connected ? Colors.greenAccent : Colors.redAccent,
            ),
        ],
      ),
    );
  }

  Widget _seatAvatar(Character c) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xffcaa24e), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          kCharacterPortrait[c]!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );

  /// [emoji], when given, sits left of [title]. Single-codepoint emoji only:
  /// one ending in U+FE0F has no Noto font on web, which then logs a
  /// missing-font warning (see the welcome screen's builder button).
  Widget _card({required String title, required Widget child, Widget? emoji}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff0b2f2f),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66caa24e)),
      ),
      // Transparent so the Container's own background/border still show —
      // it only exists so the SwitchListTile inside `child` has a Material
      // ancestor to paint its background/ink splashes on, since those never
      // paint on a plain DecoratedBox.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (emoji != null) ...[emoji, const SizedBox(width: 8)],
                Text(title,
                    style: const TextStyle(
                        color: Color(0xffe9d58f), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
