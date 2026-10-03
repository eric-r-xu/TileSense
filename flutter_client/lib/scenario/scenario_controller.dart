/// Scores a posed [Scenario] with the same TileSense guide the live game uses.
///
/// Isolated from [GameController] by construction: no bots, no turn timer, no
/// telemetry, no autoplay, no wall to draw from. It builds a [Round.posed] so
/// the real table / hand / guide widgets have something to render, and then
/// hands the same inputs to the same [EfficiencyEngine].
library;

import 'package:flutter/foundation.dart';

import '../game/game_controller.dart';
import '../game/guide_host.dart';
import '../game/mortal_advisor.dart';
import '../game/sfx.dart' show Character;
import '../logic/auto_dials.dart';
import '../logic/efficiency_engine.dart';
import 'package:mahjong_core/hong_kong/hong_kong_wall.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:mahjong_core/wall.dart';
import 'scenario.dart';
import 'scenario_mjai.dart';

class ScenarioController extends ChangeNotifier implements GuideHost {
  /// [seatWind] is the wind you start on (East when null).
  ScenarioController({Wind? seatWind, @visibleForTesting MortalAdvisor? mortal})
      : _mortal =
            mortal ?? (kMortalUrl.isEmpty ? null : MortalAdvisor(kMortalUrl)) {
    if (seatWind != null) scenario.seatWind = seatWind;
    rebuild();
  }

  final MortalAdvisor? _mortal;

  // Bumped by every edit, so a reply to a table since changed is dropped.
  int _mortalAsk = 0;
  bool _disposed = false;

  final Scenario scenario = Scenario();
  final _efficiency = EfficiencyEngine();

  @override
  late Round round;

  @override
  EfficiencyReport report = EfficiencyReport.waiting();

  /// Why the guide has nothing to say, when it has nothing to say.
  String? blockedReason;

  /// The dials a live game would play at this point, as [autoDials] picks
  /// them: the hand is read off the round and seat wind as a hanchan in which
  /// you dealt first (East 1), as single player seats you. Past South 4 is
  /// overtime, one hand at a time.
  AutoDials get _autoDials => autoDials(ruleset,
      minimumPoints: scenario.minimumPoints,
      handsLeft: switch (scenario.roundWind) {
        Wind.east => 8 - scenario.dealer,
        Wind.south => 4 - scenario.dealer,
        _ => 1,
      });

  // The builder has no dials of its own — it plays what the guide would.
  @override
  PlayStyle get playStyle => _autoDials.style;

  @override
  void setPlayStyle(PlayStyle value) {}

  @override
  HandFocus get handFocus => _autoDials.focus;

  @override
  void setHandFocus(HandFocus value) {}

  // Always Points: the builder has no score inputs for the other three
  // seats, so Placement would have nothing to weigh here.
  @override
  Strategy get strategy => Strategy.points;

  @override
  void setStrategy(Strategy value) {}

  Ruleset get ruleset => scenario.ruleset;

  /// Switches the posed table's rules. The tiles are cleared: dora, riichi
  /// and flowers mean nothing under the other game. The dials follow the
  /// rules on their own (see [_autoDials]).
  void setRuleset(Ruleset value) {
    if (scenario.ruleset == value) return;
    scenario.ruleset = value;
    scenario.clear();
    rebuild();
  }

  // A posed table never animates a discard.
  @override
  int get discardSerial => 0;
  @override
  int? get lastDiscardSeat => null;
  @override
  bool get lastDiscardTsumogiri => false;

  @override
  int get handInWind => 1;
  @override
  int get honba => scenario.honba;
  // The builder poses a single static hand — there is no dealer-repeat
  // streak to show.
  @override
  int get dealerRepeat => 0;
  @override
  int? get turnDeadlineMs => null;
  // The builder has no characters: its table draws no portraits, and seats
  // go by where they sit. [GuideHost] still asks for a character, which
  // nothing here shows.
  @override
  Character characterForSeat(int seat) => kSeatCharacters[seat];
  @override
  String seatLabel(int seat) => kScenarioSeatNames[seat];

  @override
  bool get humanFuriten =>
      scenario.hand.isNotEmpty && round.isFuriten(kHumanSeat);

  @override
  MinimumShortfall get humanMinimumShortfall => scenario.hand.isNotEmpty
      ? round.minimumShortfall(kHumanSeat)
      : MinimumShortfall.none;

  @override
  CallOption? humanCallOption;
  CallAdvice? _callAdvice;

  @override
  MortalAdvice? mortalAdvice;

  /// Idle while the table can't be read yet; failed when no history fits it.
  void _askMortal() {
    final ask = ++_mortalAsk;
    if (_mortal == null || !ruleset.isRiichi) {
      mortalAdvice = null;
      return;
    }
    if (!scenario.isValid ||
        (!scenario.isDiscardRead && scenario.offered == null)) {
      mortalAdvice = MortalAdvice.idle;
      return;
    }
    final events = scenarioMjaiEvents(scenario);
    if (events == null) {
      mortalAdvice = MortalAdvice.failed;
      return;
    }
    mortalAdvice = MortalAdvice.thinking;
    _mortal.advise(events, call: !scenario.isDiscardRead).then(
        (advice) => advice, onError: (Object e) {
      debugPrint('Mortal advice unavailable: $e');
      return MortalAdvice.failed;
    }).then((advice) {
      if (_disposed || ask != _mortalAsk) return;
      mortalAdvice = advice;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  bool get awaitingHumanCall => humanCallOption != null;

  @override
  CallType? get recommendedCall => switch (_callAdvice?.recommended) {
        GuidedAction.ron => CallType.ron,
        GuidedAction.kan => CallType.kan,
        GuidedAction.pon => CallType.pon,
        GuidedAction.chi => CallType.chi,
        _ => CallType.none,
      };

  @override
  String? get recommendedCallReason => _callAdvice?.reason;

  @override
  ({TileType type, bool isAdded, ActionAdvice advice})? kanAdvice;

  @override
  int? get safetyOpponentSeat => _threatOpponent()?.seat;

  /// Whoever is in riichi, or in Hong Kong whoever has exposed three or more
  /// sets — the same threat the live game defends against.
  SeatState? _threatOpponent() {
    for (final s in round.seats) {
      if (s.seat == kHumanSeat) continue;
      if (ruleset.isChineseStyle
          ? s.melds.where((m) => !m.concealed).length >=
              HongKongGuideTuning.threatSetsFor(ruleset)
          : s.riichi) {
        return s;
      }
    }
    return null;
  }

  /// Re-pose the table and re-score it. Called after every edit.
  void rebuild() {
    round = _poseRound();
    _askMortal();
    humanCallOption = null;
    _callAdvice = null;
    kanAdvice = null;
    blockedReason = null;

    final problems = scenario.problems();
    if (problems.isNotEmpty) {
      report = EfficiencyReport.waiting();
      blockedReason = problems.first;
      notifyListeners();
      return;
    }

    final riichiOpp = _threatOpponent();
    final oppDiscards = riichiOpp == null
        ? const <TileType>[]
        : [for (final t in riichiOpp.pond) t.type];
    final passed = riichiOpp == null
        ? const <TileType>[]
        : scenario.passedAfterRiichi(riichiOpp.seat).toList();
    final oppMelds = riichiOpp?.melds ?? const <Meld>[];
    final visible = scenario.visibleCounts34();
    final human = round.seats[kHumanSeat];
    final context = EfficiencyValueContext(
      melds: human.melds,
      roundWind: scenario.roundWind,
      seatWind: human.wind,
      isDealer: human.isDealer,
      inRiichi: human.riichi,
      wallTilesRemaining: scenario.wallRemaining,
      doraIndicators: scenario.dora,
      honba: scenario.honba,
      riichiSticks: scenario.riichiSticks,
      style: playStyle,
      focus: handFocus,
      strategy: strategy,
      ruleset: ruleset,
      flowers: human.flowers.map((t) => t.type).toList(),
      minimumFaan: scenario.minimumFaan,
      minimumPoints: scenario.minimumPoints,
    );

    if (scenario.isDiscardRead) {
      report = _efficiency.analyze(
        hand: human.hand,
        visibleCounts34: visible,
        canRiichi: _canRiichi(human),
        valueContext: context,
        defenseHand: riichiOpp != null ? human.hand : null,
        opponentDiscards: oppDiscards,
        passedDiscardsAfterRiichi: passed,
        opponentRiichi: riichiOpp != null,
        opponentIsDealer: riichiOpp?.isDealer ?? false,
        opponentMelds: oppMelds,
      );
      kanAdvice =
          _kanAdvice(human, context, visible, oppDiscards, passed, oppMelds);
      notifyListeners();
      return;
    }

    // 13 concealed tiles: the read is "should I call this tile?", so it needs
    // a tile on offer to answer.
    final offered = scenario.offered;
    if (offered == null) {
      report = EfficiencyReport.waiting();
      blockedReason = 'Set the tile an opponent just discarded to get a '
          'call recommendation, or add a 14th tile for a discard read.';
      notifyListeners();
      return;
    }

    final types = <CallType>{
      if (round.canRon(kHumanSeat, offered)) CallType.ron,
      if (round.canPon(kHumanSeat, offered)) CallType.pon,
      if (round.canOpenKan(kHumanSeat, offered)) CallType.kan,
      if (round.canChi(kHumanSeat, offered)) CallType.chi,
    };
    if (types.isEmpty) {
      report = EfficiencyReport.waiting();
      blockedReason = 'Your hand cannot call ${offered.type.code} from '
          '${seatLabel(scenario.offeredFrom)}.';
      notifyListeners();
      return;
    }

    humanCallOption = CallOption(kHumanSeat, types);
    _callAdvice = _efficiency.adviseCall(
      hand: human.hand,
      offered: offered,
      available: {
        for (final t in types)
          if (_guidedFor(t) case final a?) a,
      },
      visibleCounts34: visible,
      context: context,
      opponentDiscards: oppDiscards,
      passedDiscardsAfterRiichi: passed,
      opponentRiichi: riichiOpp != null,
      opponentIsDealer: riichiOpp?.isDealer ?? false,
      opponentMelds: oppMelds,
    );
    // Keep a defensive read on screen next to the call advice.
    report = _efficiency.analyze(
      hand: [...human.hand, offered],
      visibleCounts34: visible,
      canRiichi: false,
      valueContext: context,
      defenseHand: riichiOpp != null ? human.hand : null,
      opponentDiscards: oppDiscards,
      passedDiscardsAfterRiichi: passed,
      opponentRiichi: riichiOpp != null,
      opponentIsDealer: riichiOpp?.isDealer ?? false,
      opponentMelds: oppMelds,
    );
    notifyListeners();
  }

  static GuidedAction? _guidedFor(CallType t) => switch (t) {
        CallType.ron => GuidedAction.ron,
        CallType.chi => GuidedAction.chi,
        CallType.pon => GuidedAction.pon,
        CallType.kan => GuidedAction.kan,
        CallType.none => null,
      };

  /// Riichi needs a closed hand (concealed kans are fine) and a live wall.
  bool _canRiichi(SeatState s) =>
      ruleset.isRiichi && !s.riichi && s.closed && scenario.wallRemaining >= 4;

  ({TileType type, bool isAdded, ActionAdvice advice})? _kanAdvice(
    SeatState human,
    EfficiencyValueContext context,
    List<int> visible,
    List<TileType> oppDiscards,
    List<TileType> passed,
    List<Meld> oppMelds,
  ) {
    final riichiOpp = _threatOpponent() != null;
    for (final type in round.closedKanTypes(kHumanSeat)) {
      return (
        type: type,
        isAdded: false,
        advice: _efficiency.adviseClosedKan(
          hand: human.hand,
          kanType: type,
          visibleCounts34: visible,
          context: context,
          opponentRiichi: riichiOpp,
        ),
      );
    }
    for (final type in round.addedKanTypes(kHumanSeat)) {
      return (
        type: type,
        isAdded: true,
        advice: _efficiency.adviseAddedKan(
          hand: human.hand,
          kanType: type,
          melds: human.melds,
          visibleCounts34: visible,
          context: context,
          opponentRiichi: riichiOpp,
          opponentDiscards: oppDiscards,
          passedDiscardsAfterRiichi: passed,
          opponentMelds: oppMelds,
        ),
      );
    }
    return null;
  }

  /// Build the [Round] the table widgets render, straight from [scenario].
  Round _poseRound() {
    final r = Round.posed(
      dealer: scenario.dealer,
      roundWind: scenario.roundWind,
      honba: scenario.honba,
      riichiSticks: scenario.riichiSticks,
      wall: ruleset.isChineseStyle
          ? HongKongWall.posed(
              remaining: scenario.wallRemaining.clamp(0, scenario.maxWall))
          : Wall.posed(
              remaining: scenario.wallRemaining.clamp(0, scenario.maxWall),
              dora: scenario.dora,
            ),
      startingPoints: List.filled(4, ruleset.startingPoints),
      ruleset: ruleset,
      minimumFaan: scenario.minimumFaan,
      minimumPoints: scenario.minimumPoints,
    );
    for (var i = 0; i < 4; i++) {
      final src = scenario.seats[i];
      final dst = r.seats[i];
      dst.pond = List.of(src.pond);
      dst.allDiscards.addAll(src.pond);
      dst.melds = List.of(src.melds);
      dst.flowers = List.of(src.flowers);
      dst.riichi = src.riichi;
      dst.riichiPondIndex = src.riichiPondIndex;
      dst.passedDiscardsAfterRiichi.addAll(scenario.passedAfterRiichi(i));
    }
    r.seats[kHumanSeat].hand = List.of(scenario.hand);
    // Opponents' concealed tiles are unknown to the guide; show face-down
    // backs at the right count so the table reads correctly.
    for (var i = 1; i < 4; i++) {
      final concealed =
          ruleset.concealedHandSize - scenario.seats[i].melds.length * 3;
      r.seats[i].hand = [
        for (var k = 0; k < concealed; k++)
          Tile(-1000 - i * 20 - k, TileType.blank),
      ];
    }
    r.pendingDiscard = scenario.offered;
    r.pendingDiscardSeat = scenario.offeredFrom;
    return r;
  }

  /// Apply an edit and re-score in one step.
  void edit(void Function(Scenario s) change) {
    change(scenario);
    rebuild();
  }
}
