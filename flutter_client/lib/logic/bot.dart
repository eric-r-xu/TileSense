/// SimpleBot — pure heuristics over the seat's public view plus a small
/// "should I stay damaten?" value check.
library;

import 'dart:math';

import 'hand_parse.dart';
import 'round.dart';
import 'scoring.dart';
import 'tile.dart';

class BotTurn {
  BotTurn(
      {this.tsumo = false, this.closedKan, this.discard, this.riichi = false});
  final bool tsumo;
  final TileType? closedKan;
  final Tile? discard;
  final bool riichi;
}

class SimpleBot {
  SimpleBot(int seed) : _rng = Random(seed);
  final Random _rng;

  BotTurn decideTurn(Round round, int seat) {
    final s = round.seats[seat];

    if (round.canTsumo(seat)) return BotTurn(tsumo: true);

    if (round.canRiichi(seat)) {
      final tenpaiTiles = _tenpaiKeepingDiscards(round, seat);
      if (tenpaiTiles.isNotEmpty) {
        final damaten = _qualifyingDamatenDiscard(round, seat, tenpaiTiles);
        if (damaten != null) return BotTurn(discard: damaten);
        return BotTurn(
          discard: tenpaiTiles[_rng.nextInt(tenpaiTiles.length)],
          riichi: true,
        );
      }
    }

    // closedKanTypes already filters to wait-preserving kans while in riichi,
    // so a riichi hand may still declare a concealed kan.
    final kanTypes = round.closedKanTypes(seat);
    if (kanTypes.isNotEmpty) return BotTurn(closedKan: kanTypes.first);

    if (s.riichi) return BotTurn(discard: s.drawn);

    return BotTurn(discard: _discardTile(round, seat));
  }

  CallType decideCall(
      Round round, int seat, Tile discard, Set<CallType> allowed) {
    if (allowed.contains(CallType.ron)) return CallType.ron;
    if (allowed.contains(CallType.pon)) {
      final s = round.seats[seat];
      final count = s.hand.where((t) => t.type == discard.type).length;
      final valuable = discard.type.isDragon ||
          discard.type == s.wind.tile ||
          discard.type == round.roundWind.tile;
      if (count == 2 && valuable) return CallType.pon;
    }
    // The round offers chi now, but the opponents still never take it: this
    // is a faithful SimpleBot port and chi is not part of it. Your own seat
    // gets chi advice from the guide instead.
    return CallType.none;
  }

  // --- helpers ----------------------------------------------------------

  List<Tile> _tenpaiKeepingDiscards(Round round, int seat) {
    final s = round.seats[seat];
    final out = <Tile>[];
    final seenTypes = <TileType>{};
    for (final tile in round.legalDiscards(seat)) {
      if (!seenTypes.add(tile.type)) continue;
      final rest = [...s.hand]..remove(tile);
      if (isTenpai(rest, openMelds: s.melds.length)) out.add(tile);
    }
    return out;
  }

  /// Approximates `EfficiencyLogging.qualifying_damaten_discard`: stay silent
  /// only if every live wait already has a real yaku and the hand clears
  /// 5200 (7700 as dealer).
  Tile? _qualifyingDamatenDiscard(
      Round round, int seat, List<Tile> tenpaiTiles) {
    final s = round.seats[seat];
    final threshold = s.isDealer ? 7700 : 5200;

    for (final discard in tenpaiTiles) {
      final rest = [...s.hand]..remove(discard);
      final waits = waitTiles(rest, openMelds: s.melds.length);
      if (waits.isEmpty) continue;

      var ok = true;
      var minPoints = 1 << 30;
      for (final wait in waits) {
        final winTile = Tile(-1, wait);
        final ctx = ScoreContext(
          roundWind: round.roundWind,
          seatWind: s.wind,
          isTsumo: false,
          closed: s.closed,
          doraIndicators: round.wall.doraIndicators(),
        );
        final score =
            scoreHand(rest, winTile, s.melds, ctx, isDealer: s.isDealer);
        if (!score.valid) {
          ok = false;
          break;
        }
        minPoints = min(minPoints, score.points);
      }
      if (ok && minPoints >= threshold) return discard;
    }
    return null;
  }

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
