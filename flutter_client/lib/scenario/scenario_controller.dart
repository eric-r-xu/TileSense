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
import '../game/sfx.dart' show Character;
import '../logic/efficiency_engine.dart';
import 'package:mahjong_core/hong_kong/hong_kong_wall.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import 'package:mahjong_core/wall.dart';
import 'scenario.dart';

class ScenarioController extends ChangeNotifier implements GuideHost {
  ScenarioController() {
    rebuild();
  }

  final Scenario scenario = Scenario();
  final _efficiency = EfficiencyEngine();

  @override
  late Round round;

  @override
  EfficiencyReport report = EfficiencyReport.waiting();

  /// Why the guide has nothing to say, when it has nothing to say.
  String? blockedReason;

  // The dial lives on the scenario itself, so the tool bar's button and the
  // guide panel's copy are two views of the same value.
  @override
  PlayStyle get playStyle => scenario.style;

  @override
  void setPlayStyle(PlayStyle value) {
    if (scenario.style == value) return;
    scenario.style = value;
    rebuild();
  }

  @override
  HandFocus get handFocus => scenario.focus;

  @override
  void setHandFocus(HandFocus value) {
    if (scenario.focus == value) return;
    scenario.focus = value;
    rebuild();
  }

  // Carried for [GuideHost] completeness — see [Scenario.strategy]. Not
  // exposed as a toolbar toggle: the builder has no score inputs for the
  // other three seats, so Placement would have nothing to weigh here.
  @override
  Strategy get strategy => scenario.strategy;

  @override
  void setStrategy(Strategy value) {
    if (scenario.strategy == value) return;
    scenario.strategy = value;
    rebuild();
  }

  Ruleset get ruleset => scenario.ruleset;

  /// The style in effect when Hong Kong last pinned it, mirroring
  /// [GameController]'s equivalent stash — the builder has its own
  /// [Scenario] rather than sharing state with the live game.
  PlayStyle? _preHongKongStyle;

  /// Mirrors [_preHongKongStyle] for [Strategy] — see
  /// [GameController._preHongKongStrategy].
  Strategy? _preHongKongStrategy;

  /// Switches the posed table's rules. The tiles are cleared: dora, riichi
  /// and flowers mean nothing under the other game. Style is pinned to
  /// Balanced under Hong Kong, which has nothing left for it to weigh, and
  /// Strategy to Points, which isn't wired up for Hong Kong yet — both
  /// restored on the way back to riichi.
  void setRuleset(Ruleset value) {
    if (scenario.ruleset == value) return;
    if (value.isHongKong) {
      _preHongKongStyle = scenario.style;
      scenario.style = PlayStyle.balanced;
      _preHongKongStrategy = scenario.strategy;
      scenario.strategy = Strategy.points;
    } else {
      if (_preHongKongStyle != null) {
        scenario.style = _preHongKongStyle!;
        _preHongKongStyle = null;
      }
      if (_preHongKongStrategy != null) {
        scenario.strategy = _preHongKongStrategy!;
        _preHongKongStrategy = null;
      }
    }
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
  @override
  Character characterForSeat(int seat) => kSeatCharacters[seat];
  @override
  String seatLabel(int seat) => kSeatNames[seat];

  @override
  bool get humanFuriten =>
      scenario.hand.isNotEmpty && round.isFuriten(kHumanSeat);

  @override
  CallOption? humanCallOption;
  CallAdvice? _callAdvice;

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
      if (ruleset.isHongKong
          ? s.melds.where((m) => !m.concealed).length >=
              HongKongGuideTuning.threatExposedSets
          : s.riichi) {
        return s;
      }
    }
    return null;
  }

  /// Re-pose the table and re-score it. Called after every edit.
  void rebuild() {
    round = _poseRound();
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
      style: scenario.style,
      focus: scenario.focus,
      strategy: scenario.strategy,
      ruleset: ruleset,
      flowers: human.flowers.map((t) => t.type).toList(),
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
      );
      kanAdvice = _kanAdvice(human, context, visible, oppDiscards, passed);
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
          '${kSeatNames[scenario.offeredFrom]}.';
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
      wall: ruleset.isHongKong
          ? HongKongWall.posed(
              remaining: scenario.wallRemaining.clamp(0, scenario.maxWall))
          : Wall.posed(
              remaining: scenario.wallRemaining.clamp(0, scenario.maxWall),
              dora: scenario.dora,
            ),
      startingPoints: List.filled(4, ruleset.startingPoints),
      ruleset: ruleset,
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
      final concealed = 13 - scenario.seats[i].melds.length * 3;
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
