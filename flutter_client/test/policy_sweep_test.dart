// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

import 'folding_bot.dart';

/// Sweeps every (PlayStyle, HandFocus) setting against the same seeds and
/// ranks them, so a tuning question is answered in one run instead of nine.
///
/// Both dials are plain fields on [GameController], so nothing in the engine
/// has to be touched to move them — which makes this the cheapest experiment
/// available and the right place to start before editing a constant.
///
/// Every arm plays the identical seeds (common random numbers), so the arms
/// are compared pairwise rather than each against its own noise. That is worth
/// roughly a 3-4x cut in the games needed to separate two settings.
///
///   SWEEP_GAMES=200 flutter test test/policy_sweep_test.dart
///   SWEEP_GAMES=200 SWEEP_EAST=1 SIM_FOLD=1 flutter test test/policy_sweep_test.dart
void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['SWEEP_GAMES'] ?? '') ?? 0;

  test('policy sweep', () async {
    final shards = int.tryParse(env['SWEEP_SHARDS'] ?? '') ?? 10;
    final base = int.tryParse(env['SWEEP_SEED'] ?? '') ?? 1000;
    final fold = env['SIM_FOLD'] == '1';
    // East-only games run in half the time and rank settings the same way;
    // confirm the winner over hanchan before believing a small gap.
    final east = env['SWEEP_EAST'] == '1';
    final sw = Stopwatch()..start();
    print('Opponents: ${fold ? 'FoldingBot' : 'SimpleBot (never fold)'}, '
        '${east ? 'East-only' : 'hanchan'}, $games games/arm');

    final arms = <(String, List<_Row>)>[];
    // The control arm is SimpleBot playing seat 0 through the human API: it
    // measures the seat itself, so every guide arm is reported net of it.
    for (final cfg in _configs) {
      arms.add((
        cfg.$1,
        await _runArm(base, games, shards, cfg.$2, cfg.$3, fold, east),
      ));
    }
    print('Ran ${arms.length * games} games in ${sw.elapsed.inSeconds}s\n');
    _report(arms);
  }, skip: games == 0 ? 'set SWEEP_GAMES to run' : false, timeout: Timeout.none);
}

/// (label, style, focus) — a null style means the SimpleBot control arm.
final _configs = <(String, PlayStyle?, HandFocus)>[
  ('control (SimpleBot)', null, HandFocus.balanced),
  for (final s in PlayStyle.values)
    for (final f in HandFocus.values) ('${s.label}/${f.label}', s, f),
];

class _Row {
  _Row(this.place, this.points, this.hands, this.wins, this.dealIns,
      this.riichi);
  final double place;
  final int points;
  final int hands;
  final int wins;
  final int dealIns;
  final int riichi;
}

Future<List<_Row>> _runArm(int base, int games, int shards, PlayStyle? style,
    HandFocus focus, bool fold, bool east) async {
  final parts = await Future.wait([
    for (var s = 0; s < shards; s++)
      Isolate.run(() =>
          _shard(base, games, s, shards, style, focus, fold, east)),
  ]);
  return [for (final p in parts) ...p];
}

List<_Row> _shard(int base, int games, int shard, int shards, PlayStyle? style,
    HandFocus focus, bool fold, bool east) {
  Sfx.i.enabled = false;
  return [
    for (var g = shard; g < games; g += shards)
      _playGame(base + g, style, focus, fold, east),
  ];
}

_Row _playGame(
    int seed, PlayStyle? style, HandFocus focus, bool fold, bool east) {
  late _Row row;
  fakeAsync((fa) {
    final game = GameController(
        seed: seed, botFactory: fold ? FoldingBot.new : SimpleBot.new);
    game.hanchan = !east;
    if (style != null) {
      game.setAutoplay(true);
      game.playStyle = style;
      game.handFocus = focus;
    }
    final seat0Bot =
        fold ? FoldingBot(seed * 31 + 3) : SimpleBot(seed * 31 + 3);
    var hands = 0, wins = 0, dealIns = 0, riichi = 0;

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        final r = game.round.result!;
        hands++;
        if (r.winners.contains(kHumanSeat)) wins++;
        if (r.loser == kHumanSeat) dealIns++;
        if (game.round.seats[kHumanSeat].riichi) riichi++;
        game.continueFromRoundEnd();
        continue;
      }
      if (style == null && !game.round.finished) {
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
    final pts = game.tablePoints;
    var place = 1.0;
    for (var i = 1; i < 4; i++) {
      if (pts[i] > pts[0]) place += 1;
      if (pts[i] == pts[0]) place += 0.5;
    }
    row = _Row(place, pts[0], hands, wins, dealIns, riichi);
    game.dispose();
  });
  return row;
}

// --- statistics -------------------------------------------------------------

double _mean(List<double> xs) => xs.fold<double>(0, (a, b) => a + b) / xs.length;

({double mean, double se}) _ms(List<double> xs) {
  final m = _mean(xs);
  final v =
      xs.fold<double>(0, (a, b) => a + (b - m) * (b - m)) / (xs.length - 1);
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

double _p(double z) => _erfc(z.abs() / sqrt2);
String _pf(double p) => p < 1e-6 ? '<1e-6' : p.toStringAsExponential(1);
String _f(double x, [int d = 3]) => x.toStringAsFixed(d);

void _report(List<(String, List<_Row>)> arms) {
  final control = arms.first.$2;
  print('arm                    place ±95%      1st%   pts/game  win/hd  '
      'deal/hd  riichi/hd   Δplace vs control');
  final ranked = [...arms]
    ..sort((a, b) =>
        _mean([for (final r in a.$2) r.place]).compareTo(
            _mean([for (final r in b.$2) r.place])));
  for (final (label, rows) in ranked) {
    final places = [for (final r in rows) r.place];
    final s = _ms(places);
    final hands = rows.fold<int>(0, (a, r) => a + r.hands);
    final firsts = places.where((p) => p == 1).length / rows.length;
    String delta = '';
    if (!identical(rows, control)) {
      final d = _ms([
        for (var i = 0; i < rows.length; i++) rows[i].place - control[i].place
      ]);
      final z = d.mean / d.se;
      delta = '${_f(d.mean, 3).padLeft(7)} ± ${_f(1.96 * d.se, 3)}  '
          'p=${_pf(_p(z))}';
    }
    print('${label.padRight(22)}'
        '${_f(s.mean).padLeft(6)} ±${_f(1.96 * s.se)}'
        '${_f(100 * firsts, 1).padLeft(7)}'
        '${(rows.fold<int>(0, (a, r) => a + r.points) / rows.length).round().toString().padLeft(11)}'
        '${_f(rows.fold<int>(0, (a, r) => a + r.wins) / hands).padLeft(8)}'
        '${_f(rows.fold<int>(0, (a, r) => a + r.dealIns) / hands).padLeft(9)}'
        '${_f(rows.fold<int>(0, (a, r) => a + r.riichi) / hands).padLeft(11)}'
        '   $delta');
  }
}
