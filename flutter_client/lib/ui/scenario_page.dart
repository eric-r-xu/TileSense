/// The Custom Hand & Context Builder: pose any table state by hand and have the
/// TileSense guide score it.
///
/// Nothing here touches the live game. The page owns its own
/// [ScenarioController], which has no bots, no turn timer and no autoplay — the
/// table is a drawing surface, and every edit re-runs the same
/// [EfficiencyEngine] the real game's guide uses.
library;

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../main.dart' show isPhoneLayout, openRules;
import 'package:mahjong_core/hong_kong/hong_kong_rules.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/taiwanese/taiwanese_rules.dart';
import 'package:mahjong_core/tile.dart';
import '../scenario/scenario.dart';
import '../scenario/scenario_controller.dart';
import 'efficiency_overlay.dart';
import 'phone_menu.dart';
import 'table_view.dart';
import 'tile_face.dart';
import 'tilesensor.dart';

/// The slot the tile palette is currently filling. [dora] is the dora
/// indicators in riichi and the selected seat's flowers in Hong Kong — the
/// same corner of the table.
enum _Slot { hand, pond, melds, dora, offer }

/// What a palette tap builds when the melds slot is selected.
enum _MeldKind { chi, pon, openKan, closedKan }

class ScenarioPage extends StatefulWidget {
  const ScenarioPage({
    super.key,
    required this.onExit,
    this.initialRuleset = Ruleset.riichi,
    this.seatWind,
  });

  /// Back to the welcome screen.
  final VoidCallback onExit;

  /// The rules the builder opens in; it can be switched from its Menu.
  final Ruleset initialRuleset;

  /// The wind you start on, from the character-select screen; East when null.
  final Wind? seatWind;

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  late final ScenarioController _c =
      ScenarioController(seatWind: widget.seatWind);

  _Slot _slot = _Slot.hand;
  int _slotSeat = kHumanSeat;
  _MeldKind _meldKind = _MeldKind.pon;
  bool _aka = false;

  /// Height of the editor band below the table: taller on a phone, whose
  /// tiles and chips are drawn big enough to tap.
  double get _editorHeight => _phone ? 336 : 214;

  /// A phone's minimum tap target in canvas pixels: 44pt at the ~0.48× a
  /// landscape iPhone draws the canvas at.
  static const double _phoneTarget = 92;

  /// The editor band's chips: at least [_phoneTarget] each way on a phone,
  /// label centred and big enough to read; as authored on a desktop.
  BoxConstraints? get _chipBox => _phone
      ? const BoxConstraints(minWidth: _phoneTarget, minHeight: _phoneTarget)
      : null;
  Alignment? get _chipAlign => _phone ? Alignment.center : null;
  double get _chipFont => _phone ? 20 : 11;

  // The tool bar is built outside the body's AnimatedBuilder, so it needs its
  // own nudge to follow controller-side edits — the guide panel's play-style
  // dial writes straight to the controller, and the tool bar's copy of that
  // dial has to move with it.
  @override
  void initState() {
    super.initState();
    _c.setRuleset(widget.initialRuleset);
    _c.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  Scenario get s => _c.scenario;
  // Named for Hong Kong, the first Chinese-style ruleset this app had, but
  // true for Taiwanese too — see [Ruleset.isChineseStyle].
  bool get _hk => s.ruleset.isChineseStyle;

  void _edit(void Function(Scenario s) change) =>
      setState(() => _c.edit(change));

  // --- palette ---------------------------------------------------------

  /// Put one tile of [type] into whatever slot is selected. Refuses anything
  /// that would put a fifth copy of a tile on the table.
  void _place(TileType type) {
    if (s.remainingCopies(type) <= 0) return;
    if (type.isBonus) {
      _edit((sc) => sc.seats[_slotSeat].flowers.add(sc.mint(type)));
      return;
    }
    if (_hk && _slot == _Slot.dora) return;
    final aka = !_hk && _aka && type.number == 5 && !s.akaUsed(type);
    _edit((sc) {
      switch (_slot) {
        case _Slot.hand:
          sc.hand.add(sc.mint(type, aka: aka));
        case _Slot.pond:
          sc.seats[_slotSeat].pond.add(sc.mint(type, aka: aka));
        case _Slot.dora:
          if (sc.dora.length < 5) sc.dora.add(type);
        case _Slot.offer:
          sc.offered = sc.mint(type, aka: aka);
        case _Slot.melds:
          _addMeld(sc, type);
      }
    });
  }

  /// Build a call from [low] in the selected seat's meld area. A chi needs the
  /// two tiles above it to still be available, so it is refused when they are
  /// not; a pon/kan needs the remaining copies.
  void _addMeld(Scenario sc, TileType low) {
    final seat = sc.seats[_slotSeat];
    switch (_meldKind) {
      case _MeldKind.chi:
        if (low.isHonor || low.number > 7) return;
        final types = [
          low,
          TileType.values[low.index + 1],
          TileType.values[low.index + 2],
        ];
        if (types.any((t) => sc.remainingCopies(t) <= 0)) return;
        seat.melds.add(Meld(
          kind: MeldKind.sequence,
          low: low,
          concealed: false,
          calledFromSeatOffset: 3,
        ));
      case _MeldKind.pon:
        if (sc.remainingCopies(low) < 3) return;
        seat.melds.add(Meld(
          kind: MeldKind.triplet,
          low: low,
          concealed: false,
          calledFromSeatOffset: 1,
        ));
      case _MeldKind.openKan:
      case _MeldKind.closedKan:
        if (sc.remainingCopies(low) < 4) return;
        seat.melds.add(Meld(
          kind: MeldKind.kan,
          low: low,
          concealed: _meldKind == _MeldKind.closedKan,
          calledFromSeatOffset: _meldKind == _MeldKind.closedKan ? null : 1,
        ));
    }
  }

  // --- randomiser ------------------------------------------------------

  /// Fill the table with a legal, reasonably lifelike scenario — a starting
  /// point to poke at rather than a puzzle worth solving.
  void _randomize() {
    _edit((sc) {
      sc.clear();
      final bag = <TileType>[
        for (var i = 0; i < 34; i++)
          for (var c = 0; c < 4; c++) typeFrom34(i),
      ]..shuffle();
      TileType take() => bag.removeLast();

      if (sc.ruleset.isRiichi) {
        sc.dora
          ..clear()
          ..add(take());
      }
      // A riichi opponent with a pond, so the safety columns have something to
      // work with; the other two seats get shorter ponds.
      for (var seat = 1; seat < 4; seat++) {
        final n = seat == 1 ? 7 : 5;
        for (var i = 0; i < n; i++) {
          sc.seats[seat].pond.add(sc.mint(take()));
        }
      }
      if (sc.ruleset.isRiichi) {
        sc.seats[1].riichi = true;
        sc.seats[1].riichiPondIndex = 4;
      }
      for (var i = 0; i < 6; i++) {
        sc.seats[0].pond.add(sc.mint(take()));
      }
      for (var i = 0; i < sc.concealedTarget(withDraw: true); i++) {
        sc.hand.add(sc.mint(take()));
      }
      sc.hand.sort((a, b) => a.type.index.compareTo(b.type.index));
      sc.wallRemaining = 30 + (bag.length % 40);
    });
  }

  /// A seat's wind letter (E/S/W/N) — the builder labels seats by wind, not
  /// by character.
  String _windOf(int seat) => _c.round.seats[seat].wind.initial;

  // --- build -----------------------------------------------------------

  /// On a phone the editor band's tiles and chips are drawn big enough to
  /// tap. The table setup lives in the Menu on every screen, phone or not.
  bool get _phone => isPhoneLayout(context);

  /// The table's editing hooks — shared by the felt and the app bar, which
  /// carries the across seat as it does in the game.
  TableEdits _tableEdits() => TableEdits(
        area: switch (_slot) {
          _Slot.pond => TableArea.pond,
          _Slot.melds => TableArea.melds,
          _Slot.dora => TableArea.dora,
          _ => null,
        },
        seat: _slotSeat,
        onSelect: (area, seat) => setState(() {
          _slot = switch (area) {
            TableArea.pond => _Slot.pond,
            TableArea.melds => _Slot.melds,
            TableArea.dora => _Slot.dora,
          };
          if (area != TableArea.dora) _slotSeat = seat;
        }),
        onRemovePondTile: (seat, i) => _edit((sc) {
          final p = sc.seats[seat].pond;
          if (i < 0 || i >= p.length) return;
          p.removeAt(i);
          final st = sc.seats[seat];
          if (st.riichiPondIndex >= p.length) {
            st.riichiPondIndex = p.length - 1;
          }
          if (p.isEmpty) {
            st.riichi = false;
            st.riichiPondIndex = -1;
          }
        }),
        onRemoveDora: (i) => _edit((sc) {
          if (sc.dora.length > 1) sc.dora.removeAt(i);
        }),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: TableView(
                      game: _c,
                      edits: _tableEdits(),
                      acrossInBar: true,
                    ),
                  ),
                  _editor(),
                ],
              ),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, c) => Stack(
                    children: [
                      Positioned(
                        left: 8,
                        top: TableView.guidePanelTop,
                        child: EfficiencyOverlay(
                          game: _c,
                          report: _c.report,
                          maxHeight: c.maxHeight -
                              TableView.guidePanelTop -
                              _editorHeight -
                              8,
                          showGameControls: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      toolbarHeight: 50,
      titleSpacing: 8,
      title: TableBarTitle(
        game: _c,
        edits: _tableEdits(),
        // No leading button, so just the titleSpacing above.
        titleStart: 8,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TileSensorTooltip(
              child: Image.asset(kTileSensorAsset,
                  height: 30,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.school, size: 30)),
            ),
            const SizedBox(width: 8),
            // Truncates on a phone, where boosted text leaves the controls
            // less room.
            const Flexible(
              child: Text('Custom Hand & Context Builder',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  /// Switching rules clears the table, so the palette goes back to your hand.
  void _setRuleset(Ruleset r) => setState(() {
        _slot = _Slot.hand;
        _slotSeat = kHumanSeat;
        _aka = false;
        _c.setRuleset(r);
      });

  // --- the menu --------------------------------------------------------

  /// The table setup, at full size, on phone and desktop alike — see
  /// [showPhoneMenu], whose parts this sheet is built from. Round and seat
  /// wind show all four winds at once rather than cycling on tap.
  void _showBuilderMenu() {
    const gold = Color(0xffe9d58f);
    const winds = [Wind.east, Wind.south, Wind.west, Wind.north];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff0c3030),
      builder: (sheet) {
        // Closes the sheet first, so the table it changed is in view.
        VoidCallback closeThen(VoidCallback action) => () {
              Navigator.pop(sheet);
              action();
            };
        return SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Menu',
                          style: TextStyle(
                              color: gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        key: const Key('builderMenuDone'),
                        onPressed: () => Navigator.pop(sheet),
                        child:
                            const Text('Done', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: phoneMenuRows([
                          [
                            phoneMenuAction(
                              key: const Key('builderMenuRandom'),
                              icon: Icons.casino,
                              label: 'Random',
                              onTap: closeThen(_randomize),
                            ),
                            phoneMenuAction(
                              key: const Key('builderMenuClear'),
                              icon: Icons.delete_outline,
                              label: 'Clear',
                              onTap:
                                  closeThen(() => _edit((sc) => sc.clear())),
                            ),
                          ],
                          [
                            phoneMenuAction(
                              key: const Key('builderMenuBack'),
                              icon: Icons.arrow_back,
                              label: 'Back to start',
                              onTap: closeThen(widget.onExit),
                            ),
                            phoneMenuAction(
                              key: const Key('builderMenuRules'),
                              icon: Icons.menu_book,
                              label: 'Rules',
                              onTap: () => openRules(s.ruleset),
                            ),
                          ],
                          [
                            _sheetStepper(
                                'Wall',
                                s.wallRemaining,
                                (v) => _edit((x) =>
                                    x.wallRemaining = v.clamp(0, x.maxWall))),
                          ],
                          if (!_hk) ...[
                            [
                              _sheetStepper('Honba', s.honba,
                                  (v) => _edit((x) => x.honba = v.clamp(0, 9))),
                            ],
                            [
                              _sheetStepper(
                                  'Sticks',
                                  s.riichiSticks,
                                  (v) => _edit(
                                      (x) => x.riichiSticks = v.clamp(0, 9))),
                            ],
                          ],
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: phoneMenuRows([
                          [
                            phoneMenuDial<Ruleset>(
                              caption: 'Rules',
                              keyPrefix: 'builderMenuRuleset',
                              values: const [
                                Ruleset.hongKong,
                                Ruleset.taiwanese,
                                Ruleset.riichi
                              ],
                              current: s.ruleset,
                              label: (r) => r.flagLabel,
                              colour: (_) => gold,
                              onPick: _setRuleset,
                            ),
                          ],
                          // The same choices the welcome screen offers.
                          if (s.ruleset == Ruleset.hongKong)
                            [
                              phoneMenuDial<int>(
                                caption: 'Min faan',
                                keyPrefix: 'builderMenuMinFaan',
                                values: HongKongRules.minimumFaanChoices,
                                current: s.minimumFaan,
                                label: (n) => '$n',
                                colour: (_) => gold,
                                onPick: (n) =>
                                    _edit((x) => x.minimumFaan = n),
                              ),
                            ],
                          if (s.ruleset == Ruleset.taiwanese)
                            [
                              phoneMenuDial<int>(
                                caption: 'Min tai',
                                keyPrefix: 'builderMenuMinTai',
                                values: TaiwaneseRules.minimumPointsChoices,
                                current: s.minimumPoints,
                                label: (n) => '$n',
                                colour: (_) => gold,
                                onPick: (n) =>
                                    _edit((x) => x.minimumPoints = n),
                              ),
                            ],
                          [
                            phoneMenuDial<Wind>(
                              caption: 'Round',
                              keyPrefix: 'builderMenuRoundWind',
                              values: winds,
                              current: s.roundWind,
                              label: (w) => w.kanji,
                              colour: (_) => gold,
                              onPick: (w) => _edit((x) => x.roundWind = w),
                            ),
                          ],
                          [
                            // East deals, so its star marks the dealer seat.
                            phoneMenuDial<Wind>(
                              caption: 'Seat',
                              keyPrefix: 'builderMenuSeatWind',
                              values: winds,
                              current: s.seatWind,
                              label: (w) =>
                                  w == Wind.east ? '${w.kanji} ★' : w.kanji,
                              colour: (_) => gold,
                              onPick: (w) => _edit((x) => x.seatWind = w),
                            ),
                          ],
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// A Wall/Honba/Sticks count with 48pt − and + either side of it.
  Widget _sheetStepper(String label, int value, void Function(int) onChange) {
    Widget step(String name, IconData icon, int to) => SizedBox(
          width: 56,
          height: 48,
          child: OutlinedButton(
            key: Key('builderMenu${label}_$name'),
            onPressed: () => onChange(to),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30),
              padding: EdgeInsets.zero,
            ),
            child: Icon(icon, size: 22),
          ),
        );
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        step('minus', Icons.remove, value - 1),
        Expanded(
          child: Text('$value',
              key: Key('builderMenu${label}Value'),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        step('plus', Icons.add, value + 1),
      ],
    );
  }

  // --- the editor band -------------------------------------------------

  Widget _editor() {
    final band = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusLine(),
        const SizedBox(height: 4),
        _slotChips(),
        const SizedBox(height: 4),
        Expanded(child: _slotContents()),
        _palette(),
      ],
    );
    return Container(
      height: _editorHeight,
      width: double.infinity,
      color: const Color(0xff052726),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Row(
        children: [
          Expanded(child: band),
          const SizedBox(width: 14),
          PhoneMenuButton(onTap: _showBuilderMenu),
          // With the band's own padding, 26 off the screen's right edge,
          // which a raised phone case can cover — as in the game.
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _statusLine() {
    final problems = s.problems();
    final blocked = _c.blockedReason;
    final (text, color) = switch ((problems.isEmpty, blocked)) {
      (false, _) => (problems.first, const Color(0xffef9a9a)),
      (true, final b?) => (b, const Color(0xffffcc80)),
      _ => (
          'Scored: ${s.isDiscardRead ? "${s.concealedTarget(withDraw: true)} tiles — discard recommendation" : "${s.concealedTarget(withDraw: false)} tiles — call recommendation"}'
              '${_c.safetyOpponentSeat != null ? " · safety vs ${_c.seatLabel(_c.safetyOpponentSeat!)}" : ""}',
          const Color(0xffa5d6a7)
        ),
    };
    return Row(
      children: [
        Icon(
            problems.isEmpty && blocked == null
                ? Icons.check_circle_outline
                : Icons.info_outline,
            size: 14,
            color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color)),
        ),
      ],
    );
  }

  Widget _slotChips() {
    Widget chip(String label, bool selected, VoidCallback onTap,
        {Color? tint, Key? key}) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: _chipBox,
            alignment: _chipAlign,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? (tint ?? const Color(0xff00695c))
                  : const Color(0xff294342),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color:
                      selected ? const Color(0xffe9d58f) : Colors.transparent),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: _chipFont,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.white60)),
          ),
        ),
      );
    }

    return SizedBox(
      height: _phone ? _phoneTarget : 26,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const VerticalDivider(width: 14, color: Colors.white24),
          chip(
              'Your hand (${s.hand.length})',
              _slot == _Slot.hand,
              () => setState(() {
                    _slot = _Slot.hand;
                    _slotSeat = kHumanSeat;
                  })),
          chip('On offer${s.offered == null ? "" : " ${s.offered!.type.code}"}',
              _slot == _Slot.offer, () => setState(() => _slot = _Slot.offer)),
          chip(
              _hk
                  ? '${_slotSeat == kHumanSeat ? 'Your' : _windOf(_slotSeat)} '
                      'flowers (${s.seats[_slotSeat].flowers.length})'
                  : 'Dora (${s.dora.length})',
              _slot == _Slot.dora,
              () => setState(() => _slot = _Slot.dora)),
          const VerticalDivider(width: 14, color: Colors.white24),
          for (var seat = 0; seat < 4; seat++) ...[
            chip(
                '${seat == kHumanSeat ? "You" : _windOf(seat)} pond '
                '(${s.seats[seat].pond.length})',
                _slot == _Slot.pond && _slotSeat == seat, () {
              setState(() {
                _slot = _Slot.pond;
                _slotSeat = seat;
              });
            }),
            chip('calls (${s.seats[seat].melds.length})',
                _slot == _Slot.melds && _slotSeat == seat, () {
              setState(() {
                _slot = _Slot.melds;
                _slotSeat = seat;
              });
            }),
            if (!_hk) _riichiToggle(seat),
            const VerticalDivider(width: 14, color: Colors.white24),
          ],
        ],
      ),
    );
  }

  Widget _riichiToggle(int seat) {
    final st = s.seats[seat];
    final canDeclare = st.pond.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: !canDeclare
            ? null
            : () => _edit((sc) {
                  final t = sc.seats[seat];
                  t.riichi = !t.riichi;
                  t.riichiPondIndex = t.riichi ? t.pond.length - 1 : -1;
                }),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: _chipBox,
          alignment: _chipAlign,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                st.riichi ? const Color(0xffb71c1c) : const Color(0xff294342),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            st.riichi ? 'RIICHI on #${st.riichiPondIndex + 1}' : 'riichi',
            style: TextStyle(
                fontSize: _chipFont,
                fontWeight: FontWeight.w700,
                color: !canDeclare
                    ? Colors.white24
                    : (st.riichi ? Colors.white : Colors.white60)),
          ),
        ),
      ),
    );
  }

  /// The selected slot's current contents — tap any tile to take it back off.
  Widget _slotContents() {
    Widget tiles(List<Tile> list, void Function(int) remove,
        {double? scale}) {
      if (list.isEmpty) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: Text('Empty — tap tiles below to add',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        );
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: InkWell(
                    onTap: () => remove(i),
                    child: TileFace(
                        tile: list[i],
                        size: TileSize.normal,
                        scale: scale ?? (_phone ? 2.0 : 1.25)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    switch (_slot) {
      case _Slot.hand:
        final sorted = [...s.hand]
          ..sort((a, b) => a.type.index.compareTo(b.type.index));
        return tiles(sorted, (i) {
          final id = sorted[i].id;
          _edit((sc) => sc.hand.removeWhere((t) => t.id == id));
        });
      case _Slot.pond:
        return tiles(s.seats[_slotSeat].pond,
            (i) => _edit((sc) => sc.seats[_slotSeat].pond.removeAt(i)));
      case _Slot.dora when _hk:
        return tiles(s.seats[_slotSeat].flowers,
            (i) => _edit((sc) => sc.seats[_slotSeat].flowers.removeAt(i)));
      case _Slot.dora:
        return tiles(
          [for (final d in s.dora) Tile(-1, d)],
          (i) => _edit((sc) {
            if (sc.dora.length > 1) sc.dora.removeAt(i);
          }),
        );
      case _Slot.offer:
        return Row(
          children: [
            if (s.offered == null)
              Text(
                  'No tile on offer. With ${s.concealedTarget(withDraw: false)} '
                  'tiles, set the tile an opponent just discarded to get a '
                  'call recommendation.',
                  style: TextStyle(color: Colors.white38, fontSize: 11))
            else ...[
              InkWell(
                onTap: () => _edit((sc) => sc.offered = null),
                child: TileFace(
                    tile: s.offered!,
                    size: TileSize.normal,
                    scale: _phone ? 2.0 : 1.25),
              ),
              const SizedBox(width: 12),
              const Text('discarded by ',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              for (var seat = 1; seat < 4; seat++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _edit((sc) => sc.offeredFrom = seat),
                    child: Container(
                      constraints: _chipBox,
                      alignment: _chipAlign,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.offeredFrom == seat
                            ? const Color(0xff00695c)
                            : const Color(0xff294342),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(_windOf(seat),
                          style: TextStyle(fontSize: _chipFont)),
                    ),
                  ),
                ),
            ],
          ],
        );
      case _Slot.melds:
        return Row(
          children: [
            for (final k in _MeldKind.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => _meldKind = k),
                  child: Container(
                    constraints: _chipBox,
                    alignment: _chipAlign,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _meldKind == k
                          ? const Color(0xff00695c)
                          : const Color(0xff294342),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      switch (k) {
                        _MeldKind.chi => s.ruleset.chiLabel,
                        _MeldKind.pon => s.ruleset.ponLabel,
                        _MeldKind.openKan => '${s.ruleset.kanLabel} (open)',
                        _MeldKind.closedKan => '${s.ruleset.kanLabel} (closed)',
                      },
                      style: TextStyle(fontSize: _chipFont),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < s.seats[_slotSeat].melds.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => _edit(
                              (sc) => sc.seats[_slotSeat].melds.removeAt(i)),
                          child: Row(
                            children: [
                              for (final t in s.seats[_slotSeat].melds[i].types)
                                TileFace(
                                    type: t,
                                    size: TileSize.small,
                                    scale: _phone ? 3.0 : 1),
                            ],
                          ),
                        ),
                      ),
                    if (s.seats[_slotSeat].melds.isEmpty)
                      const Text('tap a tile below to call it',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  /// Every tile type, with how many copies the table can still take. Tapping
  /// one puts it in the selected slot; a type with nothing left is dimmed and
  /// inert, which is what keeps the table to four copies of anything.
  Widget _palette() {
    return SizedBox(
      height: _phone ? 108 : 62,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_hk)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _aka = !_aka),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  constraints: _chipBox,
                  alignment: _chipAlign,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _aka
                        ? const Color(0xffb71c1c)
                        : const Color(0xff294342),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Red 5',
                      style: TextStyle(
                          fontSize: _chipFont,
                          fontWeight: FontWeight.w700,
                          color: _aka ? Colors.white : Colors.white54)),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Hong Kong's flower slot takes flowers and seasons only.
                  if (_hk && _slot == _Slot.dora)
                    for (final t in TileType.values.where((t) => t.isBonus))
                      _paletteTile(t)
                  else
                    for (var i = 0; i < 34; i++) _paletteTile(typeFrom34(i)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paletteTile(TileType type) {
    final left = s.remainingCopies(type);
    final enabled = left > 0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _phone ? 3 : 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.25,
            child: InkWell(
              onTap: enabled ? () => _place(type) : null,
              child: TileFace(
                  type: type,
                  size: TileSize.normal,
                  scale: _phone ? 1.9 : 1),
            ),
          ),
          Text('$left',
              style: TextStyle(
                  fontSize: _phone ? 12 : 9,
                  color: enabled ? Colors.white54 : Colors.white24)),
        ],
      ),
    );
  }
}
