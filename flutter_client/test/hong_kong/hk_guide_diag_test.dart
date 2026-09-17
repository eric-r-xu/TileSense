// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:mahjong_core/bot.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:mahjong_core/round.dart';
import 'package:mahjong_core/ruleset.dart';

/// Decision-level counters for seat 0 under Hong Kong rules, the guide
/// (Aggressive / Speed) against SimpleBot on the same seeds — to explain the
/// placement gap `policy_sweep_test.dart` measures.
///
///   HK_DIAG=400 flutter test test/hong_kong/hk_guide_diag_test.dart
void main() {
  final n = int.tryParse(Platform.environment['HK_DIAG'] ?? '') ?? 0;
  test('Hong Kong guide diagnostics', () async {
    for (final guide in [true, false]) {
      final parts = await Future.wait([
        for (var s = 0; s < 10; s++) Isolate.run(() => _shard(n, s, guide)),
      ]);
      final m = <String, num>{};
      for (final p in parts) {
        p.forEach((k, v) => m[k] = (m[k] ?? 0) + v);
      }
      print('\n[${guide ? 'GUIDE Aggressive/Speed' : 'CONTROL SimpleBot'}]');
      final hands = m['hands']!;
      for (final k in m.keys.toList()..sort()) {
        final v = m[k]!;
        print('  ${k.padRight(26)} ${v.toString().padLeft(8)}'
            '   per hand ${(v / hands).toStringAsFixed(3)}');
      }
    }
  }, skip: n == 0 ? 'set HK_DIAG to run' : false, timeout: Timeout.none);
}

final _examples = <String>[];

Map<String, num> _shard(int n, int shard, bool guide) {
  Sfx.i.enabled = false;
  final c = <String, num>{};
  void inc(String k, [num v = 1]) => c[k] = (c[k] ?? 0) + v;
  for (var g = shard; g < n; g += 10) {
    _game(2000 + g, guide, inc);
  }
  if (shard == 0 && guide) _examples.forEach(print);
  return c;
}

void _game(int seed, bool guide, void Function(String, [num]) inc) {
  fakeAsync((fa) {
    final game = GameController(seed: seed, ruleset: Ruleset.hongKong)
      ..hanchan = false
      ..playStyle = PlayStyle.aggressive
      ..handFocus = HandFocus.speed;
    final bot = SimpleBot(seed * 31 + 3);
    var readyThisHand = false;
    var calledThisHand = false;

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        final r = game.round.result!;
        inc('hands');
        if (readyThisHand) inc('hands_reached_ready');
        if (calledThisHand) inc('hands_with_a_call');
        if (r.kind == RoundEndKind.exhaustiveDraw) inc('hands_drawn');
        final i = r.winners.indexOf(kHumanSeat);
        if (i >= 0) {
          inc('wins');
          if (calledThisHand) inc('wins_after_calling');
          if (r.kind == RoundEndKind.tsumo) inc('wins_self_pick');
          inc('win_faan_total', r.scores[i].faan);
          inc('win_chips_total', r.pointDeltas[kHumanSeat]!);
        } else if (r.winners.isNotEmpty) {
          inc('others_won');
          if (r.loser == kHumanSeat) {
            inc('deal_ins');
            inc('deal_in_chips', -r.pointDeltas[kHumanSeat]!);
          }
        }
        readyThisHand = false;
        calledThisHand = false;
        game.continueFromRoundEnd();
        continue;
      }
      final round = game.round;
      if (!round.finished && game.awaitingHumanCall) {
        final opt = game.humanCallOption!;
        final types = opt.types;
        CallType choice;
        if (guide) {
          choice = game.recommendedCall ?? CallType.none;
          final botChoice = bot.decideCall(
              round, kHumanSeat, round.pendingDiscard!, types);
          if (choice == CallType.none &&
              botChoice != CallType.none &&
              botChoice != CallType.ron) {
            inc('declined_bot_${botChoice.name}');
            if (game.report.defending) inc('declined_while_threatened');
            if (_examples.length < 24 && seed % 3 == 1) {
              _examples.add('DECLINE ${botChoice.name} of '
                  '${round.pendingDiscard!.type.code} '
                  'hand=${round.seats[kHumanSeat].hand.map((t) => t.type.code).join(' ')} '
                  'melds=${round.seats[kHumanSeat].melds.length} '
                  'threat=${game.safetyOpponentSeat != null}\n   '
                  '${game.recommendedCallReason}');
            }
          }
        } else {
          choice = bot.decideCall(
              round, kHumanSeat, round.pendingDiscard!, types);
        }
        for (final t in types) {
          inc('offer_${t.name}');
        }
        if (choice != CallType.none) inc('take_${choice.name}');
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
        if (report.currentShanten == 0) readyThisHand = true;
        if (game.humanCanTsumo) {
          game.humanTsumo();
          continue;
        }
        inc('discard_turns');
        if (report.defending) inc('turns_defending');
        if (guide) {
          final kan = game.kanAdvice;
          if (kan != null && kan.advice.eligible) {
            kan.isAdded
                ? game.humanAddKan(kan.type)
                : game.humanClosedKan(kan.type);
            continue;
          }
          final line = report.lines.firstWhere((l) => l.recommended,
              orElse: () => report.lines.first);
          if (line.shanten > report.currentShanten) {
            inc('backward_steps');
            if (report.defending) inc('backward_steps_defending');
            if (!report.defending && _examples.length < 12 && seed % 3 == 0) {
              final best = report.lines
                  .where((l) => l.shanten == report.currentShanten)
                  .reduce((a, b) => a.expectedValue >= b.expectedValue ? a : b);
              String f(DiscardLine l) => '${l.discard.code} sh${l.shanten} '
                  'uk${l.ukeire} p=${l.winProbability.toStringAsFixed(3)} '
                  'pts=${l.averagePoints.toStringAsFixed(1)} '
                  'ev=${l.expectedValue.toStringAsFixed(2)} ${l.valuePlan}';
              final seat = round.seats[kHumanSeat];
              _examples.add('hand=${seat.hand.map((t) => t.type.code).join(' ')} '
                  'melds=${seat.melds.map((m) => m.types.map((t) => t.code).join()).join('|')} '
                  'wall=${round.wall.remaining}\n   chose ${f(line)}\n   best  ${f(best)}');
            }
          }
          final tile = round.legalDiscards(kHumanSeat)
              .firstWhere((t) => t.type == line.discard);
          game.humanDiscard(tile);
        } else {
          final d = bot.decideTurn(round, kHumanSeat);
          if (d.closedKan != null) {
            game.humanClosedKan(d.closedKan!);
            continue;
          }
          if (d.addedKan != null) {
            game.humanAddKan(d.addedKan!);
            continue;
          }
          final tile = d.discard ?? round.legalDiscards(kHumanSeat).first;
          final line = report.lines.where((l) => l.discard == tile.type);
          if (line.isNotEmpty && line.first.shanten > report.currentShanten) {
            inc('backward_steps');
            if (report.defending) inc('backward_steps_defending');
          }
          game.humanDiscard(tile);
        }
        continue;
      }
      fa.elapse(const Duration(milliseconds: 1104));
    }
    game.dispose();
  });
}
