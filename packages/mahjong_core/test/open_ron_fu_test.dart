import 'package:mahjong_core/mahjong_core.dart';
import 'package:test/test.dart';

import 'sanma/helpers.dart' show tiles;

void main() {
  // Open 234m, concealed 456m 678p 55s 34s, ron on 2s: tanyao is the
  // only yaku, with a non-value pair and a two-sided sequence wait.
  HandScore openHand({bool dealer = false, bool dora = false}) => scoreHand(
        tiles('456m 678p 55s 34s'),
        tiles('2s').single,
        [
          Meld(
            kind: MeldKind.sequence,
            low: TileType.man2,
            concealed: false,
            tiles: tiles('234m'),
          ),
        ],
        ScoreContext(
          roundWind: Wind.east,
          seatWind: dealer ? Wind.east : Wind.south,
          isTsumo: false,
          closed: false,
          doraIndicators: [if (dora) TileType.pin6], // one 7p dora
        ),
        isDealer: dealer,
      );

  for (final (dealer, dora, points) in [
    (false, false, 1000),
    (true, false, 1500),
    (false, true, 2000),
    (true, true, 2900),
  ]) {
    test(
        'open ron: ${dealer ? 'dealer' : 'non-dealer'}, '
        '${dora ? 2 : 1} han scores 30 fu and $points points', () {
      final score = openHand(dealer: dealer, dora: dora);
      expect(score.valid, isTrue);
      expect(score.fu, 30);
      expect(score.han, dora ? 2 : 1);
      expect(score.points, points);
      expect(score.yaku.map((y) => y.name), isNot(contains('Pinfu')));
    });
  }

  test('closed pinfu tsumo still scores 20 fu', () {
    final score = scoreHand(
      tiles('234m 456m 678p 55s 34s'),
      tiles('2s').single,
      const [],
      ScoreContext(
        roundWind: Wind.east,
        seatWind: Wind.south,
        isTsumo: true,
        closed: true,
      ),
      isDealer: false,
    );
    expect(score.valid, isTrue);
    expect(score.yaku.map((y) => y.name), contains('Pinfu'));
    expect(score.fu, 20);
  });

  test('seven pairs still scores 25 fu', () {
    final score = scoreHand(
      tiles('11m 22p 33p 44p 66s 88s 9s'),
      tiles('9s').single,
      const [],
      ScoreContext(
        roundWind: Wind.east,
        seatWind: Wind.south,
        isTsumo: false,
        closed: true,
      ),
      isDealer: false,
    );
    expect(score.valid, isTrue);
    expect(score.fu, 25);
    expect(score.points, 1600);
  });
}
