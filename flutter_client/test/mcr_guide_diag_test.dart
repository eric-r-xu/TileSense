// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/bot.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

/// Decision-level counters for seat 0 under MCR, the guide (on the dials an
/// MCR game gives it) against SimpleBot on the same seeds — to explain why
/// `minimum_reach_diag_test.dart` finds the guide winning a third as often
/// as the bot and reaching ready less than half as often. Modelled on
/// `hong_kong/hk_guide_diag_test.dart`.
///
///   MCR_DIAG=400 flutter test test/mcr_guide_diag_test.dart
///   MCR_DIAG_FLAGS=none MCR_DIAG=400 flutter test ...
///
/// `MCR_DIAG_FLAGS`, when set, replaces the shipped MCR flags for the guide
/// arm with exactly the ones it names: [HongKongGuideTuning.mcrNeverStepBack]
/// (`no-step-back`), [HongKongGuideTuning.mcrTakeShantenCalls]
/// (`shanten-calls`) and [HongKongGuideTuning.mcrCallsOnlyToReady]
/// (`ready-calls`); `MCR_DIAG_FLAGS=none` turns them all off.
final _flags = Platform.environment['MCR_DIAG_FLAGS']?.split(',').toSet();

void main() {
  final n = int.tryParse(Platform.environment['MCR_DIAG'] ?? '') ?? 0;
  final base = int.tryParse(Platform.environment['MCR_DIAG_SEED'] ?? '') ??
      610000;
  test('MCR guide diagnostics', () async {
    for (final guide in [true, false]) {
      final parts = await Future.wait([
        for (var s = 0; s < 8; s++)
          Isolate.run(() => _shard(base, n, s, guide)),
      ]);
      final m = <String, num>{};
      final examples = <String>[];
      for (final p in parts) {
        p.$1.forEach((k, v) => m[k] = (m[k] ?? 0) + v);
        examples.addAll(p.$2);
      }
      print('\n[${guide ? 'GUIDE' : 'CONTROL SimpleBot'}] $n East-only games, '
          'seeds $base+');
      final hands = m['hands']!;
      for (final k in m.keys.toList()..sort()) {
        final v = m[k]!;
        print('  ${k.padRight(44)} ${v.toString().padLeft(8)}'
            '   per hand ${(v / hands).toStringAsFixed(3)}');
      }
      if (guide) {
        print('\n  examples:');
        examples.take(30).forEach((e) => print('  $e'));
      }
    }
  }, skip: n == 0 ? 'set MCR_DIAG to run' : false, timeout: Timeout.none);
}

(Map<String, num>, List<String>) _shard(
    int base, int n, int shard, bool guide) {
  Sfx.i.enabled = false;
  if (_flags case final flags?) {
    HongKongGuideTuning.mcrNeverStepBack = flags.contains('no-step-back');
    HongKongGuideTuning.mcrTakeShantenCalls = flags.contains('shanten-calls');
    HongKongGuideTuning.mcrCallsOnlyToReady = flags.contains('ready-calls');
  }
  final c = <String, num>{};
  final examples = <String>[];
  void inc(String k, [num v = 1]) => c[k] = (c[k] ?? 0) + v;
  for (var g = shard; g < n; g += 8) {
    _game(base + g, guide, inc, examples);
  }
  return (c, examples);
}

String _line(DiscardLine l) => '${l.discard.code} sh${l.shanten} '
    'uk${l.ukeire} p=${l.winProbability.toStringAsFixed(3)} '
    'pts=${l.averagePoints.toStringAsFixed(1)} '
    'ev=${l.expectedValue.toStringAsFixed(2)} ${l.valuePlan}';

void _game(int seed, bool guide, void Function(String, [num]) inc,
    List<String> examples) {
  fakeAsync((fa) {
    final game =
        GameController(seed: seed, ruleset: Ruleset.mcr, hanchan: false);
    final bot = SimpleBot(seed * 31 + 3);
    var readyThisHand = false;
    var deadReadyThisHand = false;
    var calledThisHand = false;
    var ownDiscards = 0;

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        final r = game.round.result!;
        inc('hands');
        if (readyThisHand) inc('hands_reached_ready');
        if (deadReadyThisHand) inc('hands_ready_shape_under_8');
        if (calledThisHand) inc('hands_with_a_call');
        if (game.round.seats[kHumanSeat].melds.every((m) => m.concealed)) {
          inc('hands_ended_closed');
        }
        if (r.kind == RoundEndKind.exhaustiveDraw) inc('hands_drawn');
        final i = r.winners.indexOf(kHumanSeat);
        if (i >= 0) {
          inc('wins');
          if (calledThisHand) inc('wins_after_calling');
          if (r.kind == RoundEndKind.tsumo) inc('wins_self_draw');
          inc('win_fan_total', r.scores[i].points);
        } else if (r.winners.isNotEmpty && r.loser == kHumanSeat) {
          inc('deal_ins');
        }
        readyThisHand = deadReadyThisHand = calledThisHand = false;
        ownDiscards = 0;
        game.continueFromRoundEnd();
        continue;
      }
      final round = game.round;
      if (!round.finished && game.awaitingHumanCall) {
        final types = game.humanCallOption!.types;
        final botChoice =
            bot.decideCall(round, kHumanSeat, round.pendingDiscard!, types);
        final choice =
            guide ? game.recommendedCall ?? CallType.none : botChoice;
        for (final t in types) {
          inc('offer_${t.name}');
        }
        if (choice != CallType.none) inc('take_${choice.name}');
        if (guide &&
            choice == CallType.none &&
            botChoice != CallType.none &&
            botChoice != CallType.ron) {
          inc('declined_bot_${botChoice.name}');
          final reason = game.recommendedCallReason ?? '(none)';
          // Bucket by the reason's opening words, which name the gate.
          final bucket = reason
              .replaceAll(RegExp(r'[0-9.]+'), '#')
              .split(' ')
              .take(7)
              .join(' ');
          inc('declined_reason: $bucket');
          if (examples.length < 12 && seed % 4 == 0) {
            examples.add('DECLINE ${botChoice.name} of '
                '${round.pendingDiscard!.type.code} '
                'hand=${round.seats[kHumanSeat].hand.map((t) => t.type.code).join(' ')} '
                'melds=${round.seats[kHumanSeat].melds.length}\n     $reason');
          }
        }
        if (choice == CallType.pon ||
            choice == CallType.chi ||
            choice == CallType.kan) {
          calledThisHand = true;
        }
        game.answerCall(choice);
        continue;
      }
      if (!round.finished && game.isHumanTurn) {
        final report = game.report;
        if (game.humanCanTsumo) {
          game.humanTsumo();
          continue;
        }
        if (report.currentShanten == 0) readyThisHand = true;
        inc('discard_turns');
        inc('shanten_sum', report.currentShanten);
        if (ownDiscards == 6) inc('shanten_at_discard_6', report.currentShanten);
        if (ownDiscards == 12) {
          inc('shanten_at_discard_12', report.currentShanten);
          inc('reached_discard_12');
        }
        if (report.defending) inc('turns_defending');
        ownDiscards++;

        BotTurn? botTurn;
        if (guide) {
          final kan = game.kanAdvice;
          if (kan != null && kan.advice.eligible) {
            kan.isAdded
                ? game.humanAddKan(kan.type)
                : game.humanClosedKan(kan.type);
            continue;
          }
        } else {
          final d = botTurn = bot.decideTurn(round, kHumanSeat);
          if (d.closedKan != null) {
            game.humanClosedKan(d.closedKan!);
            continue;
          }
          if (d.addedKan != null) {
            game.humanAddKan(d.addedKan!);
            continue;
          }
        }
        final DiscardLine line;
        if (guide) {
          line = report.lines.firstWhere((l) => l.recommended,
              orElse: () => report.lines.first);
        } else {
          final d = botTurn!;
          final type = (d.discard ?? round.legalDiscards(kHumanSeat).first).type;
          line = report.lines.firstWhere((l) => l.discard == type,
              orElse: () => report.lines.first);
        }
        inc('plan: ${line.valuePlan}');
        // Speed: how the chosen line compares with the fastest one.
        final fastest = report.lines
            .where((l) => l.shanten == report.currentShanten)
            .fold<DiscardLine?>(null,
                (a, l) => a == null || l.ukeire > a.ukeire ? l : a);
        if (line.shanten > report.currentShanten) {
          inc('backward_steps');
          if (report.defending) inc('backward_steps_defending');
          if (guide && !report.defending && examples.length < 24 &&
              seed % 4 == 1 && fastest != null) {
            final seat = round.seats[kHumanSeat];
            examples.add('BACKWARD hand=${seat.hand.map((t) => t.type.code).join(' ')} '
                'melds=${seat.melds.length} wall=${round.wall.remaining}\n'
                '     chose ${_line(line)}\n     fast  ${_line(fastest)}');
          }
        } else if (fastest != null && line.ukeire < fastest.ukeire) {
          inc('narrower_than_fastest');
          inc('ukeire_given_up', fastest.ukeire - line.ukeire);
          if (guide && !report.defending && examples.length < 30 &&
              seed % 4 == 2) {
            final seat = round.seats[kHumanSeat];
            examples.add('NARROWER hand=${seat.hand.map((t) => t.type.code).join(' ')} '
                'melds=${seat.melds.length}\n'
                '     chose ${_line(line)}\n     fast  ${_line(fastest)}');
          }
        }
        game.humanDiscard(round
            .legalDiscards(kHumanSeat)
            .firstWhere((t) => t.type == line.discard));
        if (round.seats[kHumanSeat].hand.length % 3 == 1 &&
            round.waitsFor(kHumanSeat).isNotEmpty &&
            round.minimumShortfall(kHumanSeat) == MinimumShortfall.dead) {
          deadReadyThisHand = true;
        }
        continue;
      }
      fa.elapse(const Duration(milliseconds: 1104));
    }
    game.dispose();
  });
}
