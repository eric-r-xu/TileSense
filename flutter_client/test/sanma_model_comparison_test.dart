// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/guide_host.dart';
import 'package:tilesense/game/mortal_advisor.dart';
import 'package:tilesense/game/sfx.dart';

/// Paired sanma hanchan, with two Model opponents and default guide dials.
/// Run with SANMA_COMPARE_GAMES=12 and a local sanma sidecar on
/// SANMA_COMPARE_PORT (18891). SANMA_COMPARE_OUT saves per-game CSV results.
void main() {
  final env = Platform.environment;
  final games = int.tryParse(env['SANMA_COMPARE_GAMES'] ?? '') ?? 0;
  test('paired sanma Model and TileSense guide', () {
    final port = int.parse(env['SANMA_COMPARE_PORT'] ?? '18891');
    final base = int.parse(env['SANMA_COMPARE_SEED'] ?? '1000');
    final rows = <String>[
      'seed,brain,dealer,hands,points,place,pts0,pts1,pts3,requests,failures,fallbacks',
    ];
    Sfx.i.enabled = false;
    try {
      for (var i = 0; i < games; i++) {
        for (final brain in AutoplayBrain.values) {
          final row = _play(base + i, i % 3, brain, port);
          rows.add(row);
          print(row);
          final out = env['SANMA_COMPARE_OUT'];
          if (out != null) File(out).writeAsStringSync('${rows.join('\n')}\n');
        }
      }
    } finally {
      Sfx.i.enabled = true;
    }
  },
      skip: games == 0 ? 'set SANMA_COMPARE_GAMES to run' : false,
      timeout: Timeout.none);
}

String _play(int seed, int dealerIndex, AutoplayBrain brain, int port) {
  final previousPrint = debugPrint;
  var fallbacks = 0;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message?.contains('fell back') ?? false) fallbacks++;
  };
  late String row;
  try {
    fakeAsync((clock) {
      final model = _BlockingModel(port);
      final dealer = Ruleset.sanma.activeSeats[dealerIndex];
      final game = GameController(
        seed: seed,
        ruleset: Ruleset.sanma,
        hanchan: true,
        startingDealer: dealer,
        mortal: model,
        seatCharacters: const [
          Character.orderic,
          Character.saeko,
          Character.hubert,
          Character.saeko,
        ],
      );
      try {
        game.setAutoplayBrain(brain);
        game.setAutoplay(true);
        var hands = 0;
        for (var guard = 0; game.phase != GamePhase.gameEnd; guard++) {
          if (guard > 100000) throw StateError('seed $seed stalled');
          if (game.phase == GamePhase.roundEnd) {
            hands++;
            game.continueFromRoundEnd();
          } else {
            clock.elapse(const Duration(milliseconds: 1104));
          }
        }
        final points = game.tablePoints;
        // Mid-rank ties; exclude sanma's empty seat.
        final place = 1 +
            Ruleset.sanma.activeSeats.where((s) => s != 0).fold<double>(
                0,
                (p, s) =>
                    p +
                    (points[s] > points[0]
                        ? 1
                        : points[s] == points[0]
                            ? 0.5
                            : 0));
        row = [
          seed,
          brain == AutoplayBrain.mortal ? 'model' : 'guide',
          dealer,
          hands,
          points[0],
          place,
          points[0],
          points[1],
          points[3],
          model.requests,
          model.failures,
          fallbacks
        ].join(',');
        expect(model.failures, 0, reason: 'model failed at seed $seed');
        expect(fallbacks, 0, reason: 'fallback at seed $seed');
      } finally {
        game.dispose();
      }
    });
  } finally {
    debugPrint = previousPrint;
  }
  return row;
}

/// Like the existing Model simulation: synchronous HTTP lets fake time drive
/// the controller without advancing while a real inference is pending.
class _BlockingModel extends MortalAdvisor {
  _BlockingModel(this.port) : super('http://unused');
  final int port;
  int requests = 0, failures = 0;

  @override
  Future<Map<String, Object?>> ask(int seat, List<MjaiEvent> events,
      {bool hanchan = true}) {
    requests++;
    try {
      final body = utf8.encode(jsonEncode({
        'player_id': seat,
        'events': mjaiView(events, seat),
        'game_length': hanchan ? 6 : 3,
      }));
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
      if (!response.startsWith('HTTP/1.0 200')) throw StateError(response);
      return Future.value(
          jsonDecode(response.split('\r\n\r\n').last) as Map<String, Object?>);
    } catch (error, stack) {
      failures++;
      return Future.error(error, stack);
    }
  }
}
