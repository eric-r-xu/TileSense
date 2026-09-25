import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'game/app_update.dart' as upd;
import 'game/fullscreen.dart' as fs;
import 'game/game_controller.dart';
import 'game/gesture_unlock.dart';
import 'game/sfx.dart';
import 'logic/efficiency_engine.dart' show HandFocus, PlayStyle, Strategy;
import 'package:mahjong_core/hong_kong/hong_kong_rules.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/taiwanese/taiwanese_rules.dart';
import 'package:mahjong_core/tile.dart' show Wind;
import 'ui/character_select_page.dart';
import 'ui/efficiency_overlay.dart';
import 'ui/hand_view.dart';
import 'ui/online_page.dart' deferred as online;
import 'ui/feature_loader.dart';
import 'ui/scenario_page.dart' deferred as scenario;
import 'ui/scoring_view.dart';
import 'ui/table_view.dart';
import 'ui/tilesensor.dart';

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
  // keeps the native stub a true no-op.
  armFirstGestureUnlock();
  runApp(const TileSenseApp());
  // Paint the menu before warming shared effects. Voices wait for a table.
  if (kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(Sfx.i.preload());
    });
  }
}

/// Colour for a play style, so the setting reads at a glance wherever it is
/// shown: cool when it is folding, warm when it is pushing.
Color playStyleColor(PlayStyle style) => switch (style) {
      PlayStyle.defensive => const Color(0xff80cbc4),
      PlayStyle.balanced => const Color(0xffe9d58f),
      PlayStyle.aggressive => const Color(0xffff8a65),
    };

/// Why the hand counts either game length advertises are a floor rather than
/// a promise. Standard riichi replays the hand whenever the dealership holds,
/// so both numbers are what you get only if it passes every single time.
const String _handCountCaveat =
    'That is with the dealership passing every hand. Under standard riichi '
    'rules a dealer who wins, or who is tenpai at an exhaustive draw, keeps '
    'it and the hand is replayed — so either length can run longer.';

/// [_handCountCaveat] under Hong Kong and Taiwanese rules, where any draw
/// keeps the deal.
const String _handCountCaveatChineseStyle =
    'That is with the dealership passing every hand. A dealer who wins, or '
    'any exhaustive draw, keeps it and the hand is replayed — so either '
    'length can run longer.';

/// The caption every top-bar tile carries above its value.
const TextStyle _barCaptionStyle = TextStyle(
    color: Colors.white38,
    fontSize: 8,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6);

/// One tile in the app bar: a dim fixed caption on top and the current value
/// (text in the control's own colour, or an icon) underneath, so every
/// control up there reads the same way at a glance.
///
/// The whole tile is the tap target, not just its value. The app is drawn on
/// the fixed [kDesignSize] canvas and scaled down to fit, to about half size
/// on a phone held sideways, so a target only as big as its label would end
/// up a few points tall under a thumb.
Widget _barTile({
  required String caption,
  required String tooltip,
  required VoidCallback onTap,
  required Widget value,
  Key? tapKey,
  double width = 84,
}) =>
    Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: tapKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          // 44px tall: clears the 50px toolbar with the group's border.
          child: SizedBox(
            width: width,
            height: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(caption,
                    maxLines: 1, softWrap: false, style: _barCaptionStyle),
                const SizedBox(height: 3),
                value,
              ],
            ),
          ),
        ),
      ),
    );

/// A guide dial in the app bar — tapped to cycle. [buttonKey] marks the value
/// text, which sits inside the tile's tap area.
Widget _barDial({
  required String caption,
  required Key buttonKey,
  required String label,
  required Color colour,
  required String tooltip,
  required VoidCallback onTap,
}) =>
    _barTile(
      caption: caption,
      tooltip: tooltip,
      onTap: onTap,
      value: KeyedSubtree(
        key: buttonKey,
        child: Text(label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: TextStyle(
                color: colour, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );

/// A thin rule between tiles in the same app-bar group.
Widget _barDivider() =>
    Container(width: 1, height: 28, color: const Color(0x22ffffff));

/// Gold for Auto-Play being on — the border its group lights up with.
const Color _autoPlayGold = Color(0xffcaa24e);

/// TileSensor with a small play badge: the mascot that is the guide, now
/// playing your seat. Greyed and dimmed when Auto-Play is off, the same way
/// the guide toggle dims, and in full colour with a soft glow when on.
class _AutoPlayBadge extends StatelessWidget {
  const _AutoPlayBadge({required this.on, this.size = 24});
  final bool on;
  final double size;

  static const ColorFilter _greyscale = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.46;
    Widget mascot = Image.asset(
      kTileSensorAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(Icons.school, size: size),
    );
    if (!on) {
      mascot = Opacity(
          opacity: 0.45,
          child: ColorFiltered(colorFilter: _greyscale, child: mascot));
    }
    return SizedBox(
      width: size + badge * 0.35,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          mascot,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? _autoPlayGold : const Color(0xff1c3534),
                border: Border.all(
                    color: on ? _autoPlayGold : Colors.white38, width: 1),
                boxShadow: on
                    ? const [BoxShadow(color: Color(0x88caa24e), blurRadius: 6)]
                    : null,
              ),
              child: Icon(Icons.play_arrow,
                  size: badge * 0.8, color: on ? Colors.black : Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}

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
            child: InteractiveViewer(
              transformationController: _zoom,
              minScale: _minScale,
              maxScale: _maxScale,
              panEnabled: _zoomedIn,
              // The wheel is handled above, under a modifier. Leaving the
              // viewer's own scale gesture on would also bind a bare trackpad
              // pinch, which is the accident this build avoids.
              scaleEnabled: false,
              child: canvas,
            ),
          ),
        ),
      ),
    );
  }

  /// The zoom controls. Only built on desktop;
  /// on touch, pinch is the natural gesture and the buttons would only cover
  /// the table. Reset is only offered once there is something to reset.
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

    return DecoratedBox(
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
              _scale > _minScale + 0.001 ? () => _zoomBy(1 / _zoomStep) : null,
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
    );
  }

  /// The zoom controls, bottom-right over the letterbox bar. Desktop only.
  Widget _corner() => _FixedCanvas._deliberateZoom
      ? Positioned(right: 6, bottom: 6, child: _zoomControls())
      : const SizedBox.shrink();

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
        child: Stack(
          children: [
            Positioned.fill(
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
            _corner(),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen toggle, shown on the welcome screen. Web only, and hidden once
/// the app is installed (there is no browser chrome left to hide). Where the
/// browser has no fullscreen API (iPhone Safari) it explains how to install
/// the app instead.
class _FullscreenButton extends StatefulWidget {
  const _FullscreenButton();

  @override
  State<_FullscreenButton> createState() => _FullscreenButtonState();
}

class _FullscreenButtonState extends State<_FullscreenButton> {
  void Function()? _unlisten;

  @override
  void initState() {
    super.initState();
    _unlisten = fs.listenFullscreenChange(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _unlisten?.call();
    super.dispose();
  }

  void _showInstallHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Install TileSense'),
        content: const Text(
          "This browser can't go full screen from a web page. Install "
          'TileSense as a web app instead and it opens full screen, with no '
          'browser bars:\n\n'
          '• iPhone / iPad: tap Share, then "Add to Home Screen"\n'
          '• Chrome / Edge: use the install icon in the address bar, or '
          'menu > "Install app"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!fs.fullscreenButtonVisible) return const SizedBox.shrink();
    final full = fs.isFullscreen;
    return Tooltip(
      message: full
          ? 'Exit full screen'
          : 'Full screen. For the best experience, install TileSense as a '
              'web app (browser menu > Install / Add to Home Screen).',
      child: TextButton.icon(
        key: const Key('fullscreen'),
        icon: Icon(full ? Icons.fullscreen_exit : Icons.fullscreen, size: 22),
        label: Text(full ? 'Exit full screen' : 'Full screen'),
        onPressed: fs.canFullscreen ? fs.toggleFullscreen : _showInstallHelp,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xff80cbc4),
          textStyle: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}

/// "Update" button, shown on the welcome screen. Web only. An installed or
/// home-screen app has no reload control and nothing in the bundle is
/// content-hashed, so this is how a player picks up a new deploy: it asks the
/// server which build it has, then reloads with every cache dropped. Only on
/// the welcome screen, so a reload never lands mid-match.
class _UpdateButton extends StatefulWidget {
  const _UpdateButton();

  @override
  State<_UpdateButton> createState() => _UpdateButtonState();
}

class _UpdateButtonState extends State<_UpdateButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    setState(() => _busy = true);
    final status = await upd.checkForUpdate();
    if (!mounted) return;
    setState(() => _busy = false);
    final (title, body, action) = switch (status) {
      upd.UpdateStatus.updateAvailable => (
          'Update available',
          'A newer version of TileSense is ready. Update now to get it.',
          'Update now',
        ),
      upd.UpdateStatus.upToDate => (
          "You're up to date",
          'This is the latest version. Refresh anyway to re-download every '
              'file.',
          'Refresh anyway',
        ),
      upd.UpdateStatus.unknown => (
          'Refresh TileSense',
          "Couldn't tell whether a newer version exists. Refresh to "
              'download the latest files.',
          'Refresh',
        ),
    };
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            key: const Key('updateConfirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _busy = true);
    await upd.applyUpdate();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!upd.updateButtonVisible) return const SizedBox.shrink();
    return Tooltip(
      message: 'Check for a newer version and refresh the app',
      child: TextButton.icon(
        key: const Key('updateApp'),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh, size: 22),
        label: Text(_busy ? 'Working…' : 'Update'),
        onPressed: _busy ? null : _onPressed,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xff80cbc4),
          textStyle: const TextStyle(fontSize: 15),
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
  const GamePage({super.key, this.createGame});

  /// Allows startup tests to observe when the first real game is created.
  final GameController Function(Ruleset, List<Character>, int, bool)?
      createGame;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  GameController? _controller;
  GameController get _game => _controller!;
  Ruleset _selectedRuleset = Ruleset.riichi;
  final List<Character> _characters = List.of(kSeatCharacters);
  int _startingDealer = 0;
  bool _hanchan = true;
  int _minimumFaan = HongKongRules.defaultMinimumFaan;
  int _minimumPoints = TaiwaneseRules.defaultMinimumPoints;
  bool _startingGame = false;
  bool _startFailed = false;
  int _startRequest = 0;
  // Off by default so a new player sees the plain table first; the TileSensor
  // button beside the hand turns it on.
  bool _showGuide = false;
  // Shown once per app load, ahead of the table; the Start button hides it
  // for the rest of the session.
  bool _showWelcome = true;

  // The Custom Hand & Context Builder, reached from the welcome screen. It
  // owns its own controller and never touches [_game], so a game in progress
  // is still here when you come back.
  bool _showBuilder = false;

  // Who sits where in the builder, drawn afresh each time it opens: it has no
  // character-select step of its own.
  List<Character> _builderCharacters = randomSeatCharacters();
  Wind _builderWind = Wind.east;

  // The character-select screen between the welcome screen and the offline
  // table.
  bool _choosingCharacters = false;

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
    onHide: () => _controller?.flushTelemetry(),
    onDetach: () => _controller?.flushTelemetry(),
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
    _controller?.dispose();
    super.dispose();
  }

  // Esc toggles pause and Ctrl/Cmd+Z takes back your last move (handled here
  // because on web widget shortcuts miss the canvas).
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    if (_showWelcome || _showBuilder || _showOnline || _startingGame) {
      return false;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _controller?.togglePause();
      return true;
    }
    final keys = HardwareKeyboard.instance;
    if (e.logicalKey == LogicalKeyboardKey.keyZ &&
        (keys.isControlPressed || keys.isMetaPressed) &&
        (_controller?.canUndo ?? false)) {
      _controller!.undo();
      return true;
    }
    return false;
  }

  /// ", 3-tai minimum" for the ruleset label's tooltip; empty under riichi.
  String _minimumSentence() => _game.ruleset.isHongKong
      ? ', ${_game.minimumFaan}-faan minimum'
      : _game.ruleset.isTaiwanese
          ? ', ${_game.minimumPoints}-tai minimum'
          : '';

  /// "3 tai min" beside the ruleset label, only when the table's minimum
  /// isn't its ruleset's default.
  String? _minimumTag() => _game.ruleset.isHongKong &&
          _game.minimumFaan != HongKongRules.defaultMinimumFaan
      ? '${_game.minimumFaan} faan min'
      : _game.ruleset.isTaiwanese &&
              _game.minimumPoints != TaiwaneseRules.defaultMinimumPoints
          ? '${_game.minimumPoints} tai min'
          : null;

  void _toggleGuide() => setState(() => _showGuide = !_showGuide);

  /// New game sits beside pause, an easy mis-tap on a phone, and throws away
  /// the game in progress — so a game that is still being played asks first.
  /// One that has already ended starts straight away.
  Future<void> _confirmNewGame() async {
    if (_game.phase == GamePhase.gameEnd) {
      _game.newGame();
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new game?'),
        content: const Text('The game in progress will be lost.'),
        actions: [
          TextButton(
            key: const Key('newGameCancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            key: const Key('newGameConfirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New game'),
          ),
        ],
      ),
    );
    if (go ?? false) _game.newGame();
  }

  // Leaving a game in progress for the welcome screen — the only way there to
  // reach the Custom Hand & Context Builder — pauses it so bots and autoplay
  // don't keep running unattended; Start un-pauses it again on the way back.
  void _backToMenu() {
    if (!_game.paused) _game.togglePause();
    setState(() {
      _selectedRuleset = _game.ruleset;
      _characters.setAll(0, _game.seatCharacters);
      _startingDealer = _game.startingDealer;
      _hanchan = _game.hanchan;
      _minimumFaan = _game.minimumFaan;
      _minimumPoints = _game.minimumPoints;
      _showWelcome = true;
    });
  }

  Future<void> _startOffline() async {
    final request = ++_startRequest;
    setState(() {
      _startingGame = true;
      _startFailed = false;
    });
    if (Sfx.i.enabled) unawaited(Sfx.i.preload(characters: _characters));
    // Give the loading screen a frame before dealing and analysing a hand.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || request != _startRequest) return;
    try {
      if (_controller == null) {
        _controller = widget.createGame?.call(
                _selectedRuleset, _characters, _startingDealer, _hanchan) ??
            GameController(
              ruleset: _selectedRuleset,
              seatCharacters: _characters,
              startingDealer: _startingDealer,
              hanchan: _hanchan,
              minimumFaan: _minimumFaan,
              minimumPoints: _minimumPoints,
            );
        _game.setMinimumFaan(_minimumFaan);
        _game.setMinimumPoints(_minimumPoints);
      } else {
        _game.setRuleset(_selectedRuleset);
        _game.setHanchan(_hanchan);
        _game.setMinimumFaan(_minimumFaan);
        _game.setMinimumPoints(_minimumPoints);
        _game.setStartingDealer(_startingDealer);
        for (var seat = 0; seat < _characters.length; seat++) {
          _game.setSeatCharacter(seat, _characters[seat]);
        }
        if (_game.paused) _game.togglePause();
      }
      setState(() {
        _startingGame = false;
        _choosingCharacters = false;
        _showWelcome = false;
      });
    } catch (_) {
      setState(() => _startFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startingGame) {
      return StartupScreen(
        label: 'Preparing your table…',
        onRetry: _startFailed ? _startOffline : null,
        onBack: () => setState(() {
          _startRequest++;
          _startingGame = false;
        }),
      );
    }
    if (_showBuilder) {
      return FeatureLoader(
        key: const Key('builderLoader'),
        load: scenario.loadLibrary,
        label: 'Loading hand builder…',
        onBack: () => setState(() => _showBuilder = false),
        builder: (_) => scenario.ScenarioPage(
          initialRuleset: _selectedRuleset,
          seatCharacters: _builderCharacters,
          seatWind: _builderWind,
          onExit: () => setState(() => _showBuilder = false),
        ),
      );
    }
    if (_showOnline) {
      void exitOnline() => setState(() {
            _showOnline = false;
            _joinCode = null;
            _showWelcome = true;
          });
      return FeatureLoader(
        key: const Key('onlineLoader'),
        load: online.loadLibrary,
        label: 'Loading multiplayer…',
        onBack: exitOnline,
        builder: (_) => online.OnlinePage(
          initialRuleset: _selectedRuleset,
          initialJoinCode: _joinCode,
          onExit: exitOnline,
        ),
      );
    }
    if (_showWelcome) {
      if (_choosingCharacters) {
        return CharacterSelectPage(
          seatCharacters: _characters,
          onSeatCharacter: (seat, c) => setState(() => _characters[seat] = c),
          startingDealer: _startingDealer,
          onStartingDealer: (seat) => setState(() => _startingDealer = seat),
          onRandomize: () => setState(() {
            _characters.setAll(0, randomSeatCharacters());
            _startingDealer = randomStartingDealer();
          }),
          advanceLabel: 'Start',
          ruleset: _selectedRuleset,
          onRuleset: (r) => setState(() => _selectedRuleset = r),
          soundOn: Sfx.i.enabled,
          onSoundOn: (on) => setState(() {
            Sfx.i.enabled = on;
            if (on) Sfx.i.unlock();
          }),
          hanchan: _hanchan,
          onHanchan: (h) => setState(() => _hanchan = h),
          minimumFaan: _minimumFaan,
          onMinimumFaan: (n) => setState(() => _minimumFaan = n),
          minimumPoints: _minimumPoints,
          onMinimumPoints: (n) => setState(() => _minimumPoints = n),
          onBack: () => setState(() => _choosingCharacters = false),
          onAdvance: _startOffline,
        );
      }
      return _WelcomeScreen(
        ruleset: _selectedRuleset,
        onRuleset: (r) => setState(() => _selectedRuleset = r),
        onStart: () => setState(() => _choosingCharacters = true),
        onBuild: () => setState(() {
          _builderCharacters = randomSeatCharacters();
          _builderWind = Wind.values[randomStartingDealer()];
          _showBuilder = true;
        }),
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
          tooltip: 'Main menu — pauses this game; Start resumes it. Change '
              'the style there (a new game), or open the Custom Hand & '
              'Context Builder',
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToMenu,
        ),
        title: Row(
          children: [
            // No TileSensor up here: the guide toggle is the big one beside
            // your hand, and the TileSensor in this bar is Auto-Play's — one
            // mascot button per bar, so neither reads as the other.
            const Text('TileSense'),
            const SizedBox(width: 16),
            // Which rules the table plays — a label, not a switch: the style
            // is fixed for the game once it is under way. It is chosen on the
            // welcome and character screens, reached with the back arrow.
            AnimatedBuilder(
              animation: _game,
              builder: (context, _) => Tooltip(
                message: 'Playing ${_game.ruleset.label} rules'
                    '${_minimumSentence()}.\n'
                    'To play another style, go back to the main menu.',
                child: Padding(
                  key: const Key('ruleset'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    switch (_minimumTag()) {
                      final tag? => '${_game.ruleset.flagLabel} · $tag',
                      null => _game.ruleset.flagLabel,
                    },
                    style: const TextStyle(
                      color: Color(0xffffdf76),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
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
                final caveat = _game.ruleset.isChineseStyle
                    ? _handCountCaveatChineseStyle
                    : _handCountCaveat;
                return Tooltip(
                  message: _game.hanchan
                      ? 'Hanchan — East and South (半庄) rounds, 8+ hands.\n'
                          '$caveat\n'
                          'Tap for East only (东风战), 4+ hands.'
                      : (_game.ruleset.isChineseStyle
                          ? 'East only — the East round, 4+ hands.\n'
                              '$caveat\n'
                              'Tap for hanchan (半庄): East and South (半庄), 8+ hands.'
                          : 'East only (东风战/tonpuusen) — the East round, 4+ hands.\n'
                              '$caveat\n'
                              'Tap for hanchan (半庄): East and South (半庄), 8+ hands.'),
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
            // Round, wall and honba/riichi (or dealer repeat) on one line,
            // centred in whatever the controls either side leave free. The
            // style is already named just left of here, so not again.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _game,
                    builder: (context, _) => TableStatusLine(game: _game),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Auto-Play and the three guide dials in one panel: Auto-Play
          // plays from the guide's own scores, so these dials are what it
          // plays by. The panel's border lights up gold while it is on, which
          // is the cue that the dials are now steering your seat, not just
          // the advice. The guide panel carries a synced copy of each dial.
          //
          // All three dials are kept rather than pruned to the ones that
          // move the numbers most: a decision-level sweep (self-play,
          // live-riichi threat included for Style, since its whole effect is
          // gated behind one) found every dial changes the top
          // recommendation on a comparable, non-trivial share of decisions —
          // Style 0.6-1.3% of discards and dozens of riichi/damaten calls
          // under a live threat, Focus 0.6% of discards and a ~50% median
          // swing in the EV number itself, Strategy 0.2% of discards and over
          // a hundred riichi/damaten calls in a placement-sensitive sample.
          // None of the three is a null next to the others.
          AnimatedBuilder(
            animation: _game,
            builder: (context, _) {
              final on = _game.autoplay;
              final dials = <Widget>[
                // Style has nothing left to weigh under Hong Kong or
                // Taiwanese rules — no riichi, no damaten, and the sweep in
                // policy_sweep_test.dart found no placement effect from it
                // either — so it is hidden rather than shown pinned on
                // Balanced.
                if (!_game.ruleset.isChineseStyle)
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
                // Placement isn't wired up for Hong Kong or Taiwanese yet, so
                // the dial is hidden there rather than shown pinned on
                // Points — same treatment as Style just above.
                if (!_game.ruleset.isChineseStyle)
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
              ];
              return AnimatedContainer(
                key: const Key('autoplayGroup'),
                duration: const Duration(milliseconds: 200),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0x14ffffff),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: on ? _autoPlayGold : const Color(0x33ffffff),
                    width: on ? 1.5 : 1,
                  ),
                  boxShadow: on
                      ? const [
                          BoxShadow(color: Color(0x44caa24e), blurRadius: 8)
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _barTile(
                      caption: 'AUTO-PLAY',
                      tapKey: const Key('autoplay'),
                      width: 92,
                      tooltip: on
                          ? 'Auto-Play is on — TileSensor plays your seat by '
                              'the guide, using the dials beside it.\n'
                              'Tap to take your seat back.'
                          : 'Auto-Play is off — you play your seat.\n'
                              'Tap to let TileSensor play it by the guide, '
                              'using the dials beside it.',
                      onTap: () => _game.setAutoplay(!on),
                      value: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AutoPlayBadge(on: on, size: 22),
                          const SizedBox(width: 5),
                          Text(on ? 'On' : 'Off',
                              style: TextStyle(
                                  color: on ? _autoPlayGold : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    for (final dial in dials) ...[_barDivider(), dial],
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 20),
          // The game's own controls, together at the edge: sound, pause and
          // a new game. Plus-in-a-circle for the new game rather than a
          // circular arrow, which reads as "go back" — and would be mistaken
          // for the take-back button over your hand.
          AnimatedBuilder(
            animation: _game,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _barTile(
                  caption: 'SOUND',
                  tapKey: const Key('soundToggle'),
                  width: 56,
                  tooltip: _game.soundOn
                      ? 'Sound on — tap to mute'
                      : 'Sound off — tap to unmute',
                  onTap: () => _game.setSoundOn(!_game.soundOn),
                  value: Icon(
                    _game.soundOn ? Icons.volume_up : Icons.volume_off,
                    size: 22,
                    color: _game.soundOn
                        ? const Color(0xffe9d58f)
                        : Colors.white38,
                  ),
                ),
                const SizedBox(width: 8),
                _barTile(
                  caption: _game.paused ? 'RESUME' : 'PAUSE',
                  width: 56,
                  tooltip: _game.paused ? 'Resume' : 'Pause',
                  onTap: _game.togglePause,
                  value: Icon(_game.paused ? Icons.play_arrow : Icons.pause,
                      size: 22, color: const Color(0xffe9d58f)),
                ),
                const SizedBox(width: 8),
                _barTile(
                  caption: 'NEW',
                  tapKey: const Key('newGame'),
                  width: 56,
                  tooltip: 'New game',
                  onTap: _confirmNewGame,
                  value: const Icon(Icons.add_circle_outline,
                      size: 22, color: Color(0xffe9d58f)),
                ),
              ],
            ),
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
                    Expanded(
                        child: TableView(
                            game: _game, autoplaying: _game.autoplay)),
                    HandView(
                      game: _game,
                      showGuide: _showGuide,
                      onToggleGuide: _toggleGuide,
                    ),
                  ],
                ),
                // The guide runs from the table's top-left corner down to just
                // above the hand's tile row — so it grows with the window
                // instead of stopping at a fixed cut-off, while never covering
                // a tile you might want to discard.
                if (_showGuide)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        children: [
                          Positioned(
                            left: 8,
                            top: TableView.guidePanelTop,
                            child: EfficiencyOverlay(
                              game: _game,
                              report: _game.report,
                              maxHeight: c.maxHeight -
                                  TableView.guidePanelTop -
                                  HandView.tileRowBandHeight -
                                  8,
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

/// First thing shown on app load: the TileSensor mascot, the app name, a short
/// explanation of what TileSense does, and a Start button into the table.
class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({
    required this.ruleset,
    required this.onRuleset,
    required this.onStart,
    required this.onBuild,
    required this.onPlayOnline,
  });

  /// The rules Start and the builder will use, and how to change them.
  final Ruleset ruleset;
  final ValueChanged<Ruleset> onRuleset;

  final VoidCallback onStart;

  /// Opens the Custom Hand & Context Builder — a posed table, scored by the
  /// same guide, with no game running behind it.
  final VoidCallback onBuild;

  /// Opens the online lobby — create a private room or join one by code.
  final VoidCallback onPlayOnline;

  /// Japanese Riichi, Hong Kong, or Taiwanese, chosen before Start, each
  /// with a link to its rules PDF beneath it.
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
        option(Ruleset.hongKong, 'faan, flowers, 0–3 faan minimum'),
        option(Ruleset.taiwanese, '17 tiles, flowers, 1–5 tai minimum'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Material ancestor: without one, Text on web can render with a stray
    // underline decoration (every other screen gets this for free via
    // Scaffold's own Material).
    return Material(
      color: kLetterboxColor,
      // Scrollable rather than fixed: this screen can be taller than the
      // design canvas leaves room for at some window sizes.
      child: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TileSensorTooltip(
                  child: Image.asset(
                    kTileSensorAsset,
                    height: 140,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
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
                // Two balanced lines, broken by hand rather than by the
                // wrapper. Left to itself at a snug width a line can land
                // within a pixel of the limit, so any browser whose default
                // face runs a hair wider than Roboto spills it onto a third.
                // The box is well wider than the longest line needs ("Sharpen
                // your Taiwanese Mahjong decisions", ~450px in Roboto), which
                // keeps these two lines two lines. Re-balance the breaks if
                // the text changes.
                SizedBox(
                  width: 840,
                  child: Text(
                    'Sharpen your ${ruleset.label} Mahjong decisions\n'
                    'with a guide that sees only what you see.',
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
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [_FullscreenButton(), _UpdateButton()],
                ),
                const SizedBox(height: 10),
                // Scales down rather than overflowing if a wide default font
                // pushes the three buttons past the canvas width.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: onStart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffcaa24e),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // The mascot that toggles the guide at the table,
                            // as the button's icon: the guide comes with
                            // offline play.
                            Image.asset(
                              kTileSensorAsset,
                              key: const Key('startGuideMascot'),
                              height: 36,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 8),
                            const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Single Player',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 2),
                                Text(
                                  'Includes the guide',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                              ],
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
                              horizontal: 12, vertical: 12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // A globe: play with anyone, anywhere.
                            Text('🌐',
                                key: Key('playOnlineEmoji'),
                                style: TextStyle(fontSize: 28)),
                            SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Play Online',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 2),
                                Text(
                                  'With friends — bots fill empty seats, no guide',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white60),
                                ),
                              ],
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
                              horizontal: 12, vertical: 12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tools: you build the table yourself. An icon,
                            // not the 🛠️ emoji: its U+FE0F has no Noto font,
                            // so Flutter web logs a missing-font warning.
                            Icon(Icons.handyman,
                                key: Key('openBuilderEmoji'), size: 28),
                            SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Custom Hand & Context Builder',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 2),
                                Text(
                                  'Pose any table and have TileSense score it',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white60),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
