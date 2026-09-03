import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        title: 'TileSense',
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
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _game.dispose();
    super.dispose();
  }

  // Esc toggles pause (works on web where widget shortcuts miss the canvas).
  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      _game.togglePause();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/tilesense.png',
              height: 28,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            const Text('TileSense'),
            const SizedBox(width: 16),
            // East-only vs. hanchan game length (hanchan is the default).
            AnimatedBuilder(
              animation: _game,
              builder: (context, _) => TextButton(
                onPressed: () => _game.setHanchan(!_game.hanchan),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xffe9d58f),
                ),
                child: Text(
                  _game.hanchan ? 'Hanchan' : 'East only',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showGuide ? 'Hide guide' : 'Show guide',
            icon: Opacity(
              opacity: _showGuide ? 1 : 0.8,
              child: Image.asset(
                'assets/clefairy.png',
                height: 30,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const Icon(Icons.school),
              ),
            ),
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
                    top: 8,
                    child: EfficiencyOverlay(game: _game, report: _game.report),
                  ),
                if (_game.paused)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xcc000000),
                      child: const Center(
                        child: Text(
                          'PAUSED\npress Esc to resume',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
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
