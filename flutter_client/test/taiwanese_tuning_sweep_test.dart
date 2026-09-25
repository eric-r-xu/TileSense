// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/bot.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

/// Measures Taiwanese guide tunings ([HongKongGuideTuning]'s Taiwanese
/// fields) against SimpleBot on identical seeds. Every arm plays seat 0 on
/// Autoplay except the control, where a SimpleBot takes seat 0; each arm is
/// compared game by game with the control.
///
///   TW_TUNE_GAMES=800 flutter test test/taiwanese_tuning_sweep_test.dart
///   TW_TUNE_ARMS=shipped,calls TW_TUNE_GAMES=1600 flutter test ...
///   TW_TUNE_MIN=1 TW_TUNE_ARMS=shipped TW_TUNE_GAMES=800 flutter test ...
/// `TW_TUNE_MIN`: the table's minimum points (5 by default).
int get _minimumPoints =>
    int.tryParse(Platform.environment['TW_TUNE_MIN'] ?? '') ?? 5;

void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['TW_TUNE_GAMES'] ?? '') ?? 0;
  test('Taiwanese tuning sweep', () async {
    final base = int.tryParse(env['TW_TUNE_SEED'] ?? '') ?? 7000;
    final only = env['TW_TUNE_ARMS']?.split(',').toSet();
    final results = <String, List<(int, double, int)>>{};
    for (final arm in _arms) {
      if (only != null && arm.name != 'control' && !only.contains(arm.name)) {
        continue;
      }
      final parts = await Future.wait([
        for (var s = 0; s < 8; s++)
          Isolate.run(() => _shard(base, games, s, arm)),
      ]);
      results[arm.name] = [for (final p in parts) ...p]
        ..sort((a, b) => a.$1.compareTo(b.$1));
    }
    final control = results['control']!;
    print('\n$games games per arm, seeds $base..${base + games - 1}, '
        '$_minimumPoints-point minimum');
    print('arm                   avg place   Δ place vs control (95% CI)    p'
        '        Δ points     p');
    for (final e in results.entries) {
      final rows = e.value;
      final place = [for (final r in rows) r.$2];
      final dPlace = [
        for (var i = 0; i < rows.length; i++) rows[i].$2 - control[i].$2
      ];
      final dPts = [
        for (var i = 0; i < rows.length; i++)
          (rows[i].$3 - control[i].$3).toDouble()
      ];
      final p = _ms(dPlace);
      final q = _ms(dPts);
      final delta = '${p.mean >= 0 ? '+' : ''}${p.mean.toStringAsFixed(3)} '
          '± ${(1.96 * p.se).toStringAsFixed(3)}';
      print(
          '${e.key.padRight(20)}  ${_mean(place).toStringAsFixed(3).padLeft(9)}'
          '   ${delta.padRight(30)}'
          '  ${_p(p).toStringAsExponential(1).padRight(8)}'
          '  ${q.mean.toStringAsFixed(2).padLeft(7)}'
          '  ${_p(q).toStringAsExponential(1)}');
    }
  },
      skip: games == 0 ? 'set TW_TUNE_GAMES to run' : false,
      timeout: Timeout.none);
}

class _Arm {
  const _Arm(this.name,
      {this.guide = true, this.threat = 4, this.model = WinModel.taiwanese});
  final String name;
  final bool guide;
  final int threat;
  final WinModel model;

  void apply() {
    HongKongGuideTuning.taiwaneseThreatExposedSets = threat;
    HongKongGuideTuning.taiwaneseWinModel = model;
  }
}

const _arms = [
  _Arm('control', guide: false),
  _Arm('shipped'),
  _Arm('draws-only', model: WinModel.hongKong),
  _Arm('threat-5', threat: 5),
  _Arm('calls', model: _calls),
];

/// Hong Kong's shipped model with pung and chow acceptance counted toward a
/// hand's width, at the rates `tools/fit_hk_win_model.py` fitted for Hong
/// Kong — typical widths in the same, call-inclusive units.
const _calls = WinModel(
  typicalWidth: [5, 31.39, 53.3, 83.47, 100.96, 107.08, 119.2],
  stepWidth: [8, 20, 28, 35, 40, 44, 48],
  survivesTurn: 0.955,
  waitInheritance: 0.5,
  winChancesPerTurn: 1.0,
  narrowPenalty: 0.5,
  pungRate: 1.030,
  chowRate: 1.609,
);

/// (seed, seat 0 placement, seat 0 final points) for one shard's games.
List<(int, double, int)> _shard(int base, int games, int shard, _Arm arm) {
  Sfx.i.enabled = false;
  arm.apply();
  return [
    for (var g = shard; g < games; g += 8) _play(base + g, arm.guide),
  ];
}

(int, double, int) _play(int seed, bool guide) {
  late (int, double, int) row;
  fakeAsync((fa) {
    final game = GameController(
        seed: seed, ruleset: Ruleset.taiwanese, minimumPoints: _minimumPoints);
    if (guide) game.setAutoplay(true);
    final bot = SimpleBot(seed * 31 + 3);
    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        game.continueFromRoundEnd();
        continue;
      }
      final round = game.round;
      if (!guide && !round.finished) {
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
    row = (seed, place, pts[0]);
    game.dispose();
  });
  return row;
}

double _mean(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;

({double mean, double se}) _ms(List<double> xs) {
  final m = _mean(xs);
  final v =
      xs.fold<double>(0, (a, b) => a + (b - m) * (b - m)) / (xs.length - 1);
  return (mean: m, se: sqrt(v / xs.length));
}

/// Two-sided normal p-value for a mean against 0.
double _p(({double mean, double se}) s) {
  if (s.se == 0) return s.mean == 0 ? 1 : 0;
  final z = (s.mean / s.se).abs();
  // Abramowitz–Stegun 7.1.26 erfc approximation.
  final x = z / sqrt2;
  final t = 1 / (1 + 0.3275911 * x);
  final erfc = t *
      (0.254829592 +
          t *
              (-0.284496736 +
                  t * (1.421413741 + t * (-1.453152027 + t * 1.061405429)))) *
      exp(-x * x);
  return erfc;
}
