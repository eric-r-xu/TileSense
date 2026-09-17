/// Create-or-join screen for online multiplayer: name, ruleset + hanchan
/// picker, a room code to share, and the seat roster while waiting to start.
/// Rendered by `OnlinePage` whenever `OnlineGameController.roomPhase` is
/// still `lobby`; `OnlineGamePage` takes over once the host starts the game.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mahjong_core/ruleset.dart';

import '../game/online_game_controller.dart';
import '../game/sfx.dart'
    show Character, kCharacterPortrait, kSelectableCharacters;
import '../main.dart' show kLetterboxColor;
import 'character_picker.dart';

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
  late final TextEditingController _nameCtl =
      TextEditingController(text: widget.controller.displayName);
  late final TextEditingController _joinCtl =
      TextEditingController(text: widget.initialJoinCode ?? '');
  late Ruleset _ruleset = widget.initialRuleset;
  bool _hanchan = true;
  late Character _character = widget.controller.myCharacter;
  String? _shownError;

  OnlineGameController get game => widget.controller;

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
    game.createRoom(ruleset: _ruleset, hanchan: _hanchan);
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

    return Scaffold(
      backgroundColor: kLetterboxColor,
      appBar: AppBar(
        backgroundColor: kLetterboxColor,
        leading: IconButton(
          tooltip: 'Back to menu',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (game.roomCode.isNotEmpty) game.leaveRoom();
            widget.onExit();
          },
        ),
        title: const Text('Play Online'),
      ),
      body: Column(
        children: [
          if (game.connectionLost) _connectionBanner(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
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

  Widget _setupCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Multiplayer has no TileSense guide — play offline for it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
        TextField(
          controller: _nameCtl,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: 'Your name',
            counterText: '',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        _characterPicker(),
        const SizedBox(height: 20),
        _card(
          title: 'Create a room',
          child: Column(
            children: [
              _rulesetPicker(),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Full game — hanchan (8+ hands)'),
                subtitle: Text(_hanchan
                    ? 'Off switches to East-only (4+ hands)'
                    : 'East-only — 4+ hands'),
                value: _hanchan,
                onChanged: (v) => setState(() => _hanchan = v),
              ),
              const SizedBox(height: 8),
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
        const SizedBox(height: 20),
        _card(
          title: 'Join a room',
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
                  style: const TextStyle(color: Colors.white, letterSpacing: 2),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: const Text('Join'),
              ),
            ],
          ),
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
      child: CharacterRow(
        options: kSelectableCharacters,
        selected: _character,
        onSelect: (c) => setState(() => _character = c),
      ),
    );
  }

  Widget _rulesetPicker() {
    Widget option(Ruleset value) {
      final selected = _ruleset == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
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

    return Row(children: [option(Ruleset.riichi), option(Ruleset.hongKong)]);
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
              '${game.hanchan ? "full game" : "East-only"}',
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

  Widget _card({required String title, required Widget child}) {
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
            Text(title,
                style: const TextStyle(
                    color: Color(0xffe9d58f), fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
