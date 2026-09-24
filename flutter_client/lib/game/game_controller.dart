/// Drives an offline hanchan: owns the [Round], three [SimpleBot]s, the async
/// turn loop, and the live [EfficiencyReport] in one cooperative loop.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:mahjong_core/bot.dart';
import 'package:mahjong_core/hong_kong/hong_kong_rules.dart';
import '../logic/efficiency_engine.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/safety.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';
import '../telemetry/telemetry.dart';
import 'call_callout.dart';
import 'guide_host.dart';
import 'sfx.dart';

export 'guide_host.dart' show GamePhase;

const int kHumanSeat = 0;

/// How long a riichi hand waits before its drawn tile is cut on its own: a
/// random 0.5–1.5 s, so the discard reads like a hand putting it down rather
/// than the tile vanishing the instant it lands. Shared by the solo and
/// online controllers.
Duration riichiAutoDiscardDelay(Random rng) =>
    Duration(milliseconds: 500 + rng.nextInt(1001));

/// The default personality per seat — 0 self (Orderic), 1 right (Grant),
/// 2 across (Hubert), 3 left (Astaroth) — and what a fresh [GameController]
/// starts with. Every seat, including the human's, can be changed to any of
/// the five personas afterward; see [GameController.setSeatCharacter].
const List<Character> kSeatCharacters = [
  Character.orderic,
  Character.grant,
  Character.hubert,
  Character.astaroth,
];

/// Fixed seat labels for contexts with no per-table character choice — the
/// scenario builder's posed table (`ScenarioController.seatLabel`). The live
/// game's own [GameController.seatLabel] tracks whatever persona is actually
/// assigned instead, since that can change after this list was picked.
const List<String> kSeatNames = ['Orderic', 'Grant', 'Hubert', 'Astaroth'];

/// How many East-round hands before the game ends (tonpuusen). Renchan can
/// extend past this.
const int kRoundsPerGame = 4;

class GameController extends ChangeNotifier implements TableGameHost {
  /// [botFactory] builds the four opponents, one per seat, and defaults to the
  /// shipped [SimpleBot]. It exists for measurement harnesses: the stock bots
  /// never fold, which makes this table far kinder to a riichi than real play
  /// is, so anything calibrated against them would be tuned to exploit blind
  /// feeding. Leave it unset and the game plays exactly as it always has.
  ///
  /// [ruleset] picks the game; it can be changed later with [setRuleset].
  GameController({
    int? seed,
    SimpleBot Function(int seed)? botFactory,
    this.ruleset = Ruleset.riichi,
    this.startingDealer = 0,
    this.hanchan = true,
    this.minimumFaan = HongKongRules.defaultMinimumFaan,
    List<Character>? seatCharacters,
  })  : _seed = seed ?? DateTime.now().millisecondsSinceEpoch,
        seatCharacters = List.of(seatCharacters ?? kSeatCharacters),
        _botFactory = botFactory ?? SimpleBot.new {
    if (ruleset.isChineseStyle) {
      playStyle = PlayStyle.balanced;
      strategy = Strategy.points;
    }
    _startGame();
  }

  /// Japanese riichi, Hong Kong, or Taiwanese rules for every hand of this
  /// game.
  Ruleset ruleset;

  /// The style in effect when Hong Kong or Taiwanese last pinned it, so it
  /// comes back on switching to riichi rather than staying stuck on
  /// Balanced. See [setRuleset].
  PlayStyle? _preHongKongStyle;

  /// The strategy in effect when Hong Kong or Taiwanese last pinned it —
  /// mirrors [_preHongKongStyle]. Placement isn't wired up for either yet
  /// (see [Strategy]), so this is pinned to Points the same way Style is
  /// pinned to Balanced there.
  Strategy? _preHongKongStrategy;

  /// Switching rules abandons the game in progress and deals a fresh one. The
  /// guide's dials carry across — except Style, which Hong Kong and
  /// Taiwanese have no use for (see [PlayStyle]) and pin to Balanced, and
  /// Strategy, which is riichi-only for now and pins to Points; both come
  /// back on the way out.
  void setRuleset(Ruleset value) {
    if (ruleset == value) return;
    if (value.isChineseStyle) {
      // Only save on the way in from riichi — Hong Kong <-> Taiwanese is
      // already pinned on both sides, and re-saving here would clobber the
      // riichi style with the pinned Balanced/Points it is currently
      // showing.
      if (!ruleset.isChineseStyle) {
        _preHongKongStyle = playStyle;
        _preHongKongStrategy = strategy;
      }
      playStyle = PlayStyle.balanced;
      strategy = Strategy.points;
    } else {
      // A game created directly in Hong Kong/Taiwanese has no saved riichi
      // preferences. Start riichi on its measured defaults in that case.
      playStyle = _preHongKongStyle ?? kDefaultPlayStyle;
      strategy = _preHongKongStrategy ?? kDefaultStrategy;
      _preHongKongStyle = null;
      _preHongKongStrategy = null;
    }
    ruleset = value;
    _tel?.settingChange(
        matchId: _matchId, setting: 'ruleset', value: value.name);
    newGame();
  }

  int _seed;
  final SimpleBot Function(int seed) _botFactory;
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

  /// Deals the current hand afresh, exactly as [_startRound] first dealt it.
  late Round Function() _dealRound;

  /// Every change made to [round] this hand, in order. Replaying a prefix of
  /// it onto [_dealRound] rebuilds the table as it stood at that point.
  final List<_Move> _log = [];

  /// Your decisions this hand, newest last: where [_log] stood just before
  /// each one, and what to call it on the take-back button.
  final List<({int logLength, String label})> _undoStack = [];

  void _apply(_Move move) {
    _log.add(move);
    move.applyTo(round);
  }

  void _markUndoPoint(String label) =>
      _undoStack.add((logLength: _log.length, label: label));

  @override
  bool get canUndo =>
      _undoStack.isNotEmpty &&
      !paused &&
      phase == GamePhase.playing &&
      !round.finished;

  @override
  String? get undoLabel => _undoStack.isEmpty ? null : _undoStack.last.label;

  /// Takes back your latest decision this hand — a discard, a call, a pass
  /// or a kan — along with everything the bots did after it, and hands the
  /// turn back to you at that point. Pressed again, it steps further back.
  ///
  /// The table is rebuilt rather than rewound: the hand is dealt again from
  /// the same seed and the moves before that decision are replayed onto it.
  /// So the wall is the same one, and you will draw the tiles you already
  /// saw — this is for studying another line, not for fishing a new draw.
  @override
  void undo() {
    if (!canUndo) return;
    final step = _undoStack.removeLast();
    _loopTimer?.cancel();
    _loopTimer = null;
    _autoDiscardTimer?.cancel();

    final replay = _log.sublist(0, step.logLength);
    _log.clear();
    round = _dealRound();
    for (final move in replay) {
      _apply(move);
    }

    // The guide was playing your seat: hand it back to you, or it would
    // make the same move again straight away.
    if (autoplay) {
      autoplay = false;
      _tel?.settingChange(matchId: _matchId, setting: 'autoplay', value: false);
    }
    _humanCallOption = null;
    _humanCallAdvice = null;
    lastDiscardSeat = null;
    lastDiscardTsumogiri = false;
    discardSerial++;
    _tel?.humanDecision(
      matchId: _matchId,
      roundId: _roundId,
      kind: 'undo',
      auto: false,
      guideVisible: guideVisible,
    );
    _refreshReport();
    notifyListeners();
    // Straight back to your decision — a call offer is re-offered here.
    _tick();
  }
  List<int> _points = List.filled(4, 25000);
  int _dealer = 0;
  int _roundNumber = 0; // 0-based East 1..4
  int _honba = 0;
  int _dealerRepeat = 0;
  int _riichiSticks = 0;

  /// Hands dealt this game. Seeds each Hong Kong deal: its dealer repeats on a
  /// draw with no honba to tell the repeat apart, so the riichi seed would
  /// deal the same hand again.
  int _dealSerial = 0;

  @override
  GamePhase phase = GamePhase.playing;
  bool autoplay = false;

  /// On by default. Browsers routinely re-suspend playback (backgrounding,
  /// screen lock, iPad multitasking) in ways that can leave bot/Auto-Play sfx
  /// and voice lines silently dropped; turning sound off and on again is itself
  /// a fresh user gesture, so it doubles as the manual "resync" a player can
  /// reach for if the browser's audio context ever gets stuck suspended
  /// mid-game.
  @override
  bool get soundOn => Sfx.i.enabled;
  @override
  void setSoundOn(bool value) {
    if (Sfx.i.enabled == value) return;
    Sfx.i.enabled = value;
    if (value) Sfx.i.unlock();
    if (value) unawaited(Sfx.i.preload(characters: seatCharacters));
    _tel?.settingChange(matchId: _matchId, setting: 'sound', value: value);
    notifyListeners();
  }

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

  /// Declare ron/tsumo automatically the moment one is legal — see
  /// [_maybeAutoTsumo] and [_resolveCallPhase]. Independent of [autoplay],
  /// which already makes its own win decisions.
  @override
  bool autoWin = true;
  @override
  void setAutoWin(bool value) {
    if (autoWin == value) return;
    autoWin = value;
    _tel?.settingChange(matchId: _matchId, setting: 'auto_win', value: value);
    notifyListeners();
  }

  /// Returns true if it fired (and so already ended the round/notified
  /// listeners itself via [humanTsumo]).
  bool _maybeAutoTsumo() {
    if (!autoWin || !round.canTsumo(kHumanSeat)) return false;
    humanTsumo();
    return true;
  }

  /// While locked into riichi, cut the drawn tile on its own after a short
  /// random pause ([riichiAutoDiscardDelay]) — every later discard is already
  /// forced to be the drawn tile ([Round.discard]'s tsumogiri lock), so there
  /// is nothing to confirm. Never fires with a self-kan on offer (a real
  /// decision, left to the player) or a tsumo/flower win on offer (a win is
  /// never thrown away). A tap on the tile during the pause still discards it
  /// at once; the timer then finds the turn already over and does nothing.
  void _maybeAutoDiscardInRiichi() {
    final human = round.seats[kHumanSeat];
    if (!human.riichi) return;
    if (round.canTsumo(kHumanSeat) || round.canFlowerWin(kHumanSeat)) return;
    if (round.closedKanTypes(kHumanSeat).isNotEmpty) return;
    final drawn = human.drawn;
    if (drawn == null) return;
    final r = round;
    _autoDiscardTimer?.cancel();
    _autoDiscardTimer = Timer(riichiAutoDiscardDelay(_autoDiscardRng), () {
      // Paused meanwhile: resuming re-runs the turn step, which re-arms this.
      if (_disposed || paused || autoplay || !identical(r, round)) return;
      if (r.turn != kHumanSeat ||
          r.phase != RoundPhase.discarding ||
          r.seats[kHumanSeat].drawn?.id != drawn.id) {
        return;
      }
      humanDiscard(drawn);
    });
  }

  Timer? _autoDiscardTimer;
  final _autoDiscardRng = Random();

  /// How the guide weighs danger against value. Feeds every score it produces,
  /// so it steers Autoplay — which plays from those scores — as well as the
  /// panel.
  @override
  PlayStyle playStyle = kDefaultPlayStyle;
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
  HandFocus handFocus = kDefaultHandFocus;
  @override
  void setHandFocus(HandFocus value) {
    if (handFocus == value) return;
    handFocus = value;
    _tel?.settingChange(
        matchId: _matchId, setting: 'hand_focus', value: value.name);
    _refreshReport();
    notifyListeners();
  }

  /// Points or placement — the third dial, independent of both the others.
  /// Riichi only: [setRuleset] pins it to [Strategy.points] under Hong Kong,
  /// the same way it pins [playStyle] to Balanced there.
  @override
  Strategy strategy = kDefaultStrategy;
  @override
  void setStrategy(Strategy value) {
    if (strategy == value) return;
    strategy = value;
    _tel?.settingChange(
        matchId: _matchId, setting: 'strategy', value: value.name);
    _refreshReport();
    notifyListeners();
  }

  /// The full game when true — hanchan (East + South, 8 hands), same for
  /// both rulesets — and East-only (4 hands) when false. The full game is
  /// the default.
  bool hanchan;
  int get _handsPerGame => ruleset.handsPerGame(fullGame: hanchan);

  /// Hong Kong only: the fewest faan a hand needs to win — one of
  /// [HongKongRules.minimumFaanChoices], 0 by default. Kept across a switch
  /// to another ruleset, which ignores it.
  int minimumFaan;

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

  /// Offline play never rushes the human, on a call offer or on a discard —
  /// see [GuideHost.turnDeadlineMs]. Only the online table has clocks.
  @override
  int? get callDeadlineMs => null;

  @override
  CallOption? get humanCallOption => _humanCallOption;

  /// The guide's verdict on [_humanCallOption], cached alongside it.
  CallAdvice? _humanCallAdvice;

  Timer? _loopTimer;
  bool _disposed = false;

  /// When paused the async turn loop stops (bots and autoplay freeze). Toggled
  /// by pressing Escape.
  @override
  bool paused = false;
  void togglePause() {
    paused = !paused;
    if (!paused) _scheduleLoop();
    notifyListeners();
  }

  int get roundNumber => _roundNumber;
  @override
  int get honba => _honba;
  @override
  int get dealerRepeat => _dealerRepeat;
  int get riichiSticks => _riichiSticks;

  /// East for hands 1-4, South for 5-8 — hanchan, same for both rulesets.
  Wind get roundWind => _roundNumber < 4 ? Wind.east : Wind.south;

  /// 1-4 within the current round wind.
  @override
  int get handInWind => (_roundNumber % 4) + 1;
  @override
  List<int> get tablePoints => _points;

  /// Offline play never rushes the human — see [GuideHost.turnDeadlineMs].
  @override
  int? get turnDeadlineMs => null;

  /// Which persona each seat renders and voices as, human seat included.
  /// Starts at [kSeatCharacters]; change it with [setSeatCharacter].
  List<Character> seatCharacters;

  Character _characterForSeat(int seat) => seatCharacters[seat];

  @override
  Character characterForSeat(int seat) => _characterForSeat(seat);

  /// Assigns [seat] the persona [c]. Seats may duplicate — this is a local
  /// game against bots, not a room full of distinct people, so there is no
  /// identity to protect the way the online lobby's `Room.resolveCharacter`
  /// does for real players; two (or four) seats can share a look and voice
  /// if that's what's picked.
  void setSeatCharacter(int seat, Character c) {
    if (seatCharacters[seat] == c) return;
    seatCharacters[seat] = c;
    if (soundOn) unawaited(Sfx.i.preload(characters: [c]));
    notifyListeners();
  }

  @override
  String seatLabel(int seat) => seat == kHumanSeat
      ? '${kCharacterName[_characterForSeat(seat)]!} (you)'
      : kCharacterName[_characterForSeat(seat)]!;

  void setHanchan(bool value) {
    if (hanchan == value) return;
    hanchan = value;
    newGame();
  }

  /// Like switching rules, a new minimum abandons the game in progress —
  /// but only a Hong Kong one, since no other ruleset reads it.
  void setMinimumFaan(int value) {
    value = HongKongRules.normalizeMinimumFaan(value);
    if (minimumFaan == value) return;
    minimumFaan = value;
    _tel?.settingChange(
        matchId: _matchId, setting: 'minimumFaan', value: '$value');
    if (ruleset.isHongKong) newGame();
  }

  // --- lifecycle -------------------------------------------------------

  /// The seat that deals first, and so is East, when a match starts; the human
  /// is [kHumanSeat], so this is what decides which wind you begin on
  /// (`(4 - startingDealer) % 4`). Change it with [setStartingDealer].
  int startingDealer;

  /// Which wind the human seat begins on.
  Wind get humanStartingWind => Wind.values[(4 - startingDealer) % 4];

  /// Picks which seat deals first. Like switching rules, this abandons the
  /// game in progress for a fresh one, since the deal is what it changes.
  void setStartingDealer(int seat) {
    if (startingDealer == seat) return;
    startingDealer = seat;
    newGame();
  }

  void _startGame() {
    _points = List.filled(4, ruleset.startingPoints);
    _dealSerial = 0;
    _dealer = startingDealer;
    _roundNumber = 0;
    _honba = 0;
    _dealerRepeat = 0;
    _riichiSticks = 0;
    phase = GamePhase.playing;
    _matchId = newUuid();
    _tel?.matchStart(
      matchId: _matchId,
      seed: _seed,
      hanchan: hanchan,
      ruleset: ruleset.name,
      fastMode: fastMode,
      autoplay: autoplay,
      guideVisible: guideVisible,
      seatCharacters: [for (final c in seatCharacters) c.name],
      seatIsBot: [for (var seat = 0; seat < 4; seat++) seat != kHumanSeat],
    );
    _startRound();
  }

  @override
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
    final serial = _dealSerial++;
    final seed = ruleset.isChineseStyle
        ? _seed + serial
        : _seed + _roundNumber * 100 + _honba;
    final dealer = _dealer;
    final wind = roundWind;
    final honba = _honba;
    final sticks = _riichiSticks;
    final points = List.of(_points);
    final rules = ruleset;
    final faan = minimumFaan;
    // Kept so [undo] can deal this exact hand again: the wall shuffles from
    // the seed, so the same arguments give the same tiles with the same ids.
    _dealRound = () => Round(
          seed: seed,
          dealer: dealer,
          roundWind: wind,
          honba: honba,
          riichiSticks: sticks,
          startingPoints: points,
          ruleset: rules,
          minimumFaan: faan,
        );
    round = _dealRound();
    _log.clear();
    _undoStack.clear();
    _bots = [
      for (var i = 0; i < 4; i++) _botFactory(_seed + i * 7 + _roundNumber)
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

  /// Pure seat-wind / honba bookkeeping applied between rounds.
  ///
  /// [dealerKept] is renchan — the dealer won, or was tenpai at an exhaustive
  /// draw. When the dealer does not keep, the button passes (dealer + 1) and the
  /// round-wind counter advances; this holds for a noten-dealer exhaustive draw
  /// too, which an earlier version wrongly froze in place. A ryuukyoku always
  /// adds a honba; otherwise a honba is added only on renchan and reset to 0.
  ///
  /// Hong Kong keeps the dealer on any draw and has no honba at all.
  @visibleForTesting
  static ({int dealer, int roundNumber, int honba}) rotateAfterRound({
    required bool exhaustiveDraw,
    required bool dealerKept,
    required int dealer,
    required int roundNumber,
    required int honba,
    Ruleset ruleset = Ruleset.riichi,
  }) {
    if (ruleset.isTaiwanese) {
      // Taiwanese's honba isn't a payment multiplier (see Round._applyRon) —
      // it counts the dealer's consecutive *wins* for TaiwaneseRules
      // .dealerBonus, so a draw resets it even though the dealer keeps the
      // seat.
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

  @override
  void continueFromRoundEnd() {
    if (phase != GamePhase.roundEnd) return;
    final r = round.result!;

    // Apply honba / dealer rotation. The dealer keeps their seat (renchan) on a
    // win of their own or, at an exhaustive draw, on being tenpai.
    final isExhaustiveDraw = r.kind == RoundEndKind.exhaustiveDraw;
    // An abortive draw (e.g. kyuushu kyuuhai) is a void hand — the dealer
    // always repeats, whoever they are, no tenpai check involved.
    // Hong Kong and Taiwanese: the dealer also repeats on any (ordinary) draw,
    // tenpai or not.
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
      pointDeltas: r.pointDeltas,
      tenpaiAtDraw: r.tenpaiAtDraw,
      dealerKept: dealerKept,
    );

    _riichiSticks = round.riichiSticks; // leftover sticks (draw) carry
    final rot = rotateAfterRound(
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
    _dealerRepeat = dealerKept ? _dealerRepeat + 1 : 0;
    _points = [for (var i = 0; i < 4; i++) round.seats[i].points];

    // Riichi ends the game when anyone goes below zero; Hong Kong plays on.
    final tobi = ruleset.isRiichi && _points.any((p) => p < 0);
    if (tobi || (_roundNumber >= _handsPerGame && !dealerKept)) {
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
    _autoDiscardTimer?.cancel();
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
  // halves that again for a 2x run. Both are nudged up a further 15% — the
  // maximum this table's discard/call/riichi tiles are allowed to slow the
  // game down by — so their travel animations (see TableView) have room to
  // read as movement rather than a snap, without the table feeling sluggish.
  Duration get _stepDelay => Duration(milliseconds: fastMode ? 552 : 1104);

  void _scheduleLoop() {
    if (_disposed || paused || (_loopTimer?.isActive ?? false)) return;
    // A call bubble is on screen: hold the next step until it has gone.
    _loopTimer = Timer(_stepDelay + CallCallout.i.remaining, _tick);
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
          if (!_maybeAutoTsumo()) {
            _maybeAutoDiscardInRiichi();
            notifyListeners();
          }
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
      _apply(_Tsumo(seat));
    } else if (decision.closedKan != null) {
      Sfx.i.play(SfxKind.kan);
      Sfx.i.voice(VoiceKind.kan, character: _characterForSeat(seat));
      CallCallout.i.show(seat, 'KAN');
      _apply(_ClosedKan(seat, decision.closedKan!));
    } else if (decision.addedKan != null) {
      Sfx.i.play(SfxKind.kan);
      Sfx.i.voice(VoiceKind.kan, character: _characterForSeat(seat));
      CallCallout.i.show(seat, 'KAN');
      _apply(_AddKan(seat, decision.addedKan!));
    } else {
      // Riichi has its own declaration sound; a plain discard gets the tile
      // clink, same as a manual one from [humanDiscard] — covers bots and
      // Autoplay, the only two paths that reach here.
      if (decision.riichi) {
        Sfx.i.play(SfxKind.riichi);
        Sfx.i.voice(VoiceKind.riichi, character: _characterForSeat(seat));
        CallCallout.i.show(seat, 'RIICHI');
      } else {
        Sfx.i.play(SfxKind.discard);
      }
      final tile = decision.discard ?? round.legalDiscards(seat).first;
      _noteDiscard(seat, tile);
      _apply(_Discard(seat, tile.id, riichi: decision.riichi));
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
        if (autoWin && opt.types.contains(CallType.ron)) {
          answerCall(CallType.ron); // settles the bot seats' calls too
          return;
        }
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
    _apply(_ResolveCalls(choices, chiLow));
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  /// A win chime at round end, a call click for a mid-round pon / kan / chi.
  void _playRoundEndSfx() {
    final res = round.result;
    if (res == null) return;
    // Ron on a discard, tsumo on a self-draw — same voice line either
    // ruleset plays under, in parity with riichi, even though Hong Kong's
    // own vocabulary for the two calls them Win / Self-pick.
    final VoiceKind? winLine = switch (res.kind) {
      RoundEndKind.ron => VoiceKind.ron,
      RoundEndKind.tsumo => VoiceKind.tsumo,
      _ => null,
    };
    if (winLine == null) return;
    Sfx.i.play(res.kind == RoundEndKind.ron ? SfxKind.ron : SfxKind.tsumo);

    // The winning seat's character calls it. Mangan or higher chains into the
    // celebratory "yeah"; on a mangan+ ron the discarder then gives a resigned
    // acknowledgement right after.
    for (var wi = 0; wi < res.winners.length; wi++) {
      final seat = res.winners[wi];
      CallCallout.i.show(seat, winLine.name);
      final bigHand =
          wi < res.scores.length && ruleset.isBigHand(res.scores[wi]);
      final winner = _characterForSeat(seat);
      // A win off a kong's replacement tile gets its own line where the
      // character has one (Saeko's "Tsumo. Rinshan kaihou.").
      final line = winLine == VoiceKind.tsumo && wi < res.scores.length
          ? tsumoLineFor(res.scores[wi].yaku.map((y) => y.name))
          : winLine;
      if (!bigHand) {
        Sfx.i.voice(line, character: winner);
        continue;
      }
      final steps = <(Character, VoiceKind)>[
        (winner, line),
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
        CallCallout.i.show(e.key, vk.name);
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

    // Riichi freezes the hand: the drawn tile is the only legal discard.
    if (seat.riichi) return BotTurn(discard: seat.drawn);

    _refreshReport();

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
      if (advice.eligible) return BotTurn(closedKan: type);
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
        opponentMelds: riichiOpp?.melds ?? const [],
        passedDiscardsAfterRiichi:
            riichiOpp?.passedDiscardsAfterRiichi.toList() ?? const [],
      );
      if (advice.eligible) return BotTurn(addedKan: type);
    }

    final line = _recommendedLine();
    if (line == null) {
      return BotTurn(discard: round.legalDiscards(kHumanSeat).first);
    }
    return BotTurn(
      discard: _tileToDiscard(line.discard),
      riichi: report.recommendRiichi && round.canRiichi(kHumanSeat),
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
      opponentMelds: riichiOpp?.melds ?? const [],
      passedDiscardsAfterRiichi:
          riichiOpp?.passedDiscardsAfterRiichi.toList() ?? const [],
      opponentRiichi: riichiOpp != null,
      opponentIsDealer: riichiOpp?.isDealer ?? false,
      otherThreats: _otherThreats(),
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

  @override
  void humanDiscard(Tile tile, {bool declareRiichi = false}) {
    if (round.finished ||
        round.turn != kHumanSeat ||
        round.phase != RoundPhase.discarding) {
      return;
    }
    Sfx.i.play(declareRiichi ? SfxKind.riichi : SfxKind.discard);
    if (declareRiichi) {
      Sfx.i.voice(VoiceKind.riichi, character: _characterForSeat(kHumanSeat));
      CallCallout.i.show(kHumanSeat, 'RIICHI');
    }
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
    // A riichi hand's cut is forced — the drawn tile, every time — so there is
    // nothing to take back; undo steps past it to a real choice.
    if (!round.seats[kHumanSeat].riichi) {
      _markUndoPoint(declareRiichi
          ? 'Riichi ${tile.type.displayName}'
          : tile.type.displayName);
    }
    _noteDiscard(kHumanSeat, tile);
    _apply(_Discard(kHumanSeat, tile.id, riichi: declareRiichi));
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  @override
  void humanTsumo() {
    if (round.canTsumo(kHumanSeat) && round.turn == kHumanSeat) {
      _apply(const _Tsumo(kHumanSeat));
      phase = GamePhase.roundEnd;
      _playRoundEndSfx();
      notifyListeners();
    }
  }

  /// Declines a Hong Kong seven- or eight-flower win and keeps drawing.
  @override
  void humanPassFlowerWin() {
    if (!round.canFlowerWin(kHumanSeat)) return;
    _markUndoPoint('Continue drawing');
    _apply(const _PassFlowerWin(kHumanSeat));
    _refreshReport();
    notifyListeners();
    _scheduleLoop();
  }

  /// Kyuushu kyuuhai — aborts the round on the human's own first
  /// uninterrupted draw. See [Round.canDeclareKyuushu].
  @override
  void humanDeclareKyuushu() {
    if (!round.canDeclareKyuushu(kHumanSeat)) return;
    _apply(const _Kyuushu(kHumanSeat));
    phase = GamePhase.roundEnd;
    _playRoundEndSfx();
    notifyListeners();
  }

  @override
  void humanClosedKan(TileType type) {
    if (round.turn == kHumanSeat && round.phase == RoundPhase.discarding) {
      Sfx.i.play(SfxKind.kan);
      Sfx.i.voice(VoiceKind.kan, character: _characterForSeat(kHumanSeat));
      CallCallout.i.show(kHumanSeat, 'KAN');
      _markUndoPoint('${ruleset.kanLabel} ${type.displayName}');
      _apply(_ClosedKan(kHumanSeat, type));
      _refreshReport();
      notifyListeners();
      _scheduleLoop();
    }
  }

  @override
  void humanAddKan(TileType type) {
    if (round.turn == kHumanSeat && round.phase == RoundPhase.discarding) {
      Sfx.i.play(SfxKind.kan);
      Sfx.i.voice(VoiceKind.kan, character: _characterForSeat(kHumanSeat));
      CallCallout.i.show(kHumanSeat, 'KAN');
      _markUndoPoint('${ruleset.kanLabel} ${type.displayName}');
      _apply(_AddKan(kHumanSeat, type));
      _refreshReport();
      notifyListeners();
      _scheduleLoop();
    }
  }

  @override
  List<TileType> get humanChiRuns {
    final discard = round.pendingDiscard;
    if (_humanCallOption == null || discard == null) return const [];
    return round.chiSequences(kHumanSeat, discard);
  }

  @override
  TileType? get recommendedChiRun => _chiLowFor(_humanCallAdvice);

  @override
  void answerCall(CallType choice, {TileType? chiLow}) {
    final opt = _humanCallOption;
    if (opt == null) return;
    final choices = <int, CallType>{};
    final chiLows = <int, TileType>{};
    if (choice != CallType.none) choices[opt.seat] = choice;

    // Several runs can often be made with the same tile. The one you picked
    // wins; with none picked (a single run, or an answer given without a
    // choice) it is the one the guide rates highest.
    if (choice == CallType.chi) {
      final low =
          chiLow ?? _humanCallAdvice?.forAction(GuidedAction.chi)?.meldLow;
      if (low != null) chiLows[opt.seat] = low;
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
    _markUndoPoint(switch (choice) {
      CallType.none => 'Pass',
      CallType.chi => ruleset.chiLabel,
      CallType.pon => ruleset.ponLabel,
      CallType.kan => ruleset.kanLabel,
      CallType.ron => ruleset.ronLabel,
    });
    _humanCallOption = null;
    _humanCallAdvice = null;
    _playCallSfx(choices); // voices every calling seat, human included
    _apply(_ResolveCalls(choices, chiLows));
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
    // Paused on a flower win, there is no discard to advise on.
    if (round.canFlowerWin(kHumanSeat)) {
      report = EfficiencyReport.waiting();
      return;
    }
    if (round.finished ||
        round.turn != kHumanSeat ||
        round.phase != RoundPhase.discarding) {
      // Still show a defensive read if the human is under threat.
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
          opponentMelds: riichiOpp.melds,
          passedDiscardsAfterRiichi:
              riichiOpp.passedDiscardsAfterRiichi.toList(),
          opponentRiichi: true,
          otherThreats: _otherThreats(),
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
      opponentMelds: riichiOpp?.melds ?? const [],
      passedDiscardsAfterRiichi:
          riichiOpp?.passedDiscardsAfterRiichi.toList() ?? const [],
      opponentRiichi: riichiOpp != null,
      opponentIsDealer: riichiOpp?.isDealer ?? false,
      otherThreats: _otherThreats(),
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
        honba: round.honba,
        riichiSticks: round.riichiSticks,
        style: playStyle,
        focus: handFocus,
        strategy: strategy,
        tablePoints: tablePoints,
        mySeat: kHumanSeat,
        // Hands left in the game, including this one — a floor rather than a
        // promise, exactly like the hand counts the app bar quotes: renchan
        // can run the game longer than this, and next turn's report
        // recomputes it fresh from the round as it actually stands.
        handsRemaining: (_handsPerGame - _roundNumber).clamp(1, 99),
        ruleset: ruleset,
        flowers: seat.flowers.map((t) => t.type).toList(),
        minimumFaan: round.minimumFaan,
      );

  /// The opponent the guide defends against: whoever is in riichi, or in Hong
  /// Kong — which has no declaration — whoever has exposed
  /// [HongKongGuideTuning.threatExposedSets] sets or more.
  /// Every opponent worth defending against, in seat order.
  ///
  /// There can be more than one, and pricing only the first understates the
  /// danger badly: measured in self-play, a discard made with two live riichi
  /// out deals in 5.97% of the time against 2.62% with one, and two are live
  /// in 25.9% of hands. A tile that is genbutsu against the first of them can
  /// be a live middle tile against the second.
  List<SeatState> _threatOpponents() => [
        for (final s in round.seats)
          if (s.seat != kHumanSeat &&
              (ruleset.isChineseStyle
                  ? s.melds.where((m) => !m.concealed).length >=
                      HongKongGuideTuning.threatSetsFor(ruleset)
                  : s.riichi))
            s,
      ];

  /// The first threat — the one the guide's safety labels are written about.
  SeatState? _threatOpponent() {
    final all = _threatOpponents();
    return all.isEmpty ? null : all.first;
  }

  /// The rest of them, priced alongside the first rather than ignored.
  List<RiichiThreat> _otherThreats() => [
        for (final s in _threatOpponents().skip(1))
          RiichiThreat(
            discards: s.allDiscards.map((t) => t.type).toList(),
            passedAfterRiichi: s.passedDiscardsAfterRiichi.toList(),
            isDealer: s.isDealer,
            melds: s.melds,
          ),
      ];

  /// The opponent the guide's safety scores refer to.
  @override
  int? get safetyOpponentSeat => _threatOpponent()?.seat;

  List<int> _visibleCounts() {
    final counts = List<int>.filled(34, 0);
    for (final s in round.seats) {
      for (final t in s.pond) {
        counts[t.type.index - 1]++;
      }
      for (final m in s.melds) {
        // An opponent's face-down Taiwanese kong isn't something you've seen.
        if (s.seat != kHumanSeat && round.isHiddenKong(m)) continue;
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

  @override
  bool get humanCanTsumo =>
      round.turn == kHumanSeat &&
      round.phase == RoundPhase.discarding &&
      round.canTsumo(kHumanSeat);

  @override
  bool get humanCanRiichi =>
      round.turn == kHumanSeat &&
      round.phase == RoundPhase.discarding &&
      round.canRiichi(kHumanSeat);

  @override
  bool get humanCanDeclareKyuushu => round.canDeclareKyuushu(kHumanSeat);

  @override
  List<TileType> get humanClosedKanTypes =>
      round.turn == kHumanSeat && round.phase == RoundPhase.discarding
          ? round.closedKanTypes(kHumanSeat)
          : const [];

  @override
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
        opponentMelds: riichiOpp?.melds ?? const [],
        passedDiscardsAfterRiichi:
            riichiOpp?.passedDiscardsAfterRiichi.toList() ?? const [],
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

  @override
  bool get isHumanTurn =>
      round.turn == kHumanSeat &&
      round.phase == RoundPhase.discarding &&
      !round.finished;

  /// True when the human seat is tenpai but in furiten, so ron is unavailable
  /// (tsumo still is). Drives the FURITEN marker on the hand bar and placard.
  @override
  bool get humanFuriten => !round.finished && round.isFuriten(kHumanSeat);

  /// The tile the auto-player would discard on the human's turn (for the green
  /// "what autoplay would do" hint). Null when it is not the human's turn.
  /// Autoplay follows the guide, so this is simply its recommended discard.
  TileType? get autoplayDiscardType =>
      isHumanTurn ? _recommendedLine()?.discard : null;
}

/// One change [GameController] made to its [Round], recorded so
/// [GameController.undo] can replay the hand up to an earlier point. Tiles are
/// held by id and looked up again in the round being replayed onto, since a
/// fresh deal hands out fresh [Tile] objects.
sealed class _Move {
  const _Move();
  void applyTo(Round round);
}

final class _Discard extends _Move {
  const _Discard(this.seat, this.tileId, {required this.riichi});
  final int seat;
  final int tileId;
  final bool riichi;

  @override
  void applyTo(Round round) => round.discard(
        seat,
        round.seats[seat].hand.firstWhere((t) => t.id == tileId),
        declareRiichi: riichi,
      );
}

final class _ResolveCalls extends _Move {
  _ResolveCalls(Map<int, CallType> choices, Map<int, TileType> chiLow)
      : choices = Map.unmodifiable(choices),
        chiLow = Map.unmodifiable(chiLow);
  final Map<int, CallType> choices;
  final Map<int, TileType> chiLow;

  @override
  void applyTo(Round round) => round.resolveCalls(choices, chiLow: chiLow);
}

final class _Tsumo extends _Move {
  const _Tsumo(this.seat);
  final int seat;

  @override
  void applyTo(Round round) => round.declareTsumo(seat);
}

final class _ClosedKan extends _Move {
  const _ClosedKan(this.seat, this.type);
  final int seat;
  final TileType type;

  @override
  void applyTo(Round round) => round.closedKan(seat, type);
}

final class _AddKan extends _Move {
  const _AddKan(this.seat, this.type);
  final int seat;
  final TileType type;

  @override
  void applyTo(Round round) => round.addKan(seat, type);
}

final class _PassFlowerWin extends _Move {
  const _PassFlowerWin(this.seat);
  final int seat;

  @override
  void applyTo(Round round) => round.passFlowerWin(seat);
}

final class _Kyuushu extends _Move {
  const _Kyuushu(this.seat);
  final int seat;

  @override
  void applyTo(Round round) => round.declareKyuushu(seat);
}
