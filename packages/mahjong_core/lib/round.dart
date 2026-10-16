/// A self-contained offline round of four-player mahjong under either
/// [Ruleset]: draws, discards, chi / pon / closed kan / added kan (with
/// chankan robbing), tsumo and ron.
///
/// Riichi adds riichi, furiten, dora, honba, riichi sticks and tenpai payments
/// at an exhaustive draw. Hong Kong adds flowers and seasons (with the seventh
/// and eighth flower wins), first-turn blessings and kong-replacement chains,
/// and ends a drawn hand with no payments.
///
/// The general engine is adapted from OpenRiichi:
/// https://github.com/FluffyStuff/OpenRiichi
library;

import 'dart:math';

import 'hand_parse.dart';
import 'hong_kong/hong_kong_rules.dart';
import 'hong_kong/hong_kong_scoring.dart';
import 'hong_kong/hong_kong_wall.dart';
import 'mcr/mcr_hand_parse.dart';
import 'mcr/mcr_scoring.dart';
import 'meld.dart';
import 'ruleset.dart';
import 'scoring.dart';
import 'sichuan/sichuan_hand_parse.dart';
import 'sichuan/sichuan_ledger.dart';
import 'sichuan/sichuan_rules.dart';
import 'sichuan/sichuan_scoring.dart';
import 'sichuan/sichuan_wall.dart';
import 'taiwanese/taiwanese_hand_parse.dart';
import 'taiwanese/taiwanese_rules.dart';
import 'taiwanese/taiwanese_scoring.dart';
import 'taiwanese/taiwanese_wall.dart';
import 'tile.dart';
import 'wall.dart';

/// [choosingVoidSuit] is Sichuan's opening step: every seat names the suit it
/// gives up before the dealer's first draw.
enum RoundPhase { drawing, discarding, callOffer, finished, choosingVoidSuit }

/// [bloodBattle] is how a Sichuan hand ends: wins do not end the hand there,
/// so the result carries every Hu and every payment line instead.
enum RoundEndKind { tsumo, ron, exhaustiveDraw, abortiveDraw, bloodBattle }

enum CallType { none, chi, pon, kan, ron }

/// How a tenpai hand falls short of the table's minimum to win — no yaku
/// (riichi), under the minimum faan (Hong Kong) or points (Taiwanese), or
/// under 8 fan (MCR). See [Round.minimumShortfall].
enum MinimumShortfall {
  /// Not tenpai, or at least one wait wins off a discard.
  none,

  /// No wait wins off a discard, but at least one wins self-drawn.
  ronOnly,

  /// No wait wins at all, discard or self-draw.
  dead,
}

class SeatState {
  SeatState(this.seat, this.wind, this.isDealer, this.points);

  final int seat;
  final Wind wind;
  bool isDealer;
  int points;

  List<Tile> hand = [];
  List<Tile> pond = [];
  List<Meld> melds = [];

  /// Hong Kong: flowers and seasons this seat has exposed.
  List<Tile> flowers = [];

  /// Hong Kong: the tile in hand came from a kong replacement draw.
  bool replacementDraw = false;

  /// Hong Kong: kongs declared in a row off their own replacement tiles, for
  /// Double Kong Replacement. Reset by every ordinary draw and discard.
  int kongChain = 0;

  /// Ordinary draws this seat has taken this hand (Blessing of Man).
  int drawCount = 0;

  bool riichi = false;
  bool doubleRiichi = false;
  bool ippatsu = false;
  int riichiPondIndex = -1;

  /// The tile drawn this turn (null once discarded).
  Tile? drawn;

  /// Tiles this seat has discarded, used for furiten. Unlike [pond] this keeps
  /// tiles that were later called away, so own-discard furiten still applies.
  final List<Tile> allDiscards = [];

  /// Other players' discards that cleared the ron window after this seat
  /// declared riichi. Kept even if subsequently called into a meld.
  final Set<TileType> passedDiscardsAfterRiichi = {};

  /// Temporary furiten: set when this seat passed up a winning tile (any
  /// player's discard that completed its wait) and cleared on this seat's next
  /// draw. While the seat is in riichi the same miss instead latches
  /// [riichiFuriten] permanently.
  bool tempFuriten = false;

  /// Permanent (riichi) furiten: once a hand in riichi passes up a winning
  /// tile it can never declare ron for the rest of the round. Never cleared.
  bool riichiFuriten = false;

  /// Sichuan: the suit (0 man, 1 pin, 2 sou) this seat gave up; null until
  /// declared. It stays hidden from the other seats until [voidRevealed].
  int? voidSuit;

  /// Sichuan: this seat has made its first discard, which shows its void suit.
  bool voidRevealed = false;

  /// Sichuan: this seat has declared Hu and no longer plays.
  bool out = false;

  /// Sichuan: when this seat went out (1 for the first Hu of the hand).
  int huOrder = 0;

  /// Sichuan: the best hand value this seat has passed up on a discard since
  /// its last turn. It may Hu a later discard only if that is worth more.
  int passedHuValue = 0;

  bool get isOpen => melds.any((m) => !(m.kind == MeldKind.kan && m.concealed));
  bool get closed => melds.every((m) => m.kind == MeldKind.kan && m.concealed);
}

class RoundResult {
  RoundResult({
    required this.kind,
    required this.winners,
    required this.pointDeltas,
    required this.label,
    this.loser,
    this.score,
    this.scores = const [],
    this.winTiles = const {},
    this.tenpaiAtDraw = const [],
    this.sichuanHu = const [],
    this.sichuanPayments = const [],
    this.nextDealer,
  });

  final RoundEndKind kind;
  final List<int> winners;
  final int? loser;

  /// The first winner's score (kept for existing callers).
  final HandScore? score;

  /// One [HandScore] per entry in [winners], in the same order — used to page
  /// through every hand on a multiple ron.
  final List<HandScore> scores;

  /// The winning tile for each winner seat.
  final Map<int, Tile> winTiles;
  final Map<int, int> pointDeltas;
  final List<int> tenpaiAtDraw;
  final String label;

  /// Sichuan: every Hu of the hand in order, and every payment line (Hu,
  /// kong, ready, penalty) behind [pointDeltas].
  final List<SichuanHu> sichuanHu;
  final List<SichuanPayment> sichuanPayments;

  /// Sichuan: the seat that deals next hand, by the Sichuan dealer rule.
  final int? nextDealer;
}

/// A pending call opportunity for one seat after a discard.
class CallOption {
  CallOption(this.seat, this.types);
  final int seat;
  final Set<CallType> types;
}

class Round {
  /// [wall] overrides the shuffled wall for [ruleset], for rule fixtures.
  /// [shuffleRng], when given, shuffles the wall instead of [seed] — the
  /// multiplayer server passes `Random.secure()` so a player can't recover
  /// the wall by brute-forcing a 31-bit seed from their own dealt tiles.
  Round({
    required int seed,
    required this.dealer,
    required this.roundWind,
    this.honba = 0,
    this.riichiSticks = 0,
    required List<int> startingPoints,
    this.ruleset = Ruleset.riichi,
    this.minimumFaan = HongKongRules.defaultMinimumFaan,
    this.minimumPoints = TaiwaneseRules.defaultMinimumPoints,
    TileWall? wall,
    Random? shuffleRng,
  })  : wall = wall ??
            (ruleset.isSichuan
                ? SichuanWall(seed, rng: shuffleRng)
                : ruleset.isTaiwanese
                    ? TaiwaneseWall(seed, rng: shuffleRng)
                    : (ruleset.isHongKong || ruleset.isMcr)
                        ? HongKongWall(seed, rng: shuffleRng)
                        : Wall(seed, rng: shuffleRng)),
        startPoints = List.of(startingPoints) {
    seats = List.generate(4, (i) {
      final wind = Wind.values[(i - dealer + 4) % 4];
      return SeatState(i, wind, i == dealer, startingPoints[i]);
    });
    final dealt = this.wall.deal();
    for (var i = 0; i < 4; i++) {
      seats[i].hand = sortByType(dealt[i]);
    }
    if (ruleset.isSichuan) {
      // Every seat names its void suit before anyone draws.
      turn = dealer;
      phase = RoundPhase.choosingVoidSuit;
      return;
    }
    _replaceDealBonuses(0);
  }

  /// Exposes and replaces any flowers dealt into the hands, dealer first, then
  /// starts the dealer's turn. A riichi wall has no flowers, so this goes
  /// straight to the first draw.
  void _replaceDealBonuses(int offset) {
    if (offset == 4) {
      turn = dealer;
      _beginDraw();
      return;
    }
    final seat = seats[(dealer + offset) % 4];
    final index = seat.hand.indexWhere((t) => t.type.isBonus);
    if (index < 0) {
      seat.hand = sortByType(seat.hand);
      _replaceDealBonuses(offset + 1);
      return;
    }
    final bonus = seat.hand.removeAt(index);
    _exposeFlower(
        seat,
        bonus,
        () => _drawFor(seat, replacement: true, onTile: (tile) {
              seat.hand.add(tile);
              _replaceDealBonuses(offset);
            }));
  }

  /// A round posed for the scenario builder: seats start empty and the caller
  /// fills in hands, ponds and melds directly. Nothing is dealt and no turn is
  /// begun, so the posed [wall] keeps exactly the count it was handed. The
  /// builder never calls [discard] or any other action on it — it exists so
  /// the real table, hand and guide widgets have a [Round] to render.
  Round.posed({
    required this.dealer,
    required this.roundWind,
    this.honba = 0,
    this.riichiSticks = 0,
    required this.wall,
    required List<int> startingPoints,
    this.ruleset = Ruleset.riichi,
    this.minimumFaan = HongKongRules.defaultMinimumFaan,
    this.minimumPoints = TaiwaneseRules.defaultMinimumPoints,
  }) : startPoints = List.of(startingPoints) {
    seats = List.generate(4, (i) {
      final wind = Wind.values[(i - dealer + 4) % 4];
      return SeatState(i, wind, i == dealer, startingPoints[i]);
    });
    turn = 0;
    // A posed Chinese-style table is mid-hand, so no first-turn blessing
    // applies.
    if (ruleset.isChineseStyle) _firstGoAround = false;
    phase = RoundPhase.discarding;
  }

  final TileWall wall;
  final Ruleset ruleset;

  /// Hong Kong only: the fewest faan a complete hand needs to be declared —
  /// one of [HongKongRules.minimumFaanChoices]. Ignored by the other rules.
  final int minimumFaan;

  /// Taiwanese only: the fewest points (tai) a complete hand needs to be
  /// declared — one of [TaiwaneseRules.minimumPointsChoices]. Ignored by the
  /// other rules.
  final int minimumPoints;
  final int dealer;
  final Wind roundWind;
  int honba;
  int riichiSticks;

  /// Each seat's points at the start of the round; the result's [pointDeltas]
  /// are measured against this so they reflect the full hand (riichi stick
  /// payments included) and always balance.
  final List<int> startPoints;

  /// The net change for each seat over the whole hand.
  Map<int, int> _handDeltas() =>
      {for (var i = 0; i < 4; i++) i: seats[i].points - startPoints[i]};

  late final List<SeatState> seats;
  int turn = 0;
  RoundPhase phase = RoundPhase.drawing;
  bool _firstGoAround = true;
  int _discardsThisRound = 0;

  RoundResult? result;
  bool get finished => phase == RoundPhase.finished;

  // Pending discard awaiting call resolution.
  Tile? pendingDiscard;
  int pendingDiscardSeat = -1;
  List<CallOption> callOptions = const [];

  /// True while [callOptions] is a chankan window (ron-only, offered on a
  /// tile being added to upgrade a pon into a kan) rather than an ordinary
  /// post-discard call offer. Distinguishes the two in [resolveCalls], since
  /// an unclaimed chankan resumes the kan instead of advancing the turn.
  bool _chankanPending = false;

  /// Whether the open call window is a chankan one (see [_chankanPending]):
  /// if nobody robs the kan, the same seat carries on rather than the next.
  bool get chankanPending => _chankanPending;

  /// The pon an added kan upgraded, held while its chankan window is open so
  /// a Hong Kong robbery can put it back.
  Meld? _pendingPung;
  int _pendingPungIndex = -1;

  SeatState get current => seats[turn];

  /// Whether [s] is frozen by a riichi declaration. Never under Hong Kong
  /// rules, whatever the seat's riichi flag says.
  bool _locked(SeatState s) => ruleset.isRiichi && s.riichi;

  /// Wait/tenpai/agari for [hand]: Taiwanese's 5-meld, 17-tile shape (plus
  /// its seven-pairs-and-a-pung alternate), or the 4-meld, 14-tile shape
  /// riichi and Hong Kong share.
  List<TileType> _waitTiles(List<Tile> hand, {required int openMelds}) =>
      ruleset.isSichuan
          ? waitTilesSichuan(hand, openMelds: openMelds)
          : ruleset.isMcr ? waitTilesMcr(hand, openMelds: openMelds) : ruleset.isTaiwanese
              ? waitTilesTaiwanese(hand, openMelds: openMelds)
              : waitTiles(hand, openMelds: openMelds);

  /// Whether [m] is a concealed kong the other seats can't see into yet —
  /// see [Ruleset.hidesConcealedKongs]. Every kong is shown once the hand
  /// has a result.
  bool isHiddenKong(Meld m) =>
      ruleset.hidesConcealedKongs && m.isKan && m.concealed && result == null;

  /// The tiles [seat]'s current hand waits on, under this round's rules.
  List<TileType> waitsFor(int seat) {
    // A Sichuan hand still holding its void suit cannot win, so it waits on
    // nothing.
    if (ruleset.isSichuan && _holdsVoid(seats[seat], seats[seat].hand)) {
      return const [];
    }
    return _waitTiles(seats[seat].hand, openMelds: seats[seat].melds.length);
  }

  bool _isTenpaiFor(List<Tile> hand, {required int openMelds}) =>
      ruleset.isSichuan
          ? isTenpaiSichuan(hand, openMelds: openMelds)
          : ruleset.isMcr ? waitTilesMcr(hand, openMelds: openMelds).isNotEmpty : ruleset.isTaiwanese
              ? isTenpaiTaiwanese(hand, openMelds: openMelds)
              : isTenpai(hand, openMelds: openMelds);

  bool _isAgari(List<int> counts34, {required int meldCount}) =>
      ruleset.isSichuan
          ? isAgariSichuan(counts34, meldCount: meldCount)
          : ruleset.isMcr ? isAgariMcr(counts34, meldCount: meldCount) : ruleset.isTaiwanese
              ? isAgariTaiwanese(counts34, meldCount: meldCount)
              : isAgari(counts34, meldCount: meldCount);

  // --- flowers (Hong Kong) -------------------------------------------------

  /// The seat paused on its seventh or eighth flower, choosing whether to
  /// claim the flower win, and what resumes the draw if it does not.
  int? _flowerSeat;
  void Function()? _flowerContinuation;

  bool canFlowerWin(int seat) => !finished && _flowerSeat == seat;

  void passFlowerWin(int seat) {
    if (!canFlowerWin(seat)) throw StateError('No flower win to pass');
    final resume = _flowerContinuation!;
    _flowerSeat = null;
    _flowerContinuation = null;
    resume();
  }

  void _exposeFlower(SeatState seat, Tile tile, void Function() resume) {
    seat.flowers.add(tile);
    // Hong Kong's own seventh flower is already an independent win; Taiwanese
    // only scores "All Flowers" at the eighth (and last) one.
    final pauseAt = ruleset.isTaiwanese ? 8 : 7;
    if (!ruleset.isMcr && seat.flowers.length >= pauseAt) {
      turn = seat.seat;
      seat.drawn = null;
      _flowerSeat = seat.seat;
      _flowerContinuation = resume;
      phase = RoundPhase.discarding;
    } else {
      resume();
    }
  }

  // --- Sichuan: void suit, ledger and bloody battle -----------------------

  /// Kongs owed a payment, settled (or cancelled) when the hand ends.
  final List<SichuanKong> _kongs = [];

  /// Each seat's latest kong, for cancelling it if the discard that follows is
  /// shot.
  final Map<int, SichuanKong> _lastKong = {};

  /// The added kong waiting out its robbery window.
  SichuanKong? _pendingAddedKong;

  /// The kong the pending discard follows, if its discarder had just made one.
  SichuanKong? _discardKong;
  bool _discardAfterKong = false;

  final List<SichuanHu> _huEvents = [];
  final List<SichuanPayment> _payments = [];
  bool _firstHuDecided = false;
  int? _nextDealer;

  /// Every Hu declared so far this hand, in order.
  List<SichuanHu> get sichuanHu => List.unmodifiable(_huEvents);

  /// Every payment line so far this hand (Hu payments immediately; the rest at
  /// the end).
  List<SichuanPayment> get sichuanPayments => List.unmodifiable(_payments);

  /// Kongs still owed a payment, with those the rules have cancelled marked.
  List<SichuanKong> get sichuanKongs => List.unmodifiable(_kongs);

  /// Seats still to name their void suit.
  bool get awaitingVoidSuit => phase == RoundPhase.choosingVoidSuit;

  bool hasDeclaredVoidSuit(int seat) => seats[seat].voidSuit != null;

  /// Whether [s] holds a tile of its void suit in [hand] or its melds. A hand
  /// that does may not win.
  bool _holdsVoid(SeatState s, List<Tile> hand) {
    final v = s.voidSuit;
    if (v == null) return false;
    return hand.any((t) => t.type.suit == v) ||
        s.melds.any((m) => m.low.suit == v);
  }

  /// Whether [seat] still holds a tile of its void suit in its hand, which it
  /// must discard before anything else.
  bool mustDiscardVoid(int seat) {
    final s = seats[seat];
    final v = s.voidSuit;
    return ruleset.isSichuan &&
        v != null &&
        s.hand.any((t) => t.type.suit == v);
  }

  /// The suit [seat] should give up: the one it holds fewest tiles of, ties
  /// going to the suit whose tiles connect least (pairs and neighbours).
  int suggestVoidSuit(int seat) {
    final counts = List<int>.filled(3, 0);
    final links = List<int>.filled(3, 0);
    final hand = seats[seat].hand;
    for (final t in hand) {
      if (!t.type.isSuit) continue;
      counts[t.type.suit]++;
      for (final o in hand) {
        if (o.id == t.id || o.type.suit != t.type.suit) continue;
        final gap = (o.type.number - t.type.number).abs();
        if (gap <= 2) links[t.type.suit] += gap == 0 ? 2 : (gap == 1 ? 2 : 1);
      }
    }
    var best = 0;
    for (var suit = 1; suit < 3; suit++) {
      if (counts[suit] < counts[best] ||
          (counts[suit] == counts[best] && links[suit] < links[best])) {
        best = suit;
      }
    }
    return best;
  }

  /// [seat] gives up [suit] (0 man, 1 pin, 2 sou). Once all four seats have, the
  /// dealer draws and play begins.
  void declareVoidSuit(int seat, int suit) {
    if (!awaitingVoidSuit) throw StateError('No void suit to declare');
    if (suit < 0 || suit > 2) throw ArgumentError('Not a suit: $suit');
    if (seats[seat].voidSuit != null) {
      throw StateError('Seat $seat has already declared');
    }
    seats[seat].voidSuit = suit;
    if (seats.every((s) => s.voidSuit != null)) {
      turn = dealer;
      _beginDraw();
    }
  }

  SichuanKong? _recordKong(int seat, SichuanKongKind kind, TileType type,
      {int? discarder, bool voided = false}) {
    if (!ruleset.isSichuan) return null;
    final payers = kind == SichuanKongKind.melded
        ? [discarder!]
        : [
            for (final o in seats)
              if (o.seat != seat && !o.out) o.seat
          ];
    final kong = SichuanKong(
      seat: seat,
      kind: kind,
      type: type,
      payers: payers,
      each: switch (kind) {
        SichuanKongKind.concealed => SichuanRules.concealedKongPayment,
        SichuanKongKind.melded => SichuanRules.meldedKongPayment,
        SichuanKongKind.added => SichuanRules.addedKongPayment,
      },
      voided: voided,
    );
    _kongs.add(kong);
    _lastKong[seat] = kong;
    return kong;
  }

  void _pay(SichuanPaymentKind kind, int from, int to, int points,
      String label) {
    seats[from].points -= points;
    seats[to].points += points;
    _payments.add(SichuanPayment(
        kind: kind, from: from, to: to, points: points, label: label));
  }

  /// Every seat that could Hu [discard] now and did not has passed it up: it
  /// may not Hu the same tile, or anything worth no more, until its own turn.
  void _registerPassedHu(Tile discard, int discarder, {bool chankan = false}) {
    for (final s in seats) {
      if (s.seat == discarder || s.out) continue;
      if (!canRon(s.seat, discard, chankan: chankan)) continue;
      final value = _score(s, s.hand, discard,
              isTsumo: false, dryRun: true, chankan: chankan)
          .points;
      if (value > s.passedHuValue) s.passedHuValue = value;
    }
  }

  /// The hand value of the best hand [seat] is ready for, or 0 if it is not
  /// ready: one tile from a legal win (void suit gone), counting a wait even
  /// when every copy is visible on the table but not when all four are in its
  /// own hand. Situational fan do not count.
  int sichuanReadyValue(int seat) {
    final s = seats[seat];
    if (!ruleset.isSichuan ||
        s.out ||
        s.hand.length % 3 != 1 ||
        _holdsVoid(s, s.hand)) {
      return 0;
    }
    final owned = [...s.hand.map((t) => t.type), ...s.melds.expand((m) => m.types)];
    var best = 0;
    for (final t in waitTilesSichuan(s.hand, openMelds: s.melds.length)) {
      if (owned.where((o) => o == t).length >= 4) continue;
      final score = scoreSichuanHand(
          s.hand,
          Tile(-1, t),
          s.melds,
          ScoreContext(
              roundWind: roundWind,
              seatWind: s.wind,
              isTsumo: false,
              closed: s.closed));
      if (score.valid && score.points > best) best = score.points;
    }
    return best;
  }

  /// A Hu by [winners] on [winTile]: a discard from [discarder] (the kong
  /// declarer, when [chankan]), or a self-draw when [discarder] is null. Hu
  /// payments move now; the winners go out; the hand carries on unless one seat
  /// is left playing.
  void _applySichuanHu(List<int> winners, Tile winTile, int? discarder,
      {bool chankan = false}) {
    final tsumo = discarder == null;
    final order = List<int>.of(winners);
    if (!tsumo) {
      order.sort((a, b) =>
          ((a - discarder + 4) % 4).compareTo((b - discarder + 4) % 4));
      // Seats that could Hu this discard and did not have passed it up.
      for (final option in callOptions) {
        if (!option.types.contains(CallType.ron) ||
            order.contains(option.seat)) {
          continue;
        }
        final s = seats[option.seat];
        final value = _score(s, s.hand, winTile,
                isTsumo: false, dryRun: true, chankan: chankan)
            .points;
        if (value > s.passedHuValue) s.passedHuValue = value;
      }
    }
    if (chankan) {
      // A robbed kong never happened: no payment for it.
      _pendingAddedKong?.voided = true;
      _pendingAddedKong = null;
    } else if (!tsumo) {
      // A Hu on the discard after a kong cancels that kong's payment.
      _discardKong?.voided = true;
    }
    final playing = [
      for (final s in seats)
        if (!s.out) s.seat
    ];
    for (final w in order) {
      final s = seats[w];
      final concealed = tsumo ? ([...s.hand]..remove(winTile)) : s.hand;
      final score =
          _score(s, concealed, winTile, isTsumo: tsumo, chankan: chankan);
      final value = score.points;
      if (tsumo) {
        for (final p in playing) {
          if (p == w) continue;
          _pay(SichuanPaymentKind.hu, p, w,
              value + SichuanRules.selfDrawBonus, 'Self-draw Hu');
        }
      } else {
        _pay(SichuanPaymentKind.hu, discarder, w, value,
            chankan ? 'Robbed kong' : 'Hu on discard');
      }
      _huEvents.add(SichuanHu(
          seat: w,
          tile: winTile,
          score: score,
          from: discarder,
          robbedKong: chankan));
      s.out = true;
      s.huOrder = _huEvents.length;
    }
    if (!_firstHuDecided) {
      _firstHuDecided = true;
      _nextDealer = order.length == 1 ? order.first : discarder;
    }
    pendingDiscard = null;
    pendingDiscardSeat = -1;
    callOptions = const [];
    _chankanPending = false;
    _pendingPung = null;
    if (seats.where((s) => !s.out).length <= 1) {
      _finishSichuan(wallEnded: false);
      return;
    }
    turn = discarder ?? order.first;
    phase = RoundPhase.drawing;
    _advanceTurn();
  }

  /// Ends a Sichuan hand — three seats have gone out, or the wall has run
  /// out — and settles what is left: unready seats pay ready ones, kong
  /// payments are collected, and a seat that finished holding its void suit
  /// pays the penalty.
  void _finishSichuan({required bool wallEnded}) {
    final remaining = [
      for (final s in seats)
        if (!s.out) s.seat
    ];
    final ready = <int, int>{
      for (final i in remaining)
        if (sichuanReadyValue(i) > 0) i: sichuanReadyValue(i),
    };
    if (remaining.length >= 2) {
      for (final loser in remaining) {
        if (ready.containsKey(loser)) continue;
        for (final winner in remaining) {
          if (!ready.containsKey(winner)) continue;
          _pay(SichuanPaymentKind.ready, loser, winner, ready[winner]!,
              'Unready pays ready');
        }
      }
    }
    for (final k in _kongs) {
      if (k.voided) continue;
      // A seat still playing and not ready collects no kong payments.
      if (!seats[k.seat].out && !ready.containsKey(k.seat)) continue;
      for (final payer in k.payers) {
        _pay(SichuanPaymentKind.kong, payer, k.seat, k.each, 'Kong');
      }
    }
    for (final i in remaining) {
      final s = seats[i];
      final v = s.voidSuit;
      if (v == null ||
          !s.hand.any((t) => t.type.suit == v) ||
          !s.allDiscards.any((t) => t.type.suit != v)) {
        continue;
      }
      for (final other in seats) {
        if (other.seat == i) continue;
        _pay(SichuanPaymentKind.penalty, i, other.seat,
            SichuanRules.voidedSuitPenalty, 'Void suit penalty');
      }
    }
    phase = RoundPhase.finished;
    result = RoundResult(
      kind: RoundEndKind.bloodBattle,
      winners: [for (final h in _huEvents) h.seat],
      pointDeltas: _handDeltas(),
      score: _huEvents.isEmpty ? null : _huEvents.first.score,
      scores: [for (final h in _huEvents) h.score],
      winTiles: {for (final h in _huEvents) h.seat: h.tile},
      label: wallEnded ? 'Wall Ends' : 'Three Hu',
      sichuanHu: List.of(_huEvents),
      sichuanPayments: List.of(_payments),
      nextDealer: _nextDealer ?? dealer,
    );
  }

  // --- turn flow -----------------------------------------------------------

  /// Draws for [seat] and hands the tile to [onTile]. A flower is exposed and
  /// replaced from the tail first. An empty wall ends the hand — checked on a
  /// riichi replacement draw too only in Hong Kong, since riichi's kan draws
  /// come from a dead wall that [TileWall.canKan] has already vouched for.
  void _drawFor(SeatState seat,
      {required bool replacement, required void Function(Tile) onTile}) {
    if ((!replacement || ruleset.isChineseStyle) && wall.isEmpty) {
      _exhaustiveDraw();
      return;
    }
    final tile = replacement ? wall.drawDeadWall() : wall.drawLive();
    if (tile.type.isBonus) {
      if (ruleset.isMcr) seat.replacementDraw = false;
      _exposeFlower(
          seat, tile, () => _drawFor(seat, replacement: true, onTile: onTile));
    } else {
      onTile(tile);
    }
  }

  void _acceptDraw(SeatState seat, Tile tile) {
    // A fresh draw ends temporary (non-riichi) furiten; permanent riichi
    // furiten is untouched.
    seat.tempFuriten = false;
    seat.drawn = tile;
    seat.hand = [...sortByType(seat.hand), tile];
    phase = RoundPhase.discarding;
  }

  void _beginDraw() {
    phase = RoundPhase.drawing;
    final seat = current;
    seat.replacementDraw = false;
    seat.kongChain = 0;
    seat.drawCount++;
    // Its own turn ends any Hu it passed up (Sichuan's skip rule).
    seat.passedHuValue = 0;
    _drawFor(seat,
        replacement: false, onTile: (tile) => _acceptDraw(seat, tile));
  }

  /// After a kan, draw from the dead wall instead.
  void _drawReplacement() {
    final seat = current;
    seat.replacementDraw = true;
    _drawFor(seat,
        replacement: true, onTile: (tile) => _acceptDraw(seat, tile));
  }

  // --- queries -----------------------------------------------------------

  List<Tile> legalDiscards(int seat) {
    if (_flowerSeat != null) return const [];
    final s = seats[seat];
    if (mustDiscardVoid(seat)) {
      return [for (final t in s.hand) if (t.type.suit == s.voidSuit) t];
    }
    if (_locked(s)) {
      // Must discard the drawn tile (tsumogiri) unless it forms a closed kan.
      return s.drawn != null ? [s.drawn!] : s.hand;
    }
    return s.hand;
  }

  bool canTsumo(int seat) {
    if (canFlowerWin(seat)) return true;
    final s = seats[seat];
    if (s.hand.length % 3 != 2) return false;
    final winTile = s.drawn;
    if (winTile == null) return false;
    final concealed = [...s.hand]..remove(winTile);
    return _winsWith(s, concealed, winTile, isTsumo: true);
  }

  bool canRon(int seat, Tile discard, {bool chankan = false}) {
    final s = seats[seat];
    if (seat == pendingDiscardSeat) return false;
    if (s.hand.length % 3 != 1) return false;
    if (ruleset.isSichuan && s.out) return false;
    if (!ruleset.isHongKong && !ruleset.isMcr && !ruleset.isSichuan && _isFuriten(s)) {
      return false;
    }
    return _winsWith(s, s.hand, discard, isTsumo: false, chankan: chankan);
  }

  /// Whether [seat] is tenpai but barred from declaring ron by furiten. Drives
  /// the UI's furiten marker; the same check gates every seat's [canRon] so no
  /// player — human or bot — can ron off a furiten wait.
  bool isFuriten(int seat) {
    if (ruleset.isHongKong || ruleset.isMcr || ruleset.isSichuan) return false;
    final s = seats[seat];
    if (_waitTiles(s.hand, openMelds: s.melds.length).isEmpty) return false;
    return _isFuriten(s);
  }

  /// Whether [seat] is tenpai but no wait reaches the table's minimum off a
  /// discard — the reason ron never gets offered, shown beside the furiten
  /// marker. Furiten itself is ignored here; [isFuriten] reports that.
  MinimumShortfall minimumShortfall(int seat) {
    // Sichuan has no minimum to win.
    if (ruleset.isSichuan) return MinimumShortfall.none;
    final s = seats[seat];
    if (s.hand.length % 3 != 1) return MinimumShortfall.none;
    final waits = _waitTiles(s.hand, openMelds: s.melds.length);
    if (waits.isEmpty) return MinimumShortfall.none;
    // A stand-in winning tile: id -1 matches no physical tile, so scoring
    // that counts visible tiles by id (MCR's last-tile check) is unaffected.
    bool wins(TileType t, {required bool isTsumo}) =>
        _winsWith(s, s.hand, Tile(-1, t), isTsumo: isTsumo);
    if (waits.any((t) => wins(t, isTsumo: false))) {
      return MinimumShortfall.none;
    }
    return waits.any((t) => wins(t, isTsumo: true))
        ? MinimumShortfall.ronOnly
        : MinimumShortfall.dead;
  }

  bool canRiichi(int seat) {
    if (ruleset.isChineseStyle) return false;
    final s = seats[seat];
    return !s.riichi &&
        s.closed &&
        s.points >= 1000 &&
        wall.remaining >= 4 &&
        _anyRiichiDiscardTenpai(s);
  }

  /// Kyuushu kyuuhai (nine kinds of terminals/honors): whether [seat] may
  /// abort the round right now — their own first decision this hand, with
  /// nothing at the table having happened yet (no call, no kan — the same
  /// [_firstGoAround] window double riichi uses), and their 14-tile hand
  /// holding at least nine *different* terminal/honor types. Available to
  /// any seat, not just the dealer. Riichi only; Hong Kong and Taiwanese have
  /// no such rule.
  bool canDeclareKyuushu(int seat) {
    if (!ruleset.isRiichi) return false;
    if (phase != RoundPhase.discarding || turn != seat) return false;
    final s = seats[seat];
    if (!_firstGoAround || s.pond.isNotEmpty) return false;
    final distinctTerminalsOrHonors = {
      for (final t in s.hand)
        if (t.type.isTerminalOrHonor) t.type,
    };
    return distinctTerminalsOrHonors.length >= 9;
  }

  /// Aborts the round on [seat]'s kyuushu kyuuhai. No one wins or pays —
  /// riichi sticks already on the table, if any, are left exactly where the
  /// exhaustive-draw path leaves them, to carry into the next hand.
  void declareKyuushu(int seat) {
    assert(canDeclareKyuushu(seat));
    phase = RoundPhase.finished;
    result = RoundResult(
      kind: RoundEndKind.abortiveDraw,
      winners: const [],
      pointDeltas: const {},
      label: 'Kyuushu Kyuuhai — nine terminals/honors',
    );
    _postFinish(dealerRepeat: true);
  }

  bool canPon(int seat, Tile discard) {
    if (seat == pendingDiscardSeat) return false;
    // Chinese-style: nothing can be called off the last discard.
    if (ruleset.isChineseStyle && wall.isEmpty) return false;
    final s = seats[seat];
    if (_locked(s)) return false;
    return s.hand.where((t) => t.type == discard.type).length >= 2;
  }

  /// Chi is open only to the seat immediately after the discarder — its
  /// kamicha — and only on a suit tile it can complete a run with.
  bool canChi(int seat, Tile discard) {
    // Sichuan allows chows in the hand but never claims a discard for one.
    if (ruleset.isSichuan) return false;
    if (seat == pendingDiscardSeat) return false;
    if (seat != (pendingDiscardSeat + 1) % 4) return false;
    if (ruleset.isChineseStyle && wall.isEmpty) return false;
    if (_locked(seats[seat])) return false;
    return chiSequences(seat, discard).isNotEmpty;
  }

  /// The lowest tile of every run [seat] could form with [discard]. Holding
  /// 3456m and offered 5m gives 345m, 456m and 567m, so the caller has to say
  /// which one it wants.
  List<TileType> chiSequences(int seat, Tile discard) {
    final type = discard.type;
    if (!type.isSuit) return const [];
    final hand = seats[seat].hand;
    final out = <TileType>[];
    final suitBase = type.index - type.number;

    for (var offset = -2; offset <= 0; offset++) {
      final lowNumber = type.number + offset;
      if (lowNumber < 1 || lowNumber + 2 > 9) continue;
      final low = TileType.values[suitBase + lowNumber];

      final used = <int>{};
      var complete = true;
      for (var i = 0; i < 3; i++) {
        final need = TileType.values[low.index + i];
        if (need == type) continue; // the discard supplies this one
        final index =
            hand.indexWhere((t) => t.type == need && !used.contains(t.id));
        if (index < 0) {
          complete = false;
          break;
        }
        used.add(hand[index].id);
      }
      if (complete) out.add(low);
    }
    return out;
  }

  bool canOpenKan(int seat, Tile discard) {
    if (seat == pendingDiscardSeat) return false;
    final s = seats[seat];
    if (_locked(s) || !wall.canKan) return false;
    return s.hand.where((t) => t.type == discard.type).length >= 3;
  }

  List<TileType> closedKanTypes(int seat) {
    final s = seats[seat];
    if (!wall.canKan || _flowerSeat != null || (ruleset.isMcr && s.drawn == null)) return const [];
    final byType = <TileType, int>{};
    for (final t in s.hand) {
      byType[t.type] = (byType[t.type] ?? 0) + 1;
    }
    final out =
        byType.entries.where((e) => e.value == 4).map((e) => e.key).toList();
    if (_locked(s)) {
      // In riichi only the tile just drawn may be kanned, and only if the kan
      // leaves the wait exactly as it was — see [_kanKeepsWait].
      return out
          .where((t) => s.drawn?.type == t && _kanKeepsWait(s, t))
          .toList();
    }
    return out;
  }

  /// Shouminkan candidates: an existing open pon this seat could extend into
  /// a kan by adding the matching tile it's currently holding. Blocked while
  /// in riichi (the hand is frozen) — real rules allow it in narrow cases,
  /// but this trainer keeps riichi hands fixed for simplicity.
  List<TileType> addedKanTypes(int seat) {
    final s = seats[seat];
    if (_locked(s) || !wall.canKan || _flowerSeat != null || (ruleset.isMcr && s.drawn == null)) return const [];
    final ponTypes = {
      for (final m in s.melds)
        if (m.kind == MeldKind.triplet) m.low,
    };
    final handTypes = s.hand.map((t) => t.type).toSet();
    return ponTypes.where(handTypes.contains).toList();
  }

  bool _winsWith(SeatState s, List<Tile> concealed, Tile winTile,
      {required bool isTsumo, bool chankan = false}) {
    final counts = toCounts34([...concealed, winTile]);
    if (!_isAgari(counts, meldCount: s.melds.length)) return false;
    final score = _score(s, concealed, winTile,
        isTsumo: isTsumo, dryRun: true, chankan: chankan);
    if (ruleset.isSichuan) {
      // No minimum, but the void suit must be gone, and a Hu passed up on a
      // discard stays passed up unless a later discard is worth more.
      if (!score.valid || _holdsVoid(s, [...concealed, winTile])) return false;
      return isTsumo || score.points > s.passedHuValue;
    }
    if (ruleset.isHongKong) {
      return score.valid && score.faan >= minimumFaan;
    }
    // Taiwanese's minimum is already baked into `score.valid`: `_score`
    // hands [minimumPoints] to `scoreTaiwaneseHand`, which rejects anything
    // under it.
    return score.valid;
  }

  /// The three riichi furiten cases, any of which bars ron:
  ///  1. permanent riichi furiten — a winning tile was passed while in riichi;
  ///  2. own-discard furiten — one of the current waits sits in this seat's
  ///     discards (kept in [SeatState.allDiscards] even once called away);
  ///  3. temporary furiten — a winning tile went past since this seat's last
  ///     draw and was not claimed.
  bool _isFuriten(SeatState s) {
    if (s.riichiFuriten) return true;
    final waits = _waitTiles(s.hand, openMelds: s.melds.length).toSet();
    if (waits.isEmpty) return true;
    if (s.allDiscards.any((d) => waits.contains(d.type))) return true;
    return s.tempFuriten;
  }

  /// Any seat (other than the discarder) whose wait includes [discard] but did
  /// not claim it is now furiten: temporarily until its next draw — or, in
  /// riichi, permanently for the rest of the round. Hong Kong has no furiten
  /// at all; Taiwanese's own "Taiwanese Furiten" is temporary only, the same
  /// as riichi's non-permanent case.
  void _registerMissedRon(Tile discard, int discarder, {bool chankan = false}) {
    if (ruleset.isSichuan) {
      _registerPassedHu(discard, discarder, chankan: chankan);
      return;
    }
    if (ruleset.isHongKong || ruleset.isMcr) return;
    for (var i = 0; i < 4; i++) {
      if (i == discarder) continue;
      final s = seats[i];
      final waits = _waitTiles(s.hand, openMelds: s.melds.length);
      if (!waits.contains(discard.type)) continue;
      s.tempFuriten = true;
      if (s.riichi) s.riichiFuriten = true;
    }
  }

  void _registerPassedDiscard(Tile discard, int discarder) {
    for (final s in seats) {
      if (s.seat != discarder && s.riichi) {
        s.passedDiscardsAfterRiichi.add(discard.type);
      }
    }
  }

  bool _anyRiichiDiscardTenpai(SeatState s) {
    for (var i = 0; i < s.hand.length; i++) {
      final rest = [...s.hand]..removeAt(i);
      if (isTenpai(rest, openMelds: s.melds.length)) return true;
    }
    return false;
  }

  /// Whether a riichi seat's closed kan of [t] (its drawn tile) leaves its wait
  /// unchanged: the tiles the 13-tile hand was waiting on before the draw are
  /// exactly the ones it waits on with [t] set aside as a kan. A kan that
  /// broke tenpai or moved the wait would leave a riichi hand that is no longer
  /// ready — and so paying noten at a draw.
  bool _kanKeepsWait(SeatState s, TileType t) {
    final drawn = s.drawn;
    if (drawn == null) return false;
    final before = waitTiles([
      for (final x in s.hand)
        if (x.id != drawn.id) x
    ], openMelds: s.melds.length)
        .toSet();
    final after = waitTiles(s.hand.where((x) => x.type != t).toList(),
            openMelds: s.melds.length + 1)
        .toSet();
    return after.isNotEmpty &&
        before.length == after.length &&
        before.containsAll(after);
  }

  // --- actions ---------------------------------------------------------

  void discard(int seat, Tile tile, {bool declareRiichi = false}) {
    assert(phase == RoundPhase.discarding && seat == turn);
    final s = current;
    if (_flowerSeat != null) {
      throw StateError('Choose flower win or continue first');
    }
    if (ruleset.isChineseStyle) {
      if (phase != RoundPhase.discarding || seat != turn) {
        throw StateError('Not this seat’s discard turn');
      }
      if (declareRiichi) {
        throw UnsupportedError('${ruleset.label} mahjong has no riichi');
      }
      if (!s.hand.contains(tile)) {
        throw ArgumentError('Tile is not in this hand');
      }
    }
    if (ruleset.isSichuan) {
      if (mustDiscardVoid(seat) && tile.type.suit != s.voidSuit) {
        throw StateError('Discard the void suit first');
      }
      // The first discard shows the void suit to the table.
      s.voidRevealed = true;
      _discardAfterKong = s.replacementDraw;
      _discardKong = s.replacementDraw ? _lastKong[seat] : null;
    }
    s.replacementDraw = false;
    s.kongChain = 0;

    // Once riichi is declared the hand is frozen: every later discard must be
    // the just-drawn tile (tsumogiri). A concealed kan goes through
    // [closedKan], not here, so this does not block it. On the declaring turn
    // itself `s.riichi` is still false, so the declaration discard is free.
    if (_locked(s) && s.drawn != null) {
      tile = s.drawn!;
    }

    if (declareRiichi) {
      s.riichi = true;
      s.ippatsu = true;
      // Double riichi: declared on this seat's very first discard, with no
      // call or kan anywhere at the table yet. `_firstGoAround` alone is not
      // enough — it stays true through the dealer's second discard (it is only
      // cleared after that discard lands), so the dealer's own-pond check is
      // what keeps a second-turn riichi from counting.
      if (_firstGoAround && s.allDiscards.isEmpty) s.doubleRiichi = true;
      s.points -= 1000;
      riichiSticks += 1;
    } else {
      s.ippatsu = false;
    }

    s.hand.remove(tile);
    s.hand = sortByType(s.hand);
    s.drawn = null;
    s.pond.add(tile);
    s.allDiscards.add(tile);
    if (declareRiichi) s.riichiPondIndex = s.pond.length - 1;
    _discardsThisRound++;
    if (turn == dealer && _discardsThisRound > 1) _firstGoAround = false;

    pendingDiscard = tile;
    pendingDiscardSeat = seat;
    callOptions = _collectCallOptions(tile, seat);
    if (callOptions.isEmpty) {
      // No one can act on it, so no one is claiming it: register the miss now.
      _registerMissedRon(tile, seat);
      _registerPassedDiscard(tile, seat);
      phase = RoundPhase.drawing;
      _advanceTurn();
    } else {
      phase = RoundPhase.callOffer;
    }
  }

  List<CallOption> _collectCallOptions(Tile discard, int discarder) {
    final options = <CallOption>[];
    for (var i = 0; i < 4; i++) {
      if (i == discarder) continue;
      if (ruleset.isSichuan && seats[i].out) continue;
      final types = <CallType>{};
      if (canRon(i, discard)) types.add(CallType.ron);
      if (canPon(i, discard)) types.add(CallType.pon);
      if (canOpenKan(i, discard)) types.add(CallType.kan);
      if (canChi(i, discard)) types.add(CallType.chi);
      if (types.isNotEmpty) options.add(CallOption(i, types));
    }
    return options;
  }

  /// Resolve the call phase. [choice] maps seat -> chosen call (absent / none
  /// means pass). Ron beats kan beats pon beats chi; ties on ron are all
  /// winners. [chiLow] names the run a chi caller wants, keyed by seat — see
  /// [chiSequences]; an absent or impossible entry falls back to the first
  /// run the hand can make.
  void resolveCalls(
    Map<int, CallType> choice, {
    Map<int, TileType> chiLow = const {},
  }) {
    assert(phase == RoundPhase.callOffer);
    if (phase != RoundPhase.callOffer) throw StateError('No call window');
    // Only calls actually on offer count; anything else is a pass.
    choice = Map.of(choice)
      ..removeWhere((seat, type) => !callOptions
          .any((option) => option.seat == seat && option.types.contains(type)));

    if (_chankanPending) {
      final ronners = choice.entries
          .where((e) => e.value == CallType.ron)
          .map((e) => e.key)
          .toList();
      _chankanPending = false;
      if (ronners.isNotEmpty) {
        // Chinese-style: a robbed kong never happened, so the pung stands.
        if (ruleset.isChineseStyle && _pendingPung != null) {
          seats[pendingDiscardSeat].melds[_pendingPungIndex] = _pendingPung!;
          _pendingPung = null;
        }
        _applyRon(ronners, pendingDiscard!, pendingDiscardSeat, chankan: true);
        return;
      }
      // No one robbed the kan: the missed tile satisfied a real wait, so it
      // counts as a missed ron exactly like an unclaimed discard.
      _registerMissedRon(pendingDiscard!, pendingDiscardSeat, chankan: true);
      _completeAddedKan();
      return;
    }

    final ronners = choice.entries
        .where((e) => e.value == CallType.ron)
        .map((e) => e.key)
        .toList();
    if (ronners.isNotEmpty) {
      _applyRon(ronners, pendingDiscard!, pendingDiscardSeat);
      return;
    }

    // The discard cleared the call window unclaimed. Any seat waiting on it
    // that chose not to ron (or had no yaku to ron with) is now furiten —
    // permanently if it is in riichi, otherwise until its next draw. This runs
    // even when the tile is then ponned/kanned: the missed ron still counts.
    _registerMissedRon(pendingDiscard!, pendingDiscardSeat);

    _registerPassedDiscard(pendingDiscard!, pendingDiscardSeat);

    int? kanSeat;
    int? ponSeat;
    int? chiSeat;
    choice.forEach((seat, type) {
      if (type == CallType.kan) kanSeat = seat;
      if (type == CallType.pon) ponSeat = seat;
      if (type == CallType.chi) chiSeat = seat;
    });

    if (kanSeat != null) {
      _applyPonOrKan(kanSeat!, pendingDiscard!, pendingDiscardSeat, kan: true);
      return;
    }
    if (ponSeat != null) {
      _applyPonOrKan(ponSeat!, pendingDiscard!, pendingDiscardSeat, kan: false);
      return;
    }
    if (chiSeat != null) {
      _applyChi(
          chiSeat!, pendingDiscard!, pendingDiscardSeat, chiLow[chiSeat!]);
      return;
    }

    pendingDiscard = null;
    pendingDiscardSeat = -1;
    callOptions = const [];
    _advanceTurn();
  }

  void declareTsumo(int seat) {
    assert(seat == turn);
    if (ruleset.isChineseStyle &&
        (seat != turn || phase != RoundPhase.discarding || !canTsumo(seat))) {
      throw StateError('No legal self draw');
    }
    final s = seats[seat];
    if (canFlowerWin(seat)) {
      final score = ruleset.isTaiwanese
          ? scoreTaiwaneseFlowerWin(s.flowers.length)
          : scoreFlowerWin(s.flowers.length);
      _flowerSeat = null;
      _flowerContinuation = null;
      _finishWin([seat], score, flowerWin: true);
      return;
    }
    final winTile = s.drawn!;
    if (ruleset.isSichuan) {
      _applySichuanHu([seat], winTile, null);
      return;
    }
    final concealed = [...s.hand]..remove(winTile);
    final score = _score(s, concealed, winTile, isTsumo: true);
    _finishWin([seat], score, loser: null, winTile: winTile);
  }

  void closedKan(int seat, TileType type) {
    assert(seat == turn && phase == RoundPhase.discarding);
    if (ruleset.isChineseStyle) {
      if (seat != turn || phase != RoundPhase.discarding) {
        throw StateError('Not this seat’s kong turn');
      }
      if (!closedKanTypes(seat).contains(type)) {
        throw StateError('Illegal closed kong');
      }
    }
    // Any kan — including a concealed one — interrupts the first go-around,
    // ending the double riichi / kyuushu / blessing window for everyone.
    _firstGoAround = false;
    // It breaks every seat's ippatsu too, the declarer's own included.
    for (final o in seats) {
      o.ippatsu = false;
    }
    final s = current;
    s.kongChain =
        s.replacementDraw && s.drawn?.type == type ? s.kongChain + 1 : 1;
    final taken = <Tile>[];
    s.hand.removeWhere((t) {
      if (t.type == type && taken.length < 4) {
        taken.add(t);
        return true;
      }
      return false;
    });
    s.melds.add(
        Meld(kind: MeldKind.kan, low: type, concealed: true, tiles: taken));
    _recordKong(seat, SichuanKongKind.concealed, type);
    s.drawn = null;
    _drawReplacement();
  }

  /// Shouminkan: fold the matching tile [type] this seat is holding into its
  /// existing open pon, upgrading it to a kan. Every other seat gets one
  /// chankan window to ron the added tile before the kan completes — see
  /// [resolveCalls]'s `_chankanPending` branch.
  void addKan(int seat, TileType type) {
    assert(seat == turn && phase == RoundPhase.discarding);
    if (ruleset.isChineseStyle) {
      if (seat != turn || phase != RoundPhase.discarding) {
        throw StateError('Not this seat’s kong turn');
      }
      if (!addedKanTypes(seat).contains(type)) {
        throw StateError('Illegal added kong');
      }
    }
    // Any kan — including a concealed one — interrupts the first go-around,
    // ending the double riichi / kyuushu / blessing window for everyone.
    _firstGoAround = false;
    final s = current;
    s.kongChain =
        s.replacementDraw && s.drawn?.type == type ? s.kongChain + 1 : 1;
    final ponIndex =
        s.melds.indexWhere((m) => m.kind == MeldKind.triplet && m.low == type);
    assert(ponIndex != -1, 'addKan requires an existing open pon of $type');
    final pon = s.melds[ponIndex];
    _pendingPung = pon;
    _pendingPungIndex = ponIndex;
    // Pays only when the kong is made on the tile just drawn, not one held.
    _pendingAddedKong = _recordKong(seat, SichuanKongKind.added, type,
        voided: s.drawn?.type != type);
    final addedIndex = s.hand.indexWhere((t) => t.type == type);
    final added = s.hand.removeAt(addedIndex);
    s.melds[ponIndex] = Meld(
      kind: MeldKind.kan,
      low: type,
      concealed: false,
      addedKan: true,
      calledFromSeatOffset: pon.calledFromSeatOffset,
      tiles: [...pon.tiles, added],
    );
    s.drawn = null;

    pendingDiscard = added;
    pendingDiscardSeat = seat;
    _chankanPending = true;
    final options = <CallOption>[
      for (var i = 0; i < 4; i++)
        if (i != seat && canRon(i, added, chankan: true))
          CallOption(i, {CallType.ron}),
    ];
    callOptions = options;
    if (options.isEmpty) {
      _completeAddedKan();
    } else {
      phase = RoundPhase.callOffer;
    }
  }

  void _completeAddedKan() {
    // Clearing the chankan flag here covers both ways in: nobody could rob it
    // in the first place, or the window opened and closed unclaimed. Leaving it
    // set meant the next discard that offered a call took the chankan branch in
    // [resolveCalls] instead of its own — drawing a second replacement tile and
    // flipping a dora indicator that no kan had earned.
    _pendingPung = null;
    _pendingAddedKong = null;
    _chankanPending = false;
    // The kan went through, so it breaks every seat's ippatsu. Not cleared in
    // [addKan] itself: a chankan ron on the added tile can still be ippatsu.
    for (final o in seats) {
      o.ippatsu = false;
    }
    pendingDiscard = null;
    pendingDiscardSeat = -1;
    callOptions = const [];
    _drawReplacement();
  }

  // --- call application ---------------------------------------------------

  void _applyChi(
      int seat, Tile discard, int discarder, TileType? requestedLow) {
    final s = seats[seat];
    final runs = chiSequences(seat, discard);
    if (runs.isEmpty) return;
    final low = (requestedLow != null && runs.contains(requestedLow))
        ? requestedLow
        : runs.first;

    final taken = <Tile>[];
    for (var i = 0; i < 3; i++) {
      final need = TileType.values[low.index + i];
      if (need == discard.type) continue; // supplied by the discard
      final index =
          s.hand.indexWhere((t) => t.type == need && !taken.contains(t));
      if (index >= 0) taken.add(s.hand[index]);
    }
    for (final tile in taken) {
      s.hand.remove(tile);
    }

    seats[discarder].pond.removeLast();
    s.melds.add(Meld(
      kind: MeldKind.sequence,
      low: low,
      concealed: false,
      calledFromSeatOffset: (discarder - seat + 4) % 4,
      tiles: [...taken, discard],
    ));
    for (final o in seats) {
      o.ippatsu = false;
    }
    _firstGoAround = false;

    pendingDiscard = null;
    pendingDiscardSeat = -1;
    callOptions = const [];
    turn = seat;
    current.drawn = null;
    phase = RoundPhase.discarding;
  }

  void _applyPonOrKan(int seat, Tile discard, int discarder,
      {required bool kan}) {
    final s = seats[seat];
    final need = kan ? 3 : 2;
    final taken = <Tile>[];
    s.hand.removeWhere((t) {
      if (t.type == discard.type && taken.length < need) {
        taken.add(t);
        return true;
      }
      return false;
    });
    // remove from discarder's pond
    seats[discarder].pond.removeLast();
    final offset = (discarder - seat + 4) % 4;
    s.melds.add(Meld(
      kind: kan ? MeldKind.kan : MeldKind.triplet,
      low: discard.type,
      concealed: false,
      calledFromSeatOffset: offset,
      tiles: [...taken, discard],
    ));
    if (kan) {
      _recordKong(seat, SichuanKongKind.melded, discard.type,
          discarder: discarder);
    }
    s.passedHuValue = 0;
    // ippatsu / first-go-around broken by a call
    for (final o in seats) {
      o.ippatsu = false;
    }
    _firstGoAround = false;

    pendingDiscard = null;
    pendingDiscardSeat = -1;
    callOptions = const [];
    turn = seat;
    current.drawn = null;
    if (kan) {
      s.kongChain = 1;
      _drawReplacement();
    } else {
      phase = RoundPhase.discarding;
    }
  }

  void _applyRon(List<int> ronners, Tile discard, int discarder,
      {bool chankan = false}) {
    if (ruleset.isSichuan) {
      _applySichuanHu(ronners, discard, discarder, chankan: chankan);
      return;
    }
    // Score each winner; sum deltas. Head-bump is not modelled — all valid
    // ronners win (double/triple ron).
    //
    // Hong Kong and Taiwanese order the winners by turn distance before
    // scoring, so the first score and the result pages follow that order.
    // Their honba and sticks are always zero, so the payments below are
    // unchanged from the ordinary discarder-pays rule.
    if (ruleset.isChineseStyle) {
      ronners.sort((a, b) =>
          ((a - discarder + 4) % 4).compareTo((b - discarder + 4) % 4));
    }
    if (ruleset.isMcr && ronners.length > 1) ronners = [ronners.first];
    HandScore? firstScore;
    final deltas = <int, int>{for (var i = 0; i < 4; i++) i: 0};
    // Taiwanese has its own dealer-streak bonus (below) in place of honba
    // payments, which mean nothing there — its honba instead counts the
    // dealer's consecutive wins. See TaiwaneseRules.dealerBonus.
    final honbaPay = (ruleset.isTaiwanese || ruleset.isMcr) ? 0 : honba * 300;
    for (final w in ronners) {
      final s = seats[w];
      final score =
          _score(s, s.hand, discard, isTsumo: false, chankan: chankan);
      firstScore ??= score;
      deltas[w] = deltas[w]! + score.points + honbaPay;
      if (ruleset.isMcr) {
        for (var i = 0; i < 4; i++) {
          if (i != w) deltas[i] = deltas[i]! - (i == discarder ? score.han + 8 : 8);
        }
      } else {
        deltas[discarder] = deltas[discarder]! - score.points - honbaPay;
      }
    }
    // Taiwanese dealer-streak bonus: on a ron, paid only by the discarder —
    // by the winner collecting it off East when East is among the ronners,
    // or by East paying every winner when East is the one dealing in.
    if (ruleset.isTaiwanese) {
      final bonus = TaiwaneseRules.dealerBonus(honba);
      if (bonus > 0) {
        if (ronners.contains(dealer)) {
          deltas[dealer] = deltas[dealer]! + bonus;
          deltas[discarder] = deltas[discarder]! - bonus;
        } else if (discarder == dealer) {
          for (final w in ronners) {
            deltas[w] = deltas[w]! + bonus;
            deltas[discarder] = deltas[discarder]! - bonus;
          }
        }
      }
    }
    // riichi sticks go to the first ronner (closest in turn order after discarder)
    ronners.sort(
        (a, b) => ((a - discarder + 4) % 4).compareTo((b - discarder + 4) % 4));
    deltas[ronners.first] = deltas[ronners.first]! + riichiSticks * 1000;

    for (final e in deltas.entries) {
      seats[e.key].points += e.value;
    }
    riichiSticks = 0;

    final dealerWins = ronners.contains(dealer);
    phase = RoundPhase.finished;
    result = RoundResult(
      kind: RoundEndKind.ron,
      winners: ronners,
      loser: discarder,
      score: firstScore,
      scores: [
        for (final w in ronners)
          _score(seats[w], seats[w].hand, discard,
              isTsumo: false, chankan: chankan)
      ],
      winTiles: {for (final w in ronners) w: discard},
      pointDeltas: _handDeltas(),
      label: ruleset.isChineseStyle
          ? (ronners.length > 1
              ? 'Multiple Wins'
              : (chankan ? 'Robbing a Kong' : 'Win on Discard'))
          : (ronners.length > 1
              ? 'Multiple Ron'
              : (chankan ? 'Chankan' : 'Ron')),
    );
    _postFinish(dealerRepeat: dealerWins);
  }

  void _finishWin(List<int> winners, HandScore score,
      {int? loser, Tile? winTile, bool flowerWin = false}) {
    final deltas = <int, int>{for (var i = 0; i < 4; i++) i: 0};
    final w = winners.first;

    // Taiwanese dealer-streak bonus: on a self-draw, every other seat pays
    // it too, same as the hand's own value — see the matching note in
    // _applyRon.
    final bonus = ruleset.isTaiwanese && seats[w].isDealer
        ? TaiwaneseRules.dealerBonus(honba)
        : 0;
    final honbaPay = (ruleset.isTaiwanese || ruleset.isMcr) ? 0 : honba * 100;

    // Tsumo only (ron goes through _applyRon).
    for (var i = 0; i < 4; i++) {
      if (i == w) continue;
      final base = seats[w].isDealer
          ? score.nonDealerPays
          : (i == dealer ? score.dealerPays : score.nonDealerPays);
      final pay = base + honbaPay + bonus;
      deltas[i] = -pay;
      deltas[w] = deltas[w]! + pay;
    }

    deltas[w] = deltas[w]! + riichiSticks * 1000;
    for (final e in deltas.entries) {
      seats[e.key].points += e.value;
    }
    riichiSticks = 0;

    phase = RoundPhase.finished;
    result = RoundResult(
      kind: RoundEndKind.tsumo,
      winners: winners,
      loser: loser,
      score: score,
      scores: [score],
      winTiles: winTile != null ? {w: winTile} : const {},
      pointDeltas: _handDeltas(),
      label: ruleset.isChineseStyle
          ? (flowerWin ? score.yaku.first.name : 'Self Draw')
          : 'Tsumo',
    );
    _postFinish(dealerRepeat: winners.contains(dealer));
  }

  void _exhaustiveDraw() {
    if (ruleset.isSichuan) {
      _finishSichuan(wallEnded: true);
      return;
    }
    final tenpai = <int>[];
    for (var i = 0; i < 4; i++) {
      if (_isTenpaiFor(seats[i].hand, openMelds: seats[i].melds.length)) {
        tenpai.add(i);
      }
    }
    final deltas = <int, int>{for (var i = 0; i < 4; i++) i: 0};
    // Hong Kong pays nothing at a draw.
    final noten = [
      if (ruleset.isRiichi)
        for (var i = 0; i < 4; i++) i
    ].where((i) => !tenpai.contains(i)).toList();
    if (tenpai.isNotEmpty && noten.isNotEmpty) {
      const pot = 3000;
      final gain = pot ~/ tenpai.length;
      final loss = pot ~/ noten.length;
      for (final i in tenpai) {
        deltas[i] = gain;
      }
      for (final i in noten) {
        deltas[i] = -loss;
      }
    }
    for (final e in deltas.entries) {
      seats[e.key].points += e.value;
    }
    phase = RoundPhase.finished;
    result = RoundResult(
      kind: RoundEndKind.exhaustiveDraw,
      winners: const [],
      pointDeltas: _handDeltas(),
      tenpaiAtDraw: tenpai,
      label: 'Exhaustive Draw',
    );
    _postFinish(
        dealerRepeat: ruleset.isChineseStyle || tenpai.contains(dealer));
  }

  void _postFinish({required bool dealerRepeat}) {
    // honba / riichi-stick carry is applied by the game controller when it
    // starts the next round; expose the intent via the result label.
  }

  void _advanceTurn() {
    // Ippatsu itself is cleared where it actually ends: any call (see
    // `_applyChi`/`_applyPonOrKan`), any kan (`closedKan` /
    // `_completeAddedKan`), or the declarer's own next discard
    // (`discard`'s `else { s.ippatsu = false; }`) — never here. It must
    // still be set when the go-around comes back around to the declarer's
    // own draw below, so a tsumo right on that draw still counts.
    seats[turn].drawn = null;
    turn = (turn + 1) % 4;
    // Seats that have declared Hu no longer play.
    while (ruleset.isSichuan && seats[turn].out) {
      turn = (turn + 1) % 4;
    }
    _beginDraw();
  }

  // --- scoring bridge --------------------------------------------------

  HandScore _score(SeatState s, List<Tile> concealed, Tile winTile,
      {required bool isTsumo, bool dryRun = false, bool chankan = false}) {
    if (ruleset.isSichuan) {
      return scoreSichuanHand(
          concealed,
          winTile,
          s.melds,
          ScoreContext(
            roundWind: roundWind,
            seatWind: s.wind,
            isTsumo: isTsumo,
            closed: s.closed,
            rinshan: isTsumo && s.replacementDraw,
            haitei: isTsumo && wall.isEmpty,
            houtei: !isTsumo && wall.isEmpty,
            chankan: chankan,
            afterKong: !isTsumo && !chankan && _discardAfterKong,
          ));
    }
    if (ruleset.isMcr) {
      // Count physical public tiles once; the offered tile is excluded.
      final visible = <int, Tile>{};
      for (final seat in seats) {
        for (final tile in seat.pond) { visible[tile.id] = tile; }
        for (final meld in seat.melds.where((m) => !m.concealed)) {
          for (final tile in meld.tiles) { visible[tile.id] = tile; }
        }
      }
      visible.remove(winTile.id);
      return scoreMcrHand(concealed, winTile, s.melds, ScoreContext(
        roundWind: roundWind, seatWind: s.wind, isTsumo: isTsumo,
        closed: s.closed, flowers: s.flowers.map((t) => t.type).toList(),
        rinshan: isTsumo && s.replacementDraw,
        haitei: isTsumo && wall.isEmpty, houtei: !isTsumo && wall.isEmpty,
        chankan: chankan,
      ), mcr: McrScoreContext(lastTile:
          visible.values.where((t) => t.type == winTile.type).length == 3));
    }
    if (ruleset.isHongKong) {
      final ctx = ScoreContext(
        roundWind: roundWind,
        seatWind: s.wind,
        isTsumo: isTsumo,
        closed: s.closed,
        flowers: s.flowers.map((t) => t.type).toList(),
        rinshan: isTsumo && s.replacementDraw,
        doubleKong: isTsumo && s.replacementDraw && s.kongChain >= 2,
        blessingOfMan: _firstGoAround &&
            s.drawCount == 1 &&
            !s.isDealer &&
            s.allDiscards.isEmpty,
        heavenly: _firstGoAround && _discardsThisRound == 0,
        earthly: _firstGoAround &&
            _discardsThisRound == 1 &&
            pendingDiscardSeat == dealer,
        haitei: isTsumo && wall.isEmpty,
        houtei: !isTsumo && wall.isEmpty,
        chankan: chankan,
      );
      return scoreHongKongHand(concealed, winTile, s.melds, ctx,
          isDealer: s.isDealer);
    }
    if (ruleset.isTaiwanese) {
      final ctx = ScoreContext(
        roundWind: roundWind,
        seatWind: s.wind,
        isTsumo: isTsumo,
        closed: s.closed,
        flowers: s.flowers.map((t) => t.type).toList(),
        rinshan: isTsumo && s.replacementDraw,
        heavenly: _firstGoAround && _discardsThisRound == 0,
        earthly: _firstGoAround &&
            _discardsThisRound == 1 &&
            pendingDiscardSeat == dealer,
        haitei: isTsumo && wall.isEmpty,
        houtei: !isTsumo && wall.isEmpty,
        chankan: chankan,
        discardCount: _discardsThisRound,
      );
      return scoreTaiwaneseHand(concealed, winTile, s.melds, ctx,
          isDealer: s.isDealer, minimumPoints: minimumPoints);
    }
    final ctx = ScoreContext(
      roundWind: roundWind,
      seatWind: s.wind,
      isTsumo: isTsumo,
      closed: s.closed,
      riichi: s.riichi && !s.doubleRiichi,
      doubleRiichi: s.doubleRiichi,
      ippatsu: s.ippatsu,
      // A win on a kan's replacement tile. Without it a hand whose only yaku
      // is rinshan kaihou could not win at all ([_winsWith] needs a yaku).
      rinshan: isTsumo && s.replacementDraw,
      // The replacement comes off the dead wall, so it is never the last tile
      // of the live wall — even when the kan drew the live wall down to empty.
      haitei: isTsumo && wall.isEmpty && !s.replacementDraw,
      houtei: !isTsumo && wall.isEmpty,
      chankan: chankan,
      doraIndicators: wall.doraIndicators(),
      uraIndicators: wall.uraDoraIndicators(),
      akaCount: [...concealed, winTile].where((t) => t.aka).length +
          s.melds.expand((m) => m.tiles).where((t) => t.aka).length,
    );
    return scoreHand(concealed, winTile, s.melds, ctx, isDealer: s.isDealer);
  }
}
