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

/// Measures MCR guide tunings ([HongKongGuideTuning]'s MCR fields) against
/// SimpleBot on identical seeds. Every arm plays seat 0 on Autoplay except the
/// control, where a SimpleBot takes seat 0; each arm is compared game by game
/// with the control and with 'shipped', the guide as it stands. Games are East
/// only (four hands).
///
///   MCR_TUNE_GAMES=800 flutter test test/mcr_tuning_sweep_test.dart
///   MCR_TUNE_ARMS=before MCR_TUNE_GAMES=1600 flutter test ...
void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['MCR_TUNE_GAMES'] ?? '') ?? 0;
  test('MCR tuning sweep', () async {
    final base = int.tryParse(env['MCR_TUNE_SEED'] ?? '') ?? 620000;
    final only = env['MCR_TUNE_ARMS']?.split(',').toSet();
    final results = <String, List<_Row>>{};
    for (final arm in _arms) {
      if (only != null &&
          arm.name != 'control' &&
          arm.name != 'shipped' &&
          !only.contains(arm.name)) {
        continue;
      }
      final parts = await Future.wait([
        for (var s = 0; s < 8; s++)
          Isolate.run(() => _shard(base, games, s, arm)),
      ]);
      results[arm.name] = [for (final p in parts) ...p]
        ..sort((a, b) => a.seed.compareTo(b.seed));
    }
    print('\n$games East-only games per arm, seeds $base..${base + games - 1}');
    print('arm             avg place  wins/game  '
        'Δ place vs control (95% CI)  p        '
        'Δ place vs shipped (95% CI)  p        Δ pts vs control');
    final control = results['control']!;
    final shipped = results['shipped']!;
    String delta(({double mean, double se}) s) =>
        '${s.mean >= 0 ? '+' : ''}${s.mean.toStringAsFixed(3)} '
        '± ${(1.96 * s.se).toStringAsFixed(3)}';
    for (final e in results.entries) {
      final rows = e.value;
      List<double> diff(List<_Row> other, double Function(_Row) f) =>
          [for (var i = 0; i < rows.length; i++) f(rows[i]) - f(other[i])];
      final vsControl = _ms(diff(control, (r) => r.place));
      final vsShipped = _ms(diff(shipped, (r) => r.place));
      final pts = _ms(diff(control, (r) => r.points.toDouble()));
      print('${e.key.padRight(14)}'
          '  ${_mean([for (final r in rows) r.place]).toStringAsFixed(3).padLeft(9)}'
          '  ${_mean([for (final r in rows) r.wins.toDouble()]).toStringAsFixed(3).padLeft(9)}'
          '  ${delta(vsControl).padRight(27)}'
          '  ${_p(vsControl).toStringAsExponential(1).padRight(7)}'
          '  ${delta(vsShipped).padRight(27)}'
          '  ${_p(vsShipped).toStringAsExponential(1).padRight(7)}'
          '  ${pts.mean.toStringAsFixed(1).padLeft(7)}');
    }
  },
      skip: games == 0 ? 'set MCR_TUNE_GAMES to run' : false,
      timeout: Timeout.none);
}

class _Arm {
  const _Arm(this.name,
      {this.guide = true,
      this.noStepBack = false,
      this.shantenCalls = false,
      this.readyCalls = false});
  final String name;
  final bool guide;

  /// [HongKongGuideTuning.mcrNeverStepBack] and
  /// [HongKongGuideTuning.mcrTakeShantenCalls].
  final bool noStepBack;
  final bool shantenCalls;

  /// [HongKongGuideTuning.mcrCallsOnlyToReady].
  final bool readyCalls;

  void apply() {
    HongKongGuideTuning.mcrNeverStepBack = noStepBack;
    HongKongGuideTuning.mcrTakeShantenCalls = shantenCalls;
    HongKongGuideTuning.mcrCallsOnlyToReady = readyCalls;
  }
}

/// 'shipped' is the guide's defaults; 'before' is the guide as it stood
/// before any of these were measured (every MCR flag off).
const _arms = [
  _Arm('control', guide: false),
  _Arm('shipped', noStepBack: true, readyCalls: true),
  _Arm('before'),
  _Arm('no-step-back', noStepBack: true),
  _Arm('shanten-calls', shantenCalls: true),
  _Arm('both', noStepBack: true, shantenCalls: true),
  _Arm('ready-calls', readyCalls: true),
];

typedef _Row = ({int seed, double place, int points, int wins});

List<_Row> _shard(int base, int games, int shard, _Arm arm) {
  Sfx.i.enabled = false;
  arm.apply();
  return [
    for (var g = shard; g < games; g += 8) _play(base + g, arm.guide),
  ];
}

_Row _play(int seed, bool guide) {
  late _Row row;
  fakeAsync((fa) {
    final game =
        GameController(seed: seed, ruleset: Ruleset.mcr, hanchan: false);
    if (guide) game.setAutoplay(true);
    final bot = SimpleBot(seed * 31 + 3);
    var wins = 0;
    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        if (game.round.result!.winners.contains(kHumanSeat)) wins++;
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
    row = (seed: seed, place: place, points: pts[0], wins: wins);
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
