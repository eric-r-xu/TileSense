/// Sanma (三麻, sannin mahjong): riichi for three players, after
/// https://riichi.wiki/Sanma. Every riichi rule applies, with these changes:
///
/// - 108 tiles: the 2-8 man are removed; 1m and 9m stay, so kokushi musou and
///   chinroutou can still be made (sanshoku doujun cannot). A 1m dora
///   indicator points to 9m.
/// - No chi. Pon and kan are called as usual.
/// - North is nukidora (pei nuki, "kita"): set it aside as a dora and draw a
///   replacement from the dead wall. It can be ronned, but that is not
///   chankan. A North kept in hand is an ordinary guest wind.
/// - The dead wall holds eight replacement draws, shared by kans and kita.
/// - Tsumo loss: a self-draw is paid by the two other players at the
///   four-player rates, with nothing added for the missing seat.
/// - 35,000 points each; seats rotate through East, South and West.
/// - One red five each in pin and sou (there is no 5m).
library;

import '../tile.dart';

class SanmaRules {
  /// Points each player starts a game on.
  static const startingPoints = 35000;

  /// Tiles in the wall: 136 less the 28 tiles from 2m to 8m.
  static const wallSize = 108;

  /// The seat left empty: the one across from you. Seat indices run from
  /// yours (0) round to your left (3), so the players are 0, 1 and 3 and
  /// the seat to your left is still the one you can see discarding into you.
  static const emptySeat = 2;

  /// Replacement draws the dead wall holds, for kans and kita together.
  static const replacementDraws = 8;

  /// Paid between the tenpai and noten players at an exhaustive draw.
  /// The wiki notes sanma's noten payment is small; this is the 2,000 the
  /// major online clients use: 1,000 from each noten player to the tenpai
  /// ones, split between them.
  static const notenPot = 2000;

  /// Whether [type] is in a sanma wall: everything but the 2-8 man.
  static bool inWall(TileType type) =>
      type.isPlayingTile &&
      !(type.isMan && type.number >= 2 && type.number <= 8);

  /// The tile set aside as nukidora.
  static const kita = TileType.pei;

  /// Marks the 2-8 man in [visibleCounts34] (counts by tile type, 1m first)
  /// as all four seen, so anything counting what is left to draw finds none
  /// of them: there are none in a sanma wall.
  static void countRemovedTiles(List<int> visibleCounts34) {
    for (var n = 2; n <= 8; n++) {
      visibleCounts34[n - 1] = 4;
    }
  }
}
