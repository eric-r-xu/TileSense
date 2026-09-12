// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/bot.dart';

import 'folding_bot.dart';

/// Monte-Carlo check of whether the guide (Autoplay at seat 0) beats the three
/// SimpleBot opponents. Drives the real [GameController] under fake time, so
/// the exact app code path is measured.
///
/// Two arms on identical seeds:
///  * guide   — seat 0 on Autoplay (efficiency / EV / safety guide);
///  * control — seat 0 played by a SimpleBot through the human-input API.
/// The control arm measures seat 0's structural edge (it always deals first),
/// so the guide's own contribution is the paired difference between arms.
///
/// Skipped unless SIM_GAMES is set:
///   SIM_GAMES=400 flutter test test/guide_vs_bots_sim_test.dart
void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['SIM_GAMES'] ?? '') ?? 0;

  test('guide vs SimpleBot simulation', () async {
    final shards = int.tryParse(env['SIM_SHARDS'] ?? '') ?? 5;
    final base = int.tryParse(env['SIM_SEED'] ?? '') ?? 1000;
    // SIM_FOLD=1 swaps the opponents for ones that get out of the way of a
    // riichi. The stock bots never fold, which makes this table far kinder to
    // aggression than real play — a riichi wins 66% of the time on a quiet
    // board against them, and 45% once they defend. Off by default so earlier
    // numbers stay reproducible.
    final fold = env['SIM_FOLD'] == '1';
    final sw = Stopwatch()..start();
    print(fold ? 'Opponents: FoldingBot' : 'Opponents: SimpleBot (never fold)');

    final arms = await Future.wait([
      _runArm(base, games, shards, guide: true, fold: fold),
      _runArm(base, games, shards, guide: false, fold: fold),
    ]);
    print('Simulated ${games * 2} hanchan in ${sw.elapsed.inSeconds}s');

    final out = env['SIM_OUT'];
    if (out != null) {
      File(out).writeAsStringSync([
        'seed,guide,hands,${_cols.join(',')}',
        for (final arm in arms)
          for (final r in arm) r.join(','),
      ].join('\n'));
    }
    _report(arms[0], arms[1]);
  }, skip: games == 0 ? 'set SIM_GAMES to run' : false, timeout: Timeout.none);
}

// Row layout: seed, guide, hands, then 4 values per column below.
const _cols = [
  'pts0', 'pts1', 'pts2', 'pts3', //
  'win0', 'win1', 'win2', 'win3',
  'dealin0', 'dealin1', 'dealin2', 'dealin3',
  'wingain0', 'wingain1', 'wingain2', 'wingain3',
  'riichi0', 'riichi1', 'riichi2', 'riichi3',
];
const _pts = 3, _win = 7, _dealIn = 11, _winGain = 15, _riichi = 19;

Future<List<List<num>>> _runArm(int base, int games, int shards,
    {required bool guide, required bool fold}) async {
  final parts = await Future.wait([
    for (var s = 0; s < shards; s++)
      Isolate.run(() => _shard(base, games, s, shards, guide, fold)),
  ]);
  return [for (final p in parts) ...p]..sort((a, b) => a[0].compareTo(b[0]));
}

List<List<num>> _shard(
    int base, int games, int shard, int shards, bool guide, bool fold) {
  Sfx.i.enabled = false;
  return [
    for (var g = shard; g < games; g += shards)
      _playGame(base + g, guide, fold),
  ];
}

List<num> _playGame(int seed, bool guide, bool fold) {
  late List<num> row;
  fakeAsync((fa) {
    final game = GameController(
        seed: seed, botFactory: fold ? FoldingBot.new : SimpleBot.new);
    if (guide) game.setAutoplay(true);
    final seat0Bot =
        fold ? FoldingBot(seed * 31 + 3) : SimpleBot(seed * 31 + 3);
    final wins = List<num>.filled(4, 0);
    final dealIns = List<num>.filled(4, 0);
    final winGain = List<num>.filled(4, 0);
    final riichi = List<num>.filled(4, 0);
    var hands = 0;

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        final r = game.round.result!;
        hands++;
        for (final w in r.winners) {
          wins[w] += 1;
          winGain[w] += r.pointDeltas[w]!;
        }
        if (r.loser != null) dealIns[r.loser!] += 1;
        for (final s in game.round.seats) {
          if (s.riichi) riichi[s.seat] += 1;
        }
        game.continueFromRoundEnd();
        continue;
      }
      if (!guide && !game.round.finished) {
        final round = game.round;
        if (game.awaitingHumanCall) {
          game.answerCall(seat0Bot.decideCall(round, kHumanSeat,
              round.pendingDiscard!, game.humanCallOption!.types));
          continue;
        }
        if (game.isHumanTurn) {
          final d = seat0Bot.decideTurn(round, kHumanSeat);
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
          continue;
        }
      }
      fa.elapse(const Duration(milliseconds: 960));
    }
    row = [
      seed, guide ? 1 : 0, hands, //
      ...game.tablePoints, ...wins, ...dealIns, ...winGain, ...riichi,
    ];
    game.dispose();
  });
  return row;
}

// --- statistics -------------------------------------------------------------

/// Placement with ties split (two seats tied for 1st both get 1.5).
double _place(List<num> row, int seat) {
  final mine = row[_pts + seat];
  var p = 1.0;
  for (var i = 0; i < 4; i++) {
    if (i == seat) continue;
    final o = row[_pts + i];
    if (o > mine) p += 1;
    if (o == mine) p += 0.5;
  }
  return p;
}

double _mean(List<num> xs) => xs.fold<double>(0, (a, b) => a + b) / xs.length;

({double mean, double se}) _ms(List<num> xs) {
  final m = _mean(xs);
  final v = xs.fold<double>(0, (a, b) => a + (b - m) * (b - m)) /
      (xs.length - 1);
  return (mean: m, se: sqrt(v / xs.length));
}

/// Complementary error function (Numerical Recipes erfcc, |err| < 1.2e-7).
double _erfc(double x) {
  final z = x.abs();
  final t = 1 / (1 + 0.5 * z);
  final r = t *
      exp(-z * z -
          1.26551223 +
          t *
              (1.00002368 +
                  t *
                      (0.37409196 +
                          t *
                              (0.09678418 +
                                  t *
                                      (-0.18628806 +
                                          t *
                                              (0.27886807 +
                                                  t *
                                                      (-1.13520398 +
                                                          t *
                                                              (1.48851587 +
                                                                  t *
                                                                      (-0.82215223 +
                                                                          t * 0.17087277)))))))));
  return x >= 0 ? r : 2 - r;
}

/// Two-sided p-value for a z statistic (n is in the hundreds, so the t
/// distribution is indistinguishable from normal).
double _p(double z) => _erfc(z.abs() / sqrt2);

String _f(double x, [int d = 3]) => x.toStringAsFixed(d);
String _pf(double p) => p < 1e-6 ? '<1e-6' : p.toStringAsExponential(2);

String _test(String label, List<num> xs, double h0) {
  final s = _ms(xs);
  final z = (s.mean - h0) / s.se;
  return '  $label: ${_f(s.mean)} ± ${_f(1.96 * s.se)} (95% CI)'
      '  vs $h0 → z=${_f(z, 2)}, p=${_pf(_p(z))}';
}

void _seatTable(String name, List<List<num>> rows) {
  final hands = rows.fold<num>(0, (a, r) => a + r[2]);
  print('\n[$name] ${rows.length} games, $hands hands');
  print('  seat        avg place  1st%   4th%   avg final  win/hand  dealin/hand'
      '  avg win gain  riichi/hand');
  for (var s = 0; s < 4; s++) {
    final places = [for (final r in rows) _place(r, s)];
    num sum(int col) => rows.fold<num>(0, (a, r) => a + r[col + s]);
    final w = sum(_win);
    print('  ${kSeatNames[s].padRight(10)}'
        '  ${_f(_mean(places), 3).padLeft(9)}'
        '  ${_f(100 * places.where((p) => p == 1).length / rows.length, 1).padLeft(5)}'
        '  ${_f(100 * places.where((p) => p == 4).length / rows.length, 1).padLeft(5)}'
        '  ${_f(sum(_pts) / rows.length, 0).padLeft(9)}'
        '  ${_f(w / hands, 3).padLeft(8)}'
        '  ${_f(sum(_dealIn) / hands, 3).padLeft(11)}'
        '  ${_f(w == 0 ? 0 : sum(_winGain) / w, 0).padLeft(12)}'
        '  ${_f(sum(_riichi) / hands, 3).padLeft(11)}');
  }
}

void _report(List<List<num>> guide, List<List<num>> control) {
  _seatTable('GUIDE at seat 0', guide);
  _seatTable('CONTROL: SimpleBot at seat 0', control);

  List<num> place0(List<List<num>> rows) => [for (final r in rows) _place(r, 0)];
  List<num> pts0(List<List<num>> rows) => [for (final r in rows) r[_pts]];
  List<num> first0(List<List<num>> rows) =>
      [for (final r in rows) _place(r, 0) == 1 ? 1 : 0];
  List<num> last0(List<List<num>> rows) =>
      [for (final r in rows) _place(r, 0) == 4 ? 1 : 0];

  print('\nOne-sample tests, seat 0 vs "no better than the table":');
  for (final (name, rows) in [('guide', guide), ('control', control)]) {
    print(' $name');
    print(_test('avg placement     ', place0(rows), 2.5));
    print(_test('final points      ', pts0(rows), 25000));
    print(_test('1st-place rate    ', first0(rows), 0.25));
    print(_test('4th-place rate    ', last0(rows), 0.25));
  }

  // Same seeds in both arms, so pair game-for-game.
  assert(guide.length == control.length);
  print('\nPaired guide − control (same seeds, isolates the guide itself):');
  List<num> diff(List<num> a, List<num> b) =>
      [for (var i = 0; i < a.length; i++) a[i] - b[i]];
  print(_test('Δ avg placement   ', diff(place0(guide), place0(control)), 0));
  print(_test('Δ final points    ', diff(pts0(guide), pts0(control)), 0));
  print(_test('Δ 1st-place rate  ', diff(first0(guide), first0(control)), 0));
}
