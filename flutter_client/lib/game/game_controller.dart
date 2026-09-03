/// Drives an offline hanchan: owns the [Round], three [SimpleBot]s, the async
/// turn loop, and the live [EfficiencyReport]. Rough analogue of the Vala
/// client's `GameController` + in-process server, collapsed to a single
/// cooperative loop (no threads, no sockets).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/bot.dart';
import '../logic/efficiency_engine.dart';
import '../logic/round.dart';
import '../logic/tile.dart';
import 'sfx.dart';

const int kHumanSeat = 0;

/// How many East-round hands before the game ends (tonpuusen). Renchan can
/// extend past this.
const int kRoundsPerGame = 4;

enum GamePhase { playing, roundEnd, gameEnd }

class GameController extends ChangeNotifier {
  GameController({int? seed}) : _seed = seed ?? DateTime.now().millisecondsSinceEpoch {
    _startGame();
  }

  int _seed;
  final _efficiency = EfficiencyEngine();

  late Round round;
  late List<SimpleBot> _bots;
  List<int> _points = List.filled(4, 25000);
  int _dealer = 0;
  int _roundNumber = 0; // 0-based East 1..4
  int _honba = 0;
  int _riichiSticks = 0;

  GamePhase phase = GamePhase.playing;
  bool autoplay = false;

  /// Hanchan (East + South, 8 hands) when true; East-only (tonpuusen, 4 hands)
  /// when false. Hanchan is the default.
  bool hanchan = true;
  int get _handsPerGame => hanchan ? 8 : 4;

  EfficiencyReport report = EfficiencyReport.waiting();

  /// Bumped on every discard so the UI can run a one-shot animation. When the
  /// discard was NOT the drawn tile (a cut from the concealed hand), the
  /// opponent's hand briefly shows a blank slot so you can see it left.
  int discardSerial = 0;
  int? lastDiscardSeat;
  bool lastDiscardTsumogiri = false;

  void _noteDiscard(int seat, Tile tile) {
    lastDiscardSeat = seat;
    lastDiscardTsumogiri = tile.id == round.seats[seat].drawn?.id;
    discardSerial++;
  }

  /// True while the human seat has a pending call to answer.
  bool get awaitingHumanCall => _humanCallOption != null;
  CallOption? _humanCallOption;
  CallOption? get humanCallOption => _humanCallOption;

  Timer? _loopTimer;
  bool _disposed = false;

  /// When paused the async turn loop stops (bots and autoplay freeze). Toggled
  /// by pressing Escape.
  bool paused = false;
  void togglePause() {
    paused = !paused;
    if (!paused) _scheduleLoop();
    notifyListeners();
  }

  int get roundNumber => _roundNumber;
  int get honba => _honba;
  int get riichiSticks => _riichiSticks;

  /// East for hands 1-4, South for 5-8 (hanchan).
  Wind get roundWind => _roundNumber < 4 ? Wind.east : Wind.south;

  /// 1-4 within the current round wind.
  int get handInWind => (_roundNumber % 4) + 1;
  List<int> get tablePoints => _points;

  void setHanchan(bool value) {
    if (hanchan == value) return;
    hanchan = value;
    newGame();
  }

  // --- lifecycle -------------------------------------------------------

  void _startGame() {
    _points = List.filled(4, 25000);
    _dealer = 0;
    _roundNumber = 0;
    _honba = 0;
    _riichiSticks = 0;
    phase = GamePhase.playing;
    _startRound();
  }

  void newGame() {
    _seed = DateTime.now().millisecondsSinceEpoch;
    _startGame();
    notifyListeners();
  }

  void _startRound() {
    round = Round(
      seed: _seed + _roundNumber * 100 + _honba,
      dealer: _dealer,
      roundWind: roundWind,
      honba: _honba,
      riichiSticks: _riichiSticks,
      startingPoints: List.of(_points),
    );
    _bots = [for (var i = 0; i < 4; i++) SimpleBot(_seed + i * 7 + _roundNumber)];
    _humanCallOption = null;
    phase = GamePhase.playing;
    _refreshReport();
    _scheduleLoop();
  }

  void continueFromRoundEnd() {
    if (phase != GamePhase.roundEnd) return;
    final r = round.result!;

    // Apply honba / dealer rotation.
    final dealerKept = r.kind == RoundEndKind.exhaustiveDraw
        ? r.tenpaiAtDraw.contains(_dealer)
        : r.winners.contains(_dealer);

    _riichiSticks = round.riichiSticks; // leftover sticks (draw) carry
    if (r.kind == RoundEndKind.exhaustiveDraw || dealerKept) {
      _honba += 1;
    } else {
      _honba = 0;
      _dealer = (_dealer + 1) % 4;
      _roundNumber += 1;
    }
    _points = [for (var i = 0; i < 4; i++) round.seats[i].points];

    final tobi = _points.any((p) => p < 0);
    if (tobi || (_roundNumber >= _handsPerGame && !dealerKept)) {
      phase = GamePhase.gameEnd;
      notifyListeners();
      return;
    }
    _startRound();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loopTimer?.cancel();
    super.dispose();
  }

  // --- the loop -------------------------------------------------------

  // Opponents act at half the old pace (960 ms vs 480 ms per step).
  static const Duration _stepDelay = Duration(milliseconds: 960);

  void _scheduleLoop() {
    if (_disposed || paused || (_loopTimer?.isActive ?? false)) return;
    _loopTimer = Timer(_stepDelay, _tick);
  }

  void _tick() {
    if (_disposed || paused) return;
    if (round.finished) {
      if (phase != GamePhase.roundEnd && phase != GamePhase.gameEnd) {
        phase = GamePhase.roundEnd;
        _points = [for (var i = 0; i < 4; i++) round.seats[i].points];
        _playRoundEndSfx();
        notifyListeners();
      }
      return;
    }

    switch (round.phase) {
      case RoundPhase.callOffer:
        _resolveCallPhase();
        break;
      case RoundPhase.discarding:
        if (round.turn == kHumanSeat && !autoplay) {
          _refreshReport();
          notifyListeners();
        } else {
          _botOrAutoTurn(round.turn);
        }
        break;
      case RoundPhase.drawing:
      case RoundPhase.finished:
        _scheduleLoop();
        break;
    }
  }

  void _botOrAutoTurn(int seat) {
    final bot = _bots[seat];
    final decision = bot.decideTurn(round, seat);
    if (decision.tsumo) {
      round.declareTsumo(seat);
    } else if (decision.closedKan != null) {
      Sfx.i.play(SfxKind.kan);
      round.closedKan(seat, decision.closedKan!);
    } else {
      if (decision.riichi) Sfx.i.play(SfxKind.riichi);
      final tile = decision.discard ?? round.legalDiscards(seat).first;
      _noteDiscard(seat, tile);
      round.discard(seat, tile, declareRiichi: decision.riichi);
    }
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  void _resolveCallPhase() {
    final choices = <int, CallType>{};
    for (final opt in round.callOptions) {
      if (opt.seat == kHumanSeat && !autoplay) {
        _humanCallOption = opt;
        notifyListeners();
        return; // wait for the human
      }
      final bot = _bots[opt.seat];
      final c = autoplay && opt.seat == kHumanSeat
          ? _autoHumanCall(opt)
          : bot.decideCall(round, opt.seat, round.pendingDiscard!, opt.types);
      if (c != CallType.none) choices[opt.seat] = c;
    }
    _humanCallOption = null;
    _playCallSfx(choices.values);
    round.resolveCalls(choices);
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  /// A win chime at round end, a call click for a mid-round pon / kan / chi.
  void _playRoundEndSfx() {
    switch (round.result?.kind) {
      case RoundEndKind.ron:
        Sfx.i.play(SfxKind.ron);
        break;
      case RoundEndKind.tsumo:
        Sfx.i.play(SfxKind.tsumo);
        break;
      default:
        break;
    }
  }

  void _playCallSfx(Iterable<CallType> calls) {
    if (calls.contains(CallType.ron)) return; // handled at round end
    if (calls.contains(CallType.kan)) {
      Sfx.i.play(SfxKind.kan);
    } else if (calls.contains(CallType.pon)) {
      Sfx.i.play(SfxKind.pon);
    }
  }

  CallType _autoHumanCall(CallOption opt) {
    // Autoplay is conservative: only auto-ron.
    return opt.types.contains(CallType.ron) ? CallType.ron : CallType.none;
  }

  // --- human input ---------------------------------------------------

  void humanDiscard(Tile tile, {bool declareRiichi = false}) {
    if (round.finished || round.turn != kHumanSeat || round.phase != RoundPhase.discarding) {
      return;
    }
    Sfx.i.play(declareRiichi ? SfxKind.riichi : SfxKind.discard);
    _noteDiscard(kHumanSeat, tile);
    round.discard(kHumanSeat, tile, declareRiichi: declareRiichi);
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  void humanTsumo() {
    if (round.canTsumo(kHumanSeat) && round.turn == kHumanSeat) {
      round.declareTsumo(kHumanSeat);
      phase = GamePhase.roundEnd;
      notifyListeners();
    }
  }

  void humanClosedKan(TileType type) {
    if (round.turn == kHumanSeat && round.phase == RoundPhase.discarding) {
      Sfx.i.play(SfxKind.kan);
      round.closedKan(kHumanSeat, type);
      _refreshReport();
      notifyListeners();
      _scheduleLoop();
    }
  }

  void answerCall(CallType choice) {
    final opt = _humanCallOption;
    if (opt == null) return;
    final choices = <int, CallType>{};
    if (choice != CallType.none) choices[opt.seat] = choice;

    // Let the remaining bot seats decide too.
    for (final other in round.callOptions) {
      if (other.seat == opt.seat) continue;
      final c = _bots[other.seat]
          .decideCall(round, other.seat, round.pendingDiscard!, other.types);
      if (c != CallType.none) choices[other.seat] = c;
    }
    _humanCallOption = null;
    _playCallSfx(choices.values);
    round.resolveCalls(choices);
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  void setAutoplay(bool value) {
    autoplay = value;
    notifyListeners();
    if (value) _scheduleLoop();
  }

  // --- efficiency report -------------------------------------------

  void _refreshReport() {
    if (round.finished ||
        round.turn != kHumanSeat ||
        round.phase != RoundPhase.discarding) {
      // Still show a defensive read if the human is under threat.
      final human = round.seats[kHumanSeat];
      final riichiOpp = _riichiOpponent();
      if (riichiOpp != null && human.hand.isNotEmpty) {
        report = _efficiency.analyze(
          hand: human.hand,
          visibleCounts34: _visibleCounts(),
          canRiichi: false,
          valueContext: _efficiencyValueContext(human),
          defenseHand: human.hand,
          opponentDiscards: riichiOpp.pond.map((t) => t.type).toList(),
          allDiscards: _allDiscardTypes(),
          opponentRiichi: true,
        );
      } else {
        report = EfficiencyReport.waiting();
      }
      return;
    }

    final human = round.seats[kHumanSeat];
    final riichiOpp = _riichiOpponent();
    report = _efficiency.analyze(
      hand: human.hand,
      visibleCounts34: _visibleCounts(),
      canRiichi: round.canRiichi(kHumanSeat),
      valueContext: _efficiencyValueContext(human),
      defenseHand: riichiOpp != null ? human.hand : null,
      opponentDiscards:
          riichiOpp != null ? riichiOpp.pond.map((t) => t.type).toList() : const [],
      allDiscards: _allDiscardTypes(),
      opponentRiichi: riichiOpp != null,
    );
  }

  EfficiencyValueContext _efficiencyValueContext(SeatState seat) =>
      EfficiencyValueContext(
        melds: seat.melds,
        roundWind: round.roundWind,
        seatWind: seat.wind,
        isDealer: seat.isDealer,
        inRiichi: seat.riichi,
        wallTilesRemaining: round.wall.remaining,
        doraIndicators: round.wall.doraIndicators(),
      );

  SeatState? _riichiOpponent() {
    for (final s in round.seats) {
      if (s.seat != kHumanSeat && s.riichi) return s;
    }
    return null;
  }

  List<TileType> _allDiscardTypes() =>
      [for (final s in round.seats) ...s.pond.map((t) => t.type)];

  List<int> _visibleCounts() {
    final counts = List<int>.filled(34, 0);
    for (final s in round.seats) {
      for (final t in s.pond) {
        counts[t.type.index - 1]++;
      }
      for (final m in s.melds) {
        for (final t in m.types) {
          counts[t.index - 1]++;
        }
      }
    }
    for (final t in round.seats[kHumanSeat].hand) {
      counts[t.type.index - 1]++;
    }
    for (final ind in round.wall.doraIndicators()) {
      counts[ind.index - 1]++;
    }
    return counts;
  }

  // --- convenience for the UI -------------------------------------

  bool get humanCanTsumo =>
      round.turn == kHumanSeat &&
      round.phase == RoundPhase.discarding &&
      round.canTsumo(kHumanSeat);

  bool get humanCanRiichi =>
      round.turn == kHumanSeat &&
      round.phase == RoundPhase.discarding &&
      round.canRiichi(kHumanSeat);

  List<TileType> get humanClosedKanTypes => round.turn == kHumanSeat &&
          round.phase == RoundPhase.discarding
      ? round.closedKanTypes(kHumanSeat)
      : const [];

  bool get isHumanTurn =>
      round.turn == kHumanSeat && round.phase == RoundPhase.discarding && !round.finished;

  /// The tile the auto-player would discard on the human's turn (for the green
  /// "what autoplay would do" hint). Null when it is not the human's turn.
  TileType? get autoplayDiscardType {
    if (!isHumanTurn) return null;
    return _bots[kHumanSeat].decideTurn(round, kHumanSeat).discard?.type;
  }
}
