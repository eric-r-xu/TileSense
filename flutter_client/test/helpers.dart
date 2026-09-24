import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/tile.dart';

/// Parse a compact hand string, e.g. "123m 456m 789p 1122s EE" or "123m456m".
/// Suit letters: m/p/s. Honors: E S W N (winds), B G R (white/green/red).
/// A `0` in a run is an aka five.
List<TileType> parseTypes(String spec) {
  final out = <TileType>[];
  for (final token in spec.split(' ')) {
    _parseToken(token, out);
  }
  return out;
}

void _parseToken(String token, List<TileType> out) {
  if (token.isEmpty) return;
  final suited = RegExp(r'^([0-9]+)([mps])$').firstMatch(token);
  if (suited != null) {
    final digits = suited.group(1)!;
    final suit = suited.group(2)!;
    for (final ch in digits.split('')) {
      final n = int.parse(ch);
      final num = n == 0 ? 5 : n;
      final base = switch (suit) {
        'm' => TileType.man1,
        'p' => TileType.pin1,
        _ => TileType.sou1,
      };
      out.add(TileType.values[base.index + num - 1]);
    }
    return;
  }
  for (final ch in token.split('')) {
    out.add(switch (ch) {
      'E' => TileType.ton,
      'S' => TileType.nan,
      'W' => TileType.shaa,
      'N' => TileType.pei,
      'B' => TileType.haku,
      'G' => TileType.hatsu,
      'R' => TileType.chun,
      _ => throw ArgumentError('bad tile "$ch" in "$token"'),
    });
  }
}

List<Tile> parseTiles(String spec) {
  var id = 0;
  return parseTypes(spec).map((t) => Tile(id++, t)).toList();
}

List<int> counts34Of(String spec) {
  final c = List<int>.filled(34, 0);
  for (final t in parseTypes(spec)) {
    c[t.index - 1]++;
  }
  return c;
}

/// Pump in slices until [ready] holds, then return.
///
/// One turn is a *chain* of timers — a call announcement holds play for
/// `kCallPause`, and what follows it is scheduled from inside that timer's
/// callback. A single long `pump` advances the clock once and so only walks
/// one link of the chain; slices walk all of it. Waiting on the state itself
/// also means the pauses can be retuned without re-tuning every test.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() ready, {
  Duration step = const Duration(milliseconds: 100),
  int tries = 60,
}) async {
  for (var i = 0; i < tries; i++) {
    if (ready()) return;
    await tester.pump(step);
  }
  fail('timed out after ${step * tries} waiting for the game to catch up');
}
