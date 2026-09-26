/// The authoritative per-room game loop: an async port of
/// `GameController`'s `Timer`-driven turn loop (see
/// flutter_client/lib/game/game_controller.dart), generalized from "one
/// local human, three local bots" to "any mix of connected humans and bots,
/// each human answered over the network instead of a local callback."
library;

import 'dart:async';
import 'dart:math';

import 'package:mahjong_core/mahjong_core.dart';
import 'package:mahjong_core/game_timing.dart';

import 'room.dart';
import 'telemetry.dart';

class TableLoop {
  /// The turn and call clocks default to the room's chosen
  /// [Room.timerSeconds] (30 or 60); the other durations to their production
  /// values; tests
  /// override them to make timeout/disconnect/bot-takeover paths exercisable
  /// in milliseconds instead of tens of real seconds.
  ///
  /// [telemetry] defaults to [MpTelemetry.maybe], which is a no-op unless
  /// `INGEST_URL` is set — tests never set it, so they get an inert instance
  /// without needing to pass one explicitly; the room's host (always a real
  /// human seat in production — bots only ever fill an otherwise-empty one)
  /// is the guest every batch for this match is posted under. A `TableLoop`
  /// built directly against a bare, not-yet-seated `Room` (some tests do
  /// this) has no host seat to report under yet, so telemetry just stays off
  /// rather than throwing.
  TableLoop(
    this.room, {
    Duration? turnTimeout,
    Duration? callTimeout,
    Duration disconnectGrace = const Duration(seconds: 30),
    Duration? continueTimeout,
    Duration botTurnPace = const Duration(milliseconds: 900),
    MpTelemetry? telemetry,
  })  : _turnTimeout = turnTimeout ?? Duration(seconds: room.timerSeconds),
        _callTimeout = callTimeout ?? Duration(seconds: room.timerSeconds),
        _disconnectGrace = disconnectGrace,
        _continueTimeout = continueTimeout,
        _botTurnPace = botTurnPace,
        _tel = telemetry ??
            (room.seats[room.hostSeat] == null
                ? null
                : MpTelemetry.maybe(
                    hostGuestId: room.seats[room.hostSeat]!.guestId,
                    hostSessionId: newUuid(),
                  ));

  final Room room;
  final Random _rng = Random();
  final MpTelemetry? _tel;
  late final String _matchId;
  late String _roundId;

  /// How long a human seat gets to answer its own turn (discard / kan /
  /// riichi / tsumo) before a bot plays that one decision for it.
  final Duration _turnTimeout;

  /// How long a human seat gets to answer a call offer (chi/pon/kan/ron)
  /// before a bot decides that one call for it — short, because real calls
  /// are time-pressured and one silent player must not stall the other
  /// three.
  final Duration _callTimeout;

  /// How long a disconnected seat is held open for a reconnect before it
  /// permanently converts to bot control.
  final Duration _disconnectGrace;

  /// How long the table waits for any player to click "next hand" at a round
  /// end before dealing it automatically (covers a room with no connected
  /// humans left, or everyone simply forgetting to click).
  /// Defaults to 25 seconds per score page, plus the winning call's bubble.
  final Duration? _continueTimeout;

  /// How long to sit on a bot's automatic discard before broadcasting it —
  /// with no delay here, a stretch of consecutive bot turns (nobody left to
  /// wait on) resolves within a single event-loop tick, and every discard in
  /// it lands in the client's next animation frame at once instead of one at
  /// a time. Zero in tests that just want the end state fast.
  final Duration _botTurnPace;

  Ruleset get ruleset => room.ruleset;
  int get _handsPerGame => ruleset.handsPerGame(fullGame: room.hanchan);

  late Round round;
  final Map<int, SimpleBot> _bots = {};
  List<int> _points = List.filled(4, 25000);
  int _dealer = 0;
  int _roundNumber = 0;
  int _honba = 0;
  int _riichiSticks = 0;

  int _discardSerial = 0;
  int? _lastDiscardSeat;
  bool _lastDiscardTsumogiri = false;

  /// When the seat currently on the clock (round.turn, mid `discardingPhase`)
  /// must act by — or, during the call phase, when the players offered a call
  /// must answer by — or null when no timer is running (between actions and at
  /// round end). Read by [_sendStateTo]
  /// so every client can render the same countdown for whoever's turn it is.
  DateTime? _actionDeadline;

  final Map<int, Completer<Map<String, dynamic>?>> _pending = {};
  final Map<int, Timer> _disconnectTimers = {};
  final Map<int, int> _timeoutStrikes = {};
  Completer<void>? _continueWaiter;

  bool _ended = false;
  bool _started = false;

  bool isBotControlled(int seat) => _bots.containsKey(seat);

  /// Pushes whatever telemetry is buffered right now, without waiting for
  /// the 15s timer. A no-op if telemetry is off, or nothing is buffered.
  /// Called for every room on process shutdown (see `bin/mp_server.dart`) —
  /// otherwise a `systemctl restart` mid-match could silently drop up to
  /// 15s of already-happened rounds/discards that never made it to
  /// Postgres, on top of whatever room state it already drops by design.
  Future<void> flushTelemetry() => _tel?.flush() ?? Future.value();

  Wind get _roundWind => _roundNumber < 4 ? Wind.east : Wind.south;

  /// Starts the game loop. Randomizes who sits where first (so join order
  /// doesn't decide who deals first), then fills any still-empty seat with a
  /// bot.
  void start() {
    if (_started) return;
    _started = true;
    _points = List.filled(4, ruleset.startingPoints);
    _shuffleSeats();
    for (var i = 0; i < 4; i++) {
      if (room.seats[i] == null) {
        final character = room.resolveCharacter(null, _rng);
        room.seats[i] = Seat(
          guestId: 'bot-$i',
          name: Room.characterName[character]!,
          character: character,
        )..isBot = true;
      }
      if (room.seats[i]!.isBot) _bots[i] = SimpleBot(_rng.nextInt(1 << 31));
    }
    room.phase = RoomPhase.playing;
    room.broadcastRoomState();
    _matchId = newUuid();
    final tel = _tel;
    if (tel != null) {
      tel.matchStart(
        matchId: _matchId,
        roomCode: room.code,
        ruleset: ruleset.name,
        hanchan: room.hanchan,
        timerSeconds: room.timerSeconds,
        seatCharacters: [for (final s in room.seats) s?.character],
        seatIsBot: [for (final s in room.seats) s?.isBot ?? false],
        seatGuestIds: [
          for (final s in room.seats) (s == null || s.isBot) ? null : s.guestId
        ],
        participants: [
          for (var i = 0; i < 4; i++)
            if (!room.seats[i]!.isBot)
              {
                'seat': '$i',
                'sessionId': i == room.hostSeat ? tel.hostSessionId : newUuid(),
                'guestId': room.seats[i]!.guestId,
              },
        ],
      );
    }
    _startRound();
    unawaited(_run());
  }

  /// Fisher-Yates over the occupied seats only — every connected guest keeps
  /// their own [Seat] (so `room_state`'s `character`/`isHost` for them is
  /// unaffected), just at a newly randomized index. Untouched empty slots
  /// are filled with bots right after by [start]. Each connection's socket
  /// handler (`server.dart`) resolves its own current seat by guest ID on
  /// every message rather than caching the index from `join_room`/
  /// `create_room`, so this reindexing needs no coordination with it.
  void _shuffleSeats() {
    final hostGuestId = room.seats[room.hostSeat]?.guestId;
    final occupied = [
      for (final s in room.seats)
        if (s != null) s
    ]..shuffle(_rng);
    var next = 0;
    for (var i = 0; i < 4; i++) {
      if (room.seats[i] != null) room.seats[i] = occupied[next++];
    }
    final newHostSeat = room.seats.indexWhere((s) => s?.guestId == hostGuestId);
    if (newHostSeat >= 0) room.hostSeat = newHostSeat;
  }

  void _startRound() {
    round = Round(
      seed: _rng.nextInt(1 << 31),
      dealer: _dealer,
      roundWind: _roundWind,
      honba: _honba,
      riichiSticks: _riichiSticks,
      startingPoints: List.of(_points),
      ruleset: ruleset,
      minimumFaan: room.minimumFaan,
      minimumPoints: room.minimumPoints,
    );
    _discardSerial = 0;
    _lastDiscardSeat = null;
    _lastDiscardTsumogiri = false;
    _roundId = newUuid();
    _tel?.roundStart(
      matchId: _matchId,
      roundId: _roundId,
      roundIndex: _roundNumber,
      roundWind: _roundWind.name,
      handNumber: (_roundNumber % 4) + 1,
      dealerSeat: _dealer,
      honba: _honba,
      riichiSticks: _riichiSticks,
    );
  }

  Future<void> _run() async {
    while (!_ended) {
      if (round.finished) {
        await _handleRoundEnd();
        continue;
      }
      switch (round.phase) {
        case RoundPhase.callOffer:
          await _resolveCallPhase();
        case RoundPhase.discarding:
          await _discardingPhase();
        case RoundPhase.drawing:
        case RoundPhase.finished:
          // Round transitions synchronously out of `drawing` inside its own
          // draw methods; this is only ever a transient value between two
          // Round calls, never a state the loop should sit in.
          break;
      }
    }
  }

  // --- turn phase --------------------------------------------------------

  Future<void> _discardingPhase() async {
    final seat = round.turn;
    if (isBotControlled(seat)) {
      await _applyBotTurn(seat);
      return;
    }
    while (true) {
      _actionDeadline = DateTime.now().add(_turnTimeout);
      _broadcastState();
      final action = await _awaitHumanAction(seat, _turnTimeout);
      if (_ended) return;
      _actionDeadline = null;
      if (action == null) {
        if (isBotControlled(seat)) return; // converted while waiting
        await _applyBotTurn(seat);
        _strike(seat);
        return;
      }
      if (_tryApplyHumanTurnAction(seat, action)) {
        _timeoutStrikes[seat] = 0;
        return;
      }
      room.sendError(seat, 'illegal action for the current turn');
    }
  }

  /// The permanent bot for an already-converted seat, or a fresh throwaway
  /// one for a single timed-out decision on an otherwise-human seat —
  /// `SimpleBot` is stateless across calls (it only ever reads `round`), so a
  /// one-off instance decides exactly as well as a persistent one would.
  SimpleBot _botFor(int seat) =>
      _bots[seat] ?? SimpleBot(_rng.nextInt(1 << 31));

  Future<void> _applyBotTurn(int seat) async {
    final decision = _botFor(seat).decideTurn(round, seat);
    if (decision.tsumo) {
      round.declareTsumo(seat);
    } else if (decision.closedKan != null) {
      round.closedKan(seat, decision.closedKan!);
    } else if (decision.addedKan != null) {
      round.addKan(seat, decision.addedKan!);
    } else {
      final tile = decision.discard ?? round.legalDiscards(seat).first;
      _noteDiscard(seat, tile);
      round.discard(seat, tile, declareRiichi: decision.riichi);
    }
    if (_botTurnPace > Duration.zero) await Future.delayed(_botTurnPace);
    _broadcastState();
  }

  bool _tryApplyHumanTurnAction(int seat, Map<String, dynamic> action) {
    final kind = action['kind'] as String?;
    switch (kind) {
      case 'tsumo':
        if (round.turn != seat || !round.canTsumo(seat)) return false;
        round.declareTsumo(seat);
        _broadcastState();
        return true;
      case 'pass_flower_win':
        if (!round.canFlowerWin(seat)) return false;
        round.passFlowerWin(seat);
        _broadcastState();
        return true;
      case 'kyuushu':
        if (!round.canDeclareKyuushu(seat)) return false;
        round.declareKyuushu(seat);
        _broadcastState();
        return true;
      case 'closed_kan':
        {
          final type = _parseTileType(action['tileType']);
          if (type == null ||
              round.turn != seat ||
              round.phase != RoundPhase.discarding ||
              !round.closedKanTypes(seat).contains(type)) {
            return false;
          }
          round.closedKan(seat, type);
          _broadcastState();
          return true;
        }
      case 'added_kan':
        {
          final type = _parseTileType(action['tileType']);
          if (type == null ||
              round.turn != seat ||
              round.phase != RoundPhase.discarding ||
              !round.addedKanTypes(seat).contains(type)) {
            return false;
          }
          round.addKan(seat, type);
          _broadcastState();
          return true;
        }
      case 'discard':
        {
          if (round.finished ||
              round.turn != seat ||
              round.phase != RoundPhase.discarding) {
            return false;
          }
          final tileId = action['tileId'] as int?;
          final declareRiichi = action['riichi'] as bool? ?? false;
          if (declareRiichi && !round.canRiichi(seat)) return false;
          Tile? tile;
          for (final t in round.legalDiscards(seat)) {
            if (t.id == tileId) tile = t;
          }
          if (tile == null) return false;
          _noteDiscard(seat, tile);
          _tel?.humanDecision(
            matchId: _matchId,
            roundId: _roundId,
            actorSeat: seat,
            kind: 'discard',
            tile: tile.code,
          );
          round.discard(seat, tile, declareRiichi: declareRiichi);
          _broadcastState();
          return true;
        }
      default:
        return false;
    }
  }

  void _noteDiscard(int seat, Tile tile) {
    _lastDiscardSeat = seat;
    _lastDiscardTsumogiri = tile.id == round.seats[seat].drawn?.id;
    _discardSerial++;
  }

  // --- call phase ----------------------------------------------------------

  Future<void> _resolveCallPhase() async {
    final choices = <int, CallType>{};
    final chiLow = <int, TileType>{};
    final humanSeats = <int>[];
    for (final opt in round.callOptions) {
      if (isBotControlled(opt.seat)) {
        final c = _botFor(opt.seat)
            .decideCall(round, opt.seat, round.pendingDiscard!, opt.types);
        if (c != CallType.none) choices[opt.seat] = c;
      } else {
        humanSeats.add(opt.seat);
      }
    }

    if (humanSeats.isNotEmpty) {
      // Clients render the same countdown for a pending call as for a turn.
      _actionDeadline = DateTime.now().add(_callTimeout);
      _broadcastState();
      final answers = await Future.wait([
        for (final seat in humanSeats) _awaitHumanAction(seat, _callTimeout)
      ]);
      _actionDeadline = null;
      if (_ended) return;
      for (var i = 0; i < humanSeats.length; i++) {
        final seat = humanSeats[i];
        final action = answers[i];
        final opt = round.callOptions.where((o) => o.seat == seat).firstOrNull;
        if (opt == null)
          continue; // the option evaporated (e.g. a ron elsewhere)
        if (isBotControlled(seat)) {
          // Converted to a bot while this call was pending; let it answer.
          final c = _botFor(seat)
              .decideCall(round, seat, round.pendingDiscard!, opt.types);
          if (c != CallType.none) choices[seat] = c;
          continue;
        }
        if (action == null) {
          // Timed out while still human: a bot decides this one call, same
          // as a timed-out turn, rather than defaulting to a pass.
          _strike(seat);
          final c = _botFor(seat)
              .decideCall(round, seat, round.pendingDiscard!, opt.types);
          if (c != CallType.none) choices[seat] = c;
          continue;
        }
        _timeoutStrikes[seat] = 0;
        final kind = action['kind'] as String?;
        var called = false;
        if (kind == 'call') {
          final callType = _parseCallType(action['callType']);
          if (callType != null &&
              callType != CallType.none &&
              opt.types.contains(callType)) {
            choices[seat] = callType;
            called = true;
            if (callType == CallType.chi) {
              final low = _parseTileType(action['chiLow']);
              if (low != null) chiLow[seat] = low;
            }
          }
        }
        // 'pass_call' (or any other/garbled message) leaves this seat passing.
        _tel?.humanDecision(
          matchId: _matchId,
          roundId: _roundId,
          actorSeat: seat,
          kind: called ? 'call' : 'pass',
          tile: round.pendingDiscard?.code,
        );
      }
    }

    round.resolveCalls(choices, chiLow: chiLow);
    _broadcastState();
  }

  // --- round end / next hand -----------------------------------------------

  Future<void> _handleRoundEnd() async {
    final r = round.result!;
    final isExhaustiveDraw = r.kind == RoundEndKind.exhaustiveDraw;
    // An abortive draw (e.g. kyuushu kyuuhai) is a void hand — the dealer
    // always repeats, whoever they are, no tenpai check involved.
    final dealerKept = r.kind == RoundEndKind.abortiveDraw ||
        (isExhaustiveDraw
            ? (ruleset.isChineseStyle || r.tenpaiAtDraw.contains(_dealer))
            : r.winners.contains(_dealer));

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
      pointDeltas: [for (var i = 0; i < 4; i++) r.pointDeltas[i] ?? 0],
      tenpaiAtDraw: r.tenpaiAtDraw,
      dealerKept: dealerKept,
    );

    _riichiSticks = round.riichiSticks;
    final rot = _rotateAfterRound(
      exhaustiveDraw: isExhaustiveDraw,
      dealerKept: dealerKept,
      dealer: _dealer,
      roundNumber: _roundNumber,
      honba: _honba,
      ruleset: ruleset,
    );
    _dealer = rot.dealer;
    _roundNumber = rot.roundNumber;
    _honba = rot.honba;
    _points = [for (var i = 0; i < 4; i++) round.seats[i].points];

    final tobi = ruleset.isRiichi && _points.any((p) => p < 0);
    final gameOver = tobi || (_roundNumber >= _handsPerGame && !dealerKept);

    _broadcastRoundResult(gameOver: gameOver);

    if (gameOver) {
      _ended = true;
      room.phase = RoomPhase.ended;
      final tel = _tel;
      if (tel != null) {
        tel.matchEnd(
          matchId: _matchId,
          reason: 'game_end',
          finalPoints: _points,
          seatPlaces: _placesFromPoints(_points),
        );
        unawaited(tel.dispose());
      }
      return;
    }

    await _awaitAnyContinue();
    if (_ended) return;
    _startRound();
  }

  Future<void> _awaitAnyContinue() async {
    final completer = Completer<void>();
    _continueWaiter = completer;
    final winners = round.result!.winners;
    final timeout = _continueTimeout ??
        kScorePageDelay * max(1, winners.length) +
            (winners.isEmpty ? Duration.zero : kCallPause);
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
    timer.cancel();
    _continueWaiter = null;
  }

  /// A pure copy of `GameController.rotateAfterRound` — kept here rather than
  /// imported, since the client controller lives in a Flutter-dependent
  /// package this pure-Dart server cannot build against. See
  /// flutter_client/lib/game/game_controller.dart for the source of truth;
  /// keep the two in sync if the rule ever changes.
  static ({int dealer, int roundNumber, int honba}) _rotateAfterRound({
    required bool exhaustiveDraw,
    required bool dealerKept,
    required int dealer,
    required int roundNumber,
    required int honba,
    required Ruleset ruleset,
  }) {
    if (ruleset.isTaiwanese) {
      final nextHonba = (dealerKept && !exhaustiveDraw) ? honba + 1 : 0;
      return dealerKept
          ? (dealer: dealer, roundNumber: roundNumber, honba: nextHonba)
          : (dealer: (dealer + 1) % 4, roundNumber: roundNumber + 1, honba: 0);
    }
    if (ruleset.isHongKong) {
      return dealerKept || exhaustiveDraw
          ? (dealer: dealer, roundNumber: roundNumber, honba: 0)
          : (dealer: (dealer + 1) % 4, roundNumber: roundNumber + 1, honba: 0);
    }
    final nextHonba = (exhaustiveDraw || dealerKept) ? honba + 1 : 0;
    if (dealerKept) {
      return (dealer: dealer, roundNumber: roundNumber, honba: nextHonba);
    }
    return (
      dealer: (dealer + 1) % 4,
      roundNumber: roundNumber + 1,
      honba: nextHonba,
    );
  }

  /// 1..4 standing per seat by final points (ties share the higher place) —
  /// the multiplayer analogue of `GameController._humanPlace`, computed for
  /// every seat at once rather than just the one human seat single-player
  /// has.
  static List<int> _placesFromPoints(List<int> points) => [
        for (var seat = 0; seat < points.length; seat++)
          1 + points.where((p) => p > points[seat]).length,
      ];

  // --- network I/O ----------------------------------------------------------

  /// Called by the connection layer for every `{"type":"action",...}` and
  /// `{"type":"continue_round"}` message from an already-seated player.
  void handleMessage(int seat, Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == 'continue_round') {
      _continueWaiter?.complete();
      return;
    }
    if (type == 'action') {
      final completer = _pending[seat];
      if (completer == null || completer.isCompleted) {
        room.sendError(seat, 'no action expected right now');
        return;
      }
      completer.complete(Map<String, dynamic>.from(message));
      return;
    }
  }

  /// A seat's socket closed. Immediately resolves any decision it owes (so
  /// the table isn't stuck waiting the full turn timeout) and starts the
  /// reconnect grace period.
  void handleDisconnect(int seat) {
    final completer = _pending[seat];
    if (completer != null && !completer.isCompleted) completer.complete(null);
    _disconnectTimers[seat]?.cancel();
    _disconnectTimers[seat] =
        Timer(_disconnectGrace, () => _convertToBot(seat, 'disconnected'));
    room.broadcastRoomState();
  }

  /// A guest reconnected to a seat that hasn't been converted to a bot.
  /// Sends it caught up with the room roster and the live table state.
  void handleReconnect(int seat) {
    _disconnectTimers.remove(seat)?.cancel();
    _timeoutStrikes.remove(seat);
    _tel?.seatEvent(
      matchId: _matchId,
      actorSeat: seat,
      event: 'reconnected',
      guestId: room.seats[seat]?.guestId,
    );
    room.broadcastRoomState();
    _sendStateTo(seat);
  }

  void _strike(int seat) {
    final strikes = (_timeoutStrikes[seat] ?? 0) + 1;
    _timeoutStrikes[seat] = strikes;
    if (strikes >= 3) _convertToBot(seat, 'unresponsive');
  }

  void _convertToBot(int seat, String reason) {
    if (isBotControlled(seat)) return;
    _tel?.seatEvent(
      matchId: _matchId,
      actorSeat: seat,
      event: 'bot_takeover',
      guestId: room.seats[seat]?.guestId,
      reason: reason,
    );
    _bots[seat] = SimpleBot(_rng.nextInt(1 << 31));
    room.seats[seat]?.isBot = true;
    _disconnectTimers.remove(seat)?.cancel();
    final completer = _pending.remove(seat);
    if (completer != null && !completer.isCompleted) completer.complete(null);
    for (var i = 0; i < 4; i++) {
      room.seats[i]?.send
          ?.call({'type': 'bot_takeover', 'seat': seat, 'reason': reason});
    }
    room.broadcastRoomState();
  }

  Future<Map<String, dynamic>?> _awaitHumanAction(
      int seat, Duration timeout) async {
    final completer = Completer<Map<String, dynamic>?>();
    _pending[seat] = completer;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });
    try {
      return await completer.future;
    } finally {
      timer.cancel();
      if (identical(_pending[seat], completer)) _pending.remove(seat);
    }
  }

  void _broadcastState() {
    for (var i = 0; i < 4; i++) {
      _sendStateTo(i);
    }
  }

  void _sendStateTo(int seat) {
    final send = room.seats[seat]?.send;
    if (send == null) return;
    send({
      'type': 'state',
      'yourSeat': seat,
      'gamePhase': 'playing',
      'handInWind': (_roundNumber % 4) + 1,
      'tablePoints': _points,
      'discardSerial': _discardSerial,
      'lastDiscardSeat': _lastDiscardSeat,
      'lastDiscardTsumogiri': _lastDiscardTsumogiri,
      'turnDeadlineMs': _actionDeadline?.millisecondsSinceEpoch,
      'round': roundSnapshotToJson(round, reveal: (s) => s == seat),
    });
  }

  void _broadcastRoundResult({required bool gameOver}) {
    for (var i = 0; i < 4; i++) {
      final send = room.seats[i]?.send;
      if (send == null) continue;
      send({
        'type': 'round_result',
        'yourSeat': i,
        'gamePhase': gameOver ? 'gameEnd' : 'roundEnd',
        'handInWind': (_roundNumber % 4) + 1,
        'tablePoints': _points,
        'discardSerial': _discardSerial,
        'lastDiscardSeat': _lastDiscardSeat,
        'lastDiscardTsumogiri': _lastDiscardTsumogiri,
        'round': roundSnapshotToJson(round, reveal: (s) => true),
      });
    }
  }

  TileType? _parseTileType(dynamic v) {
    if (v is! String) return null;
    for (final t in TileType.values) {
      if (t.name == v) return t;
    }
    return null;
  }

  CallType? _parseCallType(dynamic v) {
    if (v is! String) return null;
    for (final t in CallType.values) {
      if (t.name == v) return t;
    }
    return null;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
