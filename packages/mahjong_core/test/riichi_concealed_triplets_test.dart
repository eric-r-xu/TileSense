import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

/// A triplet is only concealed (an ankou) if all three tiles came from the
/// player's own draws. Winning on a discard that completes a triplet leaves
/// that triplet open (a minkou) for sanankou, suuankou and fu; winning on one
/// that can be read as completing a sequence or the pair instead leaves every
/// triplet concealed.
void main() {
  List<Tile> tiles(List<TileType> types) =>
      [for (var i = 0; i < types.length; i++) Tile(i, types[i])];

  HandScore score(List<Tile> hand, TileType win, {required bool tsumo}) =>
      scoreHand(
        hand,
        Tile(99, win),
        const [],
        ScoreContext(
          roundWind: Wind.east,
          seatWind: Wind.south,
          isTsumo: tsumo,
          closed: true,
          riichi: true,
        ),
        isDealer: false,
      );

  List<String> yaku(HandScore s) => s.yaku.map((y) => y.name).toList();

  // 111m 555p 999s, waiting on 8p or 7s (two pairs).
  final shanpon = tiles(const [
    TileType.man1, TileType.man1, TileType.man1, //
    TileType.pin5, TileType.pin5, TileType.pin5,
    TileType.sou9, TileType.sou9, TileType.sou9,
    TileType.pin8, TileType.pin8,
    TileType.sou7, TileType.sou7,
  ]);

  test('a ron that completes a triplet is not suuankou', () {
    final won = yaku(score(shanpon, TileType.pin8, tsumo: false));
    expect(won, isNot(contains('Suuankou')));
    expect(won, containsAll(['Sanankou', 'Toitoi']));
  });

  test('the same triplet completed by tsumo is', () {
    expect(
        yaku(score(shanpon, TileType.pin8, tsumo: true)), contains('Suuankou'));
  });

  test('a ron that completes the pair keeps all four triplets concealed', () {
    // 111m 555p 999s 888p, waiting on the single 7s.
    final tanki = tiles(const [
      TileType.man1, TileType.man1, TileType.man1, //
      TileType.pin5, TileType.pin5, TileType.pin5,
      TileType.sou9, TileType.sou9, TileType.sou9,
      TileType.pin8, TileType.pin8, TileType.pin8,
      TileType.sou7,
    ]);
    expect(
        yaku(score(tanki, TileType.sou7, tsumo: false)), contains('Suuankou'));
  });

  test('a ron that can complete a sequence instead keeps the triplet', () {
    // 111m 999s 555p and 4p-6p: a 5p completes the 456p sequence, so the
    // 555p triplet was never touched by the discard.
    final hand = tiles(const [
      TileType.man1, TileType.man1, TileType.man1, //
      TileType.sou9, TileType.sou9, TileType.sou9,
      TileType.pin5, TileType.pin5, TileType.pin5,
      TileType.pin4, TileType.pin6,
      TileType.sou7, TileType.sou7,
    ]);
    expect(
        yaku(score(hand, TileType.pin5, tsumo: false)), contains('Sanankou'));
  });

  test('a triplet completed by ron scores open-triplet fu', () {
    // 111m 234p 567s, waiting on 8p or 9s. On a ron of 8p: 20 base + 10
    // closed ron + 8 (concealed terminal 111m) + 2 (open simple 888p) = 40.
    // Counting 888p as concealed (+4) would round up to 50.
    final hand = tiles(const [
      TileType.man1, TileType.man1, TileType.man1, //
      TileType.pin2, TileType.pin3, TileType.pin4,
      TileType.sou5, TileType.sou6, TileType.sou7,
      TileType.pin8, TileType.pin8,
      TileType.sou9, TileType.sou9,
    ]);
    expect(score(hand, TileType.pin8, tsumo: false).fu, 40);
  });
}
