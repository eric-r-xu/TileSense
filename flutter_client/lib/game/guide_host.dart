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
import '../logic/round.dart';
import '../logic/tile.dart';

abstract class GuideHost implements Listenable {
  /// The table state being rendered.
  Round get round;

  /// The guide's current read of the human seat.
  EfficiencyReport get report;

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
}
