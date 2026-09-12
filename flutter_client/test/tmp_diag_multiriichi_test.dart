// ignore_for_file: avoid_print, depend_on_referenced_packages
// TEMPORARY — how much more dangerous is a second live riichi? The engine
// prices danger against the first riichi opponent only. Delete.
import 'dart:io';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/bot.dart';

import 'folding_bot.dart';

void main() {
  final n = int.tryParse(Platform.environment['SIM_MR'] ?? '') ?? 0;
  test('multi-riichi hazard', () async {
    final parts = await Future.wait([
      for (var s = 0; s < 5; s++) Isolate.run(() => _shard(n, s)),
    ]);
    final m = <String, int>{};
    for (final p in parts) {
      p.forEach((k, v) => m[k] = (m[k] ?? 0) + v);
    }
    final keys = m.keys.toList()..sort();
    for (final k in keys) {
      print('  ${k.padRight(26)} ${m[k]}');
    }
    double rate(String a, String b) => (m[b] ?? 0) == 0 ? 0 : m[a]! / m[b]!;
    print('\nPer-discard deal-in rate:');
    print('  against 1 live riichi   ${rate('dealin_vs1', 'disc_vs1').toStringAsFixed(4)}');
    print('  against 2+ live riichi  ${rate('dealin_vs2', 'disc_vs2').toStringAsFixed(4)}');
    final r1 = rate('dealin_vs1', 'disc_vs1');
    final r2 = rate('dealin_vs2', 'disc_vs2');
    print('  hazard multiplier       ${(r1 == 0 ? 0 : r2 / r1).toStringAsFixed(2)}x');
    print('  hands with 2+ riichi    '
        '${(100 * rate('hands_2plus', 'hands')).toStringAsFixed(1)}% of all hands, '
        '${(100 * rate('hands_2plus', 'hands_riichi')).toStringAsFixed(1)}% of hands with any riichi');
  }, skip: n == 0 ? 'set SIM_MR to run' : false, timeout: Timeout.none);
}

Map<String, int> _shard(int games, int shard) {
  Sfx.i.enabled = false;
  final c = <String, int>{};
  void inc(String k) => c[k] = (c[k] ?? 0) + 1;
  for (var g = shard; g < games; g += 5) {
    _game(7000 + g, inc);
  }
  return c;
}

void _game(int seed, void Function(String) inc) {
  fakeAsync((fa) {
    final game = GameController(seed: seed, botFactory: FoldingBot.new);
    final bot = FoldingBot(seed * 17 + 2);
    // How many opponents were in riichi when each seat last discarded.
    var lastCtx = List<int>.filled(4, 0);

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('stuck $seed');
      final round = game.round;

      if (game.phase == GamePhase.roundEnd) {
        final r = round.result!;
        inc('hands');
        final riichiSeats = round.seats.where((s) => s.riichi).length;
        if (riichiSeats >= 1) inc('hands_riichi');
        if (riichiSeats >= 2) inc('hands_2plus');
        final loser = r.loser;
        if (loser != null && lastCtx[loser] > 0) {
          inc(lastCtx[loser] >= 2 ? 'dealin_vs2' : 'dealin_vs1');
        }
        lastCtx = List<int>.filled(4, 0);
        game.continueFromRoundEnd();
        continue;
      }

      final pondLens = [for (final s in round.seats) s.pond.length];
      final liveRiichi = [
        for (final s in round.seats)
          if (s.riichi) s.seat,
      ];

      if (game.awaitingHumanCall) {
        game.answerCall(bot.decideCall(round, kHumanSeat,
            round.pendingDiscard!, game.humanCallOption!.types));
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

      for (final s in game.round.seats) {
        if (s.pond.length > pondLens[s.seat]) {
          final against = liveRiichi.where((r) => r != s.seat).length;
          lastCtx[s.seat] = against;
          if (against >= 2) {
            inc('disc_vs2');
          } else if (against == 1) {
            inc('disc_vs1');
          }
        }
      }
    }
    game.dispose();
  });
}
