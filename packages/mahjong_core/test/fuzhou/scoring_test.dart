import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final gold = {type('5s')};

  /// Scores [concealed] (the tiles in hand, the winning tile last in [win]).
  HandScore score(String concealed, String win,
      {List<Meld> melds = const [],
      List<TileType> flowers = const [],
      Set<TileType>? goldTypes,
      bool dealer = false,
      bool tsumo = true,
      int streak = 0,
      bool robbing = false,
      bool heavenly = false,
      bool earthly = false}) {
    return scoreFuzhouHand(
      tiles(concealed),
      tiles(win).single,
      melds,
      ScoreContext(
        roundWind: Wind.east,
        seatWind: Wind.south,
        isTsumo: tsumo,
        closed: melds.every((m) => m.concealed),
        flowers: flowers,
        heavenly: heavenly,
        earthly: earthly,
      ),
      isDealer: dealer,
      fuzhou: FuzhouScoreContext(
          goldTypes: goldTypes ?? gold,
          dealerContinuation: streak,
          robbingGold: robbing),
    );
  }

  final sixFlowers = [
    TileType.plum,
    TileType.orchid,
    TileType.spring,
    TileType.summer,
    TileType.ton,
    TileType.nan
  ];

  test('the guide\'s worked example, with the table\'s value for All Sequences',
      () {
    // 123m 456m 789m 123p 4_6p (a gold 5s stands for 5p) 99s, self-drawn,
    // six flowers: (5 + 6 + 1) x 2 = 24, + 10 for All Sequences.
    final s = score('123m 456m 789m 123p 46p 9s 5s', '9s', flowers: sixFlowers);
    expect(s.valid, isTrue);
    expect(points(s, 'Base Points'), 5);
    expect(points(s, 'Flower Points'), 6);
    expect(points(s, 'Gold Points'), 1);
    expect(points(s, 'Doubled'), 12);
    expect(names(s), contains('All Sequences'));
    expect(s.points, 34);
    expect(s.dealerPays, 34);
    expect(s.nonDealerPays, 34);
    // The listed lines add up to the total.
    expect(s.yaku.fold<int>(0, (a, y) => a + y.han), s.points);
  });

  test('a plain win is the base, doubled', () {
    final s = score('111m 456m 789m 123p 456p 9s', '9s', flowers: const []);
    expect(s.points, 10);
    expect(names(s), isNot(contains('All Sequences')));
  });

  test('an incomplete or oversized hand is invalid', () {
    expect(score('111m 456m 789m 123p 456p 9s', '8s').valid, isFalse);
    expect(
        scoreFuzhouHand(tiles('111m 456m'), tiles('9s').single, const [],
                ScoreContext(
                    roundWind: Wind.east,
                    seatWind: Wind.east,
                    isTsumo: true,
                    closed: true),
                isDealer: false)
            .valid,
        isFalse);
  });

  test('no minimum: any complete hand wins', () {
    expect(score('111m 456m 789m 123p 456p 9s', '9s').valid, isTrue);
  });

  test('every flower is a point, and a complete set adds Full Bloom', () {
    final s = score('111m 456m 789m 123p 456p 9s', '9s', flowers: [
      TileType.plum,
      TileType.orchid,
      TileType.chrysanthemum,
      TileType.bamboo,
    ]);
    expect(points(s, 'Flower Points'), 4);
    expect(points(s, 'Full Bloom'), 6);
    // (5 + 4 + 6) x 2
    expect(s.points, 30);
  });

  test('four of one wind is a Full Bloom set too; three is not', () {
    final four = score('111m 456m 789m 123p 456p 9s', '9s',
        flowers: List.filled(4, TileType.ton));
    expect(points(four, 'Full Bloom'), 6);
    final three = score('111m 456m 789m 123p 456p 9s', '9s',
        flowers: List.filled(3, TileType.ton));
    expect(names(three), isNot(contains('Full Bloom')));
  });

  test('exactly one flower earns One Flower', () {
    final s = score('111m 456m 789m 123p 456p 9s', '9s',
        flowers: [TileType.plum]);
    expect(points(s, 'One Flower'), 15);
    expect(score('111m 456m 789m 123p 456p 9s', '9s').yaku.any((y) => y.name == 'One Flower'),
        isFalse);
  });

  test('the dealer\'s streak counts for the dealer only', () {
    final dealer = score('111m 456m 789m 123p 456p 9s', '9s',
        dealer: true, streak: 3);
    expect(points(dealer, 'Dealer Continuation'), 3);
    expect(dealer.points, (5 + 3) * 2);
    final other = score('111m 456m 789m 123p 456p 9s', '9s', streak: 3);
    expect(names(other), isNot(contains('Dealer Continuation')));
  });

  test('kongs: one point open, two concealed, in the doubled part', () {
    final open = Meld(
        kind: MeldKind.kan,
        low: type('2p'),
        concealed: false,
        tiles: tiles('2222p'));
    final hidden = Meld(
        kind: MeldKind.kan,
        low: type('3p'),
        concealed: true,
        tiles: tiles('3333p'));
    // Two melds out: 17 - 6 = 11 concealed tiles.
    final s = score('456m 789m 123s 6s', '6s', melds: [open, hidden]);
    expect(s.valid, isTrue);
    expect(points(s, 'Open Kong'), 1);
    expect(points(s, 'Concealed Kong'), 2);
    expect(s.points, (5 + 1 + 2) * 2);
  });

  test('a gold in hand scores a point and stands for any tile', () {
    // 45p has no third tile without the gold...
    final dead = score('111m 456m 789m 123p 45p 9s', '9s');
    expect(dead.valid, isFalse);
    // ...and with the gold standing in as 3p or 6p, it is a win.
    final win = score('111m 456m 789m 123p 45p 5s 9s', '9s');
    expect(win.valid, isTrue);
    expect(points(win, 'Gold Points'), 1);
    expect(win.points, (5 + 1) * 2);
  });

  test('Golden Pair, Three Gold Knockdown and Golden Dragon do not stack', () {
    // Two golds as the pair.
    final pair = score('111m 456m 789m 123p 456p 5s', '5s');
    expect(points(pair, 'Golden Pair'), 20);
    expect(names(pair), isNot(contains('Three Gold Knockdown')));
    expect(points(pair, 'Gold Points'), 2);

    // Three golds as a triplet: Golden Dragon, and no lesser gold hand.
    final dragon = score('456m 789m 123p 456p 99s 5s5s', '5s');
    expect(points(dragon, 'Golden Dragon'), 40);
    expect(names(dragon), isNot(contains('Three Gold Knockdown')));
    expect(names(dragon), isNot(contains('Golden Pair')));
    expect(points(dragon, 'Gold Points'), 3);

    // Three golds each completing a different run cannot be a triplet:
    // Three Gold Knockdown.
    final knock = score('13m 46p 79s 456m 789m 99p 5s5s', '5s');
    expect(knock.valid, isTrue);
    expect(points(knock, 'Three Gold Knockdown'), 30);
    expect(names(knock), isNot(contains('Golden Dragon')));
    expect(names(knock), isNot(contains('Golden Pair')));
  });

  test('Robbing the Gold and the first-turn blessings', () {
    final rob = score('111m 456m 789m 123p 456p 9s', '9s', robbing: true);
    expect(points(rob, 'Robbing the Gold'), 50);
    expect(rob.points, 10 + 50);

    final heaven = score('111m 456m 789m 123p 456p 9s', '9s',
        dealer: true, heavenly: true);
    expect(points(heaven, 'Blessing of Heaven'), 50);
    // Heaven is the dealer's own self-draw.
    final notDealer = score('111m 456m 789m 123p 456p 9s', '9s', heavenly: true);
    expect(names(notDealer), isNot(contains('Blessing of Heaven')));

    final earth = score('111m 456m 789m 123p 456p 9s', '9s',
        tsumo: false, earthly: true);
    expect(points(earth, 'Blessing of Earth'), 40);
  });

  test('open melds that are not all runs rule out All Sequences', () {
    final pung = Meld(
        kind: MeldKind.triplet,
        low: type('2p'),
        concealed: false,
        tiles: tiles('222p'));
    final s = score('456m 789m 123s 456s 9s', '9s', melds: [pung]);
    expect(s.valid, isTrue);
    expect(names(s), isNot(contains('All Sequences')));
  });

  test('flower gold types: a flipped flower makes the other seven gold', () {
    expect(FuzhouRules.goldTypesFor(TileType.plum).length, 7);
    expect(FuzhouRules.goldTypesFor(TileType.plum), isNot(contains(TileType.plum)));
    expect(FuzhouRules.goldTypesFor(type('5s')), {type('5s')});
    expect(FuzhouRules.goldTypesFor(TileType.ton), {TileType.ton});
  });
}
