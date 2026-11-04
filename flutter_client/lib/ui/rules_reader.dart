import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../l10n/mahjong_terms.dart';
import 'e2e_id.dart';
import 'rules_content.dart';
import 'rules_text.dart';
import 'theme.dart';
import 'tile_face.dart';

/// A reference overlay only: opening it never changes the table or its clock.
Future<void> showRulesReader(BuildContext context, Ruleset ruleset,
        {int? minimumFaan, int? minimumPoints}) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.sheet,
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 900),
          child: RulesReader(
            ruleset: ruleset,
            minimumFaan: minimumFaan,
            minimumPoints: minimumPoints,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );

class RulesReader extends StatefulWidget {
  const RulesReader({
    super.key,
    required this.ruleset,
    this.minimumFaan,
    this.minimumPoints,
    required this.onClose,
    this.openReference,
  });

  final Ruleset ruleset;
  final int? minimumFaan;
  final int? minimumPoints;
  final VoidCallback onClose;
  final Future<bool> Function(Uri)? openReference;

  @override
  State<RulesReader> createState() => _RulesReaderState();
}

class _RulesReaderState extends State<RulesReader> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  bool _referenceFailed = false;

  /// How far the text and tiles are magnified. Reflows rather than scaling
  /// the page like a picture: the words stay sharp, wrap at the dialog's
  /// width and scroll, which is what a long reference needs.
  double _zoom = _minZoom;

  /// Where two fingers are, for pinch-to-zoom on a touch screen.
  final Map<int, Offset> _fingers = {};
  double? _pinchSpan;
  double _pinchZoom = _minZoom;

  static const double _minZoom = 1;
  static const double _maxZoom = 3;

  /// One press of a button or shortcut, a ratio so it feels the same at every
  /// magnification (the table's own zoom steps by the same 1.25).
  static const double _zoomStep = 1.25;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setZoom(double value) {
    final next = value.clamp(_minZoom, _maxZoom).toDouble();
    if ((next - _zoom).abs() < 0.001) return;
    setState(() => _zoom = next);
  }

  void _zoomBy(double factor) => _setZoom(_zoom * factor);

  /// Ctrl/Cmd + wheel, as in the table. A bare scroll still scrolls the list;
  /// [_ZoomLockedPhysics] is what stops the list taking this one too.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_zoomKeyHeld()) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final scroll = e as PointerScrollEvent;
      _zoomBy(scroll.scrollDelta.dy < 0 ? _zoomStep : 1 / _zoomStep);
      scroll.respond(allowPlatformDefault: false);
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _fingers[event.pointer] = event.position;
    _restartPinch();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_fingers.containsKey(event.pointer)) return;
    _fingers[event.pointer] = event.position;
    final span = _pinchSpan;
    if (span == null || _fingers.length != 2) return;
    final points = _fingers.values.toList();
    _setZoom(_pinchZoom * (points[0] - points[1]).distance / span);
  }

  void _onPointerEnd(PointerEvent event) {
    _fingers.remove(event.pointer);
    _restartPinch();
  }

  void _restartPinch() {
    if (_fingers.length == 2) {
      final points = _fingers.values.toList();
      final span = (points[0] - points[1]).distance;
      _pinchSpan = span < 1 ? null : span;
      _pinchZoom = _zoom;
    } else {
      _pinchSpan = null;
    }
  }

  /// The zoom buttons: out, the current level, in, and back to normal. Out
  /// and reset are off at the smallest size, in at the largest.
  Widget _zoomControls(AppLocalizations l10n) {
    Widget button(IconData icon, String tip, VoidCallback? onTap, Key key) =>
        Tooltip(
          message: tip,
          child: IconButton(
            key: key,
            icon: Icon(icon, size: 22),
            onPressed: onTap,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
            padding: EdgeInsets.zero,
            color: Colors.white70,
            disabledColor: Colors.white24,
          ),
        );
    final canOut = _zoom > _minZoom + 0.001;
    final canIn = _zoom < _maxZoom - 0.001;
    return DecoratedBox(
      key: const Key('rulesZoom'),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        button(
            Icons.remove,
            l10n.zoomOut,
            canOut ? () => _zoomBy(1 / _zoomStep) : null,
            const Key('rulesZoomOut')),
        SizedBox(
          width: 46,
          child: Text('${(_zoom * 100).round()}%',
              key: const Key('rulesZoomLevel'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        button(Icons.add, l10n.zoomIn, canIn ? () => _zoomBy(_zoomStep) : null,
            const Key('rulesZoomIn')),
        button(
            Icons.crop_free,
            l10n.zoomReset,
            canOut ? () => _setZoom(_minZoom) : null,
            const Key('rulesZoomReset')),
      ]),
    );
  }

  void _filter(String value) {
    setState(() => _query = value.trim().toLowerCase());
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _openReference() async {
    var opened = false;
    try {
      final uri = Uri.parse(widget.ruleset.rulesUrl);
      opened = await (widget.openReference?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } on PlatformException {
      opened = false;
    }
    if (mounted) setState(() => _referenceFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = rulesSections(widget.ruleset,
            l10n: l10n,
            minimumFaan: widget.minimumFaan,
            minimumPoints: widget.minimumPoints)
        .map((section) => section.filtered(_query))
        .nonNulls
        .toList();
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Main-row and numpad forms, and shift held, because "+" on most
        // layouts is shift-equals; Ctrl on Windows and Linux, Cmd on a Mac.
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
          _ZoomIntent: CallbackAction<_ZoomIntent>(onInvoke: (intent) {
            final factor = intent.factor;
            factor == null ? _setZoom(_minZoom) : _zoomBy(factor);
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Listener(
            onPointerSignal: _onPointerSignal,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: _body(context, l10n, sections),
          ),
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, AppLocalizations l10n, List<RuleSection> sections) {
    return Material(
      key: const Key('rulesReader'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(l10n.rulesetName(widget.ruleset),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.goldText,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
              ),
              _zoomControls(l10n),
              const SizedBox(width: 6),
              TextButton.icon(
                key: const Key('rulesReaderClose'),
                onPressed: widget.onClose,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l10n.back),
              ),
            ]),
            e2eId(
              'rulesSearch',
              TextField(
                key: const Key('rulesSearch'),
                controller: _search,
                onChanged: _filter,
                style: const TextStyle(color: Colors.white, fontSize: 17),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.rulesSearchHint,
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('rulesSearchClear'),
                          tooltip: l10n.rulesClearSearch,
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _search.clear();
                            _filter('');
                          },
                        ),
                  enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gold)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              // Plain Text, each its own semantics node: on the web a
              // SelectableText (or a SelectionArea) is an empty text field to
              // accessibility, and plain Texts merge into one long label.
              child: MediaQuery(
                // The zoom: every Text below grows with it, and the tiles are
                // given the same factor.
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(_zoom)),
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: true,
                  child: ListView(
                    key: const Key('rulesList'),
                    controller: _scroll,
                    physics: const _ZoomLockedPhysics(),
                    padding: const EdgeInsets.only(right: 14),
                    children: [
                      Text(l10n.rulesSummaryNotice,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.4)),
                      if (sections.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(l10n.rulesNoMatch,
                              key: const Key('rulesEmpty'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 17)),
                        ),
                      for (final section in sections)
                        Padding(
                          key: Key('rule_${section.id}'),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                container: true,
                                header: true,
                                child: Text(section.title,
                                    style: const TextStyle(
                                        color: AppColors.goldText,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold)),
                              ),
                              if (section.points.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _Points(section.points),
                              ],
                              if (section.entries.isNotEmpty)
                                _CatalogueTable(section.entries,
                                    text: RulesText.of(l10n),
                                    zoom: _zoom,
                                    nameHeading: section.nameHeading,
                                    valueHeading: section.valueHeading),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_referenceFailed)
              Text(l10n.rulesReferenceFailed,
                  key: const Key('rulesReferenceError'),
                  style: const TextStyle(color: AppColors.goldText)),
            TextButton.icon(
              key: const Key('rulesExternalReference'),
              onPressed: _openReference,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.rulesLinkLabel(widget.ruleset)),
              style: TextButton.styleFrom(foregroundColor: AppColors.link),
            ),
          ],
        ),
      ),
    );
  }
}

const _bodyStyle = TextStyle(color: Colors.white, fontSize: 19, height: 1.5);

/// Whether Ctrl (or Cmd on a Mac) is down: the "deliberate act" that turns the
/// wheel into zoom, so a bare scroll never changes the size by accident.
bool _zoomKeyHeld() =>
    HardwareKeyboard.instance.isControlPressed ||
    HardwareKeyboard.instance.isMetaPressed;

/// One zoom shortcut: scale by [factor], or back to normal when it is null.
class _ZoomIntent extends Intent {
  const _ZoomIntent(this.factor);

  final double? factor;
}

/// The list's own scrolling, except while the zoom key is held: Ctrl/Cmd and
/// the wheel belong to the zoom, and the list must not also move under it.
class _ZoomLockedPhysics extends ScrollPhysics {
  const _ZoomLockedPhysics({super.parent});

  @override
  _ZoomLockedPhysics applyTo(ScrollPhysics? ancestor) =>
      _ZoomLockedPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      !_zoomKeyHeld() && super.shouldAcceptUserOffset(position);
}

/// A section's text: one point as a paragraph, several as bullets.
class _Points extends StatelessWidget {
  const _Points(this.points);

  final List<String> points;

  @override
  Widget build(BuildContext context) {
    if (points.length == 1) {
      return Semantics(
          container: true, child: Text(points.single, style: _bodyStyle));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              container: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ',
                      style:
                          TextStyle(color: AppColors.goldText, fontSize: 19)),
                  Expanded(child: Text(point, style: _bodyStyle)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A catalogue as a table: each pattern's name, its definition and a single
/// row of tiles that show it in one cell, and its value beside them. The
/// tiles are left out when no row has any (a table of minimums);
/// [nameHeading] and [valueHeading] replace the catalogue's own headings for
/// a table that is not one.
///
/// The tiles sit under the definition, not in a column of their own, so they
/// can use the table's full width: a 14-tile hand then fits one row at a size
/// that is easy to read, instead of wrapping onto two in a narrow column.
class _CatalogueTable extends StatelessWidget {
  const _CatalogueTable(this.entries,
      {required this.text,
      required this.zoom,
      this.nameHeading,
      this.valueHeading});

  final List<RuleEntry> entries;
  final RulesText text;
  final double zoom;
  final String? nameHeading;
  final String? valueHeading;

  static const _heading = TextStyle(
      color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 12, 10), child: child);
    final showExample = entries.any((e) => e.example.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      // One column: the value sits on the name's line, so everything under it
      // (the note, the tiles) has the table's whole width.
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: const TableBorder(
            horizontalInside: BorderSide(color: Colors.white12)),
        children: [
          TableRow(children: [
            cell(Row(children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  children: [
                    Text(nameHeading ?? text.nameHeading, style: _heading),
                    if (showExample) Text(text.exampleHeading, style: _heading),
                  ],
                ),
              ),
              Text(valueHeading ?? text.valueHeading, style: _heading),
            ])),
          ]),
          for (final entry in entries)
            TableRow(children: [
              cell(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(entry.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      // Values are short ("4 han (3 open)"); capped so a long
                      // one wraps rather than squeezing the name.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.4),
                        child: Text(entry.value.isEmpty ? '—' : entry.value,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: AppColors.goldText, fontSize: 18)),
                      ),
                    ],
                  ),
                  if (entry.note.isNotEmpty)
                    Text(entry.note,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16, height: 1.4)),
                  if (entry.example.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _Example(entry.example, zoom: zoom),
                    ),
                ],
              )),
            ]),
        ],
      ),
    );
  }
}

/// An example's tiles, set by set, always in one row.
///
/// At normal zoom a row too wide for its cell shrinks to fit, so nothing hides
/// off to the side; once zoomed in the tiles keep the size asked for and the
/// row scrolls sideways instead, because a magnified tile that shrank back
/// would defeat the zoom.
class _Example extends StatefulWidget {
  const _Example(this.example, {required this.zoom});

  final String example;
  final double zoom;

  /// The tiles' size before zoom, as a multiple of [TileSize.normal] (32 wide,
  /// 44 tall): large enough to tell a 4-pin from a 5-pin at a glance.
  static const double baseScale = 1.2;

  /// [TileSize.normal]'s width, the unit the row's width is measured in.
  static const double _tileWidth = 32;

  /// Space between sets, and an arrow's width beside its tiles.
  static const double _setGap = 10;
  static const double _arrow = 22;

  @override
  State<_Example> createState() => _ExampleState();
}

class _ExampleState extends State<_Example> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sets = widget.example.split(' ');
    final tileCount = [
      for (final set in sets)
        if (set != '→') exampleSet(set).length
    ].fold<int>(0, (a, b) => a + b);
    // What does not scale with the tiles: gaps between sets and the arrows.
    final fixed = (sets.length - 1) * _Example._setGap +
        sets.where((s) => s == '→').length * _Example._arrow;
    return LayoutBuilder(builder: (context, constraints) {
      var scale = _Example.baseScale * widget.zoom;
      if (widget.zoom <= 1 && constraints.maxWidth.isFinite) {
        final fit =
            (constraints.maxWidth - fixed) / (tileCount * _Example._tileWidth);
        // Never so small it stops being readable; a very narrow cell scrolls.
        scale = math.min(scale, math.max(fit, 0.6));
      }
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sets.length; i++) ...[
            if (i > 0) const SizedBox(width: _Example._setGap),
            if (sets[i] == '→')
              SizedBox(
                width: _Example._arrow,
                child: Icon(Icons.arrow_forward,
                    size: 18 * scale / _Example.baseScale,
                    color: Colors.white70),
              )
            else
              for (final tile in exampleSet(sets[i]))
                TileFace(tile: tile, size: TileSize.normal, scale: scale),
          ],
        ],
      );
      final overflows = fixed + tileCount * _Example._tileWidth * scale >
          constraints.maxWidth;
      return ScrollConfiguration(
        // A mouse can drag the row sideways as a finger does.
        behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: PointerDeviceKind.values.toSet(), scrollbars: false),
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: overflows,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // Room under the tiles for the scrollbar when there is one.
            padding: EdgeInsets.only(bottom: overflows ? 12 : 0),
            child: row,
          ),
        ),
      );
    });
  }
}
