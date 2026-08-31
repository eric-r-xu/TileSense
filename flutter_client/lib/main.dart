import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const OpenRiichiApp());

class OpenRiichiApp extends StatelessWidget {
  const OpenRiichiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OpenRiichi 2D',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xffcaa24e),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const GamePage(),
      );
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final _game = RiichiRound();
  Timer? _botTimer;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  void _newRound() {
    _botTimer?.cancel();
    setState(_game.start);
    _scheduleBot();
  }

  void _scheduleBot() {
    _botTimer?.cancel();
    if (_game.finished || _game.currentPlayer == 0) return;
    _botTimer = Timer(const Duration(milliseconds: 520), () {
      if (!mounted || _game.finished || _game.currentPlayer == 0) return;
      setState(_game.playBotTurn);
      _scheduleBot();
    });
  }

  void _discard(Tile tile) {
    if (_game.finished || _game.currentPlayer != 0) return;
    setState(() => _game.discard(tile));
    _scheduleBot();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenRiichi — 2D'),
        actions: [
          IconButton(
            tooltip: 'New round',
            onPressed: _newRound,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 680 || constraints.maxWidth < 520;
            return Container(
              color: const Color(0xff073d3d),
              child: Column(
                children: [
                  _statusBar(game),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned(top: 10, left: 10, right: 10, child: _opponent(game, 2, false)),
                        Positioned(left: 8, top: 86, bottom: compact ? 102 : 132, child: _sideOpponent(game, 3)),
                        Positioned(right: 8, top: 86, bottom: compact ? 102 : 132, child: _sideOpponent(game, 1)),
                        Center(child: _table(game, compact)),
                      ],
                    ),
                  ),
                  _hand(game, compact),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusBar(RiichiRound game) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(
          children: [
            Text('East 1  •  Wall ${game.wall.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(game.status, textAlign: TextAlign.end),
          ],
        ),
      );

  Widget _table(RiichiRound game, bool compact) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 260 : 390),
        child: Card(
          color: const Color(0xff0b5c58),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xffcaa24e))),
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('DISCARDS', style: TextStyle(letterSpacing: 1.5, color: Color(0xffe9d58f))),
                const SizedBox(height: 6),
                for (final player in [2, 3, 1, 0])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _pond(game, player, compact),
                  ),
                if (game.finished) ...[
                  const SizedBox(height: 8),
                  Text(game.status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xffffdf76))),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _pond(RiichiRound game, int player, bool compact) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: compact ? 38 : 64, child: Text(game.names[player], style: TextStyle(fontSize: compact ? 9 : 11))),
          Expanded(
            child: Wrap(
              spacing: 1,
              runSpacing: 1,
              children: game.ponds[player].map((tile) => TileFace(tile: tile, small: true)).toList(),
            ),
          ),
        ],
      );

  Widget _opponent(RiichiRound game, int player, bool reveal) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _playerName(game, player),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: List.generate(game.hands[player].length, (_) => TileFace(hidden: !reveal, small: true))),
        ],
      );

  Widget _sideOpponent(RiichiRound game, int player) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotatedBox(quarterTurns: player == 1 ? 1 : 3, child: _playerName(game, player)),
          const SizedBox(height: 3),
          Column(mainAxisSize: MainAxisSize.min, children: List.generate(min(8, game.hands[player].length), (_) => const TileFace(hidden: true, small: true))),
          if (game.hands[player].length > 8) Text('+${game.hands[player].length - 8}', style: const TextStyle(fontSize: 10)),
        ],
      );

  Widget _playerName(RiichiRound game, int player) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: game.currentPlayer == player && !game.finished ? const Color(0xffcaa24e) : const Color(0xff164d4d),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('${game.names[player]}  ${game.scores[player]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );

  Widget _hand(RiichiRound game, bool compact) {
    final canPlay = game.currentPlayer == 0 && !game.finished;
    return Container(
      width: double.infinity,
      color: const Color(0xff062e2d),
      padding: EdgeInsets.fromLTRB(8, compact ? 5 : 8, 8, compact ? 7 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _playerName(game, 0),
          const SizedBox(height: 5),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: compact ? 2 : 4,
            runSpacing: 3,
            children: game.hands[0]
                .map((tile) => Semantics(
                      button: canPlay,
                      label: 'Discard ${tile.name}',
                      child: InkWell(
                        onTap: canPlay ? () => _discard(tile) : null,
                        borderRadius: BorderRadius.circular(5),
                        child: TileFace(tile: tile, selectable: canPlay, compact: compact),
                      ),
                    ))
                .toList(),
          ),
          if (canPlay && game.canTsumo(0))
            TextButton.icon(onPressed: () => setState(() => game.tsumo(0)), icon: const Icon(Icons.emoji_events), label: const Text('TSUMO')),
        ],
      ),
    );
  }
}

class TileFace extends StatelessWidget {
  const TileFace({super.key, this.tile, this.hidden = false, this.small = false, this.selectable = false, this.compact = false});
  final Tile? tile;
  final bool hidden, small, selectable, compact;

  @override
  Widget build(BuildContext context) {
    final width = small ? 16.0 : (compact ? 27.0 : 34.0);
    final height = small ? 23.0 : (compact ? 39.0 : 49.0);
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hidden ? const Color(0xffb84e3f) : (selectable ? const Color(0xfffff8db) : const Color(0xffe9e5d3)),
        border: Border.all(color: selectable ? const Color(0xffd59e2e) : const Color(0xff403d35), width: selectable ? 2 : 1),
        borderRadius: BorderRadius.circular(small ? 2 : 5),
      ),
      child: hidden ? null : Text(tile!.glyph, style: TextStyle(fontSize: small ? 14 : (compact ? 23 : 29), color: Colors.black87)),
    );
  }
}

class Tile {
  const Tile(this.kind, this.id);
  final int kind;
  final int id;
  String get glyph => _glyphs[kind];
  String get name => _names[kind];
  static const _glyphs = ['🀇','🀈','🀉','🀊','🀋','🀌','🀍','🀎','🀏','🀙','🀚','🀛','🀜','🀝','🀞','🀟','🀠','🀡','🀐','🀑','🀒','🀓','🀔','🀕','🀖','🀗','🀘','🀀','🀁','🀂','🀃','🀆','🀅','🀄'];
  static const _names = ['1 Man','2 Man','3 Man','4 Man','5 Man','6 Man','7 Man','8 Man','9 Man','1 Pin','2 Pin','3 Pin','4 Pin','5 Pin','6 Pin','7 Pin','8 Pin','9 Pin','1 Sou','2 Sou','3 Sou','4 Sou','5 Sou','6 Sou','7 Sou','8 Sou','9 Sou','East','South','West','North','White','Green','Red'];
}

class RiichiRound {
  final random = Random();
  final names = const ['You', 'Right', 'Top', 'Left'];
  final scores = [25000, 25000, 25000, 25000];
  List<List<Tile>> hands = List.generate(4, (_) => <Tile>[]);
  List<List<Tile>> ponds = List.generate(4, (_) => <Tile>[]);
  List<Tile> wall = <Tile>[];
  int currentPlayer = 0;
  bool needsDraw = true;
  bool finished = false;
  String status = 'Preparing round…';

  void start() {
    final tiles = <Tile>[];
    var id = 0;
    for (var kind = 0; kind < 34; kind++) {
      for (var copy = 0; copy < 4; copy++) tiles.add(Tile(kind, id++));
    }
    tiles.shuffle(random);
    hands = List.generate(4, (_) => <Tile>[]);
    ponds = List.generate(4, (_) => <Tile>[]);
    for (var i = 0; i < 13; i++) {
      for (var player = 0; player < 4; player++) hands[player].add(tiles.removeLast());
    }
    wall = tiles;
    currentPlayer = 0;
    needsDraw = true;
    finished = false;
    _drawForCurrent();
  }

  void _drawForCurrent() {
    if (wall.isEmpty) {
      finished = true;
      status = 'Exhaustive draw';
      return;
    }
    hands[currentPlayer].add(wall.removeLast());
    _sort(hands[currentPlayer]);
    needsDraw = false;
    status = currentPlayer == 0 ? 'Your turn — choose a tile to discard' : '${names[currentPlayer]} is thinking…';
  }

  void discard(Tile tile) {
    if (finished || currentPlayer != 0 || !hands[0].remove(tile)) return;
    ponds[0].add(tile);
    _advance();
  }

  void playBotTurn() {
    if (finished || currentPlayer == 0) return;
    if (canTsumo(currentPlayer)) {
      tsumo(currentPlayer);
      return;
    }
    final hand = hands[currentPlayer];
    // Prefer discarding isolated honors and terminals; it makes bots play credibly without hidden information.
    hand.sort((a, b) => _discardValue(b, hand).compareTo(_discardValue(a, hand)));
    final discarded = hand.removeLast();
    ponds[currentPlayer].add(discarded);
    _advance();
  }

  void _advance() {
    currentPlayer = (currentPlayer + 1) % 4;
    needsDraw = true;
    _drawForCurrent();
  }

  int _discardValue(Tile tile, List<Tile> hand) {
    final same = hand.where((other) => other.id != tile.id && other.kind == tile.kind).length;
    if (same > 0) return -20;
    if (tile.kind >= 27) return 20;
    final number = tile.kind % 9;
    final suit = tile.kind ~/ 9;
    final linked = hand.where((other) => other.id != tile.id && other.kind < 27 && other.kind ~/ 9 == suit && (other.kind % 9 - number).abs() <= 2).length;
    return (number == 0 || number == 8 ? 12 : 5) - linked * 8;
  }

  bool canTsumo(int player) => hands[player].length % 3 == 2 && _isAgari(hands[player]);

  void tsumo(int player) {
    if (!canTsumo(player)) return;
    finished = true;
    scores[player] += 12000;
    for (var p = 0; p < 4; p++) if (p != player) scores[p] -= 4000;
    status = '${names[player]} wins by TSUMO!';
  }

  void _sort(List<Tile> tiles) => tiles.sort((a, b) => a.kind.compareTo(b.kind));

  bool _isAgari(List<Tile> tiles) {
    final counts = List<int>.filled(34, 0);
    for (final tile in tiles) counts[tile.kind]++;
    if (_isKokushi(counts) || counts.where((count) => count == 2).length == 7 && counts.every((count) => count == 0 || count == 2)) return true;
    for (var pair = 0; pair < 34; pair++) {
      if (counts[pair] < 2) continue;
      counts[pair] -= 2;
      final valid = _melds(counts);
      counts[pair] += 2;
      if (valid) return true;
    }
    return false;
  }

  bool _isKokushi(List<int> counts) {
    const terminals = [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33];
    return terminals.every((kind) => counts[kind] > 0) && terminals.any((kind) => counts[kind] > 1) && counts.asMap().entries.where((entry) => !terminals.contains(entry.key)).every((entry) => entry.value == 0);
  }

  bool _melds(List<int> counts) {
    final first = counts.indexWhere((count) => count > 0);
    if (first == -1) return true;
    if (counts[first] >= 3) {
      counts[first] -= 3;
      if (_melds(counts)) { counts[first] += 3; return true; }
      counts[first] += 3;
    }
    if (first < 27 && first % 9 <= 6 && counts[first + 1] > 0 && counts[first + 2] > 0) {
      counts[first]--; counts[first + 1]--; counts[first + 2]--;
      if (_melds(counts)) { counts[first]++; counts[first + 1]++; counts[first + 2]++; return true; }
      counts[first]++; counts[first + 1]++; counts[first + 2]++;
    }
    return false;
  }
}
