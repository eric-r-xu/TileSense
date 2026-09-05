/// A self-contained offline round of four-player riichi. A pragmatic subset of
/// the Vala client's `RoundState` + `GameState.round_finished`: draws, discards,
/// riichi, chi / pon / closed-kan,
/// tsumo, ron, exhaustive draw with tenpai payments, honba and riichi sticks.
library;

import 'hand_parse.dart';
import 'meld.dart';
import 'scoring.dart';
import 'tile.dart';
import 'wall.dart';

enum RoundPhase { drawing, discarding, callOffer, finished }

enum RoundEndKind { tsumo, ron, exhaustiveDraw, abortiveDraw }

enum CallType { none, chi, pon, kan, ron }

class SeatState {
  SeatState(this.seat, this.wind, this.isDealer, this.points);

  final int seat;
  final Wind wind;
  bool isDealer;
  int points;

  List<Tile> hand = [];
  List<Tile> pond = [];
  List<Meld> melds = [];

  bool riichi = false;
  bool doubleRiichi = false;
  bool ippatsu = false;
  int riichiPondIndex = -1;

  /// The tile drawn this turn (null once discarded).
  Tile? drawn;

  /// Tiles this seat has discarded, used for furiten. Unlike [pond] this keeps
  /// tiles that were later called away, so own-discard furiten still applies.
  final List<Tile> allDiscards = [];

  /// Temporary furiten: set when this seat passed up a winning tile (any
  /// player's discard that completed its wait) and cleared on this seat's next
  /// draw. While the seat is in riichi the same miss instead latches
  /// [riichiFuriten] permanently.
  bool tempFuriten = false;

  /// Permanent (riichi) furiten: once a hand in riichi passes up a winning
  /// tile it can never declare ron for the rest of the round. Never cleared.
  bool riichiFuriten = false;

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
}

/// A pending call opportunity for one seat after a discard.
class CallOption {
  CallOption(this.seat, this.types);
  final int seat;
  final Set<CallType> types;
}

class Round {
  Round({
    required int seed,
    required this.dealer,
    required this.roundWind,
    required this.honba,
    required this.riichiSticks,
    required List<int> startingPoints,
  })  : wall = Wall(seed),
        startPoints = List.of(startingPoints) {
    seats = List.generate(4, (i) {
      final wind = Wind.values[(i - dealer + 4) % 4];
      return SeatState(i, wind, i == dealer, startingPoints[i]);
    });
    final dealt = wall.deal();
    for (var i = 0; i < 4; i++) {
      seats[i].hand = sortByType(dealt[i]);
    }
    turn = dealer;
    _beginDraw();
  }

  final Wall wall;
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

  SeatState get current => seats[turn];

  // --- turn flow -----------------------------------------------------------

  void _beginDraw() {
    phase = RoundPhase.drawing;
    if (wall.isEmpty) {
      _exhaustiveDraw();
      return;
    }
    final tile = wall.drawLive();
    // A fresh draw ends temporary (non-riichi) furiten; permanent riichi
    // furiten is untouched.
    current.tempFuriten = false;
    current.drawn = tile;
    current.hand = [...sortByType(current.hand), tile];
    phase = RoundPhase.discarding;
  }

  /// After a kan, draw from the dead wall instead.
  void _drawReplacement() {
    final tile = wall.drawDeadWall();
    current.tempFuriten = false;
    current.drawn = tile;
    current.hand = [...sortByType(current.hand), tile];
    phase = RoundPhase.discarding;
  }

  // --- queries -----------------------------------------------------------

  List<Tile> legalDiscards(int seat) {
    final s = seats[seat];
    if (s.riichi) {
      // Must discard the drawn tile (tsumogiri) unless it forms a closed kan.
      return s.drawn != null ? [s.drawn!] : s.hand;
    }
    return s.hand;
  }

  bool canTsumo(int seat) {
    final s = seats[seat];
    if (s.hand.length % 3 != 2) return false;
    final winTile = s.drawn;
    if (winTile == null) return false;
    final concealed = [...s.hand]..remove(winTile);
    return _winsWith(s, concealed, winTile, isTsumo: true);
  }

  bool canRon(int seat, Tile discard) {
    final s = seats[seat];
    if (seat == pendingDiscardSeat) return false;
    if (s.hand.length % 3 != 1) return false;
    if (_isFuriten(s)) return false;
    return _winsWith(s, s.hand, discard, isTsumo: false);
  }

  /// Whether [seat] is tenpai but barred from declaring ron by furiten. Drives
  /// the UI's furiten marker; the same check gates every seat's [canRon] so no
  /// player — human or bot — can ron off a furiten wait.
  bool isFuriten(int seat) {
    final s = seats[seat];
    if (waitTiles(s.hand, openMelds: s.melds.length).isEmpty) return false;
    return _isFuriten(s);
  }

  bool canRiichi(int seat) {
    final s = seats[seat];
    return !s.riichi &&
        s.closed &&
        s.points >= 1000 &&
        wall.remaining >= 4 &&
        _anyRiichiDiscardTenpai(s);
  }

  bool canPon(int seat, Tile discard) {
    if (seat == pendingDiscardSeat) return false;
    final s = seats[seat];
    if (s.riichi) return false;
    return s.hand.where((t) => t.type == discard.type).length >= 2;
  }

  /// Chi is open only to the seat immediately after the discarder — its
  /// kamicha — and only on a suit tile it can complete a run with.
  bool canChi(int seat, Tile discard) {
    if (seat == pendingDiscardSeat) return false;
    if (seat != (pendingDiscardSeat + 1) % 4) return false;
    if (seats[seat].riichi) return false;
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
        final index = hand.indexWhere(
            (t) => t.type == need && !used.contains(t.id));
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
    if (s.riichi || !wall.canKan) return false;
    return s.hand.where((t) => t.type == discard.type).length >= 3;
  }

  List<TileType> closedKanTypes(int seat) {
    final s = seats[seat];
    if (!wall.canKan) return const [];
    final byType = <TileType, int>{};
    for (final t in s.hand) {
      byType[t.type] = (byType[t.type] ?? 0) + 1;
    }
    final out = byType.entries.where((e) => e.value == 4).map((e) => e.key).toList();
    if (s.riichi) {
      // In riichi a closed kan must not change the wait; approximate by
      // allowing it only if the kan tile isn't part of any wait shape.
      return out.where((t) => _kanKeepsWait(s, t)).toList();
    }
    return out;
  }

  bool _winsWith(SeatState s, List<Tile> concealed, Tile winTile,
      {required bool isTsumo}) {
    final counts = toCounts34([...concealed, winTile]);
    if (!isAgari(counts, meldCount: s.melds.length)) return false;
    final score = _score(s, concealed, winTile, isTsumo: isTsumo, dryRun: true);
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
    final waits = waitTiles(s.hand, openMelds: s.melds.length).toSet();
    if (waits.isEmpty) return true;
    if (s.allDiscards.any((d) => waits.contains(d.type))) return true;
    return s.tempFuriten;
  }

  /// Any seat (other than the discarder) whose wait includes [discard] but did
  /// not claim it is now furiten: temporarily until its next draw, or —
  /// if it is in riichi — permanently for the rest of the round.
  void _registerMissedRon(Tile discard, int discarder) {
    for (var i = 0; i < 4; i++) {
      if (i == discarder) continue;
      final s = seats[i];
      final waits = waitTiles(s.hand, openMelds: s.melds.length);
      if (!waits.contains(discard.type)) continue;
      s.tempFuriten = true;
      if (s.riichi) s.riichiFuriten = true;
    }
  }

  bool _anyRiichiDiscardTenpai(SeatState s) {
    for (var i = 0; i < s.hand.length; i++) {
      final rest = [...s.hand]..removeAt(i);
      if (isTenpai(rest, openMelds: s.melds.length)) return true;
    }
    return false;
  }

  bool _kanKeepsWait(SeatState s, TileType t) {
    final before = waitTiles([...s.hand]..removeWhere((x) => x.type == t),
        openMelds: s.melds.length + 1);
    // conservative: only if the hand without those 4 is still tenpai on the
    // same tiles
    final without = s.hand.where((x) => x.type != t).toList();
    final after = waitTiles(without, openMelds: s.melds.length + 1);
    return before.toSet().containsAll(after) && after.toSet().containsAll(before);
  }

  // --- actions ---------------------------------------------------------

  void discard(int seat, Tile tile, {bool declareRiichi = false}) {
    assert(phase == RoundPhase.discarding && seat == turn);
    final s = current;

    // Once riichi is declared the hand is frozen: every later discard must be
    // the just-drawn tile (tsumogiri). A concealed kan goes through
    // [closedKan], not here, so this does not block it. On the declaring turn
    // itself `s.riichi` is still false, so the declaration discard is free.
    if (s.riichi && s.drawn != null) {
      tile = s.drawn!;
    }

    if (declareRiichi) {
      s.riichi = true;
      s.ippatsu = true;
      if (_firstGoAround) s.doubleRiichi = true;
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

    // Clear other seats' ippatsu once a call-free go-around is broken by any
    // discard that isn't their own riichi turn.
    for (final o in seats) {
      if (o.seat != seat && o.riichi && o.riichiPondIndex != o.pond.length) {
        // ippatsu window: only the turn immediately after declaration
      }
    }

    pendingDiscard = tile;
    pendingDiscardSeat = seat;
    callOptions = _collectCallOptions(tile, seat);
    if (callOptions.isEmpty) {
      // No one can act on it, so no one is claiming it: register the miss now.
      _registerMissedRon(tile, seat);
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

    final ronners =
        choice.entries.where((e) => e.value == CallType.ron).map((e) => e.key).toList();
    if (ronners.isNotEmpty) {
      _applyRon(ronners, pendingDiscard!, pendingDiscardSeat);
      return;
    }

    // The discard cleared the call window unclaimed. Any seat waiting on it
    // that chose not to ron (or had no yaku to ron with) is now furiten —
    // permanently if it is in riichi, otherwise until its next draw. This runs
    // even when the tile is then ponned/kanned: the missed ron still counts.
    _registerMissedRon(pendingDiscard!, pendingDiscardSeat);

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
      _applyChi(chiSeat!, pendingDiscard!, pendingDiscardSeat,
          chiLow[chiSeat!]);
      return;
    }

    pendingDiscard = null;
    pendingDiscardSeat = -1;
    callOptions = const [];
    _advanceTurn();
  }

  void declareTsumo(int seat) {
    assert(seat == turn);
    final s = seats[seat];
    final winTile = s.drawn!;
    final concealed = [...s.hand]..remove(winTile);
    final score = _score(s, concealed, winTile, isTsumo: true);
    _finishWin([seat], score, loser: null, winTile: winTile);
  }

  void closedKan(int seat, TileType type) {
    assert(seat == turn && phase == RoundPhase.discarding);
    final s = current;
    final taken = <Tile>[];
    s.hand.removeWhere((t) {
      if (t.type == type && taken.length < 4) {
        taken.add(t);
        return true;
      }
      return false;
    });
    s.melds.add(Meld(kind: MeldKind.kan, low: type, concealed: true, tiles: taken));
    s.drawn = null;
    _drawReplacement();
  }

  // --- call application ---------------------------------------------------

  void _applyChi(int seat, Tile discard, int discarder, TileType? requestedLow) {
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

  void _applyPonOrKan(int seat, Tile discard, int discarder, {required bool kan}) {
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
      _drawReplacement();
    } else {
      phase = RoundPhase.discarding;
    }
  }

  void _applyRon(List<int> ronners, Tile discard, int discarder) {
    // Score each winner; sum deltas. Head-bump is not modelled — all valid
    // ronners win (double/triple ron).
    HandScore? firstScore;
    final deltas = <int, int>{for (var i = 0; i < 4; i++) i: 0};
    for (final w in ronners) {
      final s = seats[w];
      final score = _score(s, s.hand, discard, isTsumo: false);
      firstScore ??= score;
      deltas[w] = deltas[w]! + score.points + honba * 300;
      deltas[discarder] = deltas[discarder]! - score.points - honba * 300;
    }
    // riichi sticks go to the first ronner (closest in turn order after discarder)
    ronners.sort((a, b) =>
        ((a - discarder + 4) % 4).compareTo((b - discarder + 4) % 4));
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
      scores: [for (final w in ronners) _score(seats[w], seats[w].hand, discard, isTsumo: false)],
      winTiles: {for (final w in ronners) w: discard},
      pointDeltas: _handDeltas(),
      label: ronners.length > 1 ? 'Multiple Ron' : 'Ron',
    );
    _postFinish(dealerRepeat: dealerWins);
  }

  void _finishWin(List<int> winners, HandScore score, {int? loser, Tile? winTile}) {
    final deltas = <int, int>{for (var i = 0; i < 4; i++) i: 0};
    final w = winners.first;

    // Tsumo only (ron goes through _applyRon).
    for (var i = 0; i < 4; i++) {
      if (i == w) continue;
      final base = seats[w].isDealer
          ? score.nonDealerPays
          : (i == dealer ? score.dealerPays : score.nonDealerPays);
      final pay = base + honba * 100;
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
      label: 'Tsumo',
    );
    _postFinish(dealerRepeat: winners.contains(dealer));
  }

  void _exhaustiveDraw() {
    final tenpai = <int>[];
    for (var i = 0; i < 4; i++) {
      if (isTenpai(seats[i].hand, openMelds: seats[i].melds.length)) tenpai.add(i);
    }
    final deltas = <int, int>{for (var i = 0; i < 4; i++) i: 0};
    final noten = [for (var i = 0; i < 4; i++) i].where((i) => !tenpai.contains(i)).toList();
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
    _postFinish(dealerRepeat: tenpai.contains(dealer));
  }

  void _postFinish({required bool dealerRepeat}) {
    // honba / riichi-stick carry is applied by the game controller when it
    // starts the next round; expose the intent via the result label.
  }

  void _advanceTurn() {
    // Clear the ippatsu window for anyone whose declaration turn has passed.
    for (final s in seats) {
      if (s.riichi && s.riichiPondIndex >= 0 && s.seat != turn) {
        final sinceDeclare = s.pond.length - 1 - s.riichiPondIndex;
        if (sinceDeclare >= 0 && s.seat != turn) {
          // ippatsu only survives to the declarer's own next draw
        }
      }
    }
    seats[turn].drawn = null;
    turn = (turn + 1) % 4;
    // ippatsu is lost once it comes back around to the declarer
    if (seats[turn].riichi && seats[turn].ippatsu && seats[turn].pond.isNotEmpty) {
      seats[turn].ippatsu = false;
    }
    _beginDraw();
  }

  // --- scoring bridge --------------------------------------------------

  HandScore _score(SeatState s, List<Tile> concealed, Tile winTile,
      {required bool isTsumo, bool dryRun = false}) {
    final ctx = ScoreContext(
      roundWind: roundWind,
      seatWind: s.wind,
      isTsumo: isTsumo,
      closed: s.closed,
      riichi: s.riichi && !s.doubleRiichi,
      doubleRiichi: s.doubleRiichi,
      ippatsu: s.ippatsu,
      haitei: isTsumo && wall.isEmpty,
      houtei: !isTsumo && wall.isEmpty,
      doraIndicators: wall.doraIndicators(),
      uraIndicators: wall.uraDoraIndicators(),
      akaCount: [...concealed, winTile].where((t) => t.aka).length +
          s.melds.expand((m) => m.tiles).where((t) => t.aka).length,
    );
    return scoreHand(concealed, winTile, s.melds, ctx, isDealer: s.isDealer);
  }
}
