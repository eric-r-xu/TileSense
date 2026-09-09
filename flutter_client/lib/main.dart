import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/game_controller.dart';
import 'game/gesture_unlock.dart';
import 'game/sfx.dart';
import 'logic/efficiency_engine.dart' show PlayStyle;
import 'ui/efficiency_overlay.dart';
import 'ui/hand_view.dart';
import 'ui/scenario_page.dart';
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

/// Colour for a play style, so the setting reads at a glance wherever it is
/// shown: cool when it is folding, warm when it is pushing.
Color playStyleColor(PlayStyle style) => switch (style) {
      PlayStyle.defensive => const Color(0xff80cbc4),
      PlayStyle.balanced => const Color(0xffe9d58f),
      PlayStyle.aggressive => const Color(0xffff8a65),
    };

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
///
/// The prompt is laid *over* [child] rather than swapped in for it. Swapping
/// unmounts the whole game subtree, which disposes [GameController] and drops
/// the match on the floor — so on web, where this gate is the only rotation
/// handling there is, turning a phone (or dragging a desktop window taller than
/// it is wide) silently restarted the game and bounced you back to the welcome
/// screen. Keeping the subtree mounted means the match you were playing is
/// still there, mid-hand, when the viewport goes back to landscape.
class _LandscapeGate extends StatelessWidget {
  const _LandscapeGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width >= size.height;
    return Stack(
      fit: StackFit.expand,
      children: [
        // maintainState keeps the game alive while portrait hides it: no
        // painting, no hit testing, no ticking — but no teardown either.
        Visibility(
          visible: landscape,
          maintainState: true,
          child: child,
        ),
        if (!landscape) const _RotatePrompt(),
      ],
    );
  }
}

/// Full-screen cover shown while the viewport is portrait. Opaque to hit tests
/// so nothing reaches the game held behind it.
class _RotatePrompt extends StatelessWidget {
  const _RotatePrompt();

  @override
  Widget build(BuildContext context) => const AbsorbPointer(
        child: ColoredBox(
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
        ),
      );
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _game = GameController();
  // Off by default so a new player sees the plain table first; the clefairy
  // buttons in the AppBar and bottom hand bar turn it on.
  bool _showGuide = false;
  // Shown once per app load, ahead of the table; the Start button hides it
  // for the rest of the session.
  bool _showWelcome = true;

  // The Custom Hand & Context Builder, reached from the welcome screen. It
  // owns its own controller and never touches [_game], so a game in progress
  // is still here when you come back.
  bool _showBuilder = false;

  // Push buffered telemetry when the tab is hidden or the app is torn down, so
  // completed rounds aren't stranded. No-op unless the app was built with
  // --dart-define=TELEMETRY=true.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: _game.flushTelemetry,
    onDetach: _game.flushTelemetry,
  );

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _lifecycle; // instantiate the listener
  }

  @override
  void dispose() {
    _lifecycle.dispose();
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

  void _toggleGuide() => setState(() => _showGuide = !_showGuide);

  @override
  Widget build(BuildContext context) {
    if (_showBuilder) {
      return ScenarioPage(onExit: () => setState(() => _showBuilder = false));
    }
    if (_showWelcome) {
      return _WelcomeScreen(
        onStart: () => setState(() => _showWelcome = false),
        onBuild: () => setState(() => _showBuilder = true),
      );
    }
    _game.guideVisible = _showGuide; // read only by telemetry
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
              onPressed: _toggleGuide,
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
                  foregroundColor:
                      _game.fastMode ? const Color(0xffffdf76) : Colors.white38,
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
          // How hard the guide (and so Autoplay) pushes — kept beside the
          // Auto-Play switch it steers. The guide panel carries a second,
          // synced copy of this dial; both drive GameController.playStyle.
          AnimatedBuilder(
            animation: _game,
            builder: (context, _) => Tooltip(
              message: 'How hard the guide (and Auto-Play) pushes',
              child: TextButton(
                key: const Key('playStyle'),
                onPressed: () => _game.setPlayStyle(_game.playStyle.next),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: playStyleColor(_game.playStyle),
                ),
                child: Text(
                  _game.playStyle.label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _game,
            builder: (context, _) => Row(
              children: [
                const Text('\u{1F916} Auto-Play',
                    style: TextStyle(fontSize: 12)),
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
                      onToggleGuide: _toggleGuide,
                    ),
                  ],
                ),
                // The guide runs from the top of the body down to just above
                // the hand's tile row — so it grows with the window instead of
                // stopping at a fixed cut-off, while never covering a tile you
                // might want to discard.
                if (_showGuide)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        children: [
                          Positioned(
                            left: 8,
                            top: 8,
                            child: EfficiencyOverlay(
                              game: _game,
                              report: _game.report,
                              maxHeight:
                                  c.maxHeight - HandView.tileRowBandHeight - 16,
                            ),
                          ),
                        ],
                      ),
                    ),
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
  const _WelcomeScreen({required this.onStart, required this.onBuild});
  final VoidCallback onStart;

  /// Opens the Custom Hand & Context Builder — a posed table, scored by the
  /// same guide, with no game running behind it.
  final VoidCallback onBuild;

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
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'TileSense',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xffe9d58f),
                  fontSize: 66,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              // Three balanced lines, broken by hand rather than by the
              // wrapper. Left to itself at a snug width the first line lands
              // within a pixel of the limit, so any browser whose default face
              // runs a hair wider than Roboto spills it to four. The box is
              // ~30% wider than the longest line needs, which keeps these
              // three lines three lines. Re-balance the breaks if the text
              // changes — the longest line here measures ~560px.
              const SizedBox(
                width: 720,
                child: Text(
                  'TileSense is a Flutter Web App built to give you a feel for\n'
                  'optimal Riichi Mahjong play, with recommended actions\n'
                  'scored by efficiency, expected value, and safety.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 22.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffcaa24e),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      textStyle: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Start'),
                  ),
                  const SizedBox(width: 18),
                  OutlinedButton(
                    key: const Key('openBuilder'),
                    onPressed: onBuild,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xffe9d58f),
                      side: const BorderSide(color: Color(0xffcaa24e)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Custom Hand & Context Builder',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text(
                          'Pose any table and have TileSense score it',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
