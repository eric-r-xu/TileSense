import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/game_controller.dart';
import 'game/gesture_unlock.dart';
import 'game/sfx.dart';
import 'ui/efficiency_overlay.dart';
import 'ui/hand_view.dart';
import 'ui/scoring_view.dart';
import 'ui/table_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The layout is authored landscape-only (see [_LandscapeGate], which is the
  // web fallback since browsers can't lock rotation). On Android / iOS lock it
  // for real so the app opens straight into landscape.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Arm a native (pre-Flutter) listener whose synchronous AudioContext.resume
  // call satisfies mobile browser autoplay policy. Its web implementation also
  // begins decoding clips; the native stub remains a true no-op.
  armFirstGestureUnlock();
  runApp(const TileSenseApp());
}

/// The design resolution the UI is authored at. Everything is laid out in these
/// logical pixels and then scaled as one unit, so the table never reflows. The
/// ~2:1 ratio is deliberately wide so a phone held in landscape fills almost the
/// whole viewport with only thin letterbox bars.
const Size kDesignSize = Size(1600, 820);

/// Colour shown in the letterbox bars around the scaled canvas.
const Color kLetterboxColor = Color(0xff042020);

class TileSenseApp extends StatelessWidget {
  const TileSenseApp({super.key});

  @override
  Widget build(BuildContext context) => Listener(
        // Redundant fallback for the native browser listener installed in
        // main(). Repeated resume calls are idempotent, and this is a no-op on
        // native platforms.
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) => Sfx.i.unlock(),
        child: MaterialApp(
          title: 'TileSense',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xffcaa24e),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          // Every size in this app is authored in kDesignSize's fixed logical
          // pixels and scaled as one unit by _FixedCanvas — but browsers each
          // set their own default system/accessibility text-scale factor
          // independently of that (e.g. Chrome for Android can differ from
          // Safari/Firefox on the very same device), which scales Text
          // separately from everything else and was exactly why things like
          // the centre status block or the rotate-landscape prompt rendered
          // taller / more loosely spaced on some browsers than others. Pin it
          // to 1.0 everywhere — including _LandscapeGate, which sits outside
          // _FixedCanvas's own MediaQuery override — so text always renders
          // at the size it was authored at.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: child!,
          ),
          home: const _LandscapeGate(child: _FixedCanvas(child: GamePage())),
        ),
      );
}

/// Renders [child] at [kDesignSize] and scales the whole thing to fit the
/// window. With [BoxFit.scaleDown] it never exceeds 1:1 — on a large desktop
/// Chrome window you get the app at its exact native pixels, centred, with
/// letterbox bars; on a smaller window or a phone in landscape it shrinks
/// uniformly to fit. Swap to [BoxFit.contain] if you'd rather it also scale up.
class _FixedCanvas extends StatelessWidget {
  const _FixedCanvas({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kLetterboxColor,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: kDesignSize.width,
            height: kDesignSize.height,
            // Give the subtree a MediaQuery that reflects the fixed canvas, not
            // the browser window, so SafeArea / layout math stays stable.
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: kDesignSize,
                padding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocks portrait orientation: web can't reliably lock rotation, so instead of
/// squashing the landscape layout we show a rotate prompt until the viewport is
/// wider than it is tall.
class _LandscapeGate extends StatelessWidget {
  const _LandscapeGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width >= size.height) return child;
    return const ColoredBox(
      color: kLetterboxColor,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_rotation, color: Colors.white70, size: 48),
              SizedBox(height: 16),
              Text(
                'Rotate your device to landscape to play TileSense',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _game = GameController();
  // Off by default so a new player sees the plain table first; the clefairy
  // button next to the GitHub link turns it on.
  bool _showGuide = false;
  // Shown once per app load, ahead of the table; the Start button hides it
  // for the rest of the session.
  bool _showWelcome = true;

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
    if (_showWelcome) {
      return _WelcomeScreen(onStart: () => setState(() => _showWelcome = false));
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The clefairy mascot doubles as the guide toggle — tap to show
            // or hide the efficiency panel, dimmed while it's off.
            IconButton(
              key: const Key('guideToggle'),
              tooltip: _showGuide
                  ? 'TileSense — hide guide'
                  : 'TileSense — show guide',
              iconSize: 32,
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _showGuide = !_showGuide),
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
            // 2x fast-mode toggle.
            AnimatedBuilder(
              animation: _game,
              builder: (context, _) => TextButton(
                onPressed: () => _game.setFastMode(!_game.fastMode),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: _game.fastMode
                      ? const Color(0xffffdf76)
                      : Colors.white38,
                ),
                child: Text(
                  '2x',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    decoration: _game.fastMode
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
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
          AnimatedBuilder(
            animation: _game,
            builder: (context, _) => IconButton(
              tooltip: _game.paused ? 'Resume' : 'Pause',
              icon: Icon(_game.paused ? Icons.play_arrow : Icons.pause),
              onPressed: _game.togglePause,
            ),
          ),
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: _game.newGame,
          ),
          // Keep the actions off the very edge.
          const SizedBox(width: 10),
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
                    HandView(
                      game: _game,
                      showGuide: _showGuide,
                    ),
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _game.togglePause,
                      child: ColoredBox(
                        color: const Color(0xcc000000),
                        child: const Center(
                          child: Text(
                            'PAUSED\ntap, or press Esc, to resume',
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

/// First thing shown on app load: the clefairy mark, the app name, a short
/// explanation of what TileSense does, and a Start button into the table.
class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // Material ancestor: without one, Text on web can render with a stray
    // underline decoration (every other screen gets this for free via
    // Scaffold's own Material).
    return Material(
      color: kLetterboxColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/clefairy.png',
                height: 140,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'TileSense',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xffe9d58f),
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 560,
                child: Text(
                  "TileSense is a Flutter Web App built to give you a feel for "
                  'optimal Riichi Mahjong play, with recommended actions scored '
                  'by efficiency, expected value, and safety.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffcaa24e),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  textStyle:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
