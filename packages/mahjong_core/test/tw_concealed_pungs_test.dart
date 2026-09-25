import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

/// A pung only counts toward the concealed-pung patterns if all three tiles
/// came from the player's own draws. Winning on a discard that completes a
/// pung exposes that pung; winning on one that can be read as completing a
/// chow or the pair instead leaves every pung concealed.
void main() {
  List<Tile> tiles(List<TileType> types) =>
      [for (var i = 0; i < types.length; i++) Tile(i, types[i])];

  List<String> patterns(List<Tile> hand, TileType win, {required bool tsumo}) =>
      scoreTaiwaneseHand(
        hand,
        Tile(99, win),
        const [],
        ScoreContext(
          roundWind: Wind.east,
          seatWind: Wind.south,
          isTsumo: tsumo,
          closed: true,
          discardCount: 20,
        ),
        isDealer: false,
        minimumPoints: 0,
      ).yaku.map((y) => y.name).toList();

  // 111m 234m 555p 456s, waiting on 8p or 9s (two pairs).
  final shanpon = tiles(const [
    TileType.man1, TileType.man1, TileType.man1, //
    TileType.man2, TileType.man3, TileType.man4,
    TileType.pin5, TileType.pin5, TileType.pin5,
    TileType.sou4, TileType.sou5, TileType.sou6,
    TileType.pin8, TileType.pin8,
    TileType.sou9, TileType.sou9,
  ]);

  test('a pung finished off a discard is not concealed', () {
    final won = patterns(shanpon, TileType.pin8, tsumo: false);
    expect(won, contains('Two Concealed Pungs'));
    expect(won, isNot(contains('Three Concealed Pungs')));
  });

  test('the same pung finished by a self-draw is', () {
    expect(patterns(shanpon, TileType.pin8, tsumo: true),
        contains('Three Concealed Pungs'));
  });

  test('a discard that can finish a chow instead leaves the pung concealed',
      () {
    // 111m 234m 999s 555p and 4p-6p: a 5p completes the 456p chow, so the
    // 555p pung was never touched by the discard.
    final hand = tiles(const [
      TileType.man1, TileType.man1, TileType.man1, //
      TileType.man2, TileType.man3, TileType.man4,
      TileType.sou9, TileType.sou9, TileType.sou9,
      TileType.pin5, TileType.pin5, TileType.pin5,
      TileType.pin4, TileType.pin6,
      TileType.sou7, TileType.sou7,
    ]);
    expect(patterns(hand, TileType.pin5, tsumo: false),
        contains('Three Concealed Pungs'));
  });

  test('a discard that finishes the pair leaves every pung concealed', () {
    // 111m 555p 999s 234m 678s, waiting on the single 7p.
    final hand = tiles(const [
      TileType.man1, TileType.man1, TileType.man1, //
      TileType.pin5, TileType.pin5, TileType.pin5,
      TileType.sou9, TileType.sou9, TileType.sou9,
      TileType.man2, TileType.man3, TileType.man4,
      TileType.sou6, TileType.sou7, TileType.sou8,
      TileType.pin7,
    ]);
    expect(patterns(hand, TileType.pin7, tsumo: false),
        contains('Three Concealed Pungs'));
  });
}
