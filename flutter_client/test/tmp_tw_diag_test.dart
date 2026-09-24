// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';

/// Temporary: seat-0 decision counters under Taiwanese rules, guide vs
/// SimpleBot, to explain the guide's low win rate.
///   TW_DIAG=200 flutter test test/tmp_tw_diag_test.dart
void main() {
  final n = int.tryParse(Platform.environment['TW_DIAG'] ?? '') ?? 0;
  final ruleset =
      Ruleset.values.byName(Platform.environment['SIM_RULESET'] ?? 'taiwanese');
  test('taiwanese diag', () async {
    for (final guide in [true, false]) {
      final parts = await Future.wait([
        for (var s = 0; s < 8; s++)
          Isolate.run(() => _shard(n, s, guide, ruleset)),
      ]);
      final m = <String, int>{};
      for (final p in parts) {
        p.forEach((k, v) => m[k] = (m[k] ?? 0) + v);
      }
      print('\n[${guide ? 'GUIDE' : 'CONTROL'}]');
      for (final k in m.keys.toList()..sort()) {
        print('  ${k.padRight(28)} ${m[k]}');
      }
    }
  }, skip: n == 0, timeout: Timeout.none);
}

Map<String, int> _shard(int n, int shard, bool guide, Ruleset ruleset) {
  Sfx.i.enabled = false;
  final c = <String, int>{};
  void inc(String k, [int v = 1]) => c[k] = (c[k] ?? 0) + v;
  for (var g = shard; g < n; g += 8) {
    fakeAsync((fa) {
      final game = GameController(seed: 1000 + g, ruleset: ruleset);
      if (guide) game.setAutoplay(true);
      final bot = SimpleBot((1000 + g) * 31 + 3);
      Round? seenOffer;
      Round? seenTsumo;
      for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
        if (guard > 100000) throw StateError('stuck');
        final round = game.round;
        if (game.phase == GamePhase.roundEnd) {
          final r = round.result!;
          final me = round.seats[kHumanSeat];
          inc('hands');
          inc('melds_at_end', me.melds.where((m) => !m.concealed).length);
          if (r.winners.contains(kHumanSeat)) {
            inc('win_${r.kind.name}');
            inc('win_points', r.scores.first.points);
          }
          if (r.loser == kHumanSeat) inc('dealt_in');
          if (r.kind == RoundEndKind.exhaustiveDraw) {
            inc('draws');
            if (r.tenpaiAtDraw.contains(kHumanSeat)) inc('ready_at_draw');
          }
          game.continueFromRoundEnd();
          continue;
        }
        if (round.phase == RoundPhase.callOffer &&
            !identical(seenOffer, round) ) {
          final opt = round.callOptions
              .where((o) => o.seat == kHumanSeat)
              .firstOrNull;
          if (opt != null) {
            for (final t in opt.types) {
              inc('offer_${t.name}');
            }
          }
        }
        if (round.phase == RoundPhase.discarding &&
            round.turn == kHumanSeat &&
            round.canTsumo(kHumanSeat) &&
            !identical(seenTsumo, round)) {
          inc('tsumo_available');
          seenTsumo = round;
        }
        final meldsBefore = round.seats[kHumanSeat].melds.length;
        if (!guide && !round.finished) {
          if (game.awaitingHumanCall) {
            game.answerCall(bot.decideCall(round, kHumanSeat,
                round.pendingDiscard!, game.humanCallOption!.types));
            if (round.seats[kHumanSeat].melds.length > meldsBefore) {
              inc('called');
            }
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
        if (game.round == round &&
            round.seats[kHumanSeat].melds.length > meldsBefore) {
          inc('called');
        }
      }
      game.dispose();
    });
  }
  return c;
}
