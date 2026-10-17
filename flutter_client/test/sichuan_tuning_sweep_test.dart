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
import 'package:tilesense/logic/sichuan_value.dart';

/// Measures the Sichuan guide against SimpleBot on identical seeds. Every arm
/// plays seat 0 on Autoplay except the control, where a SimpleBot takes seat
/// 0; each arm is compared game by game with the control. Sichuan is zero-sum
/// in points, so the figure that matters is seat 0's final points per game
/// (and, less sharply, its placement).
///
///   SC_TUNE_GAMES=800 flutter test test/sichuan_tuning_sweep_test.dart
///   SC_TUNE_ARMS=shipped SC_TUNE_GAMES=1600 flutter test ...
///   SC_TUNE_HANDS=4 ...   (practice length instead of the full eight hands)
int get _hands => int.tryParse(Platform.environment['SC_TUNE_HANDS'] ?? '') ?? 8;

void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['SC_TUNE_GAMES'] ?? '') ?? 0;
  test('Sichuan tuning sweep', () async {
    final base = int.tryParse(env['SC_TUNE_SEED'] ?? '') ?? 9000;
    final only = env['SC_TUNE_ARMS']?.split(',').toSet();
    final results = <String, List<_Row>>{};
    for (final arm in _arms) {
      if (only != null && arm.name != 'control' && !only.contains(arm.name)) {
        continue;
      }
      final parts = await Future.wait([
        for (var s = 0; s < 8; s++)
          Isolate.run(() => _shard(base, games, s, arm)),
      ]);
      results[arm.name] = [for (final p in parts) ...p]
        ..sort((a, b) => a.seed.compareTo(b.seed));
    }
    final control = results['control']!;
    print('\n$games games per arm, seeds $base..${base + games - 1}, '
        '$_hands hands');
    print('arm                   avg place   Δ place vs control (95% CI)    p'
        '        Δ points (95% CI)       p');
    for (final e in results.entries) {
      final rows = e.value;
      final place = [for (final r in rows) r.place];
      final dPlace = [
        for (var i = 0; i < rows.length; i++) rows[i].place - control[i].place
      ];
      final dPts = [
        for (var i = 0; i < rows.length; i++)
          (rows[i].points - control[i].points).toDouble()
      ];
      final p = _ms(dPlace);
      final q = _ms(dPts);
      final delta = '${p.mean >= 0 ? '+' : ''}${p.mean.toStringAsFixed(3)} '
          '± ${(1.96 * p.se).toStringAsFixed(3)}';
      print(
          '${e.key.padRight(20)}  ${_mean(place).toStringAsFixed(3).padLeft(9)}'
          '   ${delta.padRight(30)}'
          '  ${_p(p).toStringAsExponential(1).padRight(8)}'
          '  ${('${q.mean >= 0 ? '+' : ''}${q.mean.toStringAsFixed(2)} '
              '± ${(1.96 * q.se).toStringAsFixed(2)}').padRight(18)}'
          '  ${_p(q).toStringAsExponential(1)}');
    }
    print('\nseat 0, per hand: wins / self-drawn share / mean Hu value / '
        'deals in / hands won by being dealt a self-draw');
    for (final e in results.entries) {
      var hands = 0, wins = 0, tsumo = 0, value = 0, dealIns = 0;
      for (final r in e.value) {
        hands += r.hands;
        wins += r.wins;
        tsumo += r.tsumo;
        value += r.value;
        dealIns += r.dealIns;
      }
      print('${e.key.padRight(20)}  ${(wins / hands).toStringAsFixed(3)}'
          '   ${(tsumo / max(wins, 1) * 100).toStringAsFixed(1).padLeft(5)}%'
          '   ${(value / max(wins, 1)).toStringAsFixed(3)}'
          '   ${(dealIns / hands).toStringAsFixed(3)}');
    }
  },
      skip: games == 0 ? 'set SC_TUNE_GAMES to run' : false,
      timeout: Timeout.none);
}

class _Arm {
  const _Arm(this.name, {this.guide = true, this.dials = const {}});
  final String name;
  final bool guide;

  /// [SichuanValueTuning] fields to move for this arm, by name.
  final Map<String, double> dials;

  void apply() {
    for (final e in dials.entries) {
      switch (e.key) {
        case 'valueScale':
          SichuanValueTuning.valueScale = e.value;
        case 'dealInScale':
          SichuanValueTuning.dealInScale = e.value;
        case 'endSettlement':
          SichuanValueTuning.endSettlement = e.value != 0;
        case 'handEnds':
          SichuanValueTuning.handEnds = e.value;
        case 'tenpaiWait':
          SichuanValueTuning.tenpaiWait = e.value;
        case 'step1':
          SichuanValueTuning.stepWidth[1] = e.value;
        case 'step2':
          SichuanValueTuning.stepWidth[2] = e.value;
        case 'step3':
          SichuanValueTuning.stepWidth = [
            ...SichuanValueTuning.stepWidth.take(3),
            for (var i = 3; i < 7; i++) e.value,
          ];
        case 'guideVoidPick':
          SichuanValueTuning.guideVoidPick = e.value != 0;
        case 'ronPerRival':
          SichuanValueTuning.ronPerRival = e.value;
        case 'flushDecay':
          SichuanValueTuning.flushDecay = e.value;
        case 'pungWeight':
          SichuanValueTuning.pungWeight = e.value;
        case 'pairsWeight':
          SichuanValueTuning.pairsWeight = e.value;
        case 'rivalValue':
          SichuanValueTuning.rivalValue = e.value;
        case 'wallEndShare':
          SichuanValueTuning.wallEndShare = e.value;
        default:
          throw ArgumentError('unknown dial ${e.key}');
      }
    }
  }
}

final _arms = [
  const _Arm('control', guide: false),
  const _Arm('shipped'),
  const _Arm('no-defence', dials: {'dealInScale': 0}),
  const _Arm('no-end', dials: {'endSettlement': 0}),
  const _Arm('no-void-pick', dials: {'guideVoidPick': 0}),
  const _Arm('no-flush', dials: {'flushDecay': 0.0001}),
];

/// One game of seat 0: where it finished and what happened in its hands.
class _Row {
  const _Row(this.seed, this.place, this.points,
      {required this.hands,
      required this.wins,
      required this.tsumo,
      required this.value,
      required this.dealIns});
  final int seed;
  final double place;
  final int points;
  final int hands, wins, tsumo, value, dealIns;
}

List<_Row> _shard(int base, int games, int shard, _Arm arm) {
  Sfx.i.enabled = false;
  arm.apply();
  return [
    for (var g = shard; g < games; g += 8) _play(base + g, arm.guide),
  ];
}

_Row _play(int seed, bool guide) {
  late _Row row;
  var hands = 0, wins = 0, tsumo = 0, value = 0, dealIns = 0;
  fakeAsync((fa) {
    final game = GameController(
        seed: seed, ruleset: Ruleset.sichuan, hanchan: _hands >= 8);
    if (guide) game.setAutoplay(true);
    final bot = SimpleBot(seed * 31 + 3);
    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 400000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        hands++;
        for (final h in game.round.result!.sichuanHu) {
          if (h.seat == kHumanSeat) {
            wins++;
            value += h.score.points;
            if (h.selfDrawn) tsumo++;
          } else if (h.from == kHumanSeat) {
            dealIns++;
          }
        }
        game.continueFromRoundEnd();
        continue;
      }
      final round = game.round;
      if (!guide && !round.finished) {
        if (round.awaitingVoidSuit && !round.hasDeclaredVoidSuit(kHumanSeat)) {
          game.humanDeclareVoidSuit(round.suggestVoidSuit(kHumanSeat));
          continue;
        }
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
    row = _Row(seed, place, pts[0],
        hands: hands,
        wins: wins,
        tsumo: tsumo,
        value: value,
        dealIns: dealIns);
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
