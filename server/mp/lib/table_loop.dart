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

import 'mortal.dart';
import 'room.dart';
import 'telemetry.dart';

class TableLoop {
  /// The turn clock defaults to the room's [Room.discardSeconds] plus its
  /// [Room.callSeconds] (see [_turnTimeout]) and the call clock to its
  /// [Room.callSeconds]; the other durations to their production values; tests
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
    Duration abandonGrace = const Duration(minutes: 5),
    Duration? continueTimeout,
    Duration botTurnPace = const Duration(milliseconds: 900),
    Duration continueLock = kScoreContinueLock,
    Duration callDiscardHold = const Duration(milliseconds: 600),
    Duration? afterCallPace,
    MpTelemetry? telemetry,
    MortalAsk? mortal,
  })  : _mortal = mortal ?? MortalClient.maybe()?.ask,
        _turnTimeout = turnTimeout ??
            Duration(seconds: room.discardSeconds + room.callSeconds),
        _callTimeout = callTimeout ?? Duration(seconds: room.callSeconds),
        _disconnectGrace = disconnectGrace,
        _abandonGrace = abandonGrace,
        _continueTimeout = continueTimeout,
        _botTurnPace = botTurnPace,
        _continueLock = continueLock,
        _callDiscardHold = callDiscardHold,
        _afterCallPace =
            afterCallPace ?? kCallPause + const Duration(milliseconds: 700),
        _tel = telemetry ??
            (room.seats[room.hostSeat] == null
                ? null
                : MpTelemetry.maybe(
                    hostGuestId: room.seats[room.hostSeat]!.guestId,
                    hostSessionId: newUuid(),
                  ));

  final Room room;
  final Random _rng = Random.secure();
  final MpTelemetry? _tel;

  /// Mortal, when the server runs with `MORTAL_URL` (tests may pass one);
  /// see [_playsMortal].
  final MortalAsk? _mortal;

  /// This hand as mjai events, for Mortal; null when nobody here plays on
  /// Mortal. Kept in step with the round by [_syncMjai].
  MjaiRecorder? _mjai;
  late final String _matchId;
  late String _roundId;

  /// How long a human seat gets to answer its own turn (discard / kan /
  /// riichi / tsumo) before a bot plays that one decision for it, which also
  /// counts a strike towards a bot takeover (see [_strike]). The room's
  /// [Room.discardSeconds] plus its [Room.callSeconds], on every turn: a turn
  /// that follows a call window is shown running from the discard, through
  /// the window (see [_maskCallWindow]), so it always has the call clock's
  /// worth folded in — and every turn shows the same clock, so its length
  /// never hints at a pending call.
  final Duration _turnTimeout;

  /// How long a human seat gets to answer a call offer (chi/pon/kan/ron)
  /// before it is passed for them — no strike, since letting an offer go is
  /// a fine way to decline it. The room's [Room.callSeconds].
  final Duration _callTimeout;

  /// How long a disconnected seat is held open before a bot takes it over.
  /// The player can still reclaim it afterwards — see [reclaimSeat].
  final Duration _disconnectGrace;

  /// How long an all-bot table (every human gone) plays on before the match
  /// is abandoned, so a player who left by accident can still rejoin.
  final Duration _abandonGrace;

  /// How long the table waits for any player to click "next hand" at a round
  /// end before dealing it automatically (covers a room with no connected
  /// humans left, or everyone simply forgetting to click).
  /// Defaults to 25 seconds per score page, plus the winning call's bubble.
  final Duration? _continueTimeout;

  /// How long to sit on a bot's automatic discard before broadcasting it —
  /// with no delay here, a stretch of consecutive bot turns (nobody left to
  /// wait on) resolves within a single event-loop tick, and every discard in
  /// it lands in the client's next animation frame at once instead of one at
  /// a time. Zero in tests that just want the end state fast. Each turn
  /// varies it upwards (see [_botPace]), so a bot seat's pause while someone
  /// answers a call doesn't stand out against its usual one.
  final Duration _botTurnPace;

  /// How long after the score panel appears before anyone's Continue counts,
  /// so one player can't skip the scores before the others have read them.
  final Duration _continueLock;

  /// The least time a discard is on the table before a chi / pon / kan takes
  /// it. With only bots able to call, the call resolves the instant the
  /// discard is sent, and the tile would vanish from the pond before its
  /// 480 ms slide-in had finished.
  final Duration _callDiscardHold;

  /// How long a bot that has just called (or declared a kan of its own) waits
  /// before its next move is shown, about 2s: the call's bubble
  /// (`kCallPause` on the client) clears, then half a second more to take in
  /// the new meld before the next tile flies.
  final Duration _afterCallPace;

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

  /// When the latest discard was first broadcast (see [_callDiscardHold]).
  int? _shownSerial;
  DateTime _discardShownAt = DateTime.now();

  /// The seat that has just called or declared a kan, whose next move waits
  /// out [_afterCallPace]; null otherwise.
  int? _justCalled;
  int? _lastDiscardSeat;
  bool _lastDiscardTsumogiri = false;

  /// When the seat currently on the clock (round.turn, mid `discardingPhase`)
  /// must act by, or null when no turn timer is running (between actions, in
  /// a call window, and at round end). Read by [_sendStateTo]
  /// so every client can render the same countdown for whoever's turn it is.
  DateTime? _actionDeadline;

  /// While humans answer a call offer: when they must answer by. Only the
  /// seats with an offer are sent it.
  DateTime? _callDeadline;

  /// While humans answer a call offer: the deadline every other seat is shown
  /// for whoever plays next if nobody calls (see [_maskCallWindow]) — and
  /// which that turn then keeps, rather than starting a fresh clock.
  DateTime? _nextTurnDeadline;

  /// When [_nextTurnDeadline]'s turn visibly began, so a bot playing it
  /// doesn't add its whole thinking pause on top of the call window.
  DateTime? _nextTurnShownAt;

  final Map<int, Completer<Map<String, dynamic>?>> _pending = {};
  final Map<int, Timer> _disconnectTimers = {};
  final Map<int, int> _timeoutStrikes = {};
  Completer<void>? _continueWaiter;

  /// When a player's Continue starts counting this round end (see
  /// [_continueLock]); one pressed earlier is held until then.
  DateTime? _continueOpensAt;
  Timer? _earlyContinue;

  bool _ended = false;
  bool _started = false;

  /// Running while every seat is bot-controlled: the match ends when it
  /// fires, unless a human has reclaimed a seat first.
  Timer? _abandonTimer;

  bool isBotControlled(int seat) => _bots.containsKey(seat);

  /// Pushes whatever telemetry is buffered right now, without waiting for
  /// the 15s timer. A no-op if telemetry is off, or nothing is buffered.
  /// Called for every room on process shutdown (see `bin/mp_server.dart`) —
  /// otherwise a `systemctl restart` mid-match could silently drop up to
  /// 15s of already-happened rounds/discards that never made it to
  /// Postgres, on top of whatever room state it already drops by design.
  Future<void> flushTelemetry() => _tel?.flush() ?? Future.value();

  Wind get _roundWind => ruleset.isMcr ? Wind.values[(_roundNumber ~/ 4).clamp(0, 3)] : (_roundNumber < 4 ? Wind.east : Wind.south);

  /// Starts the game loop. Randomizes who sits where first (so join order
  /// doesn't decide who deals first), then fills any still-empty seat with a
  /// bot.
  void start() {
    if (_started) return;
    _started = true;
    _points = List.filled(4, ruleset.startingPoints);
    _shuffleSeats();
    // Under riichi the first bot is Saeko, who plays on Mortal, unless a
    // player already has her.
    var wantSaeko = ruleset.isRiichi;
    for (var i = 0; i < 4; i++) {
      if (room.seats[i] == null) {
        final character =
            room.resolveCharacter(wantSaeko ? 'saeko' : null, _rng);
        wantSaeko = false;
        room.seats[i] = Seat(
          guestId: 'bot-$i',
          name: Room.characterName[character]!,
          character: character,
        )
          ..isBot = true
          ..filledByBot = true;
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
        timerSeconds: room.discardSeconds,
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
      shuffleRng: _rng,
      dealer: _dealer,
      roundWind: _roundWind,
      honba: _honba,
      riichiSticks: _riichiSticks,
      startingPoints: List.of(_points),
      ruleset: ruleset,
      minimumFaan: room.minimumFaan,
      minimumPoints: room.minimumPoints,
    );
    _mjai = _mortal != null &&
            ruleset.isRiichi &&
            room.seats.any((s) => s?.character == 'saeko')
        ? MjaiRecorder(round, kyoku: (_roundNumber % 4) + 1)
        : null;
    _discardSerial = 0;
    _justCalled = null;
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
    // A turn already shown running through a call window keeps the deadline
    // and start it was shown with.
    final carried = _nextTurnDeadline;
    final shownAt = _nextTurnShownAt;
    _nextTurnDeadline = null;
    _nextTurnShownAt = null;
    if (isBotControlled(seat)) {
      await _applyBotTurn(seat, shownAt: shownAt);
      return;
    }
    final deadline = carried ?? DateTime.now().add(_turnTimeout);
    while (true) {
      _actionDeadline = deadline;
      _broadcastState();
      final left = deadline.difference(DateTime.now());
      final action =
          await _awaitHumanAction(seat, left.isNegative ? Duration.zero : left);
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
      room.sendError(seat, 'illegal_action', 'illegal action for the current turn');
    }
  }

  /// The permanent bot for an already-converted seat, or a fresh throwaway
  /// one for a single timed-out decision on an otherwise-human seat —
  /// `SimpleBot` is stateless across calls (it only ever reads `round`), so a
  /// one-off instance decides exactly as well as a persistent one would.
  SimpleBot _botFor(int seat) =>
      _bots[seat] ?? SimpleBot(_rng.nextInt(1 << 31));

  /// [_botTurnPace] up to about 2.8x (0.9–2.5 s in production).
  Duration _botPace() => _botTurnPace * (1 + 16 / 9 * _rng.nextDouble());

  /// [shownAt]: when this turn visibly began, if that was earlier than now
  /// (it ran through a call window); the pause only makes up the difference.
  Future<void> _applyBotTurn(int seat, {DateTime? shownAt}) async {
    // Right after this seat's call, its bubble is still up on every client.
    final pace = _justCalled == seat && _afterCallPace > _botTurnPace
        ? _afterCallPace
        : _botPace();
    _justCalled = null;
    shownAt ??= DateTime.now();
    final decision = await _botTurn(seat);
    if (_ended) return;
    if (decision.tsumo) {
      round.declareTsumo(seat);
    } else if (decision.closedKan != null) {
      round.closedKan(seat, decision.closedKan!);
      _justCalled = seat; // its KAN bubble, before the replacement's discard
    } else if (decision.addedKan != null) {
      round.addKan(seat, decision.addedKan!);
      _justCalled = seat;
    } else {
      final tile = decision.discard ?? round.legalDiscards(seat).first;
      _noteDiscard(seat, tile);
      round.discard(seat, tile, declareRiichi: decision.riichi);
    }
    // Mortal's thinking time comes out of the pause, not on top of it.
    final wait = pace - DateTime.now().difference(shownAt);
    if (wait > Duration.zero) await Future.delayed(wait);
    _broadcastState();
  }

  // --- Saeko on Mortal -----------------------------------------------------

  /// Whether Mortal plays [seat]: a bot seat showing Saeko, in a riichi game,
  /// on a server run with `MORTAL_URL` — as in single player. A timed-out
  /// human Saeko's one-off move stays on [SimpleBot].
  bool _playsMortal(int seat) =>
      _mjai != null &&
      _bots.containsKey(seat) &&
      room.seats[seat]?.character == 'saeko';

  /// Brings [_mjai] up to date with the round. It must see every action
  /// separately to keep them in order, so this runs at every broadcast (each
  /// follows exactly one action) and before every question to Mortal.
  void _syncMjai() {
    try {
      _mjai?.sync();
    } catch (e) {
      // A recorder that can't follow the table would only feed Mortal a
      // wrong hand: Saeko finishes this one on SimpleBot instead.
      print('[mp] mjai recorder stopped: $e');
      _mjai = null;
    }
  }

  /// Mortal's reply read by [read], or [fallback]'s answer if Mortal fails
  /// or names a move this table doesn't offer.
  Future<T> _askMortal<T>(int seat, T Function(Map<String, Object?>) read,
      T Function() fallback) async {
    _syncMjai();
    final mjai = _mjai;
    if (mjai == null) return fallback();
    try {
      return read(await _mortal!(seat, List.of(mjai.events)));
    } catch (e) {
      print('[mp] Saeko (Mortal) fell back to SimpleBot: $e');
      return fallback();
    }
  }

  Future<BotTurn> _botTurn(int seat) async {
    BotTurn simple() => _botFor(seat).decideTurn(round, seat);
    if (!_playsMortal(seat)) return simple();
    return _askMortal(
        seat, (reply) => MortalMove.turn(reply, round, seat), simple);
  }

  /// [opt]'s bot answer; a chi names its run in `chiLow`.
  Future<({CallType call, TileType? chiLow})> _botCall(CallOption opt) async {
    ({CallType call, TileType? chiLow}) simple() => (
          call: _botFor(opt.seat)
              .decideCall(round, opt.seat, round.pendingDiscard!, opt.types),
          chiLow: null
        );
    if (!_playsMortal(opt.seat)) return simple();
    return _askMortal(opt.seat,
        (reply) => MortalMove.call(reply, round, opt.seat, opt.types), simple);
  }

  void _noteBotCall(int seat, ({CallType call, TileType? chiLow}) answer,
      Map<int, CallType> choices, Map<int, TileType> chiLow) {
    if (answer.call == CallType.none) return;
    choices[seat] = answer.call;
    if (answer.chiLow != null) chiLow[seat] = answer.chiLow!;
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
    // Bots answer while the humans think: Mortal may take a moment.
    final botAnswers = <int, Future<({CallType call, TileType? chiLow})>>{};
    for (final opt in round.callOptions) {
      if (isBotControlled(opt.seat)) {
        botAnswers[opt.seat] = _botCall(opt);
      } else {
        humanSeats.add(opt.seat);
      }
    }

    if (humanSeats.isNotEmpty) {
      // The seats with an offer get the call clock; everyone else sees the
      // next turn's clock start (see [_maskCallWindow]).
      final now = DateTime.now();
      _callDeadline = now.add(_callTimeout);
      _nextTurnDeadline = now.add(_turnTimeout);
      _nextTurnShownAt = now;
      _broadcastState();
      final answers = await Future.wait([
        for (final seat in humanSeats) _awaitHumanAction(seat, _callTimeout)
      ]);
      _callDeadline = null;
      if (_ended) return;
      for (var i = 0; i < humanSeats.length; i++) {
        final seat = humanSeats[i];
        final action = answers[i];
        final opt = round.callOptions.where((o) => o.seat == seat).firstOrNull;
        if (opt == null)
          continue; // the option evaporated (e.g. a ron elsewhere)
        if (isBotControlled(seat)) {
          // Converted to a bot while this call was pending; let it answer.
          _noteBotCall(seat, await _botCall(opt), choices, chiLow);
          if (_ended) return;
          continue;
        }
        // Timed out while still human: the offer is passed, a ron included,
        // and it is no strike — a turn timeout still is.
        if (action == null) continue;
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

    for (final e in botAnswers.entries) {
      _noteBotCall(e.key, await e.value, choices, chiLow);
    }
    if (_ended) return;

    // A chi / pon / kan takes the discard out of the pond: let it be seen
    // landing first. (A ron ends the hand, and its panel already waits out
    // the bubble; a pass leaves the tile where it is.)
    final meldCalls = {
      for (final e in choices.entries)
        if (e.value != CallType.ron) e.key: e.value
    };
    final ron = choices.values.contains(CallType.ron);
    if (meldCalls.isNotEmpty && !ron) {
      final wait =
          _callDiscardHold - DateTime.now().difference(_discardShownAt);
      if (wait > Duration.zero) await Future.delayed(wait);
      if (_ended) return;
    }

    round.resolveCalls(choices, chiLow: chiLow);
    // Only an unclaimed window leads into the turn that was shown starting;
    // a call (or the hand ending) gives whoever plays next a clock of their
    // own.
    if (choices.isNotEmpty || round.finished) {
      _nextTurnDeadline = null;
      _nextTurnShownAt = null;
    } else if (_nextTurnDeadline != null && !isBotControlled(round.turn)) {
      // Unclaimed: the turn shown starting carries straight on, clock and
      // all — no gap in it that a window, unlike a plain turn, would leave.
      _actionDeadline = _nextTurnDeadline;
    }
    // Whoever's call went through now has the turn; a bot holds its move
    // for the bubble (a human's turn is theirs to take).
    if (!ron &&
        round.phase == RoundPhase.discarding &&
        meldCalls.containsKey(round.turn) &&
        isBotControlled(round.turn)) {
      _justCalled = round.turn;
    }
    _broadcastState();
  }

  // --- round end / next hand -----------------------------------------------

  Future<void> _handleRoundEnd() async {
    final r = round.result!;
    final isExhaustiveDraw = r.kind == RoundEndKind.exhaustiveDraw;
    // An abortive draw (e.g. kyuushu kyuuhai) is a void hand — the dealer
    // always repeats, whoever they are, no tenpai check involved.
    final dealerKept = !ruleset.isMcr && (r.kind == RoundEndKind.abortiveDraw ||
        (isExhaustiveDraw
            ? (ruleset.isChineseStyle || r.tenpaiAtDraw.contains(_dealer))
            : r.winners.contains(_dealer)));

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
      _endMatch('game_end');
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
    // Clients hold a win's panel back behind the call bubble and the win
    // pause (see the client's ScoringView); the lock starts when it shows.
    final revealWait =
        winners.isEmpty ? Duration.zero : kCallPause + kWinScorePause;
    _continueOpensAt = DateTime.now().add(revealWait + _continueLock);
    final timeout = _continueTimeout ??
        kScorePageDelay * max(1, winners.length) + revealWait;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
    timer.cancel();
    _earlyContinue?.cancel();
    _earlyContinue = null;
    _continueOpensAt = null;
    _continueWaiter = null;
  }

  /// A player pressed Continue. Before the lock is up it is held until then
  /// rather than dropped, so a panel that showed a moment early on one
  /// client still gets its press honoured. Later presses (several players,
  /// or one pressing twice) are no-ops.
  void _requestContinue() {
    final completer = _continueWaiter;
    if (completer == null || completer.isCompleted) return;
    final wait = _continueOpensAt?.difference(DateTime.now()) ?? Duration.zero;
    if (wait <= Duration.zero) {
      completer.complete();
      return;
    }
    _earlyContinue ??= Timer(wait, () {
      _earlyContinue = null;
      if (!completer.isCompleted) completer.complete();
    });
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
    if (ruleset.isMcr) {
      return (dealer: (dealer + 1) % 4, roundNumber: roundNumber + 1, honba: 0);
    }
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
      _requestContinue();
      return;
    }
    if (type == 'action') {
      final completer = _pending[seat];
      if (completer == null || completer.isCompleted) {
        room.sendError(seat, 'no_action_expected', 'no action expected right now');
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
    // With nobody left the bots play on, unwatched, for [_abandonGrace] so
    // whoever left by accident can still come back; after that the table
    // would only hold memory.
    if (!_ended && _abandonTimer == null && room.seats.every((s) => s!.isBot)) {
      _abandonTimer = Timer(_abandonGrace, () {
        _abandonTimer = null;
        if (!_ended && room.seats.every((s) => s!.isBot)) {
          _endMatch('abandoned');
        }
      });
    }
  }

  /// A human who was converted to a bot (see [_convertToBot]) came back:
  /// their seat is theirs again from the next decision on. The caller
  /// attaches the socket and then calls [handleReconnect].
  void reclaimSeat(int seat) {
    if (!isBotControlled(seat) || (room.seats[seat]?.filledByBot ?? true)) {
      return;
    }
    _bots.remove(seat);
    room.seats[seat]!.isBot = false;
    _abandonTimer?.cancel();
    _abandonTimer = null;
    _tel?.seatEvent(
      matchId: _matchId,
      actorSeat: seat,
      event: 'reclaimed',
      guestId: room.seats[seat]?.guestId,
    );
  }

  /// Stops the loop, reports the match's end, and frees the room.
  void _endMatch(String reason) {
    _ended = true;
    _earlyContinue?.cancel();
    _earlyContinue = null;
    _abandonTimer?.cancel();
    _abandonTimer = null;
    room.phase = RoomPhase.ended;
    final tel = _tel;
    if (tel != null) {
      tel.matchEnd(
        matchId: _matchId,
        reason: reason,
        finalPoints: _points,
        seatPlaces: _placesFromPoints(_points),
      );
      unawaited(tel.dispose());
    }
    room.onIdleEmpty?.call();
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
    _syncMjai();
    if (_discardSerial != _shownSerial) {
      _shownSerial = _discardSerial;
      _discardShownAt = DateTime.now();
    }
    for (var i = 0; i < 4; i++) {
      _sendStateTo(i);
    }
  }

  void _sendStateTo(int seat) {
    final send = room.seats[seat]?.send;
    if (send == null) return;
    var snapshot = roundSnapshotToJson(round, reveal: (s) => s == seat);
    var deadline = _actionDeadline;
    if (round.phase == RoundPhase.callOffer && !round.finished) {
      if (round.callOptions.any((o) => o.seat == seat)) {
        deadline = _callDeadline;
      } else {
        final next = _nextToPlay;
        snapshot = _maskCallWindow(snapshot, viewer: seat, next: next);
        // A bot's turn never shows a clock.
        deadline = isBotControlled(next) ? null : _nextTurnDeadline;
      }
    }
    send({
      'type': 'state',
      'yourSeat': seat,
      'gamePhase': 'playing',
      'handInWind': (_roundNumber % 4) + 1,
      'tablePoints': _points,
      'discardSerial': _discardSerial,
      'lastDiscardSeat': _lastDiscardSeat,
      'lastDiscardTsumogiri': _lastDiscardTsumogiri,
      'turnDeadlineMs': deadline?.millisecondsSinceEpoch,
      'round': snapshot,
    });
  }

  /// Who plays once the open call window closes unclaimed: the discarder's
  /// next seat — or, for a kan nobody robbed, the kan's own seat.
  int get _nextToPlay => round.chankanPending
      ? round.turn
      : (round.pendingDiscardSeat + 1) % 4;

  /// What a seat with no offer of its own is shown while others answer one:
  /// the next player's turn already under way, exactly as it looks when
  /// nobody can call (drawn tile, wall count and all) — so the wait reads as
  /// that player thinking, never as somebody, let alone who, weighing a
  /// call. The next player is shown their own turn waiting on its draw, since
  /// their real hand can't show a tile they don't have yet.
  static Map<String, dynamic> _maskCallWindow(Map<String, dynamic> snapshot,
      {required int viewer, required int next}) {
    final masked = Map<String, dynamic>.from(snapshot)
      ..['turn'] = next
      ..['pendingDiscard'] = null
      ..['pendingDiscardSeat'] = null
      ..['callOptions'] = const <Object>[];
    if (viewer == next) {
      masked['phase'] = RoundPhase.drawing.name;
      return masked;
    }
    masked['phase'] = RoundPhase.discarding.name;
    final wall = snapshot['wallRemaining'] as int;
    if (wall > 0) {
      masked['wallRemaining'] = wall - 1;
      masked['seats'] = [
        for (final s in (snapshot['seats'] as List).cast<Map<String, dynamic>>())
          s['seat'] == next
              ? {
                  ...s,
                  'handCount': (s['handCount'] as int) + 1,
                  'hasDrawn': true,
                }
              : s,
      ];
    }
    return masked;
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
