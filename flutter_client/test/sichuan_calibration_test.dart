// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/logic/sichuan_value.dart';

/// Measures what the Sichuan value model (`sichuan_value.dart`) is built on,
/// from four SimpleBots playing each other:
///
///   * how often a seat is ready after its n-th discard,
///   * how often a ready seat gets home, against the model's own formula,
///   * how often a discard deals in, by tile class and by who has discarded it,
///   * what a Hu is worth, and how many seats finish a wall-end hand ready.
///
///   SC_CAL_GAMES=3000 flutter test test/sichuan_calibration_test.dart
///
/// The constants it reports are the ones in `SichuanValueTuning`; the table is
/// reproduced in EXPECTED_VALUE.md.
void main() {
  final games =
      int.tryParse(Platform.environment['SC_CAL_GAMES'] ?? '') ?? 0;
  test('Sichuan calibration', () {
    final c = _Counts();
    for (var g = 0; g < games; g++) {
      _playHand(c, 1000 + g);
    }
    c.report(games);
  },
      skip: games == 0 ? 'set SC_CAL_GAMES to run' : false,
      timeout: Timeout.none);
}

class _Counts {
  // Ready after the n-th discard (n = 1..20), among seats still in.
  final seatsAt = List<int>.filled(21, 0);
  final readyAt = List<int>.filled(21, 0);

  // Ready transitions: predicted vs. actual win, bucketed by live outs.
  final transitions = <_Transition>[];

  // Every sixth discard: shanten, outs, unseen, draws, rivals, and whether the
  // seat went on to win.
  final samples = <_Sample>[];

  // Deal-in: [class][genbutsu] -> (trials with a ready rival, hits).
  final trials = <String, int>{};
  final hits = <String, int>{};

  // Hu values and styles.
  final huValue = <int>[];
  var huTsumo = 0;
  var huRon = 0;
  var hands = 0;
  var wallEnds = 0;
  var wallEndReady = 0;
  var wallEndSeats = 0;
  var huSeatsTotal = 0;
  final readyValue = <int>[];
  final remainingAtReady = <int>[];

  void report(int games) {
    print('\n$games hands of SimpleBot self-play');
    print('hands ending on the wall: ${_pct(wallEnds, hands)}; '
        'Hu per hand: ${(huSeatsTotal / hands).toStringAsFixed(2)}');
    print('\nready after the n-th discard (seats still in)');
    for (var n = 1; n <= 20; n++) {
      if (seatsAt[n] == 0) continue;
      print('  n=${n.toString().padLeft(2)}  ${_pct(readyAt[n], seatsAt[n])}'
          '  (${seatsAt[n]})');
    }
    print('\nHu value: mean ${_mean(huValue).toStringAsFixed(2)}; '
        'self-drawn ${_pct(huTsumo, huTsumo + huRon)}');
    for (final v in [1, 2, 4, 8]) {
      print('  value $v: ${_pct(huValue.where((x) => x == v).length, huValue.length)}');
    }
    print('wall-end seats still in that finish ready: '
        '${_pct(wallEndReady, wallEndSeats)}; '
        'their mean ready value ${_mean(readyValue).toStringAsFixed(2)}');

    print('\ndeal-in rate per (discard, ready rival who is not void in it)');
    final keys = trials.keys.toList()..sort();
    for (final k in keys) {
      print('  ${k.padRight(18)} ${_pct(hits[k] ?? 0, trials[k]!)}'
          '  (${trials[k]})');
    }

    print('\nready seat gets home: predicted vs. actual, by draws left');
    const edges = [0, 10, 20, 30, 45, 60];
    for (var b = 0; b + 1 < edges.length; b++) {
      final rows = transitions
          .where((t) => t.wall >= edges[b] && t.wall < edges[b + 1])
          .toList();
      if (rows.isEmpty) continue;
      print('  wall ${edges[b]}-${edges[b + 1] - 1}: '
          'won ${_pct(rows.where((t) => t.won).length, rows.length)}, '
          'mean live outs ${_mean([for (final t in rows) t.outs]).toStringAsFixed(1)}, '
          'mean unseen ${_mean([for (final t in rows) t.unseen]).toStringAsFixed(0)}, '
          'mean rivals in ${_mean([for (final t in rows) t.rivals]).toStringAsFixed(2)} '
          '(${rows.length})');
    }
    // Fit the ron multiplier: the model says a ready seat wins a given turn
    // with (outs / unseen) * (1 + ron * rivals); find the ron that makes the
    // predicted win rate over the whole sample equal the actual one.
    final actual = transitions.where((t) => t.won).length / transitions.length;
    double predicted(double ron) => _mean([
          for (final t in transitions)
            1 -
                pow(1 - min(0.9, t.outs / t.unseen * (1 + ron * t.rivals)),
                    t.draws)
        ]);
    var lo = 0.0, hi = 3.0;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (predicted(mid) < actual) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    print('\nwin chance of a hand after a discard, by shanten: model vs. actual');
    for (var s = 0; s <= 5; s++) {
      final rows = samples.where((x) => x.shanten == s).toList();
      if (rows.length < 50) continue;
      double predicted(double scale) => _mean([
            for (final x in rows)
              SichuanValue.chain(
                shanten: x.shanten,
                outs: x.outs,
                unseen: x.unseen,
                draws: x.draws,
                rivals: x.rivals,
              ).win
          ]);
      final actualRate = rows.where((x) => x.won).length / rows.length;
      print('  $s away: actual ${(actualRate * 100).toStringAsFixed(1)}%, '
          'model ${(predicted(1) * 100).toStringAsFixed(1)}% '
          '(${rows.length}, mean outs ${_mean([for (final x in rows) x.outs]).toStringAsFixed(1)})');
    }
    // Fit the widths, from the hands nearest ready outward: s=1 settles the
    // width of a ready hand's wait, s=2 the step from one away, and so on.
    double modelAt(int s) => _mean([
          for (final x in samples.where((x) => x.shanten == s))
            SichuanValue.chain(
              shanten: x.shanten,
              outs: x.outs,
              unseen: x.unseen,
              draws: x.draws,
              rivals: x.rivals,
            ).win
        ]);
    double actualAt(int s) {
      final rows = samples.where((x) => x.shanten == s).toList();
      return rows.where((x) => x.won).length / rows.length;
    }

    double bisect(void Function(double) set, int s) {
      var lo = 0.5, hi = 120.0;
      for (var i = 0; i < 40; i++) {
        final mid = (lo + hi) / 2;
        set(mid);
        if (modelAt(s) < actualAt(s)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return (lo + hi) / 2;
    }

    for (final h in [0.0, 0.02, 0.04, 0.06, 0.09]) {
      SichuanValueTuning.handEnds = h;
      print('\nhand ends each turn with chance $h');
    if (samples.where((x) => x.shanten == 1).length > 200) {
        final fitted = <String>[];
        final tw = bisect((v) => SichuanValueTuning.tenpaiWait = v, 1);
        SichuanValueTuning.tenpaiWait = tw;
        fitted.add('tenpaiWait ${tw.toStringAsFixed(1)}');
        for (var k = 1; k <= 3; k++) {
          if (samples.where((x) => x.shanten == k + 1).length < 200) break;
          final w = bisect((v) => SichuanValueTuning.stepWidth[k] = v, k + 1);
          SichuanValueTuning.stepWidth[k] = w;
          fitted.add('stepWidth[$k] ${w.toStringAsFixed(1)}');
        }
        print('\nfitted: ${fitted.join(', ')}');
        for (var s = 0; s <= 4; s++) {
          if (samples.where((x) => x.shanten == s).length < 50) continue;
          print('  $s away: actual ${(actualAt(s) * 100).toStringAsFixed(1)}%, '
              'refitted model ${(modelAt(s) * 100).toStringAsFixed(1)}%');
        }
      }
    }
    SichuanValueTuning.handEnds = 0;
    print('actual win rate once ready ${(actual * 100).toStringAsFixed(1)}%; '
        'fitted ron factor per rival ${lo.toStringAsFixed(2)}');
  }
}

class _Sample {
  _Sample(this.shanten, this.outs, this.unseen, this.draws, this.rivals,
      this.won);
  final int shanten, outs, unseen, draws, rivals;
  final bool won;
}

class _Transition {
  _Transition(this.wall, this.outs, this.unseen, this.rivals, this.draws,
      this.won);
  final int wall, outs, unseen, rivals, draws;
  final bool won;
}

String _pct(int a, int b) =>
    b == 0 ? 'n/a' : '${(100 * a / b).toStringAsFixed(1)}%';
double _mean(List<num> xs) =>
    xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b) / xs.length;

String _class(TileType t) {
  final n = t.number;
  if (n == 1 || n == 9) return 'terminal';
  if (n == 2 || n == 8) return 'two/eight';
  if (n == 3 || n == 7) return 'three/seven';
  return 'four-six';
}

void _playHand(_Counts c, int seed) {
  final round = Round(
    seed: seed,
    dealer: seed % 4,
    roundWind: Wind.east,
    startingPoints: List.filled(4, 0),
    ruleset: Ruleset.sichuan,
  );
  final bots = [for (var i = 0; i < 4; i++) SimpleBot(seed * 7 + i)];
  for (var i = 0; i < 4; i++) {
    round.declareVoidSuit(i, round.suggestVoidSuit(i));
  }
  // (seat, transition record) for seats that became ready; resolved at the end.
  final pending = <(int, _Transition Function(bool))>[];
  final sampled = <(int, _Sample)>[];
  final wasReady = List<bool>.filled(4, false);

  for (var guard = 0; guard < 2000 && !round.finished; guard++) {
    final phase = round.phase;
    final mover = round.turn;
    final beforeCount = round.seats[mover].allDiscards.length;
    if (phase == RoundPhase.callOffer) {
      final choices = <int, CallType>{};
      for (final opt in round.callOptions) {
        final call = bots[opt.seat]
            .decideCall(round, opt.seat, round.pendingDiscard!, opt.types);
        if (call != CallType.none) choices[opt.seat] = call;
      }
      round.resolveCalls(choices);
    } else if (phase == RoundPhase.discarding) {
      final decision = bots[mover].decideTurn(round, mover);
      if (decision.tsumo) {
        round.declareTsumo(mover);
      } else if (decision.closedKan != null) {
        round.closedKan(mover, decision.closedKan!);
      } else if (decision.addedKan != null) {
        round.addKan(mover, decision.addedKan!);
      } else {
        final tile = decision.discard ?? round.legalDiscards(mover).first;
        _beforeDiscard(c, round, mover, tile);
        round.discard(mover, tile);
      }
    }
    if (round.finished) break;
    final s = round.seats[mover];
    if (s.allDiscards.length > beforeCount && !s.out) {
      final n = s.allDiscards.length;
      final ready = _ready(s);
      if (n <= 20) {
        c.seatsAt[n]++;
        if (ready) c.readyAt[n]++;
      }
      if (round.wall.remaining > 0 && (seed + n + mover) % 6 == 0) {
        final vis = _visible(round, mover);
        final counts = _dead(toTrainerCounts(s.hand), s.voidSuit);
        final remaining = withoutVoidSuit(
            trainerCountsFromTypeCounts([for (final c in vis) (4 - c).clamp(0, 4)]),
            s.voidSuit);
        final shanten = _calc.calculateWaitingShanten(counts);
        final outs = _calc.acceptance(counts, remaining).count;
        final rivals = round.seats.where((o) => o.seat != mover && !o.out).length;
        final voidLeft = s.voidSuit == null
            ? 0
            : s.hand.where((t) => t.type.suit == s.voidSuit).length;
        final draws = max(0,
            SichuanValue.draws(round.wall.remaining, rivals) - voidLeft);
        final unseen = max(1, 108 - vis.fold<int>(0, (a, b) => a + b));
        sampled.add((mover, _Sample(shanten, outs, unseen, draws, rivals, false)));
      }
      if (ready && !wasReady[mover]) {
        final vis = _visible(round, mover);
        final outs = _outs(s, vis);
        final unseen = 108 - vis.fold<int>(0, (a, b) => a + b);
        final rivals = round.seats.where((o) => o.seat != mover && !o.out).length;
        final wall = round.wall.remaining;
        final draws = max(1, (wall / (rivals + 1)).ceil());
        pending.add((
          mover,
          (won) => _Transition(wall, outs, max(unseen, 1), rivals, draws, won)
        ));
      }
      wasReady[mover] = ready;
    }
  }
  if (!round.finished) return;
  c.hands++;
  final result = round.result!;
  final won = {for (final h in result.sichuanHu) h.seat};
  for (final p in pending) {
    c.transitions.add(p.$2(won.contains(p.$1)));
  }
  for (final p in sampled) {
    final x = p.$2;
    c.samples.add(_Sample(x.shanten, x.outs, x.unseen, x.draws, x.rivals,
        won.contains(p.$1)));
  }
  c.huSeatsTotal += result.sichuanHu.length;
  for (final h in result.sichuanHu) {
    c.huValue.add(h.score.points);
    if (h.selfDrawn) {
      c.huTsumo++;
    } else {
      c.huRon++;
    }
  }
  if (result.label == 'Wall Ends') {
    c.wallEnds++;
    for (final s in round.seats.where((s) => !s.out)) {
      c.wallEndSeats++;
      if (_ready(s)) {
        c.wallEndReady++;
        c.readyValue.add(_readyValue(s));
      }
    }
  }
}

bool _ready(SeatState s) {
  final v = s.voidSuit;
  if (v != null && s.hand.any((t) => t.type.suit == v)) return false;
  return isTenpaiSichuan(s.hand, openMelds: s.melds.length);
}

int _readyValue(SeatState s) {
  var best = 1;
  for (final w in waitTilesSichuan(s.hand, openMelds: s.melds.length)) {
    final win = Tile(9000 + w.index, w);
    final score = scoreSichuanHand(s.hand, win, s.melds,
        ScoreContext(roundWind: Wind.east, seatWind: s.wind, isTsumo: false, closed: s.closed));
    if (score.valid && score.points > best) best = score.points;
  }
  return best;
}

/// 34-slot counts of every tile [seat] can see: its own hand, every pond and
/// every meld.
List<int> _visible(Round round, int seat) {
  final counts = List<int>.filled(34, 0);
  for (final t in round.seats[seat].hand) {
    counts[t.type.index - 1]++;
  }
  for (final o in round.seats) {
    for (final t in [...o.pond, ...o.melds.expand((m) => m.tiles)]) {
      counts[t.type.index - 1]++;
    }
  }
  return counts;
}

int _outs(SeatState s, List<int> vis) {
  var n = 0;
  for (final w in waitTilesSichuan(s.hand, openMelds: s.melds.length)) {
    n += (4 - vis[w.index - 1]).clamp(0, 4);
  }
  return n;
}

/// For each ready rival who is not void in [tile]'s suit: did this discard
/// complete them? Keyed by tile class and by whether that rival had already
/// discarded the same tile.
void _beforeDiscard(_Counts c, Round round, int seat, Tile tile) {
  for (final r in round.seats) {
    if (r.seat == seat || r.out || !_ready(r)) continue;
    if (r.voidSuit == tile.type.suit) continue;
    final gen = r.allDiscards.any((t) => t.type == tile.type);
    final key = '${_class(tile.type)}${gen ? ' / thrown' : ''}';
    c.trials[key] = (c.trials[key] ?? 0) + 1;
    final waits = waitTilesSichuan(r.hand, openMelds: r.melds.length);
    if (waits.contains(tile.type)) c.hits[key] = (c.hits[key] ?? 0) + 1;
    final all = gen ? 'any / thrown' : 'any / fresh';
    c.trials[all] = (c.trials[all] ?? 0) + 1;
    if (waits.contains(tile.type)) c.hits[all] = (c.hits[all] ?? 0) + 1;
  }
}

final _calc = SichuanEfficiencyCalculator();

/// The guide's dead-weight trick: void-suit tiles become lone honors.
List<int> _dead(List<int> counts, int? voidSuit) {
  if (voidSuit == null) return counts;
  final out = List<int>.of(counts);
  var dead = 0;
  for (var n = 1; n <= 9; n++) {
    dead += out[voidSuit * 10 + n];
    out[voidSuit * 10 + n] = 0;
  }
  for (var i = 0; i < dead; i++) {
    out[31 + i % 7]++;
  }
  return out;
}
