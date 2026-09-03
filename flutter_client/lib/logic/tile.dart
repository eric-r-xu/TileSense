/// Tile model, ported from the Vala client's `source/Game/Logic/Tile.vala`.
///
/// The [TileType] ordering is deliberately identical to the Vala enum so the
/// integer gaps the rules and efficiency code rely on are preserved:
///   BLANK = 0, MAN1..MAN9 = 1..9, PIN1..PIN9 = 10..18, SOU1..SOU9 = 19..27,
///   TON/NAN/SHAA/PEI = 28..31, HAKU/HATSU/CHUN = 32..34.
library;

enum TileType {
  blank,
  man1, man2, man3, man4, man5, man6, man7, man8, man9,
  pin1, pin2, pin3, pin4, pin5, pin6, pin7, pin8, pin9,
  sou1, sou2, sou3, sou4, sou5, sou6, sou7, sou8, sou9,
  ton, nan, shaa, pei, // east, south, west, north
  haku, hatsu, chun; // white, green, red

  bool get isMan => index >= TileType.man1.index && index <= TileType.man9.index;
  bool get isPin => index >= TileType.pin1.index && index <= TileType.pin9.index;
  bool get isSou => index >= TileType.sou1.index && index <= TileType.sou9.index;
  bool get isSuit => isMan || isPin || isSou;
  bool get isWind => index >= TileType.ton.index && index <= TileType.pei.index;
  bool get isDragon => index >= TileType.haku.index && index <= TileType.chun.index;
  bool get isHonor => isWind || isDragon;

  /// 1..9 for a suit tile, 0 otherwise.
  int get number {
    if (isMan) return index - TileType.man1.index + 1;
    if (isPin) return index - TileType.pin1.index + 1;
    if (isSou) return index - TileType.sou1.index + 1;
    return 0;
  }

  bool get isTerminal => isSuit && (number == 1 || number == 9);
  bool get isTerminalOrHonor => isHonor || isTerminal;

  /// 0 = man, 1 = pin, 2 = sou, -1 = honor.
  int get suit {
    if (isMan) return 0;
    if (isPin) return 1;
    if (isSou) return 2;
    return -1;
  }

  /// The tile a dora indicator of this type points to (with terminal and
  /// honor wraparound), matching `Tile.dora_indicator()` in the Vala client.
  TileType get doraTarget {
    if (isSuit) {
      final base = isMan
          ? TileType.man1
          : isPin
              ? TileType.pin1
              : TileType.sou1;
      return TileType.values[base.index + (number % 9)];
    }
    switch (this) {
      case TileType.ton:
        return TileType.nan;
      case TileType.nan:
        return TileType.shaa;
      case TileType.shaa:
        return TileType.pei;
      case TileType.pei:
        return TileType.ton;
      case TileType.haku:
        return TileType.hatsu;
      case TileType.hatsu:
        return TileType.chun;
      case TileType.chun:
        return TileType.haku;
      default:
        return TileType.blank;
    }
  }

  /// A short ascii label ("1m", "E", "R"), handy for logs and tests.
  String get code {
    if (isMan) return '${number}m';
    if (isPin) return '${number}p';
    if (isSou) return '${number}s';
    switch (this) {
      case TileType.ton:
        return 'E';
      case TileType.nan:
        return 'S';
      case TileType.shaa:
        return 'W';
      case TileType.pei:
        return 'N';
      case TileType.haku:
        return 'B'; // blank, so it is not confused with West
      case TileType.hatsu:
        return 'G';
      case TileType.chun:
        return 'R';
      default:
        return '?';
    }
  }

  /// The short red corner mark drawn on a tile face: the bare number for a suit
  /// tile (its suit is already obvious from the face) and a letter for the
  /// honours — E/S/W/N for the winds, B/G/R for white / green / red dragon.
  String get redIndex => isSuit ? '$number' : code;

  /// The Unicode mahjong glyph for this tile face.
  String get glyph => _glyphs[index];

  /// Human-readable name, e.g. "5 Man", "East", "Red Dragon".
  String get displayName => _names[index];
}

const List<String> _glyphs = [
  '🀫',
  '🀇', '🀈', '🀉', '🀊', '🀋', '🀌', '🀍', '🀎', '🀏',
  '🀙', '🀚', '🀛', '🀜', '🀝', '🀞', '🀟', '🀠', '🀡',
  '🀐', '🀑', '🀒', '🀓', '🀔', '🀕', '🀖', '🀗', '🀘',
  '🀀', '🀁', '🀂', '🀃',
  '🀆', '🀅', '🀄',
];

const List<String> _names = [
  'Blank',
  '1 Man', '2 Man', '3 Man', '4 Man', '5 Man', '6 Man', '7 Man', '8 Man', '9 Man',
  '1 Pin', '2 Pin', '3 Pin', '4 Pin', '5 Pin', '6 Pin', '7 Pin', '8 Pin', '9 Pin',
  '1 Sou', '2 Sou', '3 Sou', '4 Sou', '5 Sou', '6 Sou', '7 Sou', '8 Sou', '9 Sou',
  'East', 'South', 'West', 'North',
  'White Dragon', 'Green Dragon', 'Red Dragon',
];

/// A physical tile in the wall. [id] is unique (0..135) and is the identity
/// used for equality, so the same [type] can appear four times.
class Tile {
  const Tile(this.id, this.type, {this.aka = false});

  /// Unique per physical tile.
  final int id;
  final TileType type;

  /// Red five (aka dora). Named `dora` on the Vala `Tile`.
  final bool aka;

  bool get isFive => type.number == 5;

  String get glyph => type.glyph;
  String get code => aka ? '0${type.code.substring(type.code.length - 1)}' : type.code;

  @override
  bool operator ==(Object other) => other is Tile && other.id == id;

  @override
  int get hashCode => id;

  @override
  String toString() => '${type.code}#$id${aka ? 'r' : ''}';
}

/// Sort by tile type then id, matching `Tile.sort_tiles_type`.
List<Tile> sortByType(Iterable<Tile> tiles) {
  final list = tiles.toList();
  list.sort((a, b) {
    final t = a.type.index.compareTo(b.type.index);
    return t != 0 ? t : a.id.compareTo(b.id);
  });
  return list;
}

/// 34-length counts array indexed by `TileType.index - 1` (man1 == 0).
List<int> toCounts34(Iterable<Tile> tiles) {
  final counts = List<int>.filled(34, 0);
  for (final tile in tiles) {
    counts[tile.type.index - 1]++;
  }
  return counts;
}

TileType typeFrom34(int i) => TileType.values[i + 1];

enum Wind {
  east,
  south,
  west,
  north;

  Wind get next => Wind.values[(index + 1) % 4];
  Wind get prev => Wind.values[(index + 3) % 4];

  String get kanji => const ['東', '南', '西', '北'][index];
  String get label => const ['East', 'South', 'West', 'North'][index];
  String get initial => label[0];

  /// The wind (yakuhai) tile for this seat/round wind.
  TileType get tile => TileType.values[TileType.ton.index + index];
}
