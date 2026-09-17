/// The read-only surface the table and the TileSense guide panel render from.
///
/// Two things implement it: the live [GameController], and the scenario
/// builder's controller. Keeping the widgets on this interface rather than on
/// [GameController] is what lets the builder reuse the real table and the real
/// guide without inheriting a running game — no bots, no turn timer, no
/// telemetry, no autoplay.
library;

import 'package:flutter/foundation.dart';

import '../logic/efficiency_engine.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/tile.dart';
import 'sfx.dart' show Character;

/// A hanchan/game's lifecycle, independent of any one round's [RoundPhase] —
/// shared by the live game and the online game so neither has to redefine it.
enum GamePhase { playing, roundEnd, gameEnd }

abstract class GuideHost implements Listenable {
  /// The table state being rendered.
  Round get round;

  /// The guide's current read of the human seat.
  EfficiencyReport get report;

  /// How hard the guide pushes. Exposed on the interface — rather than only on
  /// [GameController] — so the guide panel can carry its own copy of the dial
  /// and stay in sync with whatever else sets it (the app bar in the live game,
  /// the tool bar in the scenario builder).
  PlayStyle get playStyle;
  void setPlayStyle(PlayStyle value);

  /// Which hand the guide chases when two are worth the same — the second,
  /// independent dial. Carried on the interface for the same reason
  /// [playStyle] is: the panel and whatever else sets it stay in sync.
  HandFocus get handFocus;
  void setHandFocus(HandFocus value);

  /// Points or placement — the third, independent dial. Riichi only; see
  /// [Strategy].
  Strategy get strategy;
  void setStrategy(Strategy value);

  /// True while the human seat has a call (chi/pon/kan/ron) to answer.
  bool get awaitingHumanCall;
  CallOption? get humanCallOption;
  CallType? get recommendedCall;
  String? get recommendedCallReason;

  /// The kan the guide would take right now, if any.
  ({TileType type, bool isAdded, ActionAdvice advice})? get kanAdvice;

  /// The opponent the safety scores refer to — null when nobody is in riichi.
  int? get safetyOpponentSeat;

  bool get humanFuriten;

  /// Discard animation cues: [discardSerial] ticks once per discard, and the
  /// other two describe that discard. A static table (the scenario builder)
  /// holds the serial at 0 so nothing ever animates.
  int get discardSerial;
  int? get lastDiscardSeat;
  bool get lastDiscardTsumogiri;

  /// Header stats: which hand of the round wind, and the honba count.
  int get handInWind;
  int get honba;

  /// Hong Kong only: how many hands in a row the current dealer has kept the
  /// seat (a win, or any exhaustive draw). Hong Kong scoring has no honba
  /// bonus, so this is a display-only counter shown in its place — riichi
  /// keeps using [honba] instead.
  int get dealerRepeat;

  /// Wall-clock deadline (epoch ms) for whoever [Round.turn] is to discard,
  /// or null when nobody's turn clock is running. Only the online table has
  /// one — offline play never rushes the human, and the scenario builder has
  /// no turn loop at all — so both report null and only the table's active
  /// placard, which already knows whose turn it is, needs to care.
  int? get turnDeadlineMs;

  /// The name shown for a seat in the UI — the fixed bot personas offline, a
  /// guest's display name (or "Bot" once taken over) online.
  String seatLabel(int seat);

  /// Which persona (portrait + voice) a seat renders as. Offline this is the
  /// fixed `kSeatCharacters` mapping; online it's whatever the seat's player
  /// picked (or the server assigned a bot), kept in sync across every client
  /// by the room roster itself.
  Character characterForSeat(int seat);
}

/// The turn-driving surface on top of [GuideHost]: everything the hand bar
/// and the between-round scoring panel need to act on the human seat's turn,
/// not just render the table. [GameController] (offline, three [SimpleBot]
/// opponents) and `OnlineGameController` (a WebSocket connection to the
/// multiplayer server) both implement it; the scenario builder does not — it
/// has no turn loop for these methods to act on.
abstract class TableGameHost implements GuideHost {
  bool get isHumanTurn;
  bool get humanCanTsumo;
  bool get humanCanRiichi;
  List<TileType> get humanClosedKanTypes;
  List<TileType> get humanAddedKanTypes;

  void humanDiscard(Tile tile, {bool declareRiichi});
  void humanTsumo();
  void humanClosedKan(TileType type);
  void humanAddKan(TileType type);
  void humanPassFlowerWin();
  void answerCall(CallType choice);

  bool get soundOn;
  void setSoundOn(bool value);

  GamePhase get phase;
  bool get paused;
  List<int> get tablePoints;

  /// Deals the next hand once the score panel has finished paging through a
  /// round's results.
  void continueFromRoundEnd();

  /// Abandons the game in progress and starts a fresh one. Online play has no
  /// use for this — leaving is "leave room" instead — so `OnlineGameController`
  /// implements it as a no-op.
  void newGame();
}
