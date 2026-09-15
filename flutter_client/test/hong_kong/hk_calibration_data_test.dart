// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_calc.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/ruleset.dart';
import 'package:tilesense/logic/tile.dart';

/// Writes the data the Hong Kong [WinModel] is fitted to: one row per discard
/// the guide makes in seat 0, describing the hand it leaves, and whether that
/// hand went on to win.
///
///   HK_CALIB_GAMES=3000 HK_CALIB_OUT=/tmp/hk_calib.csv \
///     flutter test test/hong_kong/hk_calibration_data_test.dart
///
/// Columns: shanten, ukeire (drawn acceptance), pung, chow (call acceptance),
/// unseen (live tiles), draws (turns left), won (0/1). For a ready hand
/// ukeire is its live wait. Fit with `tools/fit_hk_win_model.py`.
void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['HK_CALIB_GAMES'] ?? '') ?? 0;
  test('Hong Kong calibration data', () async {
    final seed = int.tryParse(env['HK_CALIB_SEED'] ?? '') ?? 20000;
    final out = env['HK_CALIB_OUT'] ?? 'hk_calib.csv';
    final parts = await Future.wait([
      for (var s = 0; s < 10; s++)
        Isolate.run(() => _shard(seed, games, s)),
    ]);
    final rows = [for (final p in parts) ...p];
    File(out).writeAsStringSync(
        'shanten,ukeire,pung,chow,unseen,draws,won\n${rows.join('\n')}\n');
    print('wrote ${rows.length} rows to $out');
  }, skip: games == 0 ? 'set HK_CALIB_GAMES to run' : false,
      timeout: Timeout.none);
}

List<String> _shard(int base, int games, int shard) {
  Sfx.i.enabled = false;
  final rows = <String>[];
  for (var g = shard; g < games; g += 10) {
    _play(base + g, rows);
  }
  return rows;
}

void _play(int seed, List<String> rows) {
  fakeAsync((fa) {
    final game = GameController(seed: seed, ruleset: Ruleset.hongKong)
      ..hanchan = false
      ..playStyle = kDefaultPlayStyle
      ..handFocus = kDefaultHandFocus
      ..setAutoplay(true);
    final calc = TileEfficiencyCalculator();
    final pending = <String>[];

    for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
      if (guard > 200000) throw StateError('seed $seed never finished');
      if (game.phase == GamePhase.roundEnd) {
        final won = game.round.result!.winners.contains(kHumanSeat) ? 1 : 0;
        rows.addAll([for (final r in pending) '$r,$won']);
        pending.clear();
        game.continueFromRoundEnd();
        continue;
      }
      final round = game.round;
      final seat = round.seats[kHumanSeat];
      // Record the hand seat 0 is about to leave, the moment before autoplay
      // discards from it.
      if (!round.finished &&
          round.turn == kHumanSeat &&
          round.phase == RoundPhase.discarding &&
          !round.canTsumo(kHumanSeat) &&
          seat.hand.length % 3 == 2) {
        final report = game.report;
        final line = report.lines.where((l) => l.recommended).firstOrNull;
        if (line != null) {
          final after = List<Tile>.of(seat.hand);
          after.remove(after.firstWhere((t) => t.type == line.discard));
          final remaining = _remaining(round);
          final unseen = remaining.fold<int>(0, (a, b) => a + b);
          final draws = (round.wall.remaining + 3) ~/ 4;
          final calls = line.shanten >= 1
              ? calc.callAcceptance(toTrainerCounts(after), remaining)
              : (pung: 0, chow: 0);
          pending.add('${line.shanten},${line.ukeire},${calls.pung},'
              '${calls.chow},$unseen,$draws');
        }
      }
      fa.elapse(const Duration(milliseconds: 960));
    }
    game.dispose();
  });
}

/// Live copies of every tile type from seat 0's point of view, as the guide
/// counts them: four of each less everything in ponds, melds and its own hand.
List<int> _remaining(Round round) {
  final seen = List<int>.filled(34, 0);
  for (final s in round.seats) {
    for (final t in s.pond) {
      seen[t.type.index - 1]++;
    }
    for (final m in s.melds) {
      for (final t in m.types) {
        seen[t.index - 1]++;
      }
    }
  }
  for (final t in round.seats[kHumanSeat].hand) {
    if (t.type.isPlayingTile) seen[t.type.index - 1]++;
  }
  return trainerCountsFromTypeCounts(
      [for (var i = 0; i < 34; i++) (4 - seen[i]).clamp(0, 4)]);
}
