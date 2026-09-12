/// Four-player Hong Kong round: chow, pung, kong, flowers,
/// zero-faan wins and no draw payments. Legacy riichi fields are inert.
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
  List<Tile> flowers = [];
  bool replacementDraw = false;
  int kongChain = 0;
  int drawCount = 0;

  bool riichi = false;
  bool doubleRiichi = false;
  bool ippatsu = false;
  int riichiPondIndex = -1;

  /// The tile drawn this turn (null once discarded).
  Tile? drawn;

  final List<Tile> allDiscards = [];

  final Set<TileType> passedDiscardsAfterRiichi = {};

  bool tempFuriten = false;

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
    Wall? wall,
    required this.dealer,
    required this.roundWind,
    this.honba = 0,
    this.riichiSticks = 0,
    required List<int> startingPoints,
  })  : wall = wall ?? Wall(seed),
        startPoints = List.of(startingPoints) {
    seats = List.generate(4, (i) {
      final wind = Wind.values[(i - dealer + 4) % 4];
      return SeatState(i, wind, i == dealer, startingPoints[i]);
    });
    final dealt = this.wall.deal();
    for (var i = 0; i < 4; i++) {
      seats[i].hand = sortByType(dealt[i]);
    }
    _replaceDealBonuses(0);
  }

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
  }) : startPoints = List.of(startingPoints) {
    seats = List.generate(4, (i) {
      final wind = Wind.values[(i - dealer + 4) % 4];
      return SeatState(i, wind, i == dealer, startingPoints[i]);
    });
    turn = 0;
    _firstGoAround = false;
    phase = RoundPhase.discarding;
  }

  final Wall wall;
  final int dealer;
  final Wind roundWind;
  int honba;
  int riichiSticks;

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
  Meld? _pendingPung;
  int _pendingPungIndex = -1;

  SeatState get current => seats[turn];
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
    if (seat.flowers.length >= 7) {
      turn = seat.seat;
      seat.drawn = null;
      _flowerSeat = seat.seat;
      _flowerContinuation = resume;
      phase = RoundPhase.discarding;
    } else {
      resume();
    }
  }

  // --- turn flow -----------------------------------------------------------

  void _drawFor(SeatState seat,
      {required bool replacement, required void Function(Tile) onTile}) {
    if (wall.isEmpty) {
      _exhaustiveDraw();
      return;
    }
    final tile = replacement ? wall.drawDeadWall() : wall.drawLive();
    if (tile.type.isBonus) {
      _exposeFlower(
          seat, tile, () => _drawFor(seat, replacement: true, onTile: onTile));
    } else {
      onTile(tile);
    }
  }

  void _acceptDraw(SeatState seat, Tile tile) {
    seat.drawn = tile;
    seat.hand = [...sortByType(seat.hand), tile];
    phase = RoundPhase.discarding;
  }

  void _beginDraw() {
    phase = RoundPhase.drawing;
    current.replacementDraw = false;
    current.kongChain = 0;
    current.drawCount++;
    final seat = current;
    _drawFor(seat,
        replacement: false, onTile: (tile) => _acceptDraw(seat, tile));
  }

  void _drawReplacement() {
    current.replacementDraw = true;
    final seat = current;
    _drawFor(seat,
        replacement: true, onTile: (tile) => _acceptDraw(seat, tile));
  }

  // --- queries -----------------------------------------------------------

  List<Tile> legalDiscards(int seat) =>
      _flowerSeat != null ? [] : seats[seat].hand;

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

    return _winsWith(s, s.hand, discard, isTsumo: false, chankan: chankan);
  }

  /// Compatibility queries: Hong Kong has neither rule.
  bool isFuriten(int seat) => false;
  bool canRiichi(int seat) => false;

  bool canPon(int seat, Tile discard) {
    if (seat == pendingDiscardSeat || wall.isEmpty) return false;
    final s = seats[seat];

    return s.hand.where((t) => t.type == discard.type).length >= 2;
  }

  /// Chi is open only to the seat immediately after the discarder — its
  /// kamicha — and only on a suit tile it can complete a run with.
  bool canChi(int seat, Tile discard) {
    if (seat == pendingDiscardSeat) return false;
    if (seat != (pendingDiscardSeat + 1) % 4 || wall.isEmpty) return false;

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
    if (seat == pendingDiscardSeat || wall.isEmpty) return false;
    final s = seats[seat];
    if (!wall.canKan) return false;
    return s.hand.where((t) => t.type == discard.type).length >= 3;
  }

  List<TileType> closedKanTypes(int seat) {
    final s = seats[seat];
    if (!wall.canKan || _flowerSeat != null) return const [];
    final byType = <TileType, int>{};
    for (final t in s.hand) {
      byType[t.type] = (byType[t.type] ?? 0) + 1;
    }
    final out =
        byType.entries.where((e) => e.value == 4).map((e) => e.key).toList();

    return out;
  }

  List<TileType> addedKanTypes(int seat) {
    final s = seats[seat];
    if (!wall.canKan || _flowerSeat != null) return const [];
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
    if (!isAgari(counts, meldCount: s.melds.length)) return false;
    final score = _score(s, concealed, winTile,
        isTsumo: isTsumo, dryRun: true, chankan: chankan);
    return score.valid;
  }

  // --- actions ---------------------------------------------------------

  void discard(int seat, Tile tile, {bool declareRiichi = false}) {
    if (phase != RoundPhase.discarding || seat != turn) {
      throw StateError('Not this seat’s discard turn');
    }
    final s = current;

    if (_flowerSeat != null) {
      throw StateError('Choose flower win or continue first');
    }
    if (declareRiichi) {
      throw UnsupportedError('Hong Kong mahjong has no riichi');
    }
    if (!s.hand.contains(tile)) throw ArgumentError('Tile is not in this hand');
    s.replacementDraw = false;
    s.kongChain = 0;

    s.hand.remove(tile);
    s.hand = sortByType(s.hand);
    s.drawn = null;
    s.pond.add(tile);
    s.allDiscards.add(tile);

    _discardsThisRound++;
    if (turn == dealer && _discardsThisRound > 1) _firstGoAround = false;

    pendingDiscard = tile;
    pendingDiscardSeat = seat;
    callOptions = _collectCallOptions(tile, seat);
    if (callOptions.isEmpty) {
      // No one can act on it, so no one is claiming it: register the miss now.

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
    if (phase != RoundPhase.callOffer) throw StateError('No call window');
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
        if (_pendingPung != null) {
          seats[pendingDiscardSeat].melds[_pendingPungIndex] = _pendingPung!;
          _pendingPung = null;
        }
        _applyRon(ronners, pendingDiscard!, pendingDiscardSeat, chankan: true);
        return;
      }
      // No one robbed the kan: the missed tile satisfied a real wait, so it
      // counts as a missed ron exactly like an unclaimed discard.

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
    if (seat != turn || phase != RoundPhase.discarding || !canTsumo(seat)) {
      throw StateError('No legal self draw');
    }
    final s = seats[seat];
    if (canFlowerWin(seat)) {
      final score = scoreFlowerWin(s.flowers.length);
      _flowerSeat = null;
      _flowerContinuation = null;
      _finishWin([seat], score, flowerWin: true);
      return;
    }
    final winTile = s.drawn!;
    final concealed = [...s.hand]..remove(winTile);
    final score = _score(s, concealed, winTile, isTsumo: true);
    _finishWin([seat], score, loser: null, winTile: winTile);
  }

  void closedKan(int seat, TileType type) {
    if (seat != turn || phase != RoundPhase.discarding) {
      throw StateError('Not this seat’s kong turn');
    }
    if (!closedKanTypes(seat).contains(type)) {
      throw StateError('Illegal closed kong');
    }
    _firstGoAround = false;
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
    s.drawn = null;
    _drawReplacement();
  }

  /// Shouminkan: fold the matching tile [type] this seat is holding into its
  /// existing open pon, upgrading it to a kan. Every other seat gets one
  /// chankan window to ron the added tile before the kan completes — see
  /// [resolveCalls]'s `_chankanPending` branch.
  void addKan(int seat, TileType type) {
    if (seat != turn || phase != RoundPhase.discarding) {
      throw StateError('Not this seat’s kong turn');
    }
    if (!addedKanTypes(seat).contains(type)) {
      throw StateError('Illegal added kong');
    }
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
    _pendingPung = null;
    _chankanPending = false;
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
    // The sheet's discarder-pays-all rule: only the discarder pays 2x.
    ronners.sort(
        (a, b) => ((a - discarder + 4) % 4).compareTo((b - discarder + 4) % 4));
    HandScore? firstScore;
    final deltas = <int, int>{for (var i = 0; i < 4; i++) i: 0};
    for (final w in ronners) {
      final score = _score(seats[w], seats[w].hand, discard,
          isTsumo: false, chankan: chankan);
      firstScore ??= score;
      deltas[discarder] = deltas[discarder]! - score.points;
      deltas[w] = deltas[w]! + score.points;
    }
    for (final e in deltas.entries) {
      seats[e.key].points += e.value;
    }

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
      label: ronners.length > 1
          ? 'Multiple Wins'
          : (chankan ? 'Robbing a Kong' : 'Win on Discard'),
    );
    _postFinish(dealerRepeat: dealerWins);
  }

  void _finishWin(List<int> winners, HandScore score,
      {int? loser, Tile? winTile, bool flowerWin = false}) {
    final deltas = <int, int>{for (var i = 0; i < 4; i++) i: 0};
    final w = winners.first;

    // Tsumo only (ron goes through _applyRon).
    for (var i = 0; i < 4; i++) {
      if (i == w) continue;
      final base = seats[w].isDealer
          ? score.nonDealerPays
          : (i == dealer ? score.dealerPays : score.nonDealerPays);
      final pay = base;
      deltas[i] = -pay;
      deltas[w] = deltas[w]! + pay;
    }

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
      label: flowerWin ? score.yaku.first.name : 'Self Draw',
    );
    _postFinish(dealerRepeat: winners.contains(dealer));
  }

  void _exhaustiveDraw() {
    final tenpai = <int>[];
    for (var i = 0; i < 4; i++) {
      if (isTenpai(seats[i].hand, openMelds: seats[i].melds.length)) {
        tenpai.add(i);
      }
    }

    phase = RoundPhase.finished;
    result = RoundResult(
      kind: RoundEndKind.exhaustiveDraw,
      winners: const [],
      pointDeltas: _handDeltas(),
      tenpaiAtDraw: tenpai,
      label: 'Exhaustive Draw',
    );
    _postFinish(dealerRepeat: true);
  }

  void _postFinish({required bool dealerRepeat}) {}

  void _advanceTurn() {
    seats[turn].drawn = null;
    turn = (turn + 1) % 4;
    _beginDraw();
  }

  // --- scoring bridge --------------------------------------------------

  HandScore _score(SeatState s, List<Tile> concealed, Tile winTile,
      {required bool isTsumo, bool dryRun = false, bool chankan = false}) {
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
    return scoreHand(concealed, winTile, s.melds, ctx, isDealer: s.isDealer);
  }
}
