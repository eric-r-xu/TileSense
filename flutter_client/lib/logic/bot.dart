library;

import 'dart:math';

import 'hand_parse.dart';
import 'round.dart';
import 'efficiency_calc.dart';
import 'tile.dart';

class BotTurn {
  BotTurn(
      {this.tsumo = false,
      this.closedKan,
      this.addedKan,
      this.discard,
      this.riichi = false});
  final bool tsumo;
  final TileType? closedKan;
  final TileType? addedKan;
  final Tile? discard;
  final bool riichi;
}

class SimpleBot {
  SimpleBot(int seed) : _rng = Random(seed);
  final Random _rng;

  BotTurn decideTurn(Round round, int seat) {
    if (round.canTsumo(seat)) return BotTurn(tsumo: true);

    final kanTypes = round.closedKanTypes(seat);
    if (kanTypes.isNotEmpty) return BotTurn(closedKan: kanTypes.first);

    // Extending an existing pon into a kan never changes this hand's shape
    // or waits, so SimpleBot always takes it, same as a closed kan.
    final addedKanTypes = round.addedKanTypes(seat);
    if (addedKanTypes.isNotEmpty) {
      return BotTurn(addedKan: addedKanTypes.first);
    }

    return BotTurn(discard: _discardTile(round, seat));
  }

  CallType decideCall(
      Round round, int seat, Tile discard, Set<CallType> allowed) {
    if (allowed.contains(CallType.ron)) return CallType.ron;
    final s = round.seats[seat];
    final calc = TileEfficiencyCalculator();
    final before = calc.calculateWaitingShanten(toTrainerCounts(s.hand));
    bool improves(List<Tile> rest) {
      final remaining = List<int>.filled(38, 4);
      final lines = calc.calculate(toTrainerCounts(rest), remaining);
      return lines.any((line) => line.shanten < before);
    }

    if (allowed.contains(CallType.kan)) return CallType.kan;
    if (allowed.contains(CallType.pon)) {
      final rest = [...s.hand];
      for (var i = 0; i < 2; i++) {
        rest.removeAt(rest.indexWhere((t) => t.type == discard.type));
      }
      if (improves(rest)) return CallType.pon;
    }
    // resolveCalls defaults to the first legal chow; assess that same run.
    if (allowed.contains(CallType.chi)) {
      final low = round.chiSequences(seat, discard).first;
      final rest = [...s.hand];
      for (var i = 0; i < 3; i++) {
        final need = TileType.values[low.index + i];
        if (need == discard.type) continue;
        rest.removeAt(rest.indexWhere((t) => t.type == need));
      }
      if (improves(rest)) return CallType.chi;
    }

    return CallType.none;
  }

  // --- helpers ----------------------------------------------------------

  Tile _discardTile(Round round, int seat) {
    final s = round.seats[seat];
    var tiles = List<Tile>.of(round.legalDiscards(seat));

    // (1) a discard that keeps tenpai.
    for (final tile in tiles) {
      final rest = [...s.hand]..remove(tile);
      if (isTenpai(rest, openMelds: s.melds.length)) return tile;
    }

    int count(Tile t) => s.hand.where((x) => x.type == t.type).length;
    bool neighbour(Tile t) =>
        t.type.isSuit &&
        s.hand.any((x) =>
            x != t &&
            x.type.suit == t.type.suit &&
            (x.type.number - t.type.number).abs() == 1);
    bool secondNeighbour(Tile t) =>
        t.type.isSuit &&
        s.hand.any((x) =>
            x != t &&
            x.type.suit == t.type.suit &&
            (x.type.number - t.type.number).abs() == 2);

    List<Tile> filter(List<Tile> src, bool Function(Tile) drop) {
      final kept = src.where((t) => !drop(t)).toList();
      return kept.isEmpty ? src : kept;
    }

    var backup = List<Tile>.of(tiles);
    tiles = tiles.where((t) => count(t) < 3).toList();
    if (tiles.isEmpty) return backup[_rng.nextInt(backup.length)];

    // (2) prefer valueless honors.
    for (final t in tiles) {
      if (t.type.isWind &&
          t.type != s.wind.tile &&
          t.type != round.roundWind.tile) {
        return t;
      }
      if (t.type.isWind && count(t) <= 1) return t;
      if (t.type.isDragon && count(t) <= 1) return t;
    }

    tiles = filter(
        tiles,
        (t) =>
            t.type.isDragon ||
            t.type == s.wind.tile ||
            t.type == round.roundWind.tile);
    tiles = filter(tiles, neighbour);
    tiles = filter(tiles, (t) => count(t) >= 2);
    tiles = filter(tiles, secondNeighbour);
    tiles = filter(tiles, (t) => !t.type.isTerminal);

    return tiles[_rng.nextInt(tiles.length)];
  }
}
