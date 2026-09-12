// ignore_for_file: avoid_print, depend_on_referenced_packages
// TEMPORARY — calibration of the tenpai/riichi value model. For every riichi
// declared in self-play it records what the engine predicted for that exact
// hand at that exact moment, then what actually happened. Delete once the
// deposit is calibrated.
//
//   SIM_RV=200 flutter test test/tmp_diag_riichi_value_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';

import 'folding_bot.dart';

// Row layout, one per riichi declaration.
const _p = 0, _pts = 1, _wait = 2, _wall = 3, _quiet = 4, _ev = 5, _won = 6,
    _delta = 7, _unseen = 8, _draws = 9;

void main() {
  final n = int.tryParse(Platform.environment['SIM_RV'] ?? '') ?? 0;
  test('riichi value calibration', () async {
    final parts = await Future.wait([
      for (var s = 0; s < 5; s++) Isolate.run(() => _shard(n, s)),
    ]);
    final rows = [for (final p in parts) ...p.$1];
    final health = <String, num>{};
    for (final p in parts) {
      p.$2.forEach((k, v) => health[k] = (health[k] ?? 0) + v);
    }
    print('riichi declarations observed: ${rows.length}');
    final hands = (health['hands'] ?? 1).toDouble();
    print('\nEnvironment health (is this table still playing a game?)');
    print('  hands                  ${hands.toInt()}');
    print('  exhaustive draws       '
        '${((health['draws'] ?? 0) / hands * 100).toStringAsFixed(1)}%');
    print('  wins per hand          '
        '${((health['wins'] ?? 0) / hands).toStringAsFixed(3)}');
    print('  riichi per hand        ${(rows.length / hands).toStringAsFixed(3)}');
    print('  contested declarations '
        '${rows.where((r) => r[_quiet] == 0).length}');
    _report(rows);
    _fit(rows);
  }, skip: n == 0 ? 'set SIM_RV to run' : false, timeout: Timeout.none);
}

void _report(List<List<num>> rows) {
  if (rows.isEmpty) return;

  void bucket(String title, String Function(List<num>) key,
      Iterable<String> order) {
    final groups = <String, List<List<num>>>{};
    for (final r in rows) {
      groups.putIfAbsent(key(r), () => []).add(r);
    }
    print('\n$title');
    print('  ${'bucket'.padRight(16)} ${'n'.padLeft(6)} '
        '${'predicted'.padLeft(10)} ${'realized'.padLeft(9)} '
        '${'ratio'.padLeft(6)} ${'pred pts'.padLeft(9)} '
        '${'real pts'.padLeft(9)} ${'model EV'.padLeft(9)}');
    for (final k in order) {
      final g = groups[k];
      if (g == null || g.isEmpty) continue;
      double mean(int i) => g.fold<double>(0, (a, r) => a + r[i]) / g.length;
      final pred = mean(_p), real = mean(_won);
      print('  ${k.padRight(16)} ${g.length.toString().padLeft(6)} '
          '${pred.toStringAsFixed(3).padLeft(10)} '
          '${real.toStringAsFixed(3).padLeft(9)} '
          '${(pred == 0 ? 0 : real / pred).toStringAsFixed(2).padLeft(6)} '
          '${mean(_pts).round().toString().padLeft(9)} '
          '${mean(_delta).round().toString().padLeft(9)} '
          '${mean(_ev).round().toString().padLeft(9)}');
    }
  }

  bucket('By predicted win probability', (r) {
    final d = (r[_p] * 10).floor().clamp(0, 9);
    return '${(d / 10).toStringAsFixed(1)}-${((d + 1) / 10).toStringAsFixed(1)}';
  }, [for (var i = 0; i < 10; i++) '${(i / 10).toStringAsFixed(1)}-${((i + 1) / 10).toStringAsFixed(1)}']);

  bucket('By live wait width', (r) {
    final w = r[_wait].toInt();
    if (w <= 2) return '1-2 tiles';
    if (w <= 4) return '3-4 tiles';
    if (w <= 6) return '5-6 tiles';
    if (w <= 8) return '7-8 tiles';
    return '9+ tiles';
  }, ['1-2 tiles', '3-4 tiles', '5-6 tiles', '7-8 tiles', '9+ tiles']);

  bucket('By wall remaining', (r) {
    final w = r[_wall].toInt();
    if (w < 20) return 'wall <20';
    if (w < 40) return 'wall 20-39';
    return 'wall 40+';
  }, ['wall <20', 'wall 20-39', 'wall 40+']);

  bucket('By board', (r) => r[_quiet] == 1 ? 'quiet' : 'contested',
      ['quiet', 'contested']);

  String band(List<num> r) {
    final w = r[_wait].toInt();
    if (w <= 2) return '1-2';
    if (w <= 4) return '3-4';
    if (w <= 6) return '5-6';
    if (w <= 8) return '7-8';
    return '9+';
  }

  bucket('By board x wait width',
      (r) => '${r[_quiet] == 1 ? 'quiet' : 'contested'} ${band(r)}', [
    for (final b in ['quiet', 'contested'])
      for (final w in ['1-2', '3-4', '5-6', '7-8', '9+']) '$b $w',
  ]);
}

(List<List<num>>, Map<String, num>) _shard(int games, int shard) {
  Sfx.i.enabled = false;
  final out = <List<num>>[];
  final stats = <String, num>{};
  void add(String k, [num v = 1]) => stats[k] = (stats[k] ?? 0) + v;
  for (var g = shard; g < games; g += 5) {
    _game(9000 + g, out, add);
  }
  return (out, stats);
}

void _game(int seed, List<List<num>> out,
    void Function(String, [num]) add) {
  fakeAsync((fa) {
    // Every seat defends, so the win rates measured here are not inflated by
    // opponents feeding a riichi blind.
    final game = GameController(seed: seed, botFactory: FoldingBot.new);
    final bot = FoldingBot(seed * 13 + 5);
    // Declarations made this hand, awaiting their outcome.
    var pending = <int, List<num>>{};

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('stuck $seed');
      final round = game.round;

      if (game.phase == GamePhase.roundEnd) {
        final r = round.result!;
        add('hands');
        if (r.kind == RoundEndKind.exhaustiveDraw) add('draws');
        add('wins', r.winners.length);
        pending.forEach((seat, row) {
          row[_won] = r.winners.contains(seat) ? 1 : 0;
          row[_delta] = r.pointDeltas[seat] ?? 0;
          out.add(row);
        });
        pending = <int, List<num>>{};
        game.continueFromRoundEnd();
        continue;
      }

      final riichiBefore = [for (final s in round.seats) s.riichi];

      if (game.awaitingHumanCall) {
        game.answerCall(bot.decideCall(
            round, kHumanSeat, round.pendingDiscard!, game.humanCallOption!.types));
      } else if (game.isHumanTurn) {
        final d = bot.decideTurn(round, kHumanSeat);
        if (d.tsumo) {
          game.humanTsumo();
        } else if (d.closedKan != null) {
          game.humanClosedKan(d.closedKan!);
        } else if (d.addedKan != null) {
          game.humanAddKan(d.addedKan!);
        } else {
          game.humanDiscard(d.discard ?? round.legalDiscards(kHumanSeat).first,
              declareRiichi: d.riichi);
        }
      } else {
        fa.elapse(const Duration(milliseconds: 960));
      }

      // A seat that just declared: score the hand it declared on, exactly as
      // the guide would have seen it one moment earlier.
      final now = game.round;
      if (now.finished) continue;
      for (final s in now.seats) {
        if (s.riichi && !riichiBefore[s.seat] && s.pond.isNotEmpty) {
          final row = _measure(now, s);
          if (row != null) pending[s.seat] = row;
        }
      }
    }
    game.dispose();
  });
}

/// The engine's own reading of the hand this seat just declared riichi on.
List<num>? _measure(Round round, SeatState s) {
  if (s.hand.length != 13) return null;
  final declared = s.pond.last;
  // The pre-discard hand: what was in front of the player when they chose.
  final hand14 = [...s.hand, declared];

  final visible = List<int>.filled(34, 0);
  for (final t in hand14) {
    visible[t.type.index - 1]++;
  }
  for (final seat in round.seats) {
    for (final t in seat.pond) {
      // The declaring tile is already counted as part of the hand above.
      if (identical(t, declared)) continue;
      visible[t.type.index - 1]++;
    }
    for (final m in seat.melds) {
      for (final t in m.tiles) {
        visible[t.type.index - 1]++;
      }
    }
  }
  final dora = round.wall.doraIndicators();
  for (final t in dora) {
    visible[t.index - 1]++;
  }
  for (var i = 0; i < 34; i++) {
    if (visible[i] > 4) return null; // double-counted somewhere; skip
  }

  final quiet = !round.seats.any((o) => o.seat != s.seat && o.riichi);
  final report = EfficiencyEngine().analyze(
    hand: hand14,
    visibleCounts34: visible,
    canRiichi: true,
    valueContext: EfficiencyValueContext(
      melds: s.melds,
      roundWind: round.roundWind,
      seatWind: s.wind,
      isDealer: s.isDealer,
      inRiichi: false,
      wallTilesRemaining: round.wall.remaining,
      doraIndicators: dora,
    ),
  );
  final line = report.lines
      .where((l) => l.discard == declared.type && l.shanten == 0)
      .firstOrNull;
  if (line == null) return null;

  var unseen = 0;
  for (var i = 0; i < 34; i++) {
    unseen += 4 - visible[i];
  }
  return [
    line.winProbability,
    line.averagePoints,
    line.ukeire,
    round.wall.remaining,
    quiet ? 1 : 0,
    line.expectedValue,
    0,
    0,
    unseen,
    (round.wall.remaining + 3) ~/ 4,
  ];
}

/// Grid-fit the two constants the tenpai win curve compounds over turns,
/// against what actually happened. Mirrors `_winChanceOverTurns`.
void _fit(List<List<num>> rows) {
  double predict(List<num> r, double survives, double chances) {
    final width = r[_wait].toDouble();
    final unseen = r[_unseen].toDouble();
    final draws = r[_draws].toInt();
    if (width <= 0 || unseen <= 0 || draws <= 0) return 1e-6;
    final rate = math.min(1.0, width / unseen);
    final perTurn = 1 - math.pow(1 - rate, chances).toDouble();
    var alive = 1.0, won = 0.0;
    for (var t = 0; t < draws; t++) {
      won += alive * perTurn;
      alive *= (1 - perTurn) * survives;
    }
    return won.clamp(1e-6, 1 - 1e-6);
  }

  double logLik(double survives, double chances) {
    var ll = 0.0;
    for (final r in rows) {
      final p = predict(r, survives, chances);
      ll += r[_won] == 1 ? math.log(p) : math.log(1 - p);
    }
    return ll;
  }

  var bestS = 0.0, bestC = 0.0, bestLl = double.negativeInfinity;
  for (var s = 0.930; s <= 1.0001; s += 0.005) {
    for (var c = 0.60; c <= 2.601; c += 0.05) {
      final ll = logLik(s, c);
      if (ll > bestLl) {
        bestLl = ll;
        bestS = s;
        bestC = c;
      }
    }
  }
  print('\nMaximum-likelihood fit to realized outcomes (${rows.length} riichi):');
  print('  _handSurvivesTurn  = ${bestS.toStringAsFixed(3)}   (engine 0.955)');
  print('  _winChancesPerTurn = ${bestC.toStringAsFixed(2)}    (engine 1.00)');
  print('  log-likelihood     = ${bestLl.toStringAsFixed(1)}'
      '   engine: ${logLik(0.955, 1.0).toStringAsFixed(1)}');

  String band(List<num> r) {
    final w = r[_wait].toInt();
    if (w <= 2) return '1-2';
    if (w <= 4) return '3-4';
    if (w <= 6) return '5-6';
    if (w <= 8) return '7-8';
    return '9+';
  }
  final groups = <String, List<List<num>>>{};
  for (final r in rows) {
    groups.putIfAbsent(band(r), () => []).add(r);
  }
  print('  wait      n   engine   fitted  realized');
  for (final k in ['1-2', '3-4', '5-6', '7-8', '9+']) {
    final g = groups[k];
    if (g == null) continue;
    double mean(double Function(List<num>) f) =>
        g.fold<double>(0, (a, r) => a + f(r)) / g.length;
    print('  ${k.padRight(5)} ${g.length.toString().padLeft(5)} '
        '${mean((r) => r[_p].toDouble()).toStringAsFixed(3).padLeft(8)} '
        '${mean((r) => predict(r, bestS, bestC)).toStringAsFixed(3).padLeft(8)} '
        '${mean((r) => r[_won].toDouble()).toStringAsFixed(3).padLeft(9)}');
  }
}
