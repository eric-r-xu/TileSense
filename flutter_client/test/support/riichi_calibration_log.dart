import 'dart:convert';

/// Buffers one game's public decision snapshots until outcomes and fallback
/// status are known. Only the chosen action receives an observed outcome.
class RiichiCalibrationLog {
  RiichiCalibrationLog({required this.seed, required this.metadata});

  final int seed;
  final Map<String, Object?> metadata;
  final _hand = <Map<String, Object?>>[];
  final _game = <Map<String, Object?>>[];
  var _handIndex = 0;
  var _decision = 0;

  void record({
    required Map<String, Object?> state,
    required List<Map<String, Object?>> candidates,
    required String chosenTile,
    required Map<String, Object?>? teacher,
    String? teacherError,
  }) {
    final type = chosenTile.replaceAll('r', '');
    final chosen = candidates.where((c) => c['discard'] == type).single;
    // Snapshot nested lists too: subsequent mjai events mutate the table.
    _hand.add(jsonDecode(jsonEncode({
      'schemaVersion': 1,
      'seed': seed,
      'handIndex': _handIndex,
      'decisionIndex': _decision++,
      'metadata': metadata,
      'state': state,
      'candidateUnit': 'tileType',
      'candidates': candidates,
      'chosenTile': chosenTile,
      'chosen': chosen,
      'teacher': teacher,
      'teacherError': teacherError,
    })) as Map<String, Object?>);
  }

  void finishHand({
    required bool won,
    required bool dealIn,
    required bool finalTenpai,
    required String endKind,
    required int netPoints,
    int? baseWinPoints,
  }) {
    if (won != (baseWinPoints != null)) {
      throw ArgumentError('Only winners have a conditional payout label');
    }
    var reached = finalTenpai || won;
    for (final row in _hand.reversed) {
      final chosen = row['chosen'] as Map<String, Object?>;
      reached = reached || (chosen['shanten'] as num) <= 0;
      row['outcome'] = {
        'won': won,
        'dealIn': dealIn,
        'reachedTenpai': reached,
        'endKind': endKind,
        'netPoints': netPoints,
        // Base hand payment, excluding honba/sticks, matches averagePoints.
        'baseWinPoints': baseWinPoints,
      };
    }
    _game.addAll(_hand);
    _hand.clear();
    _handIndex++;
  }

  Iterable<String> finishGame({required int fallbacks}) sync* {
    if (_hand.isNotEmpty) {
      throw StateError('Unfinished hand in calibration log');
    }
    for (final row in _game) {
      yield jsonEncode(
          {...row, 'validGame': fallbacks == 0, 'fallbacks': fallbacks});
    }
    _game.clear();
  }
}
