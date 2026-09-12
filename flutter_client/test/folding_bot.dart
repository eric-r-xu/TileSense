/// A [SimpleBot] that gets out of the way of a riichi when its hand is out of
/// the running — and keeps playing when it is not.
///
/// Test-only, and it exists because of a measurement. Against the stock
/// opponents a declared riichi wins 66% of the time on a quiet board, where
/// real play puts it nearer 45-50%: the shipped bots never fold — their
/// `_discardTile` sorts purely by shape — so they feed a riichi almost at
/// will. Any constant calibrated against that table would be tuned to exploit
/// blind feeding and would make the guide worse against opponents who defend,
/// humans included.
///
/// The threshold matters as much as the folding does. An earlier version here
/// folded every hand that was not already tenpai, and that broke the table in
/// the other direction: 46.5% of hands ended in an exhaustive draw (real play
/// is nearer 16-20%), nobody ever declared into a live riichi, and a riichi
/// was left to run unopposed for all of its draws. So the rule is drawn where
/// real play draws it: two or more shanten gets out of the way, tenpai and
/// one-shanten play on.
library;

import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/efficiency_calc.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/safety.dart';
import 'package:tilesense/logic/tile.dart';

class FoldingBot extends SimpleBot {
  FoldingBot(super.seed);

  static final _calc = TileEfficiencyCalculator();

  /// Steps from tenpai for the hand this seat would hold after tsumogiri.
  ///
  /// Melds are folded back in the way the engine does it: a completed set per
  /// meld, so the count stays a thirteen-tile equivalent.
  static int _shanten(SeatState s) {
    final concealed = [
      for (final t in s.hand)
        if (!identical(t, s.drawn)) t,
    ];
    final counts = toTrainerCounts(concealed);
    for (var i = 0; i < s.melds.length; i++) {
      counts[31] += 3;
    }
    return _calc.calculateWaitingShanten(counts);
  }

  /// Far enough from a finished hand that pushing into a riichi is not worth
  /// it. Tenpai and one-shanten keep playing.
  static bool _outOfTheRunning(SeatState s) => _shanten(s) >= 2;

  @override
  BotTurn decideTurn(Round round, int seat) {
    final s = round.seats[seat];
    final threats = [
      for (final o in round.seats)
        if (o.seat != seat && o.riichi) o,
    ];
    // Nothing to fold to, no choice left, or a hand still worth playing.
    if (threats.isEmpty ||
        s.riichi ||
        round.canTsumo(seat) ||
        !_outOfTheRunning(s)) {
      return super.decideTurn(round, seat);
    }

    final visible = List<int>.filled(34, 0);
    for (final t in s.hand) {
      visible[t.type.index - 1]++;
    }
    for (final o in round.seats) {
      for (final t in o.pond) {
        visible[t.type.index - 1]++;
      }
      for (final m in o.melds) {
        for (final t in m.tiles) {
          visible[t.type.index - 1]++;
        }
      }
    }
    for (final t in round.wall.doraIndicators()) {
      visible[t.index - 1]++;
    }

    final legal = round.legalDiscards(seat);
    if (legal.isEmpty) return super.decideTurn(round, seat);
    final ranked = rankSafety(
      legal,
      opponentDiscards: [
        for (final o in threats) ...o.allDiscards.map((t) => t.type),
      ],
      passedDiscardsAfterRiichi: [
        for (final o in threats) ...o.passedDiscardsAfterRiichi,
      ],
      visibleCounts34: visible,
    );
    if (ranked.isEmpty) return super.decideTurn(round, seat);

    var safest = ranked.first;
    for (final r in ranked) {
      if (r.rating > safest.rating) safest = r;
    }
    for (final tile in legal) {
      if (tile.type == safest.type) return BotTurn(discard: tile);
    }
    return super.decideTurn(round, seat);
  }

  /// Opening the hand while a riichi is live only commits it further, so a
  /// hand that is out of the running passes. Ron is always taken, and a hand
  /// still in the running calls as it normally would.
  @override
  CallType decideCall(
      Round round, int seat, Tile discard, Set<CallType> allowed) {
    if (allowed.contains(CallType.ron)) return CallType.ron;
    final threatened = round.seats.any((o) => o.seat != seat && o.riichi);
    if (threatened && _outOfTheRunning(round.seats[seat])) {
      return CallType.none;
    }
    return super.decideCall(round, seat, discard, allowed);
  }
}
