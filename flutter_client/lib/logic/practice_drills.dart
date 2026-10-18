/// The practice hands: short fixed questions that teach what a lesson only
/// describes. Whether an answer is right is worked out from the tiles with the
/// same win test the game uses, never stored, so a drill can't carry a wrong
/// answer. Each one has a plain-language explanation for the screen to show.
library;

import 'package:mahjong_core/hand_parse.dart' show waitTiles;
import 'package:mahjong_core/ruleset.dart';
import 'package:mahjong_core/tile.dart';

/// What a drill asks.
enum DrillKind {
  /// A hand one tile from winning: which tile completes it?
  winningTile,

  /// A hand with a tile just drawn: which discard leaves it one tile away?
  discard,

  /// Another player's discard: what, if anything, can you claim with it?
  claim,
}

/// What a player can do with another's discard.
enum ClaimChoice { chow, pung, pass }

/// Where the player who discarded sits, from your seat.
enum DiscardFrom { left, across, right }

class PracticeDrill {
  const PracticeDrill._(this.id, this.kind, this._hand,
      {this.options = const [], this.claimed, this.from});

  /// Names the drill's explanation string, and its keys in tests.
  final String id;
  final DrillKind kind;
  final String _hand;

  /// [DrillKind.winningTile]: the tiles offered as answers.
  final List<String> options;

  /// [DrillKind.claim]: the discard, and who made it.
  final String? claimed;
  final DiscardFrom? from;

  /// Your tiles: 13 for a [DrillKind.winningTile] or [DrillKind.claim] drill,
  /// 14 for a [DrillKind.discard] drill.
  List<TileType> get hand => _parse(_hand);

  List<TileType> get optionTiles => [for (final o in options) _parse(o).single];

  TileType? get claimedTile =>
      claimed == null ? null : _parse(claimed!).single;

  /// Whether the drill shows an honor tile, which Sichuan does not have.
  bool get usesHonors =>
      hand.any((t) => t.isHonor) ||
      optionTiles.any((t) => t.isHonor) ||
      (claimedTile?.isHonor ?? false);

  /// Whether a chow comes into it: the claimed tile could finish a run, so
  /// the lesson is partly about who a chow may be claimed from. Sichuan has no
  /// chows.
  bool get involvesChow =>
      kind == DrillKind.claim && _runsWith(hand, claimedTile!).isNotEmpty;

  /// Whether [ruleset] has everything this drill teaches.
  bool suits(Ruleset ruleset) =>
      !ruleset.isSichuan || !(usesHonors || involvesChow);

  // --- answers, worked out from the tiles --------------------------------

  /// The tiles that win a [DrillKind.winningTile] hand.
  List<TileType> get winningTiles => waitTiles(_tiles(hand));

  /// Whether [choice] answers a [DrillKind.winningTile] drill correctly.
  bool isWinningTile(TileType choice) => winningTiles.contains(choice);

  /// The tiles in a [DrillKind.discard] hand worth throwing: each leaves the
  /// other 13 one tile from winning.
  List<TileType> get goodDiscards => [
        for (final t in hand.toSet())
          if (discardLeavesReady(t)) t,
      ];

  bool discardLeavesReady(TileType discard) {
    final rest = List.of(hand)..remove(discard);
    return waitTiles(_tiles(rest)).isNotEmpty;
  }

  /// What can be claimed in a [DrillKind.claim] drill: a pung with any
  /// player's tile when two match; a chow only from the player on your left;
  /// otherwise nothing.
  ClaimChoice get correctClaim {
    final tile = claimedTile!;
    if (hand.where((t) => t == tile).length >= 2) return ClaimChoice.pung;
    if (from == DiscardFrom.left && _runsWith(hand, tile).isNotEmpty) {
      return ClaimChoice.chow;
    }
    return ClaimChoice.pass;
  }
}

/// The runs [tile] could finish with tiles from [hand], as the two tiles
/// beside it that [hand] holds.
List<(TileType, TileType)> _runsWith(List<TileType> hand, TileType tile) {
  if (!tile.isSuit) return const [];
  final n = tile.number;
  TileType at(int offset) => TileType.values[tile.index + offset];
  bool has(int offset) {
    final m = n + offset;
    return m >= 1 && m <= 9 && hand.contains(at(offset));
  }

  return [
    if (has(-2) && has(-1)) (at(-2), at(-1)),
    if (has(-1) && has(1)) (at(-1), at(1)),
    if (has(1) && has(2)) (at(1), at(2)),
  ];
}

List<Tile> _tiles(List<TileType> types) =>
    [for (final (i, t) in types.indexed) Tile(i, t)];

/// "123m 55p E" as tile types: suits by digits then m/p/s, honors by letter
/// (E S W N for the winds, B G R for the dragons).
List<TileType> _parse(String spec) {
  final out = <TileType>[];
  for (final token in spec.split(' ')) {
    if (token.isEmpty) continue;
    final suit = token[token.length - 1];
    final base = switch (suit) {
      'm' => TileType.man1.index,
      'p' => TileType.pin1.index,
      's' => TileType.sou1.index,
      _ => -1,
    };
    if (base >= 0) {
      for (final d in token.substring(0, token.length - 1).split('')) {
        out.add(TileType.values[base + int.parse(d) - 1]);
      }
    } else {
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
  }
  return out;
}

/// Every practice hand, in the order to meet them.
const List<PracticeDrill> kPracticeDrills = [
  // One tile from winning: which tile finishes the hand?
  PracticeDrill._('w1', DrillKind.winningTile, '123m 456m 789m 55s 13p',
      options: ['5s', '4p', '1p', '2p']),
  PracticeDrill._('w2', DrillKind.winningTile, '234m 567m 789s 55p 12p',
      options: ['4p', '3p', '2p', '5p']),
  PracticeDrill._('w3', DrillKind.winningTile, '123m 456m 789m 123p 5s',
      options: ['4s', '6s', '5s', '1p']),
  // A tile just drawn: which discard leaves the hand one tile from winning?
  PracticeDrill._('d1', DrillKind.discard, '123m 456m 789m 66p 34p 9s'),
  PracticeDrill._('d2', DrillKind.discard, '234m 567m 789p 55s 12s E'),
  PracticeDrill._('d3', DrillKind.discard, '234m 567m 456s 55p 78s W'),
  // Another player's discard: what can you claim?
  PracticeDrill._('c1', DrillKind.claim, '55p 147m 258s 369m 24s',
      claimed: '5p', from: DiscardFrom.across),
  PracticeDrill._('c2', DrillKind.claim, '46p 147m 258s 369m 24s',
      claimed: '5p', from: DiscardFrom.left),
  PracticeDrill._('c3', DrillKind.claim, '46p 147m 258s 369m 24s',
      claimed: '5p', from: DiscardFrom.right),
  PracticeDrill._('c4', DrillKind.claim, '147m 258s 369m 24s 13p',
      claimed: 'E', from: DiscardFrom.left),
];

/// The drills to show under [ruleset], in order.
List<PracticeDrill> practiceDrillsFor(Ruleset ruleset) =>
    [for (final d in kPracticeDrills) if (d.suits(ruleset)) d];
