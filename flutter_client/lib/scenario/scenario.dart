/// The editable table state behind the Custom Hand & Context Builder.
///
/// This is a *posed* table, not a played one: there is no wall to draw from and
/// no turn order to advance. It holds exactly what the TileSense guide reads —
/// your concealed tiles and melds, every seat's discards and calls, the dora
/// indicators, the wall counter, and who is in riichi — and nothing else.
/// Under Hong Kong rules the dora and riichi give way to each seat's flowers.
library;

import '../game/game_controller.dart' show kHumanSeat;
import '../logic/efficiency_engine.dart'
    show
        HandFocus,
        PlayStyle,
        Strategy,
        kDefaultHandFocus,
        kDefaultPlayStyle,
        kDefaultStrategy;
import 'package:mahjong_core/hong_kong/hong_kong_rules.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/taiwanese/taiwanese_rules.dart';
import 'package:mahjong_core/tile.dart';

/// The most tiles of one type that can exist, and the most red fives per suit.
const int kCopiesPerTile = 4;

/// One seat of a posed table. For opponents only what is *visible* matters —
/// their discards and their called melds — since the guide never sees a
/// concealed hand it does not own.
class ScenarioSeat {
  ScenarioSeat(this.seat);

  final int seat;
  final List<Tile> pond = [];
  final List<Meld> melds = [];

  /// Hong Kong: flowers and seasons this seat has exposed.
  final List<Tile> flowers = [];

  bool riichi = false;

  /// Index into [pond] of the sideways declaration tile. -1 while not in
  /// riichi. Declaring with an empty pond is not possible, so a riichi seat
  /// always has at least one discard.
  int riichiPondIndex = -1;

  void clear() {
    pond.clear();
    melds.clear();
    flowers.clear();
    riichi = false;
    riichiPondIndex = -1;
  }
}

/// Where the tile palette puts the next tile you tap.
enum EditTarget { hand, pond, melds, dora }

/// How the builder names each seat, by index: by where it sits, since the
/// builder has no characters.
const List<String> kScenarioSeatNames = ['You', 'Right', 'Across', 'Left'];

class Scenario {
  /// Which game the posed table follows. Change it through
  /// [ScenarioController.setRuleset], which also clears the table.
  Ruleset ruleset = Ruleset.riichi;

  final List<ScenarioSeat> seats = List.generate(4, (i) => ScenarioSeat(i));

  /// Your concealed tiles (seat 0). Melds are held on [seats]`[0].melds`.
  final List<Tile> hand = [];

  /// Revealed dora indicators — the *indicator*, not the dora itself, exactly
  /// as the dead wall shows them.
  final List<TileType> dora = [TileType.man1];

  /// How the guide weighs danger against value when scoring this table.
  PlayStyle style = kDefaultPlayStyle;

  /// Whether the guide chases the faster hand or the bigger one here.
  HandFocus focus = kDefaultHandFocus;

  /// Points or placement. The builder has no score inputs for the other three
  /// seats, so this stays Points here — there is nothing for Placement to
  /// weigh without them. Carried for [ScenarioController]'s [GuideHost]
  /// implementation, not exposed as a toolbar toggle.
  Strategy strategy = kDefaultStrategy;

  int wallRemaining = 70;
  Wind roundWind = Wind.east;

  /// Which seat holds the dealership. Rather than set this directly, set
  /// [seatWind] — where the button sits is what fixes everyone's wind, and
  /// being East is what makes you the dealer.
  int dealer = 0;
  int honba = 0;
  int riichiSticks = 0;

  /// Hong Kong's minimum faan and Taiwanese's minimum tai for a win — one of
  /// [HongKongRules.minimumFaanChoices] and
  /// [TaiwaneseRules.minimumPointsChoices]. Settings, like the winds: [clear]
  /// keeps them.
  int minimumFaan = HongKongRules.defaultMinimumFaan;
  int minimumPoints = TaiwaneseRules.defaultMinimumPoints;

  /// The tile on offer for a call, for the 13-tile "should I call?" read.
  /// Null in the 14-tile discard read.
  Tile? offered;
  int offeredFrom = 1;

  /// Your own seat wind. It decides your seat's yakuhai, and — when it is East
  /// — that you are the dealer, worth half again on a win and more to deal
  /// into. [Round.posed] derives every seat's wind from [dealer], so this is
  /// the same setting read from the other end.
  Wind get seatWind => Wind.values[(4 - dealer) % 4];
  set seatWind(Wind wind) => dealer = (4 - wind.index) % 4;

  bool get isDealer => dealer == kHumanSeat;

  int _nextId = 0;
  Tile mint(TileType type, {bool aka = false}) =>
      Tile(_nextId++, type, aka: aka);

  // --- counting and validity ------------------------------------------

  /// Every tile the posed table shows: your concealed hand, all four ponds,
  /// all called melds, the dora indicators, and the tile on offer. A meld's
  /// tiles are counted from its [Meld.types] so a hand-built meld with no
  /// physical tiles still counts.
  List<int> visibleCounts34() {
    final counts = List<int>.filled(34, 0);
    void bump(TileType t) {
      if (!t.isPlayingTile) return;
      counts[t.index - 1]++;
    }

    for (final t in hand) {
      bump(t.type);
    }
    for (final s in seats) {
      for (final t in s.pond) {
        bump(t.type);
      }
      for (final m in s.melds) {
        for (final t in m.types) {
          bump(t);
        }
      }
    }
    for (final t in dora) {
      bump(t);
    }
    if (offered != null) bump(offered!.type);
    return counts;
  }

  int used(TileType type) => type.isBonus
      ? seats.expand((s) => s.flowers).where((t) => t.type == type).length
      : type == TileType.blank
          ? 0
          : visibleCounts34()[type.index - 1];

  /// How many more copies of [type] the table can still hold. Each flower and
  /// season exists once.
  int remainingCopies(TileType type) =>
      (type.isBonus ? 1 : kCopiesPerTile) - used(type);

  /// Red fives already placed in [type]'s suit — at most one exists per suit.
  bool akaUsed(TileType type) {
    bool isAka(Tile t) => t.aka && t.type == type;
    if (hand.any(isAka)) return true;
    for (final s in seats) {
      if (s.pond.any(isAka)) return true;
      if (s.melds.any((m) => m.tiles.any(isAka))) return true;
    }
    return offered != null && isAka(offered!);
  }

  /// Concealed tiles the hand should hold: 13 (or 14 with a draw) — 16 (or
  /// 17) for Taiwanese — less three for every call. A kan still eats only one
  /// meld slot's worth of three.
  int concealedTarget({required bool withDraw}) =>
      ruleset.concealedHandSize +
      (withDraw ? 1 : 0) -
      seats[0].melds.length * 3;

  /// The turn a seat's nth discard was made on, counted from the dealer's
  /// first turn. A posed table has no global discard clock, so this is the
  /// ordering the builder assumes: seats discard in turn order and nothing was
  /// called away. It is the same reading a player takes off a real table.
  int turnOf(int seat, int pondIndex) =>
      pondIndex * 4 + ((seat - dealer + 4) % 4);

  /// Other seats' discards that cleared the ron window after [seat] declared
  /// riichi — the second half of genbutsu, alongside the riichi seat's own
  /// pond.
  Set<TileType> passedAfterRiichi(int seat) {
    final s = seats[seat];
    if (!s.riichi || s.riichiPondIndex < 0) return const {};
    final declaredOn = turnOf(seat, s.riichiPondIndex);
    return {
      for (final other in seats)
        if (other.seat != seat)
          for (var i = 0; i < other.pond.length; i++)
            if (turnOf(other.seat, i) > declaredOn) other.pond[i].type,
    };
  }

  /// Every reason the posed table does not yet make sense, in the order worth
  /// fixing them. Empty means the guide can score it.
  List<String> problems() {
    final out = <String>[];
    final counts = visibleCounts34();
    final over = <String>[
      for (var i = 0; i < 34; i++)
        if (counts[i] > kCopiesPerTile) '${typeFrom34(i).code} ×${counts[i]}',
    ];
    if (over.isNotEmpty) {
      out.add(
          'More than $kCopiesPerTile copies on the table: ${over.join(', ')}');
    }

    final concealed = hand.length;
    final call = concealedTarget(withDraw: false);
    final draw = concealedTarget(withDraw: true);
    if (concealed != call && concealed != draw) {
      out.add('Your hand holds $concealed tiles — it needs $call '
          '(waiting on a call) or $draw (your turn, with a draw)'
          '${seats[0].melds.isEmpty ? '' : ', after ${seats[0].melds.length} call(s)'}.');
    }

    for (final s in seats) {
      if (s.riichi && s.pond.isEmpty) {
        out.add('${_seatWord(s.seat)} is in riichi but has no discards — '
            'riichi is declared by discarding.');
      }
      if (s.riichi && s.melds.any((m) => !m.concealed)) {
        out.add('${_seatWord(s.seat)} is in riichi with an open call — '
            'riichi needs a closed hand.');
      }
    }

    if (ruleset.isChineseStyle) {
      for (final type in TileType.values.where((t) => t.isBonus)) {
        if (used(type) > 1) out.add('Only one ${type.displayName} exists.');
      }
      if (hand.any((t) => !t.type.isPlayingTile)) {
        out.add('Flowers belong in the bonus area.');
      }
    } else if (dora.isEmpty) {
      out.add('Set at least one dora indicator.');
    }
    if (wallRemaining < 0 || wallRemaining > maxWall) {
      out.add('Wall must be between 0 and $maxWall tiles.');
    }
    return out;
  }

  bool get isValid => problems().isEmpty;

  /// The most tiles a live wall can hold once the hands are dealt.
  int get maxWall => ruleset.isChineseStyle ? 144 : 122;

  /// True when the hand is full (a drawn tile in hand: 14, or 17 for
  /// Taiwanese) and the guide
  /// should recommend a discard rather than a call.
  bool get isDiscardRead => hand.length == concealedTarget(withDraw: true);

  String _seatWord(int seat) => kScenarioSeatNames[seat];

  void clear() {
    hand.clear();
    for (final s in seats) {
      s.clear();
    }
    dora.clear();
    if (ruleset.isRiichi) dora.add(TileType.man1);
    offered = null;
    wallRemaining = ruleset.isChineseStyle ? 84 : 70;
    honba = 0;
    riichiSticks = 0;
    // Round wind, seat wind and play style are settings, not table state —
    // clearing the tiles leaves them where you put them.
  }
}
