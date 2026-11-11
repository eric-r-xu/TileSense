/// Plays a posed Hand Builder hand out: you draw and discard, the three
/// opponents play as [SimpleBot]s, and it runs until the hand is won or the
/// wall runs out.
///
/// It owns a real [Round] (built by [ScenarioController.buildPlayRound]) and
/// drives it with the same calls the live game makes. The bots are run
/// synchronously, so after every action by you the session is either waiting
/// on your next decision or [finished]. Draws are automatic: your turn
/// begins with the tile already in hand.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mahjong_core/bot.dart';
import 'package:mahjong_core/hand_parse.dart' show isTenpai;
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';

import '../game/game_controller.dart' show kHumanSeat;
import '../game/guide_host.dart';
import '../game/mortal_advisor.dart' show MortalAdvice;
import '../game/sfx.dart' show Character;
import '../logic/efficiency_engine.dart';
import 'scenario.dart';
import 'scenario_controller.dart';

class PlayOutSession extends ChangeNotifier implements TableGameHost {
  /// [stepDelay] is the pause before each move by an opponent, so a turn
  /// plays out one seat at a time where it can be followed. Zero plays them
  /// all at once, in the same call (for tests).
  PlayOutSession(this._source,
      {this.seed = 1, this.stepDelay = const Duration(milliseconds: 700)}) {
    reset();
  }

  final Duration stepDelay;
  Timer? _timer;

  final ScenarioController _source;

  /// Fixes the wall and the bots, so [reset] replays the same hand.
  final int seed;

  @override
  late Round round;
  late List<SimpleBot> _bots;

  /// What the bots chose for a discard you may call, held until you answer;
  /// [_heldFor] is the tile they were chosen for.
  Map<int, CallType> _botCalls = {};
  Tile? _heldFor;

  /// Draws and discards made so far, for the status line.
  int turns = 0;

  /// The guide: a controller of its own, handed a copy of the live round (as
  /// the [Scenario] it is) at each decision of yours, so the discard, call,
  /// kan and defence reads are exactly the builder's.
  final ScenarioController _guide = ScenarioController(askMortal: false);

  /// Back to the posed hand, with the same wall.
  void reset() {
    round = _source.buildPlayRound(Random(seed));
    _bots = [for (var i = 0; i < 4; i++) SimpleBot(seed + i)];
    _botCalls = {};
    _heldFor = null;
    turns = 0;
    _advance();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    _refreshGuide();
    super.notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _guide.dispose();
    super.dispose();
  }

  bool _guided = false;

  /// Re-reads the table for the guide when you have a decision to make.
  void _refreshGuide() {
    _guided = !finished && (humanToDiscard || humanCall != null);
    if (!_guided) return;
    _copyRound(_guide.scenario);
    _guide.rebuild();
  }

  /// Why the guide has nothing to say right now, when it has nothing to say.
  String? get guideNote => _guided ? _guide.blockedReason : null;

  void _copyRound(Scenario sc) {
    final r = round;
    sc
      ..ruleset = r.ruleset
      ..dealer = r.dealer
      ..roundWind = r.roundWind
      ..honba = r.honba
      ..riichiSticks = r.riichiSticks
      ..minimumFaan = r.minimumFaan
      ..minimumPoints = r.minimumPoints
      ..wallRemaining = r.wall.remaining
      ..points = [for (final seat in r.seats) seat.points];
    sc.dora
      ..clear()
      ..addAll(switch (r.ruleset) {
        Ruleset.riichi || Ruleset.sanma => r.wall.doraIndicators(),
        Ruleset.fuzhou => [if (r.goldIndicator != null) r.goldIndicator!.type],
        _ => _source.scenario.dora,
      });
    final call = humanCall;
    final offered = call == null ? null : r.pendingDiscard;
    sc.offered = offered;
    sc.offeredFrom = r.pendingDiscardSeat;
    for (var i = 0; i < 4; i++) {
      final from = r.seats[i];
      final to = sc.seats[i]
        ..clear()
        ..voidSuit = from.voidSuit
        ..out = from.out
        ..riichi = from.riichi
        ..riichiPondIndex = from.riichiPondIndex;
      // The tile on offer is the one just cut, so the scenario lists it
      // apart from the pond.
      to.pond.addAll([
        for (final t in from.pond)
          if (offered == null || t.id != offered.id) t
      ]);
      to.melds.addAll(from.melds);
      to.flowers.addAll(from.flowers);
      to.kita.addAll(from.kita);
    }
    sc.hand
      ..clear()
      ..addAll(r.seats[kHumanSeat].hand);
  }

  bool get finished => round.finished;
  RoundResult? get result => round.result;

  /// Whether you won, and by what — null while the hand is still going.
  bool get humanWon =>
      finished && (result?.winners.contains(kHumanSeat) ?? false);

  bool get humanToDiscard =>
      !finished &&
      round.phase == RoundPhase.discarding &&
      round.turn == kHumanSeat &&
      !round.canFlowerWin(kHumanSeat);

  /// Hong Kong and its kin: a flower just completed a flower win. Take it
  /// with [tsumo], or [passFlowerWin] to play on.
  bool get flowerWinPending => !finished && round.canFlowerWin(kHumanSeat);

  /// Sanma: a North in hand can be set aside as kita.
  bool get canKita => round.canKita(kHumanSeat);

  /// Your options on a discard another seat just made, or null.
  CallOption? get humanCall {
    if (finished || round.phase != RoundPhase.callOffer) return null;
    for (final o in round.callOptions) {
      if (o.seat == kHumanSeat) return o;
    }
    return null;
  }

  Tile? get offeredTile => round.pendingDiscard;

  bool get canTsumo =>
      (humanToDiscard || flowerWinPending) && round.canTsumo(kHumanSeat);
  bool get canRiichi => humanToDiscard && round.canRiichi(kHumanSeat);
  List<TileType> get closedKans =>
      humanToDiscard ? round.closedKanTypes(kHumanSeat) : const [];
  List<TileType> get chiRuns {
    final tile = offeredTile;
    return humanCall?.types.contains(CallType.chi) ?? false
        ? round.chiSequences(kHumanSeat, tile!)
        : const [];
  }

  /// Whether discarding [tile] could declare riichi: it must leave the
  /// hand ready.
  bool riichiOk(Tile tile) {
    if (!canRiichi) return false;
    final rest = [
      for (final t in round.seats[kHumanSeat].hand)
        if (t.id != tile.id) t
    ];
    return isTenpai(rest, openMelds: round.seats[kHumanSeat].melds.length);
  }

  void discard(Tile tile, {bool riichi = false}) {
    if (!humanToDiscard) return;
    if (riichi && !riichiOk(tile)) return;
    round.discard(kHumanSeat, tile, declareRiichi: riichi);
    turns++;
    _advance();
    notifyListeners();
  }

  void tsumo() {
    if (!canTsumo) return;
    round.declareTsumo(kHumanSeat);
    notifyListeners();
  }

  void passFlowerWin() {
    if (!flowerWinPending) return;
    round.passFlowerWin(kHumanSeat);
    _advance();
    notifyListeners();
  }

  void kita() {
    if (!canKita) return;
    round.declareKita(kHumanSeat);
    _advance();
    notifyListeners();
  }

  /// Pons you could add your fourth tile to.
  List<TileType> get addedKans =>
      humanToDiscard ? round.addedKanTypes(kHumanSeat) : const [];

  void addKan(TileType type) {
    if (!addedKans.contains(type)) return;
    round.addKan(kHumanSeat, type);
    _advance();
    notifyListeners();
  }

  /// Nine different terminals and honors in your first hand: abort it.
  bool get canKyuushu =>
      humanToDiscard && round.canDeclareKyuushu(kHumanSeat);

  void kyuushu() {
    if (!canKyuushu) return;
    round.declareKyuushu(kHumanSeat);
    notifyListeners();
  }

  void closedKan(TileType type) {
    if (!closedKans.contains(type)) return;
    round.closedKan(kHumanSeat, type);
    _advance();
    notifyListeners();
  }

  /// Answers the call on offer: [CallType.none] passes. [chiLow] picks which
  /// run to chi when more than one is possible.
  @override
  void answerCall(CallType type, {TileType? chiLow}) {
    final option = humanCall;
    if (option == null) return;
    round.resolveCalls(
      {..._botCalls, if (type != CallType.none) kHumanSeat: type},
      chiLow: {if (chiLow != null) kHumanSeat: chiLow},
    );
    _botCalls = {};
    _heldFor = null;
    _advance();
    notifyListeners();
  }

  /// Whether an opponent has a move to make: it is their turn, or a discard
  /// of yours (or theirs) is open for them to call and you have no say in it.
  bool get botsToMove =>
      !finished &&
      ((round.phase == RoundPhase.callOffer && humanCall == null) ||
          (round.phase == RoundPhase.discarding && round.turn != kHumanSeat));

  /// Whose move the table is waiting on, while it is not yours.
  int? get actingSeat => botsToMove ? round.turn : null;

  /// Lines up the opponents' moves: one now-and-all-at-once without a delay,
  /// else one per [stepDelay], each shown before the next is made. Stops where
  /// you have a decision to make or the hand ends.
  void _advance() {
    _timer?.cancel();
    _timer = null;
    _holdBotCalls();
    if (!botsToMove) return;
    if (stepDelay == Duration.zero) {
      for (var guard = 0; guard < 2000 && botsToMove; guard++) {
        _step();
      }
      _holdBotCalls();
      return;
    }
    _timer = Timer(stepDelay, () {
      _timer = null;
      if (!botsToMove) return;
      _step();
      _advance();
      notifyListeners();
    });
  }

  /// When a discard is on offer to you, settles what the opponents will do
  /// with it, to be resolved together with your answer.
  void _holdBotCalls() {
    final tile = round.pendingDiscard;
    if (round.phase != RoundPhase.callOffer ||
        humanCall == null ||
        tile == null ||
        identical(_heldFor, tile)) {
      return;
    }
    _heldFor = tile;
    _botCalls = _botChoices();
  }

  Map<int, CallType> _botChoices() {
    final choices = <int, CallType>{};
    for (final o in round.callOptions) {
      if (o.seat == kHumanSeat) continue;
      final pick = _bots[o.seat]
          .decideCall(round, o.seat, round.pendingDiscard!, o.types);
      if (pick != CallType.none) choices[o.seat] = pick;
    }
    return choices;
  }

  /// One opponent move.
  void _step() {
    if (round.phase == RoundPhase.callOffer) {
      round.resolveCalls(_botChoices());
    } else {
      _botTurn(round.turn);
    }
  }

  void _botTurn(int seat) {
    final d = _bots[seat].decideTurn(round, seat);
    if (d.tsumo) {
      round.declareTsumo(seat);
    } else if (d.kita) {
      round.declareKita(seat);
    } else if (d.closedKan != null) {
      round.closedKan(seat, d.closedKan!);
    } else if (d.addedKan != null) {
      round.addKan(seat, d.addedKan!);
    } else {
      final tile = d.discard ?? round.legalDiscards(seat).first;
      round.discard(seat, tile, declareRiichi: d.riichi);
    }
  }

  // --- the table's view of the session ---------------------------------
  //
  // The guide has nothing to say while a hand is being played out, and the
  // dials stay as the builder has them.

  @override
  EfficiencyReport get report =>
      _guided ? _guide.report : EfficiencyReport.waiting();
  @override
  PlayStyle get playStyle => _guide.playStyle;
  @override
  void setPlayStyle(PlayStyle value) {}
  @override
  HandFocus get handFocus => _guide.handFocus;
  @override
  void setHandFocus(HandFocus value) {}
  @override
  Strategy get strategy => _guide.strategy;
  @override
  void setStrategy(Strategy value) {}
  @override
  bool get awaitingHumanCall => humanCall != null;
  @override
  CallOption? get humanCallOption => humanCall;
  @override
  CallType? get recommendedCall => _guided ? _guide.recommendedCall : null;
  @override
  String? get recommendedCallReason =>
      _guided ? _guide.recommendedCallReason : null;
  @override
  ({TileType type, bool isAdded, ActionAdvice advice})? get kanAdvice =>
      _guided ? _guide.kanAdvice : null;
  @override
  MortalAdvice? get mortalAdvice => null;
  @override
  int? get safetyOpponentSeat => _guided ? _guide.safetyOpponentSeat : null;
  @override
  bool get humanFuriten => !finished && round.isFuriten(kHumanSeat);
  @override
  MinimumShortfall get humanMinimumShortfall =>
      finished ? MinimumShortfall.none : round.minimumShortfall(kHumanSeat);
  @override
  int get discardSerial => 0;
  @override
  int? get lastDiscardSeat => null;
  @override
  bool get lastDiscardTsumogiri => false;
  @override
  int get handInWind => _source.handInWind;
  @override
  int get honba => _source.honba;
  @override
  int get dealerRepeat => 0;
  @override
  int? get turnDeadlineMs => null;
  @override
  String seatLabel(int seat) => seatNames?[seat] ?? _source.seatLabel(seat);

  /// The seats' names in the language on screen (you, right, across, left),
  /// set by the page; the builder's English ones until then.
  List<String>? seatNames;
  @override
  Character characterForSeat(int seat) => _source.characterForSeat(seat);

  // --- the rest of what the table and the results screen ask of a game ---
  //
  // Most of it has no meaning in a play-out (no clock, sound, undo or Mortal);
  // the rest is the same moves under the names the live game uses.

  /// What "Continue" on the results screen does: the page sets it to deal a
  /// fresh wall, since a play-out has no next hand of its own.
  VoidCallback onContinue = () {};

  @override
  void continueFromRoundEnd() => onContinue();
  @override
  void newGame() => onContinue();

  @override
  bool get isHumanTurn => humanToDiscard;
  @override
  int? get callDeadlineMs => null;
  @override
  bool get humanCanTsumo => canTsumo;
  @override
  bool get humanCanRiichi => canRiichi;
  @override
  List<TileType> get humanClosedKanTypes => closedKans;
  @override
  List<TileType> get humanAddedKanTypes => addedKans;
  @override
  bool get humanCanDeclareKyuushu => canKyuushu;
  @override
  void humanDiscard(Tile tile, {bool declareRiichi = false}) =>
      discard(tile, riichi: declareRiichi);
  @override
  void humanTsumo() => tsumo();
  @override
  void humanClosedKan(TileType type) => closedKan(type);
  @override
  void humanAddKan(TileType type) => addKan(type);
  @override
  void humanPassFlowerWin() => passFlowerWin();
  @override
  void humanDeclareKyuushu() => kyuushu();
  @override
  bool get humanCanKita => canKita;
  @override
  void humanKita() => kita();
  @override
  bool get awaitingHumanVoidSuit => false;
  @override
  void humanDeclareVoidSuit(int suit) {}
  @override
  int get suggestedVoidSuit => round.suggestVoidSuit(kHumanSeat);
  @override
  List<TileType> get humanChiRuns => chiRuns;
  @override
  TileType? get recommendedChiRun => null;
  @override
  bool get soundOn => false;
  @override
  void setSoundOn(bool value) {}
  @override
  bool get autoWin => false;
  @override
  void setAutoWin(bool value) {}
  @override
  bool get autoPass => false;
  @override
  void setAutoPass(bool value) {}
  @override
  AutoplayBrain get autoplayBrain => AutoplayBrain.tilesense;
  @override
  void setAutoplayBrain(AutoplayBrain value) {}
  @override
  bool get mortalAvailable => false;
  @override
  GamePhase get phase => finished ? GamePhase.roundEnd : GamePhase.playing;
  @override
  bool get paused => false;
  @override
  List<int> get tablePoints => [for (final s in round.seats) s.points];
  @override
  bool get canUndo => false;
  @override
  String? get undoLabel => null;
  @override
  void undo() {}
}
