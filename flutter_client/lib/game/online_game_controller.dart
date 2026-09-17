/// Drives an online multiplayer game: owns the [MpClient] connection, mirrors
/// whatever redacted [Round] snapshot the server last sent (see
/// `package:mahjong_core/protocol.dart`), and turns every human-input method
/// into an outgoing network message instead of a local mutation — the server
/// is the sole source of truth. Implements the same [TableGameHost] surface
/// [GameController] does so the existing table/hand/scoring widgets need no
/// changes to render an online game.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mahjong_core/mahjong_core.dart';

import '../logic/efficiency_engine.dart';
import '../net/guest_identity.dart';
import '../net/mp_client.dart';
import 'game_controller.dart' show kHumanSeat;
import 'guide_host.dart';
import 'sfx.dart';

/// The room's own lifecycle, as the server reports it — separate from
/// [GamePhase], which only exists once a game is actually being played.
enum RoomLifecycle { lobby, playing, ended }

/// One seat's roster entry for the lobby / seating UI.
class LobbySeat {
  const LobbySeat({
    required this.seat,
    required this.name,
    required this.character,
    required this.isBot,
    required this.isHost,
    required this.connected,
  });

  factory LobbySeat.fromJson(Map<String, dynamic> json) => LobbySeat(
        seat: json['seat'] as int,
        name: json['name'] as String?,
        character: _parseCharacter(json['character'] as String?),
        isBot: json['isBot'] as bool? ?? false,
        isHost: json['isHost'] as bool? ?? false,
        connected: json['connected'] as bool? ?? false,
      );

  final int seat;
  final String? name;

  /// The server's pick for this seat — see `Room.resolveCharacter` on the
  /// multiplayer server. Null only for a still-empty seat.
  final Character? character;
  final bool isBot;
  final bool isHost;
  final bool connected;

  bool get isOpen => name == null && !isBot;
}

Character? _parseCharacter(String? name) {
  if (name == null) return null;
  for (final c in Character.values) {
    if (c.name == name) return c;
  }
  return null;
}

List<LobbySeat> _emptyLobby() => [
      for (var i = 0; i < 4; i++)
        LobbySeat(
          seat: i,
          name: null,
          character: null,
          isBot: false,
          isHost: i == 0,
          connected: false,
        ),
    ];

Round _placeholderRound() => Round.posed(
      dealer: 0,
      roundWind: Wind.east,
      wall: Wall.posed(remaining: 0, dora: const []),
      startingPoints: List.filled(4, 25000),
      ruleset: Ruleset.riichi,
    );

class OnlineGameController extends ChangeNotifier implements TableGameHost {
  OnlineGameController() : _identity = GuestIdentity.load() {
    round = _placeholderRound();
    _sub = _client.messages.listen(_onMessage);
  }

  final MpClient _client = MpClient();
  final GuestIdentity _identity;
  StreamSubscription<Map<String, dynamic>>? _sub;
  final _efficiency = EfficiencyEngine();

  String get displayName => _identity.name;
  void setDisplayName(String name) => _identity.saveName(name.trim());

  /// The persona picked on the lobby's character screen — sent with
  /// `create_room`/`join_room` as a request, not a guarantee: joining a room
  /// where that persona is already taken gets you whatever
  /// `Room.resolveCharacter` assigns instead, and `_applyRoomState`
  /// reconciles this back to match as soon as the room confirms it, so this
  /// never drifts from what you are actually seen as at the table.
  Character get myCharacter => _identity.character;
  void setMyCharacter(Character value) {
    _identity.saveCharacter(value);
    notifyListeners();
  }

  // --- lobby / room state -------------------------------------------------

  String roomCode = '';
  Ruleset ruleset = Ruleset.riichi;
  bool hanchan = true;
  RoomLifecycle roomPhase = RoomLifecycle.lobby;
  int? mySeat;
  List<LobbySeat> lobbySeats = _emptyLobby();
  String? lastError;
  int? lastBotTakeoverSeat;
  bool connectionLost = false;

  bool get isHost =>
      mySeat != null &&
      lobbySeats.any((s) => s.seat == mySeat && s.isHost);

  void createRoom({required Ruleset ruleset, required bool hanchan}) {
    this.ruleset = ruleset;
    this.hanchan = hanchan;
    _client.send({
      'type': 'create_room',
      'guestId': _identity.guestId,
      'name': _effectiveName,
      'character': _identity.character.name,
      'ruleset': ruleset.name,
      'hanchan': hanchan,
    });
  }

  void joinRoom(String code) {
    _client.send({
      'type': 'join_room',
      'roomCode': code.trim().toUpperCase(),
      'guestId': _identity.guestId,
      'name': _effectiveName,
      'character': _identity.character.name,
    });
  }

  String get _effectiveName =>
      _identity.name.trim().isEmpty ? 'Guest' : _identity.name.trim();

  void startGame() {
    if (roomPhase == RoomLifecycle.lobby) _client.send({'type': 'start_game'});
  }

  void leaveRoom() {
    _client.send({'type': 'leave_room'});
    roomCode = '';
    mySeat = null;
    roomPhase = RoomLifecycle.lobby;
    lobbySeats = _emptyLobby();
    _roundReady = false;
    round = _placeholderRound();
    notifyListeners();
  }

  // --- table state (populated once the game starts) -----------------------

  bool _roundReady = false;

  @override
  late Round round;

  @override
  GamePhase phase = GamePhase.playing;

  List<int> _tablePoints = List.filled(4, 0);
  @override
  List<int> get tablePoints => _tablePoints;

  int _handInWind = 1;
  @override
  int get handInWind => _handInWind;

  @override
  int get honba => _roundReady ? round.honba : 0;

  int _discardSerial = 0;
  @override
  int get discardSerial => _discardSerial;

  int? _lastDiscardSeat;
  @override
  int? get lastDiscardSeat => _lastDiscardSeat;

  bool _lastDiscardTsumogiri = false;
  @override
  bool get lastDiscardTsumogiri => _lastDiscardTsumogiri;

  int? _turnDeadlineMs;
  @override
  int? get turnDeadlineMs => _turnDeadlineMs;

  /// Online play cannot pause three other humans.
  @override
  bool get paused => false;

  @override
  PlayStyle playStyle = kDefaultPlayStyle;
  @override
  void setPlayStyle(PlayStyle value) {
    if (playStyle == value) return;
    playStyle = value;
    _refreshReport();
    notifyListeners();
  }

  @override
  HandFocus handFocus = kDefaultHandFocus;
  @override
  void setHandFocus(HandFocus value) {
    if (handFocus == value) return;
    handFocus = value;
    _refreshReport();
    notifyListeners();
  }

  // Placement isn't wired up for online play yet — same as Hong Kong — so
  // this satisfies [GuideHost] but stays pinned to the reference model.
  @override
  Strategy strategy = kDefaultStrategy;
  @override
  void setStrategy(Strategy value) {
    if (strategy == value) return;
    strategy = value;
    _refreshReport();
    notifyListeners();
  }

  @override
  EfficiencyReport report = EfficiencyReport.waiting();

  CallOption? _humanCallOption;
  @override
  bool get awaitingHumanCall => _humanCallOption != null;
  @override
  CallOption? get humanCallOption => _humanCallOption;
  CallAdvice? _humanCallAdvice;

  @override
  bool get soundOn => Sfx.i.enabled;
  @override
  void setSoundOn(bool value) {
    if (Sfx.i.enabled == value) return;
    Sfx.i.enabled = value;
    if (value) Sfx.i.unlock();
    notifyListeners();
  }

  // --- server -> client -----------------------------------------------------

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type'] as String?) {
      case 'room_state':
        _applyRoomState(msg);
      case 'state':
        _applyRoundSnapshot(msg, isResult: false);
      case 'round_result':
        _applyRoundSnapshot(msg, isResult: true);
      case 'error':
        lastError = msg['message'] as String?;
        notifyListeners();
      case 'bot_takeover':
        lastBotTakeoverSeat = msg['seat'] as int?;
        notifyListeners();
      case 'player_disconnected':
      case 'player_reconnected':
        notifyListeners();
      case '_connection_lost':
        connectionLost = true;
        notifyListeners();
      case '_reconnected':
        connectionLost = false;
        if (roomCode.isNotEmpty) {
          _client.send({
            'type': 'reconnect',
            'roomCode': roomCode,
            'guestId': _identity.guestId,
          });
        }
        notifyListeners();
    }
  }

  void _applyRoomState(Map<String, dynamic> msg) {
    roomCode = msg['code'] as String;
    ruleset = msg['ruleset'] == 'hongKong' ? Ruleset.hongKong : Ruleset.riichi;
    hanchan = msg['hanchan'] as bool;
    roomPhase = RoomLifecycle.values.byName(msg['phase'] as String);
    final yourSeat = msg['yourSeat'] as int?;
    if (yourSeat != null) mySeat = yourSeat;
    lobbySeats = [
      for (final s in msg['seats'] as List)
        LobbySeat.fromJson(s as Map<String, dynamic>)
    ];
    // `Room.resolveCharacter` silently substitutes a different persona when
    // the one requested is already taken by an earlier seat in this room
    // (e.g. two guests both defaulting to the same cached pick). Without
    // this, `myCharacter` — and so the lobby's own "you are ___" picker —
    // kept showing the request instead of what was actually assigned, while
    // every other seat's roster row (and the table, once the game starts)
    // correctly showed the server's real pick: a visible mismatch between
    // what you picked and what you're actually playing as.
    if (mySeat != null) {
      final mine = lobbySeats.where((s) => s.seat == mySeat);
      final assigned = mine.isEmpty ? null : mine.first.character;
      if (assigned != null && assigned != _identity.character) {
        _identity.saveCharacter(assigned);
      }
    }
    notifyListeners();
  }

  void _applyRoundSnapshot(Map<String, dynamic> msg, {required bool isResult}) {
    final seat = msg['yourSeat'] as int;
    mySeat = seat;
    phase = GamePhase.values.byName(msg['gamePhase'] as String);
    _tablePoints = List<int>.from(msg['tablePoints'] as List);
    _handInWind = msg['handInWind'] as int;
    _discardSerial = msg['discardSerial'] as int;
    _lastDiscardSeat = msg['lastDiscardSeat'] as int?;
    _lastDiscardTsumogiri = msg['lastDiscardTsumogiri'] as bool;
    _turnDeadlineMs = msg['turnDeadlineMs'] as int?;
    round =
        buildRoundFromSnapshot(msg['round'] as Map<String, dynamic>, mySeat: seat);
    _roundReady = true;
    _updateCallState();
    _refreshReport();
    if (isResult) {
      _playRoundEndSfx();
    } else {
      _playTurnSfx();
    }
    notifyListeners();
  }

  void _updateCallState() {
    final mine = round.callOptions.where((o) => o.seat == kHumanSeat);
    if (mine.isEmpty) {
      _humanCallOption = null;
      _humanCallAdvice = null;
      return;
    }
    final opt = mine.first;
    _humanCallOption = opt;
    _humanCallAdvice = _guidedCallAdvice(opt);
  }

  // --- human input: every action is a network message, never a local
  // mutation of [round] — the next `state`/`round_result` broadcast is the
  // only thing that ever changes it. ------------------------------------

  @override
  void humanDiscard(Tile tile, {bool declareRiichi = false}) {
    if (!_roundReady ||
        round.finished ||
        round.turn != kHumanSeat ||
        round.phase != RoundPhase.discarding) {
      return;
    }
    _client.send({
      'type': 'action',
      'kind': 'discard',
      'tileId': tile.id,
      'riichi': declareRiichi,
    });
  }

  @override
  void humanTsumo() {
    if (_roundReady && round.turn == kHumanSeat && round.canTsumo(kHumanSeat)) {
      _client.send({'type': 'action', 'kind': 'tsumo'});
    }
  }

  @override
  void humanPassFlowerWin() {
    if (_roundReady && round.canFlowerWin(kHumanSeat)) {
      _client.send({'type': 'action', 'kind': 'pass_flower_win'});
    }
  }

  @override
  void humanClosedKan(TileType type) {
    if (_roundReady &&
        round.turn == kHumanSeat &&
        round.phase == RoundPhase.discarding) {
      _client.send(
          {'type': 'action', 'kind': 'closed_kan', 'tileType': type.name});
    }
  }

  @override
  void humanAddKan(TileType type) {
    if (_roundReady &&
        round.turn == kHumanSeat &&
        round.phase == RoundPhase.discarding) {
      _client.send(
          {'type': 'action', 'kind': 'added_kan', 'tileType': type.name});
    }
  }

  @override
  void answerCall(CallType choice) {
    if (_humanCallOption == null) return;
    if (choice == CallType.none) {
      _client.send({'type': 'action', 'kind': 'pass_call'});
    } else {
      final payload = <String, dynamic>{
        'type': 'action',
        'kind': 'call',
        'callType': choice.name,
      };
      if (choice == CallType.chi) {
        final low = _humanCallAdvice?.forAction(GuidedAction.chi)?.meldLow;
        if (low != null) payload['chiLow'] = low.name;
      }
      _client.send(payload);
    }
    // Cleared optimistically so the call buttons disappear immediately; the
    // next broadcast is the actual confirmation.
    _humanCallOption = null;
    _humanCallAdvice = null;
    notifyListeners();
  }

  @override
  void continueFromRoundEnd() {
    if (phase != GamePhase.roundEnd) return;
    _client.send({'type': 'continue_round'});
  }

  /// Online play has no local restart — see [leaveRoom].
  @override
  void newGame() {}

  // --- convenience getters, identical formulas to GameController's --------

  @override
  bool get isHumanTurn =>
      _roundReady &&
      round.turn == kHumanSeat &&
      round.phase == RoundPhase.discarding &&
      !round.finished;

  @override
  bool get humanCanTsumo =>
      _roundReady &&
      round.turn == kHumanSeat &&
      round.phase == RoundPhase.discarding &&
      round.canTsumo(kHumanSeat);

  @override
  bool get humanCanRiichi =>
      _roundReady &&
      round.turn == kHumanSeat &&
      round.phase == RoundPhase.discarding &&
      round.canRiichi(kHumanSeat);

  @override
  List<TileType> get humanClosedKanTypes => _roundReady &&
          round.turn == kHumanSeat &&
          round.phase == RoundPhase.discarding
      ? round.closedKanTypes(kHumanSeat)
      : const [];

  @override
  List<TileType> get humanAddedKanTypes => _roundReady &&
          round.turn == kHumanSeat &&
          round.phase == RoundPhase.discarding
      ? round.addedKanTypes(kHumanSeat)
      : const [];

  @override
  bool get humanFuriten =>
      _roundReady && !round.finished && round.isFuriten(kHumanSeat);

  @override
  int? get safetyOpponentSeat => _roundReady ? _threatOpponent()?.seat : null;

  @override
  CallType? get recommendedCall {
    final advice = _humanCallAdvice;
    return advice == null ? null : _callTypeFor(advice.recommended);
  }

  @override
  String? get recommendedCallReason => _humanCallAdvice?.reason;

  @override
  ({TileType type, bool isAdded, ActionAdvice advice})? get kanAdvice {
    if (!_roundReady ||
        round.turn != kHumanSeat ||
        round.phase != RoundPhase.discarding) {
      return null;
    }
    final seat = round.seats[kHumanSeat];
    final riichiOpp = _threatOpponent();
    for (final type in round.closedKanTypes(kHumanSeat)) {
      final advice = _efficiency.adviseClosedKan(
        hand: seat.hand,
        kanType: type,
        visibleCounts34: _visibleCounts(),
        context: _efficiencyValueContext(seat),
        opponentRiichi: riichiOpp != null,
        opponentIsDealer: riichiOpp?.isDealer ?? false,
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
        opponentRiichi: riichiOpp != null,
        opponentIsDealer: riichiOpp?.isDealer ?? false,
        opponentDiscards: riichiOpp != null
            ? riichiOpp.allDiscards.map((t) => t.type).toList()
            : const [],
        passedDiscardsAfterRiichi:
            riichiOpp?.passedDiscardsAfterRiichi.toList() ?? const [],
      );
      return (type: type, isAdded: true, advice: advice);
    }
    return null;
  }

  @override
  String seatLabel(int seat) {
    final match = lobbySeats.where((s) => s.seat == seat);
    final entry = match.isEmpty ? null : match.first;
    final name = entry?.name;
    final label = name == null || name.isEmpty
        ? (entry?.isBot ?? false ? 'Bot' : 'Seat ${seat + 1}')
        : (entry!.isBot ? '$name (bot)' : name);
    return seat == mySeat ? '$label (you)' : label;
  }

  /// Falls back to Hubert only for a not-yet-seated lobby slot (before the
  /// server has assigned anyone there) — every seat has a real assignment by
  /// the time a game is actually running.
  @override
  Character characterForSeat(int seat) {
    final match = lobbySeats.where((s) => s.seat == seat);
    final entry = match.isEmpty ? null : match.first;
    return entry?.character ?? Character.hubert;
  }

  // --- the guide, ported from GameController --------------------------
  //
  // This is a deliberate duplication, not an oversight: it is legitimate
  // here for exactly the reason GameController's version is legitimate for
  // the human seat — every input (`round.seats[kHumanSeat]`'s real hand,
  // plus every other seat's already-public pond/melds/riichi) is information
  // this player is already shown. See flutter_client/lib/game/game_controller.dart
  // for the source of truth if the analysis ever changes; keep both in sync.

  void _refreshReport() {
    if (!_roundReady) {
      report = EfficiencyReport.waiting();
      return;
    }
    if (round.canFlowerWin(kHumanSeat)) {
      report = EfficiencyReport.waiting();
      return;
    }
    if (round.finished ||
        round.turn != kHumanSeat ||
        round.phase != RoundPhase.discarding) {
      final human = round.seats[kHumanSeat];
      final riichiOpp = _threatOpponent();
      if (riichiOpp != null && human.hand.isNotEmpty) {
        report = _efficiency.analyze(
          hand: human.hand,
          visibleCounts34: _visibleCounts(),
          canRiichi: false,
          valueContext: _efficiencyValueContext(human),
          defenseHand: human.hand,
          opponentDiscards: riichiOpp.allDiscards.map((t) => t.type).toList(),
          passedDiscardsAfterRiichi:
              riichiOpp.passedDiscardsAfterRiichi.toList(),
          opponentRiichi: true,
        );
      } else {
        report = EfficiencyReport.waiting();
      }
      return;
    }

    final human = round.seats[kHumanSeat];
    final riichiOpp = _threatOpponent();
    report = _efficiency.analyze(
      hand: human.hand,
      visibleCounts34: _visibleCounts(),
      canRiichi: round.canRiichi(kHumanSeat),
      valueContext: _efficiencyValueContext(human),
      defenseHand: riichiOpp != null ? human.hand : null,
      opponentDiscards: riichiOpp != null
          ? riichiOpp.allDiscards.map((t) => t.type).toList()
          : const [],
      passedDiscardsAfterRiichi:
          riichiOpp?.passedDiscardsAfterRiichi.toList() ?? const [],
      opponentRiichi: riichiOpp != null,
      opponentIsDealer: riichiOpp?.isDealer ?? false,
    );
  }

  CallAdvice? _guidedCallAdvice(CallOption opt) {
    final offered = round.pendingDiscard;
    if (offered == null) return null;
    final seat = round.seats[opt.seat];
    final riichiOpp = _threatOpponent();
    return _efficiency.adviseCall(
      hand: seat.hand,
      offered: offered,
      available: _guidedActionsFor(opt.types),
      visibleCounts34: _visibleCounts(),
      context: _efficiencyValueContext(seat),
      opponentDiscards: riichiOpp != null
          ? riichiOpp.allDiscards.map((t) => t.type).toList()
          : const [],
      passedDiscardsAfterRiichi:
          riichiOpp?.passedDiscardsAfterRiichi.toList() ?? const [],
      opponentRiichi: riichiOpp != null,
      opponentIsDealer: riichiOpp?.isDealer ?? false,
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

  EfficiencyValueContext _efficiencyValueContext(SeatState seat) =>
      EfficiencyValueContext(
        melds: seat.melds,
        roundWind: round.roundWind,
        seatWind: seat.wind,
        isDealer: seat.isDealer,
        inRiichi: seat.riichi,
        wallTilesRemaining: round.wall.remaining,
        doraIndicators: round.wall.doraIndicators(),
        honba: round.honba,
        riichiSticks: round.riichiSticks,
        style: playStyle,
        focus: handFocus,
        strategy: strategy,
        ruleset: ruleset,
        flowers: seat.flowers.map((t) => t.type).toList(),
      );

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

  // --- sound: simple local cues only. The fixed bot-persona voice lines
  // GameController plays don't make sense once other seats are real people,
  // so they are dropped entirely rather than ported. -----------------------

  int? _lastSfxDiscardSerial;
  void _playTurnSfx() {
    if (_lastSfxDiscardSerial != null && _discardSerial > _lastSfxDiscardSerial!) {
      Sfx.i.play(SfxKind.discard);
    }
    _lastSfxDiscardSerial = _discardSerial;
  }

  void _playRoundEndSfx() {
    final res = round.result;
    if (res == null) return;
    switch (res.kind) {
      case RoundEndKind.ron:
        Sfx.i.play(SfxKind.ron);
      case RoundEndKind.tsumo:
        Sfx.i.play(SfxKind.tsumo);
      case RoundEndKind.exhaustiveDraw:
      case RoundEndKind.abortiveDraw:
        break;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _client.close();
    super.dispose();
  }
}
