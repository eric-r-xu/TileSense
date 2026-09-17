// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:mahjong_core/bot.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:mahjong_core/ruleset.dart';

/// Measures [HongKongGuideTuning] variants against the bots on identical
/// seeds (common random numbers). Every guide arm plays Aggressive / Speed;
/// the control arm is SimpleBot in seat 0. Each variant is compared
/// game-by-game with the round's baseline — its second arm — and with the
/// control, Holm-corrected. `_Arm`'s defaults are riichi's model ('original').
///
///   HK_TUNE_GAMES=1000 flutter test test/hong_kong/hk_tuning_sweep_test.dart
///   HK_TUNE_GAMES=400 HK_TUNE_FULL=1 flutter test test/hong_kong/hk_tuning_sweep_test.dart
void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['HK_TUNE_GAMES'] ?? '') ?? 0;
  test('Hong Kong tuning sweep', () async {
    final full = env['HK_TUNE_FULL'] == '1';
    final base = int.tryParse(env['HK_TUNE_SEED'] ?? '') ?? 5000;
    final only = env['HK_TUNE_ARMS']?.split(',').toSet();
    final sw = Stopwatch()..start();
    final results = <(String, List<(double, int, int, int)>)>[];
    for (final arm in _arms) {
      if (only != null && !only.contains(arm.name) && arm.name != 'control' &&
          arm.name != _arms[1].name) {
        continue;
      }
      final parts = await Future.wait([
        for (var s = 0; s < 10; s++)
          Isolate.run(() => _shard(base, games, s, arm, full)),
      ]);
      results.add((arm.name, [for (final p in parts) ...p]));
      print('  ${arm.name} done at ${sw.elapsed.inSeconds}s');
    }
    _report(results, games, full);
  }, skip: games == 0 ? 'set HK_TUNE_GAMES to run' : false,
      timeout: Timeout.none);
}

class _Arm {
  const _Arm(this.name,
      {this.guide = true,
      this.gate = true,
      this.threat = 2,
      this.narrow = 1.0,
      this.tries = 1.0,
      this.concealed = true,
      this.model});
  final String name;
  final bool guide;
  final bool gate;
  final int threat;
  final double narrow;
  final double tries;
  final bool concealed;

  /// A whole win model, overriding [narrow] and [tries] when set.
  final WinModel? model;

  void apply() {
    HongKongGuideTuning.gateCallsUnderThreat = gate;
    HongKongGuideTuning.threatExposedSets = threat;
    HongKongGuideTuning.winModel = model ?? WinModel(
      typicalWidth: WinModel.riichi.typicalWidth,
      stepWidth: WinModel.riichi.stepWidth,
      survivesTurn: WinModel.riichi.survivesTurn,
      waitInheritance: WinModel.riichi.waitInheritance,
      winChancesPerTurn: WinModel.riichi.winChancesPerTurn,
      narrowPenalty: narrow,
      stepTries: tries,
    );
    HongKongGuideTuning.concealedFaanInEstimate = concealed;
  }
}

/// The arms for `HK_TUNE_ROUND` (1 by default).
List<_Arm> get _arms => switch (Platform.environment['HK_TUNE_ROUND']) {
      '2' => _round2,
      '3' => _holdout,
      '4' => _winModels,
      '5' => _headToHead,
      _ => _round1,
    };

/// The calibrated call-aware model against the shipped guide, game by game.
const _headToHead = [
  _Arm('control', guide: false),
  _Arm('shipped', threat: 3, model: WinModel.hongKongDrawsOnly),
  _Arm('calibrated-calls', threat: 3, model: _calibratedCalls),
];

/// Ideas 1 and 2 from the Hong Kong guide plan, separately and together, each
/// on the shipped threat (three sets) and call gate. Constants are the fits
/// `tools/fit_hk_win_model.py` made to 159k guide decisions.
const _winModels = [
  _Arm('control', guide: false),
  _Arm('original'),
  _Arm('shipped', threat: 3, model: WinModel.hongKongDrawsOnly),
  _Arm('calibrated-draws', threat: 3, model: _calibratedDraws),
  _Arm('calls-uncalibrated', threat: 3, model: _callsUncalibrated),
  _Arm('calibrated-calls', threat: 3, model: _calibratedCalls),
];

const _calibratedDraws = WinModel(
  typicalWidth: [5, 15.21, 29.15, 54.3, 72.99, 84.34, 99.17],
  stepWidth: [3.24, 25.14, 41.23, 40.51, 41.15, 44.03, 47.98],
  survivesTurn: 0.999,
  waitInheritance: 1.0,
  winChancesPerTurn: 0.791,
  narrowPenalty: 0.465,
);

const _calibratedCalls = WinModel(
  typicalWidth: [5, 31.39, 53.3, 83.47, 100.96, 107.08, 119.2],
  stepWidth: [3.33, 22.39, 40.62, 41.01, 41.45, 44.05, 47.98],
  survivesTurn: 0.999,
  waitInheritance: 1.0,
  winChancesPerTurn: 0.790,
  narrowPenalty: 0.484,
  pungRate: 1.030,
  chowRate: 1.609,
);

/// Idea 1 alone: calls counted at the fitted rates, typical widths in the
/// same units, everything else as shipped.
const _callsUncalibrated = WinModel(
  typicalWidth: [5, 31.39, 53.3, 83.47, 100.96, 107.08, 119.2],
  stepWidth: [8, 20, 28, 35, 40, 44, 48],
  survivesTurn: 0.955,
  waitInheritance: 0.5,
  winChancesPerTurn: 1.0,
  narrowPenalty: 0.5,
  pungRate: 1.030,
  chowRate: 1.609,
);

/// Confirms the chosen settings on seeds no tuning round has seen.
const _holdout = [
  _Arm('control', guide: false),
  _Arm('original'),
  _Arm('n0.5+threat-3', narrow: 0.5, threat: 3),
];

const _round2 = [
  _Arm('control', guide: false),
  _Arm('original'),
  _Arm('narrow-0.25', narrow: 0.25),
  _Arm('narrow-0.5', narrow: 0.5),
  _Arm('narrow-0.75', narrow: 0.75),
  _Arm('n0.5+no-gate', narrow: 0.5, gate: false),
  _Arm('n0.5+threat-3', narrow: 0.5, threat: 3),
  _Arm('n0.5+no-gate+threat-3', narrow: 0.5, gate: false, threat: 3),
];

const _round1 = [
  _Arm('control', guide: false),
  _Arm('original'),
  _Arm('no-call-gate', gate: false),
  _Arm('threat-3-sets', threat: 3),
  _Arm('narrow-0.5', narrow: 0.5),
  _Arm('narrow-0', narrow: 0),
  _Arm('step-tries-1.5', tries: 1.5),
  _Arm('no-concealed-faan', concealed: false),
  _Arm('combo', gate: false, narrow: 0.5, tries: 1.5, concealed: false),
];

/// (placement, chips, wins, hands) per game.
List<(double, int, int, int)> _shard(
    int base, int games, int shard, _Arm arm, bool full) {
  Sfx.i.enabled = false;
  arm.apply();
  return [
    for (var g = shard; g < games; g += 10) _play(base + g, arm, full),
  ];
}

(double, int, int, int) _play(int seed, _Arm arm, bool full) {
  late (double, int, int, int) row;
  fakeAsync((fa) {
    final game = GameController(seed: seed, ruleset: Ruleset.hongKong)
      ..hanchan = full;
    if (arm.guide) {
      game
        ..setAutoplay(true)
        ..playStyle = PlayStyle.aggressive
        ..handFocus = HandFocus.speed;
    }
    final bot = SimpleBot(seed * 31 + 3);
    var hands = 0, wins = 0;
    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 200000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        hands++;
        if (game.round.result!.winners.contains(kHumanSeat)) wins++;
        game.continueFromRoundEnd();
        continue;
      }
      final round = game.round;
      if (!arm.guide && !round.finished) {
        if (game.awaitingHumanCall) {
          game.answerCall(bot.decideCall(round, kHumanSeat,
              round.pendingDiscard!, game.humanCallOption!.types));
          continue;
        }
        if (game.isHumanTurn) {
          final d = bot.decideTurn(round, kHumanSeat);
          if (d.tsumo) {
            game.humanTsumo();
          } else if (d.closedKan != null) {
            game.humanClosedKan(d.closedKan!);
          } else if (d.addedKan != null) {
            game.humanAddKan(d.addedKan!);
          } else {
            game.humanDiscard(
                d.discard ?? round.legalDiscards(kHumanSeat).first);
          }
          continue;
        }
      }
      fa.elapse(const Duration(milliseconds: 1104));
    }
    final pts = game.tablePoints;
    var place = 1.0;
    for (var i = 1; i < 4; i++) {
      if (pts[i] > pts[0]) place += 1;
      if (pts[i] == pts[0]) place += 0.5;
    }
    row = (place, pts[0], wins, hands);
    game.dispose();
  });
  return row;
}

double _mean(List<double> xs) =>
    xs.fold<double>(0, (a, b) => a + b) / xs.length;

({double mean, double se, double p}) _paired(
    List<(double, int, int, int)> a, List<(double, int, int, int)> b) {
  final d = [for (var i = 0; i < a.length; i++) a[i].$1 - b[i].$1];
  final m = _mean(d);
  final v = d.fold<double>(0, (s, x) => s + (x - m) * (x - m)) / (d.length - 1);
  final se = sqrt(v / d.length);
  return (mean: m, se: se, p: se == 0 ? 1 : _p(m / se));
}

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

double _p(double z) => _erfc(z.abs() / sqrt2);

List<double> _holm(List<double> ps) {
  final order = List.generate(ps.length, (i) => i)
    ..sort((a, b) => ps[a].compareTo(ps[b]));
  final out = List<double>.filled(ps.length, 1);
  var running = 0.0;
  for (var k = 0; k < order.length; k++) {
    running = max(running, min(1.0, (ps.length - k) * ps[order[k]]));
    out[order[k]] = running;
  }
  return out;
}

String _f(double x, [int d = 3]) => x.toStringAsFixed(d);
String _pf(double p) => p < 1e-6 ? '<1e-6' : p.toStringAsExponential(1);

void _report(List<(String, List<(double, int, int, int)>)> results, int games,
    bool full) {
  final control = results.firstWhere((r) => r.$1 == 'control').$2;
  final baselineName = results[1].$1;
  final baseline = results[1].$2;
  final variants = results
      .where((r) => r.$1 != 'control' && r.$1 != baselineName)
      .toList();
  final vsBaseline = [for (final v in variants) _paired(v.$2, baseline)];
  final holm = _holm([for (final c in vsBaseline) c.p]);
  print('\nHong Kong, ${full ? 'four winds' : 'East only'}, $games games/arm, '
      'Aggressive / Speed\n');
  print('arm                      place   win/hd   Δ vs control          '
      'Δ vs $baselineName   raw p   Holm p');
  for (final (name, rows) in results) {
    final hands = rows.fold<int>(0, (a, r) => a + r.$4);
    final wins = rows.fold<int>(0, (a, r) => a + r.$3);
    final place = _mean([for (final r in rows) r.$1]);
    var line = '${name.padRight(24)}${_f(place).padLeft(6)}'
        '${_f(wins / hands).padLeft(9)}';
    if (name != 'control') {
      final c = _paired(rows, control);
      line += '   ${_f(c.mean).padLeft(7)} ±${_f(1.96 * c.se)} p=${_pf(c.p)}';
    }
    final i = variants.indexWhere((v) => v.$1 == name);
    if (i >= 0) {
      final c = vsBaseline[i];
      line += '   ${_f(c.mean).padLeft(7)} ±${_f(1.96 * c.se)}'
          '${_pf(c.p).padLeft(9)}${_pf(holm[i]).padLeft(9)}';
    }
    print(line);
  }
}
