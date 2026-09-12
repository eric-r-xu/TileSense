library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/bot.dart';
import '../logic/efficiency_engine.dart';
import '../logic/round.dart';
import '../logic/tile.dart';
import '../telemetry/telemetry.dart';
import 'guide_host.dart';
import 'sfx.dart';

const int kHumanSeat = 0;

/// Fixed personality per seat: 0 self (Orderic), 1 right (Grant), 2 across
/// (Hubert), 3 left (Astaroth).
const List<Character> kSeatCharacters = [
  Character.orderic,
  Character.grant,
  Character.hubert,
  Character.astaroth,
];
Character _characterForSeat(int seat) => kSeatCharacters[seat];

const List<String> kSeatNames = ['Orderic', 'Grant', 'Hubert', 'Astaroth'];

/// The name shown for a seat in the UI; the human seat is tagged "(you)".
String seatDisplayName(int seat) =>
    seat == kHumanSeat ? '${kSeatNames[seat]} (you)' : kSeatNames[seat];

const int kRoundsPerGame = 4;

enum GamePhase { playing, roundEnd, gameEnd }

class GameController extends ChangeNotifier implements GuideHost {
  GameController({int? seed})
      : _seed = seed ?? DateTime.now().millisecondsSinceEpoch {
    _startGame();
  }

  int _seed;
  final _efficiency = EfficiencyEngine();

  /// Optional gameplay logging — `null` unless the app was built with
  /// `--dart-define=TELEMETRY=true` and a `TELEMETRY_ENDPOINT`. Every call site
  /// uses `_tel?.` so a null instance is a no-op.
  final Telemetry? _tel = Telemetry.maybe();
  String _matchId = '';
  String _roundId = '';

  /// Whether the efficiency guide panel is currently on screen. Set by the
  /// widget layer; only read for telemetry.
  bool guideVisible = false;

  @override
  late Round round;
  late List<SimpleBot> _bots;
  List<int> _points = List.filled(4, 1000);
  int _dealer = 0;
  int _roundNumber = 0; // 0-based East 1..4
  int _honba = 0;
  int _dealSerial = 0;
  int _riichiSticks = 0;

  GamePhase phase = GamePhase.playing;
  bool autoplay = false;

  /// When true the turn loop runs at 2x speed (opponents act twice as fast).
  bool fastMode = false;
  void setFastMode(bool value) {
    if (fastMode == value) return;
    fastMode = value;
    _tel?.settingChange(matchId: _matchId, setting: 'fast_mode', value: value);
    // Re-arm the pending step so the new pace takes effect immediately.
    if (_loopTimer?.isActive ?? false) {
      _loopTimer!.cancel();
      _loopTimer = null;
      _scheduleLoop();
    }
    notifyListeners();
  }

  /// How the guide weighs danger against value. Feeds every score it produces,
  /// so it steers Autoplay — which plays from those scores — as well as the
  /// panel.
  @override
  PlayStyle playStyle = PlayStyle.balanced;
  @override
  void setPlayStyle(PlayStyle value) {
    if (playStyle == value) return;
    playStyle = value;
    _tel?.settingChange(
        matchId: _matchId, setting: 'play_style', value: value.name);
    _refreshReport();
    notifyListeners();
  }

  /// Which hand the guide chases when two are worth the same. Independent of
  /// [playStyle] — that one weighs danger, this one weighs speed against
  /// value — and it steers Autoplay the same way.
  @override
  HandFocus handFocus = HandFocus.balanced;
  @override
  void setHandFocus(HandFocus value) {
    if (handFocus == value) return;
    handFocus = value;
    _tel?.settingChange(
        matchId: _matchId, setting: 'hand_focus', value: value.name);
    _refreshReport();
    notifyListeners();
  }

  bool hanchan = true;
  int get _handsPerGame => hanchan ? 16 : 4;

  @override
  EfficiencyReport report = EfficiencyReport.waiting();

  /// Bumped on every discard so the UI can run a one-shot animation. When the
  /// discard was NOT the drawn tile (a cut from the concealed hand), the
  /// opponent's hand briefly shows a blank slot so you can see it left.
  @override
  int discardSerial = 0;
  @override
  int? lastDiscardSeat;
  @override
  bool lastDiscardTsumogiri = false;

  void _noteDiscard(int seat, Tile tile) {
    lastDiscardSeat = seat;
    lastDiscardTsumogiri = tile.id == round.seats[seat].drawn?.id;
    discardSerial++;
  }

  /// True while the human seat has a pending call to answer.
  @override
  bool get awaitingHumanCall => _humanCallOption != null;
  CallOption? _humanCallOption;
  @override
  CallOption? get humanCallOption => _humanCallOption;

  /// The guide's verdict on [_humanCallOption], cached alongside it.
  CallAdvice? _humanCallAdvice;

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
  @override
  int get honba => _honba;
  int get riichiSticks => _riichiSticks;

  Wind get roundWind => Wind.values[(_roundNumber ~/ 4).clamp(0, 3)];

  /// 1-4 within the current round wind.
  @override
  int get handInWind => (_roundNumber % 4) + 1;
  List<int> get tablePoints => _points;

  void setHanchan(bool value) {
    if (hanchan == value) return;
    hanchan = value;
    newGame();
  }

  // --- lifecycle -------------------------------------------------------

  void _startGame() {
    _points = List.filled(4, 1000);
    _dealer = 0;
    _roundNumber = 0;
    _honba = 0;
    _riichiSticks = 0;
    phase = GamePhase.playing;
    _matchId = newUuid();
    _tel?.matchStart(
      matchId: _matchId,
      seed: _seed,
      hanchan: hanchan,
      fastMode: fastMode,
      autoplay: autoplay,
      guideVisible: guideVisible,
    );
    _startRound();
  }

  void newGame() {
    // A match already in progress is being abandoned for a fresh one.
    if (_matchId.isNotEmpty && phase != GamePhase.gameEnd) {
      _tel?.matchEnd(
        matchId: _matchId,
        reason: 'new_game',
        finalPoints: List.of(_points),
        humanSeat: kHumanSeat,
        humanPlace: _humanPlace(),
      );
    }
    _seed = DateTime.now().millisecondsSinceEpoch;
    _startGame();
    notifyListeners();
  }

  /// 1..4 — the human seat's current standing by points (ties share the higher
  /// place).
  int _humanPlace() => 1 + _points.where((p) => p > _points[kHumanSeat]).length;

  void _startRound() {
    round = Round(
      seed: _seed + _dealSerial++,
      dealer: _dealer,
      roundWind: roundWind,
      honba: _honba,
      riichiSticks: _riichiSticks,
      startingPoints: List.of(_points),
    );
    _bots = [
      for (var i = 0; i < 4; i++) SimpleBot(_seed + i * 7 + _roundNumber)
    ];
    _humanCallOption = null;
    _humanCallAdvice = null;
    phase = GamePhase.playing;
    _roundId = newUuid();
    _tel?.roundStart(
      matchId: _matchId,
      roundId: _roundId,
      roundIndex: _roundNumber,
      roundWind: roundWind.name,
      handNumber: handInWind,
      dealerSeat: _dealer,
      honba: _honba,
      riichiSticks: _riichiSticks,
    );
    _refreshReport();
    _scheduleLoop();
  }

  @visibleForTesting
  static ({int dealer, int roundNumber, int honba}) rotateAfterRound({
    required bool exhaustiveDraw,
    required bool dealerKept,
    required int dealer,
    required int roundNumber,
    required int honba,
  }) {
    const nextHonba = 0;
    if (dealerKept || exhaustiveDraw) {
      return (dealer: dealer, roundNumber: roundNumber, honba: nextHonba);
    }
    return (
      dealer: (dealer + 1) % 4,
      roundNumber: roundNumber + 1,
      honba: nextHonba,
    );
  }

  void continueFromRoundEnd() {
    if (phase != GamePhase.roundEnd) return;
    final r = round.result!;

    final isExhaustiveDraw = r.kind == RoundEndKind.exhaustiveDraw;
    final dealerKept = isExhaustiveDraw ? true : r.winners.contains(_dealer);

    _tel?.roundEnd(
      matchId: _matchId,
      roundId: _roundId,
      endKind: r.kind.name,
      winners: r.winners,
      loser: r.loser,
      han: r.score?.han,
      fu: r.score?.fu,
      points: r.score?.points,
      yaku: [for (final y in r.score?.yaku ?? const []) y.name],
      pointDeltas: r.pointDeltas,
      tenpaiAtDraw: r.tenpaiAtDraw,
      dealerKept: dealerKept,
    );

    _riichiSticks = 0;
    final rot = rotateAfterRound(
      exhaustiveDraw: isExhaustiveDraw,
      dealerKept: dealerKept,
      dealer: _dealer,
      roundNumber: _roundNumber,
      honba: _honba,
    );
    _dealer = rot.dealer;
    _roundNumber = rot.roundNumber;
    _honba = rot.honba;
    _points = [for (var i = 0; i < 4; i++) round.seats[i].points];

    if (_roundNumber >= _handsPerGame && !dealerKept) {
      phase = GamePhase.gameEnd;
      _tel?.matchEnd(
        matchId: _matchId,
        reason: 'game_end',
        finalPoints: List.of(_points),
        humanSeat: kHumanSeat,
        humanPlace: _humanPlace(),
      );
      // The overall points leader (ties broken by seat order) gives their win
      // line for the whole match.
      final best = _points.reduce((a, b) => a > b ? a : b);
      final champion = _points.indexOf(best);
      Sfx.i.voice(VoiceKind.win, character: _characterForSeat(champion));
      notifyListeners();
      return;
    }
    _startRound();
    notifyListeners();
  }

  /// Push buffered telemetry to the network now. Safe to call often — used on
  /// tab-hide so completed rounds aren't stranded in the buffer. A match with
  /// round events but no terminal `match_end` reads as abandoned in analysis.
  void flushTelemetry() => _tel?.flushBeacon();

  @override
  void dispose() {
    _disposed = true;
    _loopTimer?.cancel();
    if (_matchId.isNotEmpty && phase != GamePhase.gameEnd) {
      _tel?.matchEnd(
        matchId: _matchId,
        reason: 'abandoned',
        finalPoints: List.of(_points),
        humanSeat: kHumanSeat,
        humanPlace: _humanPlace(),
      );
    }
    _tel?.dispose();
    super.dispose();
  }

  // --- the loop -------------------------------------------------------

  // Opponents act at half the old pace (960 ms vs 480 ms per step); fast mode
  // halves that again for a 2x run.
  Duration get _stepDelay => Duration(milliseconds: fastMode ? 480 : 960);

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
    // Your own seat is played by the guide, never by the opponents' heuristic:
    // autoplay follows the same efficiency / expected-value / safety analysis
    // the panel shows you. Seats 1-3 stay on [SimpleBot].
    final decision = (seat == kHumanSeat && autoplay)
        ? _guidedTurnDecision()
        : _bots[seat].decideTurn(round, seat);
    if (decision.tsumo) {
      round.declareTsumo(seat);
    } else if (decision.closedKan != null) {
      Sfx.i.play(SfxKind.kan);
      Sfx.i.voice(VoiceKind.kan, character: _characterForSeat(seat));
      round.closedKan(seat, decision.closedKan!);
    } else if (decision.addedKan != null) {
      Sfx.i.play(SfxKind.kan);
      Sfx.i.voice(VoiceKind.kan, character: _characterForSeat(seat));
      round.addKan(seat, decision.addedKan!);
    } else {
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
    final chiLow = <int, TileType>{};
    for (final opt in round.callOptions) {
      if (opt.seat == kHumanSeat && !autoplay) {
        _humanCallOption = opt;
        // Worked out once here rather than per rebuild: adviseCall runs a full
        // analysis per option, and the overlay rebuilds on every notify.
        _humanCallAdvice = _guidedCallAdvice(opt);
        notifyListeners();
        return; // wait for the human
      }
      final bot = _bots[opt.seat];
      CallType c;
      if (autoplay && opt.seat == kHumanSeat) {
        final advice = _guidedCallAdvice(opt);
        c = _callTypeFor(advice?.recommended);
        final low = _chiLowFor(advice);
        if (low != null) chiLow[opt.seat] = low;
      } else {
        c = bot.decideCall(round, opt.seat, round.pendingDiscard!, opt.types);
      }
      if (c != CallType.none) choices[opt.seat] = c;
    }
    _humanCallOption = null;
    _humanCallAdvice = null;
    _playCallSfx(choices);
    round.resolveCalls(choices, chiLow: chiLow);
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  /// A win chime at round end, a call click for a mid-round pon / kan / chi.
  void _playRoundEndSfx() {
    final res = round.result;
    if (res == null) return;
    final VoiceKind? winLine = switch (res.kind) {
      RoundEndKind.ron => VoiceKind.win,
      RoundEndKind.tsumo => VoiceKind.win,
      _ => null,
    };
    if (winLine == null) return;
    Sfx.i.play(res.kind == RoundEndKind.ron ? SfxKind.ron : SfxKind.tsumo);

    for (var wi = 0; wi < res.winners.length; wi++) {
      final seat = res.winners[wi];
      final bigHand =
          wi < res.scores.length && res.scores[wi].limitName.isNotEmpty;
      final winner = _characterForSeat(seat);
      if (!bigHand) {
        Sfx.i.voice(winLine, character: winner);
        continue;
      }
      final steps = <(Character, VoiceKind)>[
        (winner, winLine),
        (winner, VoiceKind.yeah),
      ];
      if (res.kind == RoundEndKind.ron && res.loser != null) {
        steps.add((_characterForSeat(res.loser!), VoiceKind.acquiescement));
      }
      Sfx.i.voiceChain(steps);
    }
  }

  void _playCallSfx(Map<int, CallType> choices) {
    final calls = choices.values;
    if (calls.contains(CallType.ron)) return; // handled at round end
    if (calls.contains(CallType.kan)) {
      Sfx.i.play(SfxKind.kan);
    } else if (calls.contains(CallType.pon)) {
      Sfx.i.play(SfxKind.pon);
    } else if (calls.contains(CallType.chi)) {
      Sfx.i.play(SfxKind.chi);
    }
    // The seat that made the call gets its character's line.
    for (final e in choices.entries) {
      final vk = switch (e.value) {
        CallType.chi => VoiceKind.chi,
        CallType.pon => VoiceKind.pon,
        CallType.kan => VoiceKind.kan,
        _ => null,
      };
      if (vk != null) {
        Sfx.i.voice(vk, character: _characterForSeat(e.key));
      }
    }
  }

  // --- the guide playing your seat ------------------------------------

  /// Autoplay's turn decision for the human seat: the efficiency / expected
  /// value / safety guide, never [SimpleBot].
  BotTurn _guidedTurnDecision() {
    final seat = round.seats[kHumanSeat];

    // A win is always taken.
    if (round.canTsumo(kHumanSeat)) return BotTurn(tsumo: true);

    _refreshReport();

    final threat = _exposedOpponent();
    for (final type in round.closedKanTypes(kHumanSeat)) {
      final advice = _efficiency.adviseClosedKan(
        hand: seat.hand,
        kanType: type,
        visibleCounts34: _visibleCounts(),
        context: _efficiencyValueContext(seat),
        opponentRiichi: threat != null,
        opponentIsDealer: threat?.isDealer ?? false,
      );
      if (advice.eligible) return BotTurn(closedKan: type);
    }
    for (final type in round.addedKanTypes(kHumanSeat)) {
      final advice = _efficiency.adviseAddedKan(
        hand: seat.hand,
        kanType: type,
        melds: seat.melds,
        visibleCounts34: _visibleCounts(),
        context: _efficiencyValueContext(seat),
        opponentRiichi: threat != null,
        opponentIsDealer: threat?.isDealer ?? false,
        opponentDiscards: threat != null
            ? threat.allDiscards.map((t) => t.type).toList()
            : const [],
        passedDiscardsAfterRiichi:
            threat?.passedDiscardsAfterRiichi.toList() ?? const [],
      );
      if (advice.eligible) return BotTurn(addedKan: type);
    }

    final line = _recommendedLine();
    if (line == null) {
      return BotTurn(discard: round.legalDiscards(kHumanSeat).first);
    }
    return BotTurn(
      discard: _tileToDiscard(line.discard),
    );
  }

  DiscardLine? _recommendedLine() {
    for (final line in report.lines) {
      if (line.recommended) return line;
    }
    return report.lines.isEmpty ? null : report.lines.first;
  }

  /// A concrete tile matching the recommended type, keeping a red five in hand
  /// where an ordinary copy will do.
  Tile _tileToDiscard(TileType type) {
    final legal = round.legalDiscards(kHumanSeat);
    for (final tile in legal) {
      if (tile.type == type && !tile.aka) return tile;
    }
    for (final tile in legal) {
      if (tile.type == type) return tile;
    }
    return legal.first;
  }

  CallAdvice? _guidedCallAdvice(CallOption opt) {
    final offered = round.pendingDiscard;
    if (offered == null) return null;
    final seat = round.seats[opt.seat];
    final threat = _exposedOpponent();
    return _efficiency.adviseCall(
      hand: seat.hand,
      offered: offered,
      available: _guidedActionsFor(opt.types),
      visibleCounts34: _visibleCounts(),
      context: _efficiencyValueContext(seat),
      opponentDiscards: threat != null
          ? threat.allDiscards.map((t) => t.type).toList()
          : const [],
      passedDiscardsAfterRiichi:
          threat?.passedDiscardsAfterRiichi.toList() ?? const [],
      opponentRiichi: threat != null,
      opponentIsDealer: threat?.isDealer ?? false,
    );
  }

  static Set<GuidedAction> _guidedActionsFor(Set<CallType> types) {
    final out = <GuidedAction>{};
    for (final type in types) {
      switch (type) {
        case CallType.ron:
          out.add(GuidedAction.ron);
        case CallType.chi:
          out.add(GuidedAction.chi);
        case CallType.pon:
          out.add(GuidedAction.pon);
        case CallType.kan:
          out.add(GuidedAction.kan);
        case CallType.none:
          break;
      }
    }
    return out;
  }

  static CallType _callTypeFor(GuidedAction? action) => switch (action) {
        GuidedAction.ron => CallType.ron,
        GuidedAction.pon => CallType.pon,
        GuidedAction.kan => CallType.kan,
        GuidedAction.chi => CallType.chi,
        _ => CallType.none,
      };

  /// The run the guide picked, for a chi it is recommending.
  static TileType? _chiLowFor(CallAdvice? advice) =>
      advice?.recommended == GuidedAction.chi
          ? advice?.forAction(GuidedAction.chi)?.meldLow
          : null;

  // --- human input ---------------------------------------------------

  void humanDiscard(Tile tile, {bool declareRiichi = false}) {
    if (round.finished ||
        round.turn != kHumanSeat ||
        round.phase != RoundPhase.discarding) {
      return;
    }
    if (declareRiichi) {
      throw UnsupportedError('Hong Kong mahjong has no riichi');
    }
    Sfx.i.play(SfxKind.discard);
    if (_tel != null) {
      final recos = [
        for (final l in report.lines)
          if (l.recommended) l.discard,
      ];
      _tel.humanDecision(
        matchId: _matchId,
        roundId: _roundId,
        kind: 'discard',
        tile: tile.code,
        auto: autoplay,
        guideVisible: guideVisible,
        guideReco:
            recos.isEmpty ? null : [for (final t in recos) t.code].join(','),
        followedGuide: recos.isEmpty ? null : recos.contains(tile.type),
      );
    }
    _noteDiscard(kHumanSeat, tile);
    round.discard(kHumanSeat, tile, declareRiichi: declareRiichi);
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  void humanPassFlowerWin() {
    if (!round.canFlowerWin(kHumanSeat)) return;
    round.passFlowerWin(kHumanSeat);
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  void humanTsumo() {
    if (round.canTsumo(kHumanSeat) && round.turn == kHumanSeat) {
      round.declareTsumo(kHumanSeat);
      phase = GamePhase.roundEnd;
      _playRoundEndSfx();
      notifyListeners();
    }
  }

  void humanClosedKan(TileType type) {
    if (round.turn == kHumanSeat && round.phase == RoundPhase.discarding) {
      Sfx.i.play(SfxKind.kan);
      Sfx.i.voice(VoiceKind.kan);
      round.closedKan(kHumanSeat, type);
      _refreshReport();
      notifyListeners();
      _scheduleLoop();
    }
  }

  void humanAddKan(TileType type) {
    if (round.turn == kHumanSeat && round.phase == RoundPhase.discarding) {
      Sfx.i.play(SfxKind.kan);
      Sfx.i.voice(VoiceKind.kan);
      round.addKan(kHumanSeat, type);
      _refreshReport();
      notifyListeners();
      _scheduleLoop();
    }
  }

  void answerCall(CallType choice) {
    final opt = _humanCallOption;
    if (opt == null) return;
    final choices = <int, CallType>{};
    final chiLow = <int, TileType>{};
    if (choice != CallType.none) choices[opt.seat] = choice;

    // Several runs can often be made with the same tile; take the one the
    // guide rates highest rather than making you pick between them.
    if (choice == CallType.chi) {
      final low = _humanCallAdvice?.forAction(GuidedAction.chi)?.meldLow;
      if (low != null) chiLow[opt.seat] = low;
    }

    // Let the remaining bot seats decide too.
    for (final other in round.callOptions) {
      if (other.seat == opt.seat) continue;
      final c = _bots[other.seat]
          .decideCall(round, other.seat, round.pendingDiscard!, other.types);
      if (c != CallType.none) choices[other.seat] = c;
    }
    if (_tel != null) {
      final advised = _humanCallAdvice?.recommended;
      _tel.humanDecision(
        matchId: _matchId,
        roundId: _roundId,
        kind: choice == CallType.none ? 'pass' : 'call',
        tile: round.pendingDiscard?.code,
        auto: autoplay,
        guideVisible: guideVisible,
        guideReco: advised?.name,
        followedGuide: advised == null ? null : _callTypeFor(advised) == choice,
      );
    }
    _humanCallOption = null;
    _humanCallAdvice = null;
    _playCallSfx(choices); // voices every calling seat, human included
    round.resolveCalls(choices, chiLow: chiLow);
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  void setAutoplay(bool value) {
    autoplay = value;
    _tel?.settingChange(matchId: _matchId, setting: 'autoplay', value: value);
    notifyListeners();
    if (value) _scheduleLoop();
  }

  // --- efficiency report -------------------------------------------

  void _refreshReport() {
    if (round.canFlowerWin(kHumanSeat)) {
      report = EfficiencyReport.waiting();
      return;
    }
    if (round.finished ||
        round.turn != kHumanSeat ||
        round.phase != RoundPhase.discarding) {
      // Still show a defensive read if the human is under threat.
      final human = round.seats[kHumanSeat];
      final threat = _exposedOpponent();
      if (threat != null && human.hand.isNotEmpty) {
        report = _efficiency.analyze(
          hand: human.hand,
          visibleCounts34: _visibleCounts(),
          canRiichi: false,
          valueContext: _efficiencyValueContext(human),
          defenseHand: human.hand,
          opponentDiscards: threat.allDiscards.map((t) => t.type).toList(),
          passedDiscardsAfterRiichi: threat.passedDiscardsAfterRiichi.toList(),
          opponentRiichi: true,
        );
      } else {
        report = EfficiencyReport.waiting();
      }
      return;
    }

    final human = round.seats[kHumanSeat];
    final threat = _exposedOpponent();
    report = _efficiency.analyze(
      hand: human.hand,
      visibleCounts34: _visibleCounts(),
      canRiichi: round.canRiichi(kHumanSeat),
      valueContext: _efficiencyValueContext(human),
      defenseHand: threat != null ? human.hand : null,
      opponentDiscards: threat != null
          ? threat.allDiscards.map((t) => t.type).toList()
          : const [],
      passedDiscardsAfterRiichi:
          threat?.passedDiscardsAfterRiichi.toList() ?? const [],
      opponentRiichi: threat != null,
      opponentIsDealer: threat?.isDealer ?? false,
    );
  }

  EfficiencyValueContext _efficiencyValueContext(SeatState seat) =>
      EfficiencyValueContext(
        melds: seat.melds,
        roundWind: round.roundWind,
        seatWind: seat.wind,
        isDealer: seat.isDealer,
        inRiichi: false,
        flowers: seat.flowers.map((t) => t.type).toList(),
        wallTilesRemaining: round.wall.remaining,
        doraIndicators: round.wall.doraIndicators(),
        honba: round.honba,
        riichiSticks: round.riichiSticks,
        style: playStyle,
        focus: handFocus,
      );

  SeatState? _exposedOpponent() {
    for (final s in round.seats) {
      if (s.seat != kHumanSeat &&
          s.melds.where((m) => !m.concealed).length >= 2) {
        return s;
      }
    }
    return null;
  }

  /// The opponent the guide's safety scores refer to.
  @override
  int? get safetyOpponentSeat => _exposedOpponent()?.seat;

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

  List<TileType> get humanClosedKanTypes =>
      round.turn == kHumanSeat && round.phase == RoundPhase.discarding
          ? round.closedKanTypes(kHumanSeat)
          : const [];

  List<TileType> get humanAddedKanTypes =>
      round.turn == kHumanSeat && round.phase == RoundPhase.discarding
          ? round.addedKanTypes(kHumanSeat)
          : const [];

  /// The guide's verdict on whichever kan (closed or added) is available on
  /// the human's turn right now — null when there's nothing to decide.
  /// Closed kan is checked first, matching [_guidedTurnDecision]'s priority.
  @override
  ({TileType type, bool isAdded, ActionAdvice advice})? get kanAdvice {
    if (round.turn != kHumanSeat || round.phase != RoundPhase.discarding) {
      return null;
    }
    final seat = round.seats[kHumanSeat];
    final threat = _exposedOpponent();
    for (final type in round.closedKanTypes(kHumanSeat)) {
      final advice = _efficiency.adviseClosedKan(
        hand: seat.hand,
        kanType: type,
        visibleCounts34: _visibleCounts(),
        context: _efficiencyValueContext(seat),
        opponentRiichi: threat != null,
        opponentIsDealer: threat?.isDealer ?? false,
      );
      return (type: type, isAdded: false, advice: advice);
    }
    for (final type in round.addedKanTypes(kHumanSeat)) {
      final advice = _efficiency.adviseAddedKan(
        hand: seat.hand,
        kanType: type,
        melds: seat.melds,
        visibleCounts34: _visibleCounts(),
        context: _efficiencyValueContext(seat),
        opponentRiichi: threat != null,
        opponentIsDealer: threat?.isDealer ?? false,
        opponentDiscards: threat != null
            ? threat.allDiscards.map((t) => t.type).toList()
            : const [],
        passedDiscardsAfterRiichi:
            threat?.passedDiscardsAfterRiichi.toList() ?? const [],
      );
      return (type: type, isAdded: true, advice: advice);
    }
    return null;
  }

  /// The call the guide recommends for the pending human call decision.
  @override
  CallType? get recommendedCall {
    if (_humanCallOption == null) return null;
    final advice = _humanCallAdvice;
    return advice == null ? null : _callTypeFor(advice.recommended);
  }

  /// Why the guide recommends [recommendedCall] — shown under the call prompt.
  @override
  String? get recommendedCallReason => _humanCallAdvice?.reason;

  bool get isHumanTurn =>
      round.turn == kHumanSeat &&
      round.phase == RoundPhase.discarding &&
      !round.finished;

  @override
  bool get humanFuriten => !round.finished && round.isFuriten(kHumanSeat);

  /// The tile the auto-player would discard on the human's turn (for the green
  /// "what autoplay would do" hint). Null when it is not the human's turn.
  /// Autoplay follows the guide, so this is simply its recommended discard.
  TileType? get autoplayDiscardType =>
      isHumanTurn ? _recommendedLine()?.discard : null;
}
