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

  EfficiencyReport report = EfficiencyReport.waiting();

  /// True while the human seat has a pending call to answer.
  bool get awaitingHumanCall => _humanCallOption != null;
  CallOption? _humanCallOption;
  CallOption? get humanCallOption => _humanCallOption;

  Timer? _loopTimer;
  bool _disposed = false;

  int get roundNumber => _roundNumber;
  int get honba => _honba;
  int get riichiSticks => _riichiSticks;
  Wind get roundWind => Wind.east;
  List<int> get tablePoints => _points;

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
      roundWind: Wind.east,
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
    if (tobi || (_roundNumber >= kRoundsPerGame && !dealerKept)) {
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

  void _scheduleLoop() {
    if (_disposed || (_loopTimer?.isActive ?? false)) return;
    _loopTimer = Timer(const Duration(milliseconds: 480), _tick);
  }

  void _tick() {
    if (_disposed) return;
    if (round.finished) {
      if (phase != GamePhase.roundEnd && phase != GamePhase.gameEnd) {
        phase = GamePhase.roundEnd;
        _points = [for (var i = 0; i < 4; i++) round.seats[i].points];
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
      round.closedKan(seat, decision.closedKan!);
    } else {
      final tile = decision.discard ?? round.legalDiscards(seat).first;
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
    round.resolveCalls(choices);
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
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
          openMelds: human.melds.length,
          canRiichi: false,
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
      openMelds: human.melds.length,
      canRiichi: round.canRiichi(kHumanSeat),
      defenseHand: riichiOpp != null ? human.hand : null,
      opponentDiscards:
          riichiOpp != null ? riichiOpp.pond.map((t) => t.type).toList() : const [],
      allDiscards: _allDiscardTypes(),
      opponentRiichi: riichiOpp != null,
    );
  }

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
}
