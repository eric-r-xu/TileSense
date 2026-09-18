import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'game/game_controller.dart';
import 'game/gesture_unlock.dart';
import 'game/sfx.dart';
import 'logic/efficiency_engine.dart' show HandFocus, PlayStyle, Strategy;
import 'package:mahjong_core/ruleset.dart';
import 'ui/character_picker.dart';
import 'ui/efficiency_overlay.dart';
import 'ui/hand_view.dart';
import 'ui/online_page.dart';
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

/// The guide dials sit in an app bar that was already full, so they are
/// drawn tight: no minimum size, no tap-target padding of their own, and
/// just enough room around the value to keep it off its neighbours — [_barDial]
/// stacks a caption above this, and both have to clear a 50px toolbar.
ButtonStyle _dialButtonStyle(Color colour) => TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      foregroundColor: colour,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

const TextStyle _dialLabelStyle =
    TextStyle(fontSize: 11, fontWeight: FontWeight.w700);

/// Why the hand counts either game length advertises are a floor rather than
/// a promise. Standard riichi replays the hand whenever the dealership holds,
/// so both numbers are what you get only if it passes every single time.
const String _handCountCaveat =
    'That is with the dealership passing every hand. Under standard riichi '
    'rules a dealer who wins, or who is tenpai at an exhaustive draw, keeps '
    'it and the hand is replayed — so either length can run longer.';

/// [_handCountCaveat] under Hong Kong rules, where any draw keeps the deal.
const String _handCountCaveatHongKong =
    'That is with the dealership passing every hand. A dealer who wins, or '
    'any exhaustive draw, keeps it and the hand is replayed — so either '
    'length can run longer.';

/// One captioned dial in the app bar: a dim fixed caption on top and the
/// current value, in the dial's own colour, on the bottom — tapped to cycle.
/// Stacked rather than side by side so every dial reads the same way at a
/// glance regardless of how many are showing at once, and so several dials
/// fit across the bar instead of only stacking two deep.
Widget _barDial({
  required String caption,
  required Key buttonKey,
  required String label,
  required Color colour,
  required String tooltip,
  required VoidCallback onTap,
}) =>
    Tooltip(
      message: tooltip,
      // Fixed column height: caption line plus a shrink-wrapped button, 44px
      // total, fits a 50px toolbar with a few pixels to spare.
      child: SizedBox(
        width: 74,
        height: 44,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(caption,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
            TextButton(
              key: buttonKey,
              onPressed: onTap,
              style: _dialButtonStyle(colour),
              child: Text(label, style: _dialLabelStyle),
            ),
          ],
        ),
      ),
    );

/// Colour for a hand focus, on a deliberately different axis from
/// [playStyleColor] so the two dials never read as one setting: this one runs
/// from the quick, cool blue of a fast cheap hand to the violet of a big slow
/// one.
Color handFocusColor(HandFocus focus) => switch (focus) {
      HandFocus.speed => const Color(0xff64b5f6),
      HandFocus.balanced => const Color(0xffe9d58f),
    };

/// Colour for a strategy, on a third axis again: points stays the same gold
/// every other dial's neutral setting uses, placement gets a podium-ish
/// magenta so the three dials never read as one setting even at a glance.
Color strategyColor(Strategy strategy) => switch (strategy) {
      Strategy.points => const Color(0xffe9d58f),
      Strategy.placement => const Color(0xffce93d8),
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
class _FixedCanvas extends StatefulWidget {
  const _FixedCanvas({required this.child});
  final Widget child;

  /// Pinch-to-zoom is offered on touch platforms only. On a desktop browser a
  /// stray trackpad pinch scaling the table would be a nuisance, so the raw
  /// gesture is left unbound there — desktop gets [_deliberateZoom] instead,
  /// which only ever fires on purpose.
  ///
  /// An iPad running Safari in its "desktop" mode reports macOS and so misses
  /// out on pinch; it picks up the buttons in exchange.
  static bool get _pinchZoomable => switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.fuchsia =>
          true,
        _ => false,
      };

  /// The other half: on-screen buttons, a modifier-held wheel, and the zoom
  /// shortcuts every other desktop app uses. Everything here needs a
  /// deliberate act — a click, or a held Ctrl/Cmd — so nothing scales the
  /// table by accident the way a bare pinch or a bare scroll would.
  static bool get _deliberateZoom => !_pinchZoomable;

  @override
  State<_FixedCanvas> createState() => _FixedCanvasState();
}

class _FixedCanvasState extends State<_FixedCanvas> {
  final TransformationController _zoom = TransformationController();

  /// Panning is off until you have actually zoomed in. At rest the canvas
  /// exactly fills its box so there is nowhere to pan to anyway, and leaving it
  /// on would have one-finger drags fighting the hand strip and the builder's
  /// tile palette for the same gesture.
  bool _zoomedIn = false;

  /// Keyboard focus for the zoom shortcuts. Kept unfocusable by traversal so
  /// it never steals a tab stop from the game itself; it only ever holds focus
  /// because it is the outermost scope.
  final FocusNode _keys = FocusNode(debugLabel: 'zoom', skipTraversal: true);

  static const double _minScale = 1;
  static const double _maxScale = 4;

  /// One press of a button or a shortcut. A ratio rather than a step, so the
  /// same press feels the same at every magnification.
  static const double _zoomStep = 1.25;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoom);
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoom);
    _zoom.dispose();
    _keys.dispose();
    super.dispose();
  }

  void _onZoom() {
    final zoomedIn = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomedIn != _zoomedIn) setState(() => _zoomedIn = zoomedIn);
  }

  double get _scale => _zoom.value.getMaxScaleOnAxis();

  /// Scale to [target], keeping the middle of the viewport where it is.
  ///
  /// [InteractiveViewer] owns the translation as well as the scale, so this
  /// cannot just write a scale in: at 2x the canvas is twice the size of its
  /// box and the offset decides which half you are looking at. Rebuilding the
  /// matrix around the centre is what stops a button press from jumping you
  /// to a corner.
  void _zoomTo(double target, {Offset? focalPoint}) {
    final clamped = target.clamp(_minScale, _maxScale);
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? kDesignSize;
    final focal = focalPoint ?? size.center(Offset.zero);

    final current = _scale;
    if ((clamped - current).abs() < 0.001) return;

    // The scene point under [focal] has to stay under it afterwards.
    final translation = _zoom.value.getTranslation();
    final scenePoint = Offset(
      (focal.dx - translation.x) / current,
      (focal.dy - translation.y) / current,
    );
    final next = Matrix4.identity()
      ..translateByDouble(focal.dx - scenePoint.dx * clamped,
          focal.dy - scenePoint.dy * clamped, 0, 1)
      ..scaleByDouble(clamped, clamped, clamped, 1);

    // Never leave the box showing letterbox where canvas should be: at 1x the
    // canvas fills it exactly, so the offset has to come back to zero.
    _zoom.value = clamped <= _minScale ? Matrix4.identity() : next;
  }

  void _zoomBy(double factor, {Offset? focalPoint}) =>
      _zoomTo(_scale * factor, focalPoint: focalPoint);

  /// Ctrl/Cmd + wheel, the way every map and document viewer does it. A bare
  /// scroll is deliberately left alone — it belongs to whatever is under the
  /// pointer, and hijacking it would make the table lurch while you were
  /// reading the guide panel.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final focal = box?.globalToLocal(event.position) ?? event.localPosition;
    _zoomBy(event.scrollDelta.dy < 0 ? _zoomStep : 1 / _zoomStep,
        focalPoint: focal);
  }

  /// The desktop zoom surface: the same [InteractiveViewer] the touch build
  /// uses, but driven only on purpose — a held Ctrl/Cmd with the wheel, the
  /// usual keyboard shortcuts, or the buttons. Dragging to pan still works
  /// once zoomed, and is still off at 1x so it cannot fight the hand strip.
  Widget _desktopZoomable(Widget canvas) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Both the main-row and numpad forms, and with shift held, because
        // "+" on most layouts *is* shift-equals.
        for (final key in [
          LogicalKeyboardKey.equal,
          LogicalKeyboardKey.add,
          LogicalKeyboardKey.numpadAdd,
        ]) ...{
          SingleActivator(key, control: true): const _ZoomIntent(_zoomStep),
          SingleActivator(key, meta: true): const _ZoomIntent(_zoomStep),
          SingleActivator(key, control: true, shift: true):
              const _ZoomIntent(_zoomStep),
          SingleActivator(key, meta: true, shift: true):
              const _ZoomIntent(_zoomStep),
        },
        for (final key in [
          LogicalKeyboardKey.minus,
          LogicalKeyboardKey.numpadSubtract,
        ]) ...{
          SingleActivator(key, control: true): const _ZoomIntent(1 / _zoomStep),
          SingleActivator(key, meta: true): const _ZoomIntent(1 / _zoomStep),
        },
        for (final key in [
          LogicalKeyboardKey.digit0,
          LogicalKeyboardKey.numpad0,
        ]) ...{
          SingleActivator(key, control: true): const _ZoomIntent(null),
          SingleActivator(key, meta: true): const _ZoomIntent(null),
        },
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ZoomIntent: CallbackAction<_ZoomIntent>(
            onInvoke: (intent) {
              final factor = intent.factor;
              if (factor == null) {
                _zoomTo(_minScale);
              } else {
                _zoomBy(factor);
              }
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _keys,
          autofocus: true,
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _zoom,
                    minScale: _minScale,
                    maxScale: _maxScale,
                    panEnabled: _zoomedIn,
                    // The wheel is handled above, under a modifier. Leaving
                    // the viewer's own scale gesture on would also bind a bare
                    // trackpad pinch, which is the accident this build avoids.
                    scaleEnabled: false,
                    child: canvas,
                  ),
                ),
                _zoomControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The zoom controls, bottom-right over the letterbox bar. Hidden on touch,
  /// where pinch is the natural gesture and the buttons would only cover the
  /// table. Reset is only offered once there is something to reset.
  Widget _zoomControls() {
    Widget button(IconData icon, String tip, VoidCallback? onTap, Key key) =>
        Tooltip(
          message: tip,
          child: IconButton(
            key: key,
            icon: Icon(icon, size: 18),
            onPressed: onTap,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
            color: Colors.white70,
            disabledColor: Colors.white24,
            hoverColor: const Color(0x22ffffff),
          ),
        );

    return Positioned(
      right: 6,
      bottom: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(
                Icons.remove,
                'Zoom out  (Ctrl/Cmd -)',
                _scale > _minScale + 0.001
                    ? () => _zoomBy(1 / _zoomStep)
                    : null,
                const Key('zoomOut')),
            button(
                Icons.add,
                'Zoom in  (Ctrl/Cmd +)',
                _scale < _maxScale - 0.001 ? () => _zoomBy(_zoomStep) : null,
                const Key('zoomIn')),
            button(
                Icons.crop_free,
                'Reset zoom  (Ctrl/Cmd 0)',
                _zoomedIn ? () => _zoomTo(_minScale) : null,
                const Key('zoomReset')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvas = Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: kDesignSize.width,
          height: kDesignSize.height,
          // Give the subtree a MediaQuery that reflects the fixed canvas, not
          // the browser window, so SafeArea / layout math stays stable. The
          // real insets are handled by the SafeArea below, before the canvas is
          // sized, so there is nothing left for the subtree to dodge.
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: kDesignSize,
              padding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    return ColoredBox(
      color: kLetterboxColor,
      // Fit the canvas inside the real safe area rather than under it. A
      // notched iPhone held in landscape insets ~59px on the notch side, which
      // is more than the letterbox bars this aspect ratio leaves — so without
      // this the guide panel's outer edge sits under the notch. The letterbox
      // colour fills the inset, so nothing looks cut off.
      child: SafeArea(
        child: _FixedCanvas._deliberateZoom
            ? _desktopZoomable(canvas)
            : _FixedCanvas._pinchZoomable
                ? InteractiveViewer(
                    transformationController: _zoom,
                    minScale: _minScale,
                    maxScale: _maxScale,
                    panEnabled: _zoomedIn,
                    child: canvas,
                  )
                : canvas,
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

  // Online multiplayer, reached from the welcome screen. Like the builder it
  // owns its own controller (an [OnlineGameController], not [_game]) so
  // leaving it back to the menu never disturbs an offline game in progress.
  bool _showOnline = false;

  // Prefilled into the join-code field from a shared `?join=CODE` link,
  // read once at startup.
  String? _joinCode;

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
    // A shared room link (https://…/tilesense/?join=CODE) jumps straight
    // into the join flow instead of the welcome screen.
    final join = Uri.base.queryParameters['join'];
    if (join != null && join.isNotEmpty) {
      _joinCode = join;
      _showWelcome = false;
      _showOnline = true;
    }
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

  // Leaving a game in progress for the welcome screen — the only way there to
  // reach the Custom Hand & Context Builder — pauses it so bots and autoplay
  // don't keep running unattended; Start un-pauses it again on the way back.
  void _backToMenu() {
    if (!_game.paused) _game.togglePause();
    setState(() => _showWelcome = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showBuilder) {
      return ScenarioPage(
        initialRuleset: _game.ruleset,
        onExit: () => setState(() => _showBuilder = false),
      );
    }
    if (_showOnline) {
      return OnlinePage(
        initialRuleset: _game.ruleset,
        initialJoinCode: _joinCode,
        onExit: () => setState(() {
          _showOnline = false;
          _joinCode = null;
          _showWelcome = true;
        }),
      );
    }
    if (_showWelcome) {
      return _WelcomeScreen(
        ruleset: _game.ruleset,
        onRuleset: (r) => setState(() => _game.setRuleset(r)),
        seatCharacters: _game.seatCharacters,
        onSeatCharacter: (seat, c) => setState(() {
          _game.setSeatCharacter(seat, c);
        }),
        onStart: () => setState(() {
          if (_game.paused) _game.togglePause();
          _showWelcome = false;
        }),
        onBuild: () => setState(() => _showBuilder = true),
        onPlayOnline: () => setState(() => _showOnline = true),
      );
    }
    _game.guideVisible = _showGuide; // read only by telemetry
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        titleSpacing: 12,
        leading: IconButton(
          key: const Key('backToMenu'),
          tooltip: 'Main menu — pauses this game; Start resumes it, or open '
              'the Custom Hand & Context Builder',
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToMenu,
        ),
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
            // Which rules the table plays. Switching deals a new game.
            AnimatedBuilder(
              animation: _game,
              builder: (context, _) => Tooltip(
                message: 'Playing ${_game.ruleset.label} rules.\n'
                    'Tap for ${_game.ruleset.next.label} — this starts a new '
                    'game.',
                child: TextButton(
                  key: const Key('ruleset'),
                  onPressed: () => _game.setRuleset(_game.ruleset.next),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xffffdf76),
                  ),
                  child: Text(
                    _game.ruleset.flagLabel,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            // The current ruleset's one-page rules reference.
            AnimatedBuilder(
              animation: _game,
              builder: (context, _) => IconButton(
                key: const Key('rulesPdf'),
                tooltip: '${_game.ruleset.label} rules (PDF)',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                color: Colors.white54,
                icon: const Icon(Icons.menu_book),
                onPressed: () => openRules(_game.ruleset),
              ),
            ),
            // East-only vs. full game length (the full game is the default).
            AnimatedBuilder(
              animation: _game,
              builder: (context, _) {
                final caveat = _game.ruleset.isHongKong
                    ? _handCountCaveatHongKong
                    : _handCountCaveat;
                return Tooltip(
                  message: _game.hanchan
                      ? 'Hanchan — East and South rounds, 8+ hands.\n'
                          '$caveat\n'
                          'Tap for East only (东风战), 4+ hands.'
                      : (_game.ruleset.isHongKong
                          ? 'East only — the East round, 4+ hands.\n'
                              '$caveat\n'
                              'Tap for hanchan (半庄): East and South, 8+ hands.'
                          : 'East only (东风战/tonpuusen) — the East round, 4+ hands.\n'
                              '$caveat\n'
                              'Tap for hanchan (半庄): East and South, 8+ hands.'),
                  child: TextButton(
                    key: const Key('hanchan'),
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
                );
              },
            ),
            // 2x fast-mode toggle.
            AnimatedBuilder(
              animation: _game,
              builder: (context, _) => Tooltip(
                message: _game.fastMode
                    ? 'Bots and draws move at double speed.\n'
                        'Tap for normal speed.'
                    : 'Bots and draws move at normal speed.\n'
                        'Tap for double speed.',
                child: TextButton(
                  key: const Key('fastMode'),
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
            ),
          ],
        ),
        actions: [
          // All three guide dials — and so every Auto-Play dial, since
          // Auto-Play plays from the guide's own scores — kept beside the
          // switch they steer. The guide panel carries a synced copy of each.
          //
          // Side by side, each one a compact caption-over-value stack (see
          // [_barDial]): three of those clear a 50px toolbar with room to
          // spare, where three full single-line buttons would not, and a
          // stack reads as clearly as a row while costing far less width.
          //
          // All three are kept rather than pruned to the ones that move the
          // numbers most: a decision-level sweep (self-play, live-riichi
          // threat included for Style, since its whole effect is gated
          // behind one) found every dial changes the top recommendation on a
          // comparable, non-trivial share of decisions — Style 0.6-1.3% of
          // discards and dozens of riichi/damaten calls under a live threat,
          // Focus 0.6% of discards and a ~50% median swing in the EV number
          // itself, Strategy 0.2% of discards and over a hundred riichi/
          // damaten calls in a placement-sensitive sample. None of the three
          // is a null next to the others.
          AnimatedBuilder(
            animation: _game,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Style has nothing left to weigh under Hong Kong rules — no
                // riichi, no damaten, and the sweep in policy_sweep_test.dart
                // found no placement effect from it either — so it is hidden
                // rather than shown pinned on Balanced.
                if (!_game.ruleset.isHongKong)
                  _barDial(
                    caption: 'STYLE',
                    buttonKey: const Key('playStyle'),
                    label: _game.playStyle.label,
                    colour: playStyleColor(_game.playStyle),
                    tooltip: 'How hard the guide (and Auto-Play) pushes: '
                        'when to fold, when to riichi, when to call',
                    onTap: () => _game.setPlayStyle(_game.playStyle.next),
                  ),
                _barDial(
                  caption: 'FOCUS',
                  buttonKey: const Key('handFocus'),
                  label: _game.handFocus.label,
                  colour: handFocusColor(_game.handFocus),
                  tooltip: 'What the guide (and Auto-Play) chases: '
                      'a quicker cheaper hand, or a slower bigger one',
                  onTap: () => _game.setHandFocus(_game.handFocus.next),
                ),
                // Placement isn't wired up for Hong Kong yet, so the dial is
                // hidden there rather than shown pinned on Points — same
                // treatment as Style just above.
                if (!_game.ruleset.isHongKong)
                  _barDial(
                    caption: 'STRATEGY',
                    buttonKey: const Key('strategy'),
                    label: _game.strategy.label,
                    colour: strategyColor(_game.strategy),
                    tooltip: 'What the guide (and Auto-Play) optimises for: '
                        'the points a line is worth, or how it moves final '
                        'placement given the scores on the table right now',
                    onTap: () => _game.setStrategy(_game.strategy.next),
                  ),
              ],
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
  const _WelcomeScreen({
    required this.ruleset,
    required this.onRuleset,
    required this.seatCharacters,
    required this.onSeatCharacter,
    required this.onStart,
    required this.onBuild,
    required this.onPlayOnline,
  });

  /// The rules Start and the builder will use, and how to change them.
  final Ruleset ruleset;
  final ValueChanged<Ruleset> onRuleset;

  /// Every seat's persona for the offline game Start deals into — index 0 is
  /// the human seat. Defaults to [kSeatCharacters]; see
  /// [GameController.setSeatCharacter].
  final List<Character> seatCharacters;
  final void Function(int seat, Character character) onSeatCharacter;

  final VoidCallback onStart;

  /// Opens the Custom Hand & Context Builder — a posed table, scored by the
  /// same guide, with no game running behind it.
  final VoidCallback onBuild;

  /// Opens the online lobby — create a private room or join one by code.
  final VoidCallback onPlayOnline;

  /// Japanese Riichi or Hong Kong, chosen before Start, each with a link to
  /// its rules PDF beneath it.
  Widget _rulesetChoice() {
    Widget option(Ruleset value, String subtitle) {
      final selected = ruleset == value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              key: Key('ruleset_${value.name}'),
              onPressed: () => onRuleset(value),
              style: OutlinedButton.styleFrom(
                backgroundColor: selected ? const Color(0x33caa24e) : null,
                foregroundColor:
                    selected ? const Color(0xffffdf76) : Colors.white54,
                side: BorderSide(
                    color: selected ? const Color(0xffcaa24e) : Colors.white24,
                    width: selected ? 2 : 1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value.flagLabel,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            TextButton.icon(
              key: Key('rulesPdf_${value.name}'),
              onPressed: () => openRules(value),
              icon: const Icon(Icons.open_in_new, size: 13),
              label: Text('${value.label} rules (PDF)'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff80cbc4),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                    fontSize: 12, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        option(Ruleset.riichi, 'yaku, dora, riichi'),
        option(Ruleset.hongKong, 'faan, flowers, 0-faan minimum'),
      ],
    );
  }

  static const _seatPosition = ['You', 'Right', 'Across', 'Left'];

  /// Every seat's persona, human included — defaults to [kSeatCharacters].
  /// Bots have always had a fixed voice and portrait; this just makes that
  /// choice visible and changeable instead of hardcoded.
  ///
  /// One small avatar per seat rather than a full picker row per seat: this
  /// screen has no room to spare for four rows of five 52px portraits each.
  /// Tapping an avatar opens the same [CharacterRow] picker the online lobby
  /// uses, in a dialog, for that one seat.
  Widget _characterChoice(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('CHOOSE YOUR CHARACTERS',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var seat = 0; seat < seatCharacters.length; seat++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: GestureDetector(
                  key: Key('seatCharacterAvatar_$seat'),
                  onTap: () => _pickCharacter(context, seat),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xff0c4747),
                          border: Border.fromBorderSide(
                              BorderSide(color: Color(0xffcaa24e))),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          kCharacterPortrait[seatCharacters[seat]]!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(_seatPosition[seat],
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickCharacter(BuildContext context, int seat) => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: kLetterboxColor,
          title: Text('${_seatPosition[seat]}\'s character'),
          content: SizedBox(
            width: 340,
            child: CharacterRow(
              options: Character.values,
              selected: seatCharacters[seat],
              keyPrefix: 'seatCharacterPick_$seat',
              onSelect: (c) {
                onSeatCharacter(seat, c);
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Material ancestor: without one, Text on web can render with a stray
    // underline decoration (every other screen gets this for free via
    // Scaffold's own Material).
    return Material(
      color: kLetterboxColor,
      // Scrollable rather than fixed: the character choice below made this
      // screen taller than the design canvas leaves room for at some window
      // sizes, where it used to always fit without scrolling.
      child: SingleChildScrollView(
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
                SizedBox(
                  width: 720,
                  child: Text(
                    'TileSense is a Flutter Web App built to give you a feel for\n'
                    'optimal ${ruleset.label} Mahjong play, with recommended actions\n'
                    'scored by efficiency, expected value, and safety.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 22.5,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _rulesetChoice(),
                const SizedBox(height: 10),
                _characterChoice(context),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffcaa24e),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Play Offline',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text(
                            'Includes the guide',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const Key('playOnline'),
                      onPressed: onPlayOnline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xffe9d58f),
                        side: const BorderSide(color: Color(0xffcaa24e)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Play Online',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text(
                            'With friends — bots fill empty seats, no guide',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            style:
                                TextStyle(fontSize: 12, color: Colors.white60),
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
      ),
    );
  }
}

/// Opens [ruleset]'s rules PDF in a new tab or the system browser.
void openRules(Ruleset ruleset) => launchUrl(
      Uri.parse(ruleset.rulesUrl),
      mode: LaunchMode.externalApplication,
    );

/// Zoom by [factor], or reset when it is null.
class _ZoomIntent extends Intent {
  const _ZoomIntent(this.factor);
  final double? factor;
}
