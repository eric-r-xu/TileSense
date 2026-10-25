/// SimpleBot — pure heuristics over the seat's public view plus a small
/// "should I stay damaten?" value check. Under Hong Kong rules there is no
/// riichi to consider and any complete hand wins, so it calls far more freely.
///
/// Adapted from OpenRiichi's simple bot: https://github.com/FluffyStuff/OpenRiichi
library;

import 'dart:math';

import 'efficiency_calc.dart';
import 'hand_parse.dart';
import 'meld.dart';
import 'mcr/mcr_efficiency.dart';
import 'mcr/mcr_hand_parse.dart';
import 'mcr/mcr_scoring.dart';
import 'mcr/mcr_strategy.dart';
import 'round.dart';
import 'scoring.dart';
import 'sichuan/sichuan_efficiency.dart';
import 'taiwanese/taiwanese_hand_parse.dart';
import 'tile.dart';

class BotTurn {
  BotTurn(
      {this.tsumo = false,
      this.closedKan,
      this.addedKan,
      this.discard,
      this.riichi = false,
      this.kyuushu = false,
      this.kita = false});
  final bool tsumo;
  final TileType? closedKan;
  final TileType? addedKan;
  final Tile? discard;
  final bool riichi;

  /// Abort the hand on kyuushu kyuuhai. SimpleBot never does; Saeko on
  /// Mortal may.
  final bool kyuushu;

  /// Sanma: set a North aside as nukidora (see [Round.declareKita]).
  final bool kita;
}

class SimpleBot {
  SimpleBot(int seed) : _rng = Random(seed);
  final Random _rng;
  final _mcrCalc = McrEfficiencyCalculator();
  final _sichuanCalc = SichuanEfficiencyCalculator();

  BotTurn decideTurn(Round round, int seat) {
    final s = round.seats[seat];

    if (round.canTsumo(seat)) return BotTurn(tsumo: true);

    // A North set aside is a free dora and a fresh draw, and a North kept in
    // hand is only a guest wind, so a sanma bot always takes it.
    if (round.canKita(seat)) return BotTurn(kita: true);

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
    // A Sichuan seat has no use for a kong of the suit it gave up.
    bool wanted(TileType t) => !(round.ruleset.isSichuan && t.suit == s.voidSuit);
    final kanTypes = round.closedKanTypes(seat).where(wanted).toList();
    if (kanTypes.isNotEmpty) return BotTurn(closedKan: kanTypes.first);

    // Extending an existing pon into a kan never changes this hand's shape
    // or waits, so SimpleBot always takes it, same as a closed kan.
    final addedKanTypes = round.addedKanTypes(seat).where(wanted).toList();
    if (addedKanTypes.isNotEmpty) {
      return BotTurn(addedKan: addedKanTypes.first);
    }

    if (s.riichi) return BotTurn(discard: s.drawn);

    return BotTurn(discard: _discardTile(round, seat));
  }

  CallType decideCall(
      Round round, int seat, Tile discard, Set<CallType> allowed) {
    if (allowed.contains(CallType.ron)) return CallType.ron;
    if (round.ruleset.isSichuan) {
      return _sichuanCall(round, seat, discard, allowed);
    }
    if (round.ruleset.isMcr) return _mcrCall(round, seat, discard, allowed);
    if (round.ruleset.isChineseStyle) {
      return _decideHongKongCall(round, seat, discard, allowed);
    }
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

  /// Hong Kong and Taiwanese need no yaku/tai path to finish, so a call is
  /// worth taking whenever it brings the hand closer: always a kong, and a
  /// pung or chow that lowers shanten.
  CallType _decideHongKongCall(
      Round round, int seat, Tile discard, Set<CallType> allowed) {
    final s = round.seats[seat];
    final totalMelds = round.ruleset.totalMelds;
    final calc = TileEfficiencyCalculator();
    final before = calc.calculateWaitingShanten(toTrainerCounts(s.hand),
        totalMelds: totalMelds);
    bool improves(List<Tile> rest) {
      final remaining = List<int>.filled(38, 4);
      final lines = calc.calculate(toTrainerCounts(rest), remaining,
          totalMelds: totalMelds);
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

  /// Sichuan: never call the void suit, always take a kong (it pays), and take
  /// a pung only when it brings the rest of the hand closer — the void suit
  /// counted as dead weight. There is no chow to take.
  CallType _sichuanCall(
      Round round, int seat, Tile discard, Set<CallType> allowed) {
    final s = round.seats[seat];
    final v = s.voidSuit;
    if (v != null && discard.type.suit == v) return CallType.none;
    if (allowed.contains(CallType.kan)) return CallType.kan;
    if (!allowed.contains(CallType.pon)) return CallType.none;
    final live = withoutVoidSuit(toTrainerCounts(s.hand), v);
    final before = _sichuanCalc.calculateWaitingShanten(live);
    final rest = List<int>.of(live);
    rest[trainerIndexOf(discard.type)] -= 2;
    final remaining = List<int>.filled(38, 4);
    final lines = _sichuanCalc.calculate(rest, remaining);
    return lines.any((line) => line.shanten < before)
        ? CallType.pon
        : CallType.none;
  }

  /// Sichuan discards: the void suit first (the rules force it), then the tile
  /// that leaves the rest of the hand fewest away from ready, then the widest
  /// acceptance.
  Tile _sichuanDiscard(Round round, int seat) {
    final s = round.seats[seat];
    final tiles = round.legalDiscards(seat);
    if (round.mustDiscardVoid(seat)) return tiles[_rng.nextInt(tiles.length)];
    final counts = toTrainerCounts(s.hand);
    final remaining = List<int>.filled(38, 4);
    for (final o in round.seats) {
      for (final t in [...o.pond, ...o.melds.expand((m) => m.tiles)]) {
        final i = trainerIndexOf(t.type);
        if (remaining[i] > 0) remaining[i]--;
      }
    }
    for (var i = 0; i < 38; i++) {
      remaining[i] = (remaining[i] - counts[i]).clamp(0, 4);
    }
    final lines = _sichuanCalc.calculate(
        withoutVoidSuit(counts, s.voidSuit), remaining);
    lines.sort((a, b) {
      final c = a.shanten.compareTo(b.shanten);
      return c != 0 ? c : b.ukeire.compareTo(a.ukeire);
    });
    for (final line in lines) {
      final pick = tiles.where((t) => trainerIndexOf(t.type) == line.tileIndex);
      if (pick.isNotEmpty) return pick.first;
    }
    return tiles[_rng.nextInt(tiles.length)];
  }

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

  double _mcrHandValue(Round round, SeatState seat, List<Tile> hand, List<Meld> melds) {
    final shanten = _mcrCalc.calculateWaitingShanten(toTrainerCounts(hand));
    final closed = melds.every((m) => m.concealed);
    if (shanten <= 0) {
      var value = 0.0;
      for (final wait in waitTilesMcr(hand, openMelds: melds.length)) {
        for (final self in [false,true]) {
          final score = scoreMcrHand(hand, Tile(-1, wait), melds, ScoreContext(
            roundWind: round.roundWind, seatWind: seat.wind, isTsumo: self,
            closed: closed, flowers: seat.flowers.map((t) => t.type).toList()));
          if (score.valid) value += score.points * (self ? 0.35 : 0.65);
        }
      }
      if (value > 0) return 100 + value / 100;
      return -15; // Shape complete but no qualifying finish: build value.
    }
    return -10 * shanten + 8 * mcrPatternPotential(hand, melds,
        seatWind: seat.wind, roundWind: round.roundWind);
  }

  CallType _mcrCall(Round round, int seatIndex, Tile discard, Set<CallType> allowed) {
    final seat = round.seats[seatIndex];
    final before = _mcrHandValue(round, seat, seat.hand, seat.melds);
    var best = before;
    var choice = CallType.none;
    for (final type in [CallType.pon, CallType.chi]) {
      if (!allowed.contains(type)) continue;
      final meld = Meld(kind: type == CallType.pon ? MeldKind.triplet : MeldKind.sequence,
          low: type == CallType.pon ? discard.type : round.chiSequences(seatIndex, discard).first,
          concealed: false);
      final rest = [...seat.hand];
      final needs = [...meld.types]..remove(discard.type);
      for (final need in needs) { rest.removeAt(rest.indexWhere((t) => t.type == need)); }
      final melds = [...seat.melds, meld];
      for (final cut in rest) {
        final value = _mcrHandValue(round, seat, [...rest]..remove(cut), melds);
        if (value > best) { best = value; choice = type; }
      }
    }
    if (allowed.contains(CallType.kan)) {
      final rest = [...seat.hand]..removeWhere((t) => t.type == discard.type);
      final melds = [...seat.melds, Meld(kind: MeldKind.kan, low: discard.type, concealed: false)];
      if (_mcrHandValue(round, seat, rest, melds) >= best) choice = CallType.kan;
    }
    return choice;
  }

  Tile _discardTile(Round round, int seat) {
    final s = round.seats[seat];
    var tiles = List<Tile>.of(round.legalDiscards(seat));
    if (round.ruleset.isSichuan) return _sichuanDiscard(round, seat);
    if (round.ruleset.isMcr) {
      tiles.sort((a,b) => _mcrHandValue(round, s, [...s.hand]..remove(b), s.melds)
          .compareTo(_mcrHandValue(round, s, [...s.hand]..remove(a), s.melds)));
      return tiles.first;
    }
    final taiwanese = round.ruleset.isTaiwanese;

    // (1) a discard that keeps tenpai.
    for (final tile in tiles) {
      final rest = [...s.hand]..remove(tile);
      final tenpai = taiwanese
          ? isTenpaiTaiwanese(rest, openMelds: s.melds.length)
          : isTenpai(rest, openMelds: s.melds.length);
      if (tenpai) return tile;
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
