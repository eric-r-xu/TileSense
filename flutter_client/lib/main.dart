import 'package:flutter/material.dart';

import 'game/game_controller.dart';
import 'ui/efficiency_overlay.dart';
import 'ui/hand_view.dart';
import 'ui/scoring_view.dart';
import 'ui/table_view.dart';

void main() => runApp(const TileSenseApp());

class TileSenseApp extends StatelessWidget {
  const TileSenseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TileSense — 2D Efficiency',
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
  late final GameController _game = GameController();
  bool _showGuide = true;

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TileSense — 2D Efficiency'),
        actions: [
          IconButton(
            tooltip: _showGuide ? 'Hide guide' : 'Show guide',
            icon: Icon(_showGuide ? Icons.school : Icons.school_outlined),
            onPressed: () => setState(() => _showGuide = !_showGuide),
          ),
          AnimatedBuilder(
            animation: _game,
            builder: (context, _) => Row(
              children: [
                const Text('Auto', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _game.autoplay,
                  onChanged: _game.setAutoplay,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: _game.newGame,
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _game,
          builder: (context, _) {
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: TableView(game: _game)),
                    HandView(game: _game),
                  ],
                ),
                if (_showGuide)
                  Positioned(
                    left: 8,
                    bottom: 120,
                    child: EfficiencyOverlay(report: _game.report),
                  ),
                if (_game.phase != GamePhase.playing) ScoringView(game: _game),
              ],
            );
          },
        ),
      ),
    );
  }
}
