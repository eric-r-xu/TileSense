// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/round.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/guide_host.dart';
import 'package:tilesense/game/mortal_advisor.dart';
import 'package:tilesense/game/sfx.dart';

/// Fixed-size paired riichi hanchan evaluation against three Saeko opponents.
/// RIICHI_COMPARE_GAMES pairs; RIICHI_COMPARE_SHARDS sidecar pairs, with stock
/// and fine-tuned models on RIICHI_COMPARE_PORT + 2*shard and +1 respectively.
/// Each shard saves completed games to RIICHI_COMPARE_OUT.SHARD.csv.
/// RIICHI_COMPARE_DECISIONS=1 also asks both models on each seat-0 position
/// and saves their replies and identical visible inputs for scenario analysis.
void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['RIICHI_COMPARE_GAMES'] ?? '') ?? 0;
  test('paired Nagomi vs Saeko riichi hanchan', () async {
    final shards = int.parse(env['RIICHI_COMPARE_SHARDS'] ?? '4');
    final base = int.parse(env['RIICHI_COMPARE_SEED'] ?? '200000');
    final port = int.parse(env['RIICHI_COMPARE_PORT'] ?? '18900');
    final out = env['RIICHI_COMPARE_OUT']!;
    if (games <= 0 || shards <= 0) {
      throw ArgumentError('positive sizes required');
    }
    await Future.wait([
      for (var shard = 0; shard < shards; shard++)
        Isolate.run(() => _runShard(base, games, shards, shard, port, out)),
    ]);
  },
      skip: games == 0 ? 'set RIICHI_COMPARE_GAMES to run' : false,
      timeout: Timeout.none);
}

void _runShard(
    int base, int games, int shards, int shard, int port, String out) {
  Sfx.i.enabled = false;
  final file = File('$out.$shard.csv').openSync(mode: FileMode.write);
  final decisions = Platform.environment['RIICHI_COMPARE_DECISIONS'] == '1'
      ? File('$out.decisions.$shard.jsonl').openSync(mode: FileMode.write)
      : null;
  file.writeStringSync('seed,model,dealer,hands,wins,deal_ins,points,place,'
      'pts0,pts1,pts2,pts3,requests,failures,fallbacks,ms\n');
  try {
    for (var i = shard; i < games; i += shards) {
      final compared = <String, Map<String, Object?>>{};
      // Balance execution order independently of the starting dealer.
      final models =
          (i ~/ 4).isEven ? ['nagomi', 'saeko'] : ['saeko', 'nagomi'];
      for (final model in models) {
        final row = _play(
            base + i, i % 4, model, port + 2 * shard, decisions, compared);
        file.writeStringSync('$row\n');
        file.flushSync();
        print(row);
      }
    }
  } finally {
    file.closeSync();
    decisions?.closeSync();
  }
}

String _play(int seed, int dealer, String model, int stockPort,
    RandomAccessFile? decisions, Map<String, Map<String, Object?>> compared) {
  final previousPrint = debugPrint;
  var fallbacks = 0;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message?.contains('fell back') ?? false) fallbacks++;
  };
  final advisor = _BlockingModels(stockPort, model == 'nagomi',
      seed: seed, decisions: decisions, compared: compared);
  final watch = Stopwatch()..start();
  late String row;
  try {
    fakeAsync((clock) {
      final game = GameController(
        seed: seed,
        hanchan: true,
        startingDealer: dealer,
        mortal: advisor,
        seatCharacters: const [
          Character.orderic,
          Character.saeko,
          Character.saeko,
          Character.saeko
        ],
      );
      try {
        game.setAutoplayBrain(AutoplayBrain.mortal);
        game.setAutoplay(true);
        var hands = 0, wins = 0, dealIns = 0;
        for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
          if (guard > 100000) throw StateError('seed $seed stalled');
          if (game.phase == GamePhase.roundEnd) {
            final result = game.round.result!;
            hands++;
            if (result.winners.contains(0)) wins++;
            if (result.kind == RoundEndKind.ron && result.loser == 0) dealIns++;
            game.continueFromRoundEnd();
          } else {
            clock.elapse(const Duration(milliseconds: 1104));
          }
        }
        final points = game.tablePoints;
        final place = 1 +
            [1, 2, 3].fold<double>(
                0,
                (sum, seat) =>
                    sum +
                    (points[seat] > points[0]
                        ? 1
                        : points[seat] == points[0]
                            ? 0.5
                            : 0));
        row = [
          seed,
          model,
          dealer,
          hands,
          wins,
          dealIns,
          points[0],
          place,
          ...points,
          advisor.requests,
          advisor.failures,
          fallbacks,
          watch.elapsedMilliseconds
        ].join(',');
        if (hands <= 0) throw StateError('seed $seed completed no hands');
      } finally {
        game.dispose();
      }
    });
  } finally {
    debugPrint = previousPrint;
  }
  return row;
}

/// Only the tested seat changes model; all three opponents always use stock.
class _BlockingModels extends MortalAdvisor {
  _BlockingModels(this.stockPort, this.nagomi,
      {required this.seed, required this.decisions, required this.compared})
      : super('http://unused');
  final int stockPort;
  final bool nagomi;
  final int seed;
  final RandomAccessFile? decisions;
  final Map<String, Map<String, Object?>> compared;
  int requests = 0, failures = 0;

  @override
  Future<Map<String, Object?>> ask(int seat, List<MjaiEvent> events,
      {bool hanchan = true}) {
    requests++;
    try {
      final request = jsonEncode({
        'player_id': seat,
        'events': mjaiView(events, seat),
        'game_length': hanchan ? 8 : 4
      });
      final body = utf8.encode(request);
      final port = stockPort + (seat == 0 && nagomi ? 1 : 0);
      final reply = _post(port, body);
      if (seat == 0 && decisions != null) {
        var pair = compared[request];
        if (pair == null) {
          final other = _post(stockPort + (nagomi ? 0 : 1), body);
          pair = {
            'nagomi': nagomi ? reply : other,
            'saeko': nagomi ? other : reply
          };
          compared[request] = pair;
        }
        decisions!.writeStringSync('${jsonEncode({
              'seed': seed,
              'trajectory': nagomi ? 'nagomi' : 'saeko',
              'events': jsonDecode(request)['events'],
              ...pair,
            })}\n');
      }
      return Future.value(reply);
    } catch (error, stack) {
      failures++;
      return Future.error(error, stack);
    }
  }

  Map<String, Object?> _post(int port, List<int> body) {
    final socket = RawSynchronousSocket.connectSync('127.0.0.1', port);
    final bytes = <int>[];
    try {
      socket.writeFromSync(utf8.encode('POST /react HTTP/1.0\r\n'
          'Content-Type: application/json\r\n'
          'Content-Length: ${body.length}\r\n\r\n'));
      socket.writeFromSync(body);
      while (true) {
        final chunk = socket.readSync(65536);
        if (chunk == null || chunk.isEmpty) break;
        bytes.addAll(chunk);
      }
    } finally {
      socket.closeSync();
    }
    final response = utf8.decode(bytes);
    if (!response.startsWith('HTTP/1.0 200')) {
      throw StateError('model returned ${response.split('\r\n').first}');
    }
    return jsonDecode(response.split('\r\n\r\n').last) as Map<String, Object?>;
  }
}
