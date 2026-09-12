// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/bot.dart';

import 'folding_bot.dart';
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
  // SIM_FOLD=1 puts opponents in that get out of the way of a riichi. The
  // stock bots never do, which flatters aggression: a riichi wins 66% of the
  // time against them and 45% once they defend.
  final fold = Platform.environment['SIM_FOLD'] == '1';
  test('guide decision diagnostics', () async {
    print(fold ? 'Opponents: FoldingBot' : 'Opponents: SimpleBot (never fold)');
    for (final guide in [true, false]) {
      final parts = await _arm(n, guide, fold);
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

Future<List<Map<String, int>>> _arm(int n, bool guide, bool fold) async {
  final parts = await Future.wait([
    for (var s = 0; s < 5; s++) Isolate.run(() => _shard(n, s, guide, fold)),
  ]);
  for (final p in parts) {
    p.$2.forEach(print);
  }
  return [for (final p in parts) p.$1];
}

(Map<String, int>, List<String>) _shard(
    int n, int shard, bool guide, bool fold) {
  Sfx.i.enabled = false;
  final c = <String, int>{};
  void inc(String k, [int n = 1]) => c[k] = (c[k] ?? 0) + n;
  for (var g = shard; g < n; g += 5) {
    _game(1000 + g, guide, fold, inc);
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

void _game(
    int seed, bool guide, bool fold, void Function(String, [int]) inc) {
  fakeAsync((fa) {
    final game = GameController(
        seed: seed, botFactory: fold ? FoldingBot.new : SimpleBot.new);
    if (guide) game.setAutoplay(true);
    final bot = fold ? FoldingBot(seed * 31 + 3) : SimpleBot(seed * 31 + 3);
    inc('games');
    // The riichi gap splits two ways — never reached tenpai, or reached it and
    // stayed quiet — and those are different problems with different fixes.
    var reachedTenpai = false;
    // First turn this hand got to each shanten level, and the acceptance it
    // was holding along the way — both per hand, so a slow hand cannot pad
    // the averages simply by staying in the pre-tenpai pool longer.
    final firstAt = <int, int>{};
    var handUkSum = 0;
    var handUkN = 0;
    // (state key, model win probability x1000, turn) per discard, resolved
    // against what the hand actually went on to do.
    final states = <(String, int, int)>[];

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
        if (reachedTenpai) inc('hands_reached_tenpai');
        if (round.seats[0].riichi) inc('hands_riichi');
        if (round.seats[0].melds.isNotEmpty) inc('hands_open');
        final tenpaiTurn = firstAt[0];
        final wonHand = r.winners.contains(0);
        for (final e in states) {
          inc('${e.$1}_n');
          inc('${e.$1}_psum', e.$2);
          if (tenpaiTurn != null && tenpaiTurn >= e.$3) inc('${e.$1}_tenpai');
          if (wonHand) inc('${e.$1}_win');
        }
        states.clear();
        if (firstAt.isNotEmpty) inc('hands_traced');
        firstAt.forEach((lvl, turn) {
          inc('reach${lvl}_n');
          inc('reach${lvl}_sum', turn);
        });
        if (handUkN > 0) {
          final tag = reachedTenpai ? 'conv' : 'noconv';
          inc('uk_${tag}_n', handUkN);
          inc('uk_${tag}_sum', handUkSum);
          inc('hands_$tag');
        }
        firstAt.clear();
        handUkSum = 0;
        handUkN = 0;
        reachedTenpai = false;
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
        if (report.lines.isNotEmpty) {
          for (var lvl = 0; lvl <= 4; lvl++) {
            if (report.currentShanten <= lvl && !firstAt.containsKey(lvl)) {
              firstAt[lvl] = pondLen;
            }
          }
          // The very first discard of the hand: the deal plus one decision,
          // before folding or anyone's riichi can be blamed for anything.
          if (pondLen == 0) {
            inc('open_n');
            inc('open_sum', report.currentShanten);
          }

          // Efficiency, measured properly. Raw ukeire cannot be compared
          // across lines at different shanten: a discard that steps BACKWARD
          // accepts more tiles precisely because it is further from home, so
          // comparing counts alone scores every backward step as free.
          final pickType = s0.pond.last.type;
          DiscardLine? pick;
          DiscardLine? fastest;
          for (final l in report.lines) {
            if (l.discard == pickType) pick = l;
            if (l.bestUkeire) fastest = l;
          }
          if (pick != null) {
            inc('disc_all');
            inc('ukn_s${pick.shanten}');
            inc('uksum_s${pick.shanten}', pick.ukeire);
            if (pick.shanten > report.currentShanten) {
              inc('back_all');
              inc(defending ? 'back_defending' : 'back_calm');
              inc('back_from_sh${report.currentShanten}');
            } else if (fastest != null && pick.ukeire < fastest.ukeire) {
              inc('narrow_all');
              inc(defending ? 'narrow_defending' : 'narrow_calm');
            }
            inc('from_sh${report.currentShanten}');
            // The state this discard leaves the hand in, to be scored later
            // against what the hand actually achieved from here.
            if (pick.shanten <= 3) {
              final uk = pick.ukeire;
              final b = uk <= 10
                  ? 'a'
                  : uk <= 20
                      ? 'b'
                      : uk <= 30
                          ? 'c'
                          : uk <= 45
                              ? 'd'
                              : 'e';
              states.add((
                'st${pick.shanten}_uk$b',
                (pick.winProbability * 1000).round(),
                pondLen,
              ));
            }
          }
        }
        // How much speed the choice gave up: the discard actually made against
        // the widest-acceptance one the very same report offered. Pre-tenpai
        // only, where "fastest" is well defined.
        if (report.currentShanten > 0 && report.lines.isNotEmpty) {
          final chosenType = s0.pond.last.type;
          DiscardLine? chosen;
          DiscardLine? widest;
          for (final l in report.lines) {
            if (l.discard == chosenType) chosen = l;
            if (l.bestUkeire) widest = l;
          }
          if (chosen != null && widest != null) {
            inc('pre_tenpai_discards');
            // Absolute speed, not speed relative to this hand's own options: a
            // player can pick the widest line available every single turn and
            // still be on a slower hand than the seat across the table.
            final t = pondLen < 3
                ? 't1_3'
                : pondLen < 6
                    ? 't4_6'
                    : pondLen < 9
                        ? 't7_9'
                        : 't10plus';
            inc('shn_$t');
            inc('shsum_$t', report.currentShanten);
            inc('uk_n');
            inc('uk_sum', chosen.ukeire);
            handUkSum += chosen.ukeire;
            handUkN++;
            final gap = widest.ukeire - chosen.ukeire;
            if (gap > 0) {
              inc('gave_up_ukeire');
              inc(defending ? 'gave_up_defending' : 'gave_up_calm');
              if (gap <= 3) {
                inc('ukeire_gap_1_3');
              } else if (gap <= 7) {
                inc('ukeire_gap_4_7');
              } else {
                inc('ukeire_gap_8plus');
              }
            }
          }
        }
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
        if (s0.riichi ||
            waitTiles(s0.hand, openMelds: s0.melds.length).isNotEmpty) {
          reachedTenpai = true;
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
