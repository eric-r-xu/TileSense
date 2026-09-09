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
import '../../main.dart' show playStyleColor;
import '../logic/meld.dart';
import '../logic/tile.dart';
import '../scenario/scenario.dart';
import '../scenario/scenario_controller.dart';
import 'efficiency_overlay.dart';
import 'table_view.dart';
import 'tile_face.dart';

/// The slot the tile palette is currently filling.
enum _Slot { hand, pond, melds, dora, offer }

/// What a palette tap builds when the melds slot is selected.
enum _MeldKind { chi, pon, openKan, closedKan }

class ScenarioPage extends StatefulWidget {
  const ScenarioPage({super.key, required this.onExit});

  /// Back to the welcome screen.
  final VoidCallback onExit;

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  final ScenarioController _c = ScenarioController();

  _Slot _slot = _Slot.hand;
  int _slotSeat = kHumanSeat;
  _MeldKind _meldKind = _MeldKind.pon;
  bool _aka = false;

  /// Height of the editor band below the table.
  static const double _editorHeight = 214;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Scenario get s => _c.scenario;

  void _edit(void Function(Scenario s) change) =>
      setState(() => _c.edit(change));

  // --- palette ---------------------------------------------------------

  /// Put one tile of [type] into whatever slot is selected. Refuses anything
  /// that would put a fifth copy of a tile on the table.
  void _place(TileType type) {
    if (s.remainingCopies(type) <= 0) return;
    final aka = _aka && type.number == 5 && !s.akaUsed(type);
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

      sc.dora
        ..clear()
        ..add(take());
      // A riichi opponent with a pond, so the safety columns have something to
      // work with; the other two seats get shorter ponds.
      for (var seat = 1; seat < 4; seat++) {
        final n = seat == 1 ? 7 : 5;
        for (var i = 0; i < n; i++) {
          sc.seats[seat].pond.add(sc.mint(take()));
        }
      }
      sc.seats[1].riichi = true;
      sc.seats[1].riichiPondIndex = 4;
      for (var i = 0; i < 6; i++) {
        sc.seats[0].pond.add(sc.mint(take()));
      }
      for (var i = 0; i < 14; i++) {
        sc.hand.add(sc.mint(take()));
      }
      sc.hand.sort((a, b) => a.type.index.compareTo(b.type.index));
      sc.wallRemaining = 30 + (bag.length % 40);
    });
  }

  // --- build -----------------------------------------------------------

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
                      edits: TableEdits(
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
                      ),
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
                        top: 8,
                        child: EfficiencyOverlay(
                          game: _c,
                          report: _c.report,
                          maxHeight: c.maxHeight - _editorHeight - 16,
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
      leading: IconButton(
        tooltip: 'Back to start',
        icon: const Icon(Icons.arrow_back),
        onPressed: widget.onExit,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/clefairy.png',
              height: 30,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const Icon(Icons.school, size: 30)),
          const SizedBox(width: 8),
          const Text('Custom Hand & Context Builder',
              style: TextStyle(fontSize: 16)),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('builderPlayStyle'),
          onPressed: () => _edit((sc) => sc.style = sc.style.next),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: playStyleColor(s.style),
          ),
          child: Text(s.style.label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        _windPicker(),
        const SizedBox(width: 8),
        _stepper('Wall', s.wallRemaining,
            (v) => _edit((sc) => sc.wallRemaining = v.clamp(0, 122))),
        const SizedBox(width: 8),
        _stepper(
            'Honba', s.honba, (v) => _edit((sc) => sc.honba = v.clamp(0, 9))),
        const SizedBox(width: 8),
        _stepper('Sticks', s.riichiSticks,
            (v) => _edit((sc) => sc.riichiSticks = v.clamp(0, 9))),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: _randomize,
          icon: const Icon(Icons.casino, size: 18),
          label: const Text('Random'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xffe9d58f)),
        ),
        TextButton.icon(
          onPressed: () => _edit((sc) => sc.clear()),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Clear'),
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _windPicker() {
    const winds = [Wind.east, Wind.south, Wind.west, Wind.north];
    return TextButton(
      onPressed: () => _edit((sc) => sc.roundWind =
          winds[(winds.indexOf(sc.roundWind) + 1) % winds.length]),
      style: TextButton.styleFrom(foregroundColor: const Color(0xffe9d58f)),
      child: Text('Round ${s.roundWind.name[0].toUpperCase()}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _stepper(String label, int value, void Function(int) onChange) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        _tinyButton(Icons.remove, () => onChange(value - 1)),
        SizedBox(
          width: 26,
          child: Text('$value',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        _tinyButton(Icons.add, () => onChange(value + 1)),
      ],
    );
  }

  Widget _tinyButton(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 15, color: Colors.white70),
        ),
      );

  // --- the editor band -------------------------------------------------

  Widget _editor() {
    return Container(
      height: _editorHeight,
      width: double.infinity,
      color: const Color(0xff052726),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusLine(),
          const SizedBox(height: 4),
          _slotChips(),
          const SizedBox(height: 4),
          Expanded(child: _slotContents()),
          _palette(),
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
          'Scored: ${s.isDiscardRead ? "14 tiles — discard recommendation" : "13 tiles — call recommendation"}'
              '${_c.safetyOpponentSeat != null ? " · safety vs ${kSeatNames[_c.safetyOpponentSeat!]}" : ""}',
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
        {Color? tint}) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.white60)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 26,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(
              'Your hand (${s.hand.length})',
              _slot == _Slot.hand,
              () => setState(() {
                    _slot = _Slot.hand;
                    _slotSeat = kHumanSeat;
                  })),
          chip('On offer${s.offered == null ? "" : " ${s.offered!.type.code}"}',
              _slot == _Slot.offer, () => setState(() => _slot = _Slot.offer)),
          chip('Dora (${s.dora.length})', _slot == _Slot.dora,
              () => setState(() => _slot = _Slot.dora)),
          const VerticalDivider(width: 14, color: Colors.white24),
          for (var seat = 0; seat < 4; seat++) ...[
            chip(
                '${seat == kHumanSeat ? "You" : kSeatNames[seat]} pond '
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
            _riichiToggle(seat),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                st.riichi ? const Color(0xffb71c1c) : const Color(0xff294342),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            st.riichi ? 'RIICHI on #${st.riichiPondIndex + 1}' : 'riichi',
            style: TextStyle(
                fontSize: 11,
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
        {double scale = 1.25}) {
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
                        tile: list[i], size: TileSize.normal, scale: scale),
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
              const Text(
                  'No tile on offer. With 13 tiles, set the tile an opponent '
                  'just discarded to get a call recommendation.',
                  style: TextStyle(color: Colors.white38, fontSize: 11))
            else ...[
              InkWell(
                onTap: () => _edit((sc) => sc.offered = null),
                child: TileFace(
                    tile: s.offered!, size: TileSize.normal, scale: 1.25),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.offeredFrom == seat
                            ? const Color(0xff00695c)
                            : const Color(0xff294342),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(kSeatNames[seat],
                          style: const TextStyle(fontSize: 11)),
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
                        _MeldKind.chi => 'Chi',
                        _MeldKind.pon => 'Pon',
                        _MeldKind.openKan => 'Kan (open)',
                        _MeldKind.closedKan => 'Kan (closed)',
                      },
                      style: const TextStyle(fontSize: 11),
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
                                TileFace(type: t, size: TileSize.small),
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
      height: 62,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _aka = !_aka),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      _aka ? const Color(0xffb71c1c) : const Color(0xff294342),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Red 5',
                    style: TextStyle(
                        fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.25,
            child: InkWell(
              onTap: enabled ? () => _place(type) : null,
              child: TileFace(type: type, size: TileSize.normal),
            ),
          ),
          Text('$left',
              style: TextStyle(
                  fontSize: 9,
                  color: enabled ? Colors.white54 : Colors.white24)),
        ],
      ),
    );
  }
}
