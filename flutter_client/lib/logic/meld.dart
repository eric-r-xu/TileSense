import 'tile.dart';

enum MeldKind { sequence, triplet, kan, pair }

/// A group of tiles: an open call, a concealed kan, or (during scoring) a
/// decomposition group. Loosely mirrors `RoundStateCall` / `TileMeld`.
class Meld {
  Meld({
    required this.kind,
    required this.low,
    required this.concealed,
    this.addedKan = false,
    this.calledFromSeatOffset,
    List<Tile>? tiles,
  }) : tiles = tiles ?? const [];

  final MeldKind kind;

  /// For a sequence, the lowest tile type; otherwise the group's tile type.
  final TileType low;

  final bool concealed;

  /// Shouminkan (added a fourth tile to an open pon).
  final bool addedKan;

  /// 1 = right (kamicha for chi), 2 = across, 3 = left. Null for concealed.
  final int? calledFromSeatOffset;

  /// The physical tiles, when known (open calls made in a live round).
  final List<Tile> tiles;

  bool get isSequence => kind == MeldKind.sequence;
  bool get isTripletLike => kind == MeldKind.triplet || kind == MeldKind.kan;
  bool get isKan => kind == MeldKind.kan;

  /// The three (or four) tile types that make up the group.
  List<TileType> get types {
    switch (kind) {
      case MeldKind.sequence:
        return [
          low,
          TileType.values[low.index + 1],
          TileType.values[low.index + 2],
        ];
      case MeldKind.triplet:
      case MeldKind.pair:
        return [low, low, low].sublist(0, kind == MeldKind.pair ? 2 : 3);
      case MeldKind.kan:
        return [low, low, low, low];
    }
  }

  bool get hasTerminalOrHonor => types.any((t) => t.isTerminalOrHonor);
  bool get allTerminalOrHonor => types.every((t) => t.isTerminalOrHonor);
  bool get allGreen => types.every(_isGreen);

  static bool _isGreen(TileType t) =>
      t == TileType.sou2 ||
      t == TileType.sou3 ||
      t == TileType.sou4 ||
      t == TileType.sou6 ||
      t == TileType.sou8 ||
      t == TileType.hatsu;

  @override
  String toString() =>
      '${concealed ? '' : 'o'}${kind.name}:${types.map((t) => t.code).join()}';
}
