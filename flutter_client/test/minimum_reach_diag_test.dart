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

/// How often seat 0 reaches a ready hand that cannot clear the table's
/// minimum — the "dead tenpai" the guide's pre-ready estimate cannot see
/// coming. Seat 0 is the guide on Autoplay, or SimpleBot for the control,
/// on the same seeds. Every time seat 0 holds a waiting hand it is checked
/// with [Round.minimumShortfall]:
///
/// - `ronOnly`: no wait clears the minimum off a discard, only self-drawn;
/// - `dead`: no wait clears it at all.
///
///   MIN_DIAG_GAMES=200 flutter test test/minimum_reach_diag_test.dart
///   MIN_DIAG_RULES=tw5,mcr MIN_DIAG_GAMES=400 flutter test ...
///
/// `MIN_DIAG_RULES` picks the tables (default `hk1,hk3,tw1,tw3,tw5,mcr`);
/// `MIN_DIAG_SEED` the first seed (default 600000, unused by the sweeps).
/// Games are East only.
void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['MIN_DIAG_GAMES'] ?? '') ?? 0;
  test('minimum-reach diagnostic', () async {
    final base = int.tryParse(env['MIN_DIAG_SEED'] ?? '') ?? 600000;
    final tables = (env['MIN_DIAG_RULES'] ?? 'hk1,hk3,tw1,tw3,tw5,mcr')
        .split(',')
        .map(_Table.parse)
        .toList();
    final sw = Stopwatch()..start();
    print('\n$games East-only games per arm, seeds $base..${base + games - 1}');
    print('table  arm      hands  win%   tenpai%  short-tenpai hands '
        '(% of tenpai hands)   ended short%   tenpai checks: ronOnly%  dead%');
    for (final table in tables) {
      for (final guide in [true, false]) {
        final parts = await Future.wait([
          for (var s = 0; s < 8; s++)
            Isolate.run(() => _shard(base, games, s, table, guide)),
        ]);
        final t = parts.reduce((a, b) => a + b);
        String pct(int n, int d) =>
            d == 0 ? '   -' : (100 * n / d).toStringAsFixed(1).padLeft(5);
        print('${table.name.padRight(5)}  ${(guide ? 'guide' : 'bot').padRight(7)}'
            '  ${'${t.hands}'.padLeft(5)}  ${pct(t.wins, t.hands)}'
            '  ${pct(t.tenpaiHands, t.hands)}'
            '    any ${pct(t.shortHands, t.tenpaiHands)}'
            '  ronOnly ${pct(t.ronOnlyHands, t.tenpaiHands)}'
            '  dead ${pct(t.deadHands, t.tenpaiHands)}'
            '   ${pct(t.endedShort, t.hands)}'
            '          ${pct(t.ronOnlyChecks, t.tenpaiChecks)}'
            '  ${pct(t.deadChecks, t.tenpaiChecks)}');
      }
    }
    print('done in ${sw.elapsed.inSeconds}s');
  },
      skip: games == 0 ? 'set MIN_DIAG_GAMES to run' : false,
      timeout: Timeout.none);
}

class _Table {
  const _Table(this.name, this.ruleset, this.minimum);
  final String name;
  final Ruleset ruleset;
  final int minimum;

  static _Table parse(String spec) {
    final s = spec.trim();
    if (s == 'mcr') return _Table(s, Ruleset.mcr, 8);
    final n = int.parse(s.substring(2));
    return switch (s.substring(0, 2)) {
      'hk' => _Table(s, Ruleset.hongKong, n),
      'tw' => _Table(s, Ruleset.taiwanese, n),
      _ => throw ArgumentError('unknown table $s (hkN, twN or mcr)'),
    };
  }
}

/// Counters for one arm at one table; hands are seat 0's.
class _Tally {
  int hands = 0, wins = 0, tenpaiHands = 0;
  int shortHands = 0, ronOnlyHands = 0, deadHands = 0;

  /// Hands seat 0 did not win that ended with it on a short ready hand.
  int endedShort = 0;
  int tenpaiChecks = 0, ronOnlyChecks = 0, deadChecks = 0;

  _Tally operator +(_Tally o) => _Tally()
    ..hands = hands + o.hands
    ..wins = wins + o.wins
    ..tenpaiHands = tenpaiHands + o.tenpaiHands
    ..shortHands = shortHands + o.shortHands
    ..ronOnlyHands = ronOnlyHands + o.ronOnlyHands
    ..deadHands = deadHands + o.deadHands
    ..endedShort = endedShort + o.endedShort
    ..tenpaiChecks = tenpaiChecks + o.tenpaiChecks
    ..ronOnlyChecks = ronOnlyChecks + o.ronOnlyChecks
    ..deadChecks = deadChecks + o.deadChecks;
}

_Tally _shard(int base, int games, int shard, _Table table, bool guide) {
  Sfx.i.enabled = false;
  final t = _Tally();
  for (var g = shard; g < games; g += 8) {
    _play(base + g, table, guide, t);
  }
  return t;
}

void _play(int seed, _Table table, bool guide, _Tally t) {
  fakeAsync((fa) {
    final game = GameController(
      seed: seed,
      ruleset: table.ruleset,
      hanchan: false,
      minimumFaan: table.ruleset.isHongKong ? table.minimum : 0,
      minimumPoints: table.ruleset.isTaiwanese ? table.minimum : 5,
    );
    if (guide) game.setAutoplay(true);
    final bot = SimpleBot(seed * 31 + 3);

    // Per-hand state for the hand in progress.
    Round? current;
    String? lastKey;
    var tenpai = false, ronOnly = false, dead = false;
    var lastShort = false;
    void closeHand(Round r) {
      t.hands++;
      final won = r.result?.winners.contains(kHumanSeat) ?? false;
      if (won) t.wins++;
      if (tenpai) t.tenpaiHands++;
      if (ronOnly || dead) t.shortHands++;
      if (ronOnly) t.ronOnlyHands++;
      if (dead) t.deadHands++;
      if (!won && lastShort) t.endedShort++;
    }

    void sample(Round r) {
      if (!identical(r, current)) {
        current = r;
        lastKey = null;
        tenpai = ronOnly = dead = lastShort = false;
      }
      if (r.finished) return;
      final s = r.seats[kHumanSeat];
      if (s.hand.length % 3 != 1) return;
      // One check per distinct waiting hand, however many ticks it lasts.
      final key = '${s.melds.length}:${(s.hand.map((x) => x.id).toList()..sort()).join(',')}';
      if (key == lastKey) return;
      lastKey = key;
      if (r.waitsFor(kHumanSeat).isEmpty) {
        lastShort = false;
        return;
      }
      tenpai = true;
      t.tenpaiChecks++;
      final shortfall = r.minimumShortfall(kHumanSeat);
      lastShort = shortfall != MinimumShortfall.none;
      if (shortfall == MinimumShortfall.ronOnly) {
        ronOnly = true;
        t.ronOnlyChecks++;
      } else if (shortfall == MinimumShortfall.dead) {
        dead = true;
        t.deadChecks++;
      }
    }

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        closeHand(game.round);
        current = null;
        game.continueFromRoundEnd();
        continue;
      }
      final round = game.round;
      sample(round);
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
    // The last hand ends the game without a round-end pause.
    if (current != null && current!.finished) closeHand(current!);
    game.dispose();
  });
}
