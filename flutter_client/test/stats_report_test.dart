// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/bot.dart';
import 'package:mahjong_core/hong_kong/hong_kong_rules.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/taiwanese/taiwanese_rules.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

/// Plays every variant, both game lengths and every decision maker the game
/// offers on the same fixed seed array (common random numbers), and appends
/// one CSV row per game to REPORT_OUT for `reports/sim_run.sh` to load into
/// PostgreSQL. Statistics are computed there, not here.
///
///   REPORT_OUT=games.csv REPORT_COMMIT=abc1234 \
///     flutter test test/stats_report_test.dart
///
/// REPORT_SKIP names a file of `arm_key,seed` lines already stored; those
/// games are not played again. The arm key matches `sim_arm.arm_key`.
///
/// Seat 0 is either SimpleBot (control) or the guide on Autoplay with a
/// (Style, Focus, Strategy) tuple; the other three seats are SimpleBot, as in
/// the shipped game. Hong Kong and Taiwanese pin Style to Balanced and
/// Strategy to Points, so only Focus varies there.
void main() {
  final env = Platform.environment;
  final out = env['REPORT_OUT'];
  final commit = env['REPORT_COMMIT'] ?? 'unknown';
  final base = int.tryParse(env['REPORT_SEED'] ?? '') ?? 500000;
  final n = int.tryParse(env['REPORT_GAMES'] ?? '') ?? 50;
  final seeds = [for (var i = 0; i < n; i++) base + i];
  final skipPath = env['REPORT_SKIP'];
  final skip = skipPath == null
      ? <String>{}
      : File(skipPath).readAsLinesSync().where((l) => l.isNotEmpty).toSet();

  test('stats report', () async {
    final variants = <(Ruleset, int)>[
      (Ruleset.riichi, 0),
      for (final m in HongKongRules.minimumFaanChoices) (Ruleset.hongKong, m),
      for (final m in TaiwaneseRules.minimumPointsChoices)
        (Ruleset.taiwanese, m),
    ];
    final file = File(out!)..writeAsStringSync('');
    final sw = Stopwatch()..start();
    var played = 0;
    for (final (ruleset, minimum) in variants) {
      for (final east in [true, false]) {
        for (final dm in _deciders(ruleset)) {
          final arm = [
            ruleset.name,
            minimum,
            east ? 'east' : 'hanchan',
            dm.style == null ? 'simple_bot' : 'guide',
            if (dm.style != null) ...[
              dm.style!.name,
              dm.focus.name,
              dm.strategy.name
            ],
          ];
          final key = [commit, ...arm].join('|');
          final todo = [
            for (final s in seeds)
              if (!skip.contains('$key,$s')) s
          ];
          final csv = StringBuffer();
          // At most 50 isolates at a time, as in the original 50-seed run.
          for (var i = 0; i < todo.length; i += 50) {
            final rows = await Future.wait([
              for (final s in todo.skip(i).take(50))
                Isolate.run(() => _playGame(s, ruleset, minimum, east, dm)),
            ]);
            for (var j = 0; j < rows.length; j++) {
              final r = rows[j];
              csv.writeln([
                commit,
                ruleset.name,
                minimum,
                east ? 'east' : 'hanchan',
                dm.style == null ? 'simple_bot' : 'guide',
                dm.style?.name ?? '',
                dm.style == null ? '' : dm.focus.name,
                dm.style == null ? '' : dm.strategy.name,
                todo[i + j],
                r.place,
                ruleset.startingPoints,
                r.points,
                r.hands,
                r.wins,
                r.dealIns,
              ].join(','));
            }
          }
          // Appended per arm so a crash keeps every finished arm.
          file.writeAsStringSync(csv.toString(), mode: FileMode.append);
          played += todo.length;
          print('${sw.elapsed.inSeconds}s  $key  played ${todo.length}, '
              'skipped ${seeds.length - todo.length}');
        }
      }
    }
    print('played $played games');
  }, skip: out == null ? 'set REPORT_OUT to run' : false,
      timeout: Timeout.none);
}

typedef _Decider = ({
  PlayStyle? style,
  HandFocus focus,
  Strategy strategy
});

/// SimpleBot, then every guide tuple the ruleset lets a player pick.
List<_Decider> _deciders(Ruleset ruleset) => [
      (
        style: null,
        focus: HandFocus.balanced,
        strategy: Strategy.points
      ),
      for (final s in ruleset.isChineseStyle
          ? [PlayStyle.balanced]
          : PlayStyle.values)
        for (final f in HandFocus.values)
          for (final t in ruleset.isChineseStyle
              ? [Strategy.points]
              : Strategy.values)
            (
              style: s,
              focus: f,
              strategy: t
            ),
    ];

typedef _Row = ({double place, int points, int hands, int wins, int dealIns});

_Row _playGame(
    int seed, Ruleset ruleset, int minimum, bool east, _Decider dm) {
  Sfx.i.enabled = false;
  late _Row row;
  fakeAsync((fa) {
    final game = GameController(
        seed: seed,
        ruleset: ruleset,
        hanchan: !east,
        minimumFaan: ruleset.isHongKong
            ? minimum
            : HongKongRules.defaultMinimumFaan,
        minimumPoints: ruleset == Ruleset.taiwanese
            ? minimum
            : TaiwaneseRules.defaultMinimumPoints);
    if (dm.style != null) {
      game.setAutoplay(true);
      game.playStyle = dm.style!;
      game.handFocus = dm.focus;
      game.strategy = dm.strategy;
    }
    final seat0Bot = SimpleBot(seed * 31 + 3);
    var hands = 0, wins = 0, dealIns = 0;

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 100000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        final r = game.round.result!;
        hands++;
        if (r.winners.contains(kHumanSeat)) wins++;
        if (r.loser == kHumanSeat) dealIns++;
        game.continueFromRoundEnd();
        continue;
      }
      if (dm.style == null && !game.round.finished) {
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
      fa.elapse(const Duration(milliseconds: 1104));
    }
    final pts = game.tablePoints;
    var place = 1.0;
    for (var i = 1; i < 4; i++) {
      if (pts[i] > pts[0]) place += 1;
      if (pts[i] == pts[0]) place += 0.5;
    }
    row = (
      place: place,
      points: pts[0],
      hands: hands,
      wins: wins,
      dealIns: dealIns
    );
    game.dispose();
  });
  return row;
}
