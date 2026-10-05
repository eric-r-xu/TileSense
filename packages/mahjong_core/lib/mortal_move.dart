/// Turns a Mortal sidecar reply into a move on a [Round].
library;

import 'dart:math';

import 'bot.dart';
import 'mjai.dart';
import 'round.dart';
import 'tile.dart';

/// A reply from the Mortal sidecar (mortal_sidecar/server.py) as a move the
/// table can play — shared by the app's offline Saeko and the multiplayer
/// server's. Each
/// throws a [StateError] when Mortal names a move this table doesn't offer;
/// the caller then falls back to another player (SimpleBot, for Saeko).
abstract final class MortalMove {
  /// [seat]'s turn: discard (after riichi, if Mortal declares it), tsumo,
  /// closed or added kan, or nine terminals.
  static BotTurn turn(Map<String, Object?> reply, Round round, int seat) {
    var reaction = reply['reaction'] as Map<String, Object?>?;
    final riichi = reaction?['type'] == 'reach';
    if (riichi) {
      if (!round.canRiichi(seat)) throw _unplayable(reaction);
      // The sidecar asks for the discard that goes with the riichi.
      reaction = reply['riichi_discard'] as Map<String, Object?>?;
    }
    switch (reaction?['type']) {
      case 'dahai':
        final pai = reaction!['pai'];
        final drawn = round.seats[seat].drawn;
        final matches =
            round.legalDiscards(seat).where((t) => mjaiTile(t) == pai);
        // Cut the drawn tile itself when Mortal does, so the table shows it.
        final tile = reaction['tsumogiri'] == true && matches.contains(drawn)
            ? drawn
            : matches.firstOrNull;
        if (tile != null) return BotTurn(discard: tile, riichi: riichi);
      case 'hora' when round.canTsumo(seat):
        return BotTurn(tsumo: true);
      case 'ankan':
        final type = _kanType(
            round.closedKanTypes(seat), (reaction!['consumed'] as List).first);
        if (type != null) return BotTurn(closedKan: type);
      case 'kakan':
        final type = _kanType(round.addedKanTypes(seat), reaction!['pai']);
        if (type != null) return BotTurn(addedKan: type);
      case 'ryukyoku' when round.canDeclareKyuushu(seat):
        return BotTurn(kyuushu: true);
    }
    throw _unplayable(reaction);
  }

  /// Whether [seat] takes the pending discard, out of the calls [offered];
  /// a chi names its run by the run's lowest tile ([Round.resolveCalls]).
  static ({CallType call, TileType? chiLow}) call(Map<String, Object?> reply,
      Round round, int seat, Set<CallType> offered) {
    final reaction = reply['reaction'] as Map<String, Object?>?;
    final call = switch (reaction?['type']) {
      null || 'none' => CallType.none,
      'hora' => CallType.ron,
      'pon' => CallType.pon,
      'daiminkan' => CallType.kan,
      'chi' => CallType.chi,
      _ => null,
    };
    if (call == null || (call != CallType.none && !offered.contains(call))) {
      throw _unplayable(reaction);
    }
    if (call != CallType.chi) return (call: call, chiLow: null);
    final low = [reaction!['pai'], ...reaction['consumed'] as List]
        .map((t) => int.parse('$t'[0]))
        .reduce(min);
    final run = round
        .chiSequences(seat, round.pendingDiscard!)
        .where((t) => t.number == low)
        .firstOrNull;
    if (run == null) throw _unplayable(reaction);
    return (call: CallType.chi, chiLow: run);
  }

  /// The kan in [legal] that Mortal's tile [pai] names (red or not).
  static TileType? _kanType(List<TileType> legal, Object? pai) => legal
      .where((t) => mjaiTile(Tile(-1, t)) == '$pai'.replaceFirst('r', ''))
      .firstOrNull;

  static StateError _unplayable(Object? reaction) =>
      StateError('Mortal reply not playable here: $reaction');
}
