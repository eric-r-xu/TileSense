import 'tile.dart';

/// Tile types forbidden on the discard immediately after a Japanese pon or
/// chi. [chiLow] is the sequence's lowest tile; omit it for pon. Red fives
/// share their ordinary tile's type and therefore the same restriction.
Set<TileType> kuikaeForbiddenDiscards(TileType called, {TileType? chiLow}) {
  final forbidden = {called};
  if (chiLow == null || !chiLow.isSuit || chiLow.suit != called.suit) {
    return forbidden;
  }
  if (called == chiLow && chiLow.number <= 6) {
    forbidden.add(TileType.values[chiLow.index + 3]);
  } else if (called.index == chiLow.index + 2 && chiLow.number > 1) {
    forbidden.add(TileType.values[chiLow.index - 1]);
  }
  return forbidden;
}
