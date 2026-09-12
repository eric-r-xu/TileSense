// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/bot.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/hand_parse.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/scoring.dart';
import 'package:tilesense/logic/tile.dart';

/// Decision-level counters for seat 0, guide vs SimpleBot, to explain the
/// outcome gap measured by guide_vs_bots_sim_test.dart.
///   SIM_DIAG=300 flutter test test/guide_diag_sim_test.dart
void main() {
  final n = int.tryParse(Platform.environment['SIM_DIAG'] ?? '') ?? 0;
  test('guide decision diagnostics', () async {
    for (final guide in [true, false]) {
      final parts = await _arm(n, guide);
      final m = <String, int>{};
      for (final p in parts) {
        p.forEach((k, v) => m[k] = (m[k] ?? 0) + v);
      }
      print('\n[${guide ? 'GUIDE' : 'CONTROL'}]');
      final keys = m.keys.toList()..sort();
      for (final k in keys) {
        print('  ${k.padRight(22)} ${m[k]}');
      }
    }
  }, skip: n == 0 ? 'set SIM_DIAG to run' : false, timeout: Timeout.none);
}

Future<List<Map<String, int>>> _arm(int n, bool guide) async {
  final parts = await Future.wait([
    for (var s = 0; s < 5; s++) Isolate.run(() => _shard(n, s, guide)),
  ]);
  for (final p in parts) {
    p.$2.forEach(print);
  }
  return [for (final p in parts) p.$1];
}

(Map<String, int>, List<String>) _shard(int n, int shard, bool guide) {
  Sfx.i.enabled = false;
  final c = <String, int>{};
  void inc(String k) => c[k] = (c[k] ?? 0) + 1;
  for (var g = shard; g < n; g += 5) {
    _game(1000 + g, guide, inc);
  }
  return (c, examples);
}

bool _damaHasRonYaku(Round round, SeatState s) {
  for (final w in waitTiles(s.hand, openMelds: s.melds.length)) {
    final ctx = ScoreContext(
      roundWind: round.roundWind,
      seatWind: s.wind,
      isTsumo: false,
      closed: s.closed,
      doraIndicators: round.wall.doraIndicators(),
    );
    if (scoreHand(s.hand, Tile(-1, w), s.melds, ctx, isDealer: s.isDealer)
        .valid) {
      return true;
    }
  }
  return false;
}

final examples = <String>[];

void _game(int seed, bool guide, void Function(String) inc) {
  fakeAsync((fa) {
    final game = GameController(seed: seed);
    if (guide) game.setAutoplay(true);
    final bot = SimpleBot(seed * 31 + 3);
    inc('games');

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('stuck $seed');
      final round = game.round;
      if (game.phase == GamePhase.roundEnd) {
        final r = round.result!;
        inc('hands');
        if (r.kind == RoundEndKind.exhaustiveDraw) {
          inc('draws');
          if (r.tenpaiAtDraw.contains(0)) inc('draws_s0_tenpai');
        }
        if (r.winners.contains(0)) inc('win_${r.kind.name}');
        if (r.loser == 0) inc('dealt_in');
        game.continueFromRoundEnd();
        continue;
      }

      final s0 = round.seats[0];
      final myTurn = !round.finished &&
          round.turn == 0 &&
          round.phase == RoundPhase.discarding &&
          (guide || game.isHumanTurn);
      final offer = !round.finished && round.phase == RoundPhase.callOffer
          ? round.callOptions.where((o) => o.seat == 0).firstOrNull
          : null;
      final observeOffer = offer != null && (guide || game.awaitingHumanCall);
      final wasRiichi = s0.riichi;
      final canRiichi = myTurn && round.canRiichi(0);
      final defending = myTurn && game.report.defending;
      final report = game.report;
      final handBefore = [for (final t in s0.hand) t.type.name].join(' ');
      final wall = round.wall.remaining;
      final pondLen = s0.pond.length;
      final meldLen = s0.melds.length;

      // Step: the guide acts via the timer; the control seat via the bot.
      if (!guide && game.awaitingHumanCall) {
        game.answerCall(bot.decideCall(round, 0, round.pendingDiscard!,
            game.humanCallOption!.types));
      } else if (!guide && game.isHumanTurn) {
        final d = bot.decideTurn(round, 0);
        if (d.tsumo) {
          game.humanTsumo();
        } else if (d.closedKan != null) {
          game.humanClosedKan(d.closedKan!);
        } else if (d.addedKan != null) {
          game.humanAddKan(d.addedKan!);
        } else {
          game.humanDiscard(d.discard ?? round.legalDiscards(0).first,
              declareRiichi: d.riichi);
        }
      } else {
        fa.elapse(const Duration(milliseconds: 960));
      }

      if (myTurn && !wasRiichi && s0.pond.length > pondLen) {
        inc('turns_free');
        if (defending) inc('turns_defending');
        if (canRiichi) {
          inc('riichi_available');
          if (s0.riichi) inc('riichi_taken');
          final stillTenpai =
              waitTiles(s0.hand, openMelds: s0.melds.length).isNotEmpty;
          if (!stillTenpai) {
            inc(defending
                ? 'riichi_avail_broke_tenpai_defending'
                : 'riichi_avail_broke_tenpai_calm');
            if (guide && !defending && examples.length < 4) {
              String fmt(DiscardLine l) => '    cut ${l.discard.name.padRight(6)}'
                  ' sh=${l.shanten} ev=${l.expectedValue.round()}'
                  ' pts=${l.averagePoints.round()}'
                  ' winP=${l.winProbability.toStringAsFixed(2)}'
                  ' riichi=${l.recommendRiichi}'
                  ' lock=${l.riichiLockCost.round()}'
                  ' commit=${l.commitmentCost.round()}'
                  ' plan=${l.valuePlan}';
              examples.add([
                '  seed $seed wall=$wall dealer=${s0.isDealer} '
                    'hand: $handBefore',
                ...report.lines.take(3).map(fmt),
                ...report.lines
                    .skip(3)
                    .where((l) => l.shanten == 0)
                    .take(1)
                    .map(fmt),
              ].join('\n'));
            }
          }
        }
        if (!s0.riichi &&
            waitTiles(s0.hand, openMelds: s0.melds.length).isNotEmpty) {
          inc('dama_tenpai_turns');
          if (!_damaHasRonYaku(round, s0)) inc('dama_tenpai_no_ron_yaku');
        }
      }
      if (observeOffer) {
        if (offer.types.contains(CallType.ron)) {
          inc('ron_offered');
          if (round.result?.winners.contains(0) ?? false) inc('ron_taken');
        }
        if (offer.types.any((t) => t != CallType.ron)) {
          inc('meld_offered');
          if (s0.melds.length > meldLen) inc('meld_taken');
        }
      }
    }
    game.dispose();
  });
}
