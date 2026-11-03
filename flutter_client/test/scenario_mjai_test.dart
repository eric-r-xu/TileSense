import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/meld.dart';
import 'package:mahjong_core/mjai.dart';
import 'package:mahjong_core/tile.dart';
import 'package:tilesense/scenario/scenario.dart';
import 'package:tilesense/scenario/scenario_mjai.dart';

import 'helpers.dart';

void main() {
  Scenario table({String hand = '123m 456m 789m 23p 55s', String? drawn}) {
    final sc = Scenario();
    for (final t in parseTypes(hand)) {
      sc.hand.add(sc.mint(t));
    }
    if (drawn != null) sc.hand.add(sc.mint(parseTypes(drawn).single));
    return sc;
  }

  void pond(Scenario sc, int seat, String tiles) {
    for (final t in parseTypes(tiles)) {
      sc.seats[seat].pond.add(sc.mint(t));
    }
  }

  /// Your hand after [events], failing if you ever cut or call with a tile
  /// you don't hold.
  List<String> replayHand(List<MjaiEvent> events) {
    final hand = [...(events.first['tehais'] as List)[0] as List<String>];
    void take(String t) {
      expect(hand.remove(t), isTrue, reason: 'you do not hold $t');
    }

    for (final e in events.skip(1)) {
      if (e['actor'] != 0) continue;
      switch (e['type']) {
        case 'tsumo':
          hand.add(e['pai'] as String);
        case 'dahai':
          take(e['pai'] as String);
        case 'chi' || 'pon' || 'daiminkan' || 'ankan':
          (e['consumed'] as List).cast<String>().forEach(take);
      }
    }
    return hand..sort();
  }

  List<String> mjai(List<Tile> tiles) =>
      [for (final t in tiles) mjaiTile(t)]..sort();

  int tilesLeft(List<MjaiEvent> events) =>
      70 - events.where((e) => e['type'] == 'tsumo').length;

  List<String> cutBy(List<MjaiEvent> events, int seat) => [
        for (final e in events)
          if (e['type'] == 'dahai' && e['actor'] == seat) e['pai'] as String
      ];

  test('a discard read ends on your draw, with the wall and ponds as posed',
      () {
    final sc = table(drawn: '9p')
      ..wallRemaining = 50
      ..seatWind = Wind.south; // seat 3 deals
    pond(sc, 0, 'E 9s');
    pond(sc, 1, 'S');
    pond(sc, 3, 'W N R');
    final events = scenarioMjaiEvents(sc)!;

    expect(events.first['oya'], 3);
    expect(events.last, {'type': 'tsumo', 'actor': 0, 'pai': '9p'});
    expect(replayHand(events), mjai(sc.hand));
    expect(tilesLeft(events), 50);
    expect(cutBy(events, 0), ['E', '9s']);
    expect(cutBy(events, 1), ['S']);
    expect(cutBy(events, 2), isEmpty);
    expect(cutBy(events, 3), ['W', 'N', 'C']);
    // Turns go round from the dealer: West, then you, then South.
    expect(
        [
          for (final e in events)
            if (e['type'] == 'dahai') e['pai']
        ].take(3),
        ['W', 'E', 'S']);
  });

  test('a call read ends on the offered tile being cut', () {
    final sc = table()
      ..offered = Tile(900, TileType.sou5)
      ..offeredFrom = 3;
    final events = scenarioMjaiEvents(sc)!;
    expect(events.last,
        {'type': 'dahai', 'actor': 3, 'pai': '5s', 'tsumogiri': false});
    expect(replayHand(events), mjai(sc.hand));
  });

  group('tsumogiri and tedashi', () {
    /// The `tsumogiri` flag on each of [seat]'s cuts, in order.
    List<bool> flagsOf(List<MjaiEvent> events, int seat) => [
          for (final e in events)
            if (e['type'] == 'dahai' && e['actor'] == seat)
              e['tsumogiri'] as bool
        ];

    test('a riichi seat\'s cuts after its declaration are tsumogiri', () {
      final sc = table(drawn: '9p');
      pond(sc, 1, 'E S W N 1m');
      sc.seats[1]
        ..riichi = true
        ..riichiPondIndex = 1;
      final events = scenarioMjaiEvents(sc)!;

      // E before riichi and S, the riichi cut itself, are tedashi; the posed
      // table can't say otherwise. Everything after the declaration is forced.
      expect(flagsOf(events, 1), [false, false, true, true, true]);
      // The declaration still brackets exactly the riichi cut.
      final types = [
        for (final e in events)
          if (e['actor'] == 1 &&
              (e['type'] == 'reach' ||
                  e['type'] == 'dahai' ||
                  e['type'] == 'reach_accepted'))
            e['type']
      ];
      expect(types, [
        'dahai',
        'reach',
        'dahai',
        'reach_accepted',
        'dahai',
        'dahai',
        'dahai'
      ]);
    });

    test('a riichi on the last tile leaves nothing to lock', () {
      final sc = table(drawn: '9p');
      pond(sc, 2, 'E S W');
      sc.seats[2]
        ..riichi = true
        ..riichiPondIndex = 2;
      expect(flagsOf(scenarioMjaiEvents(sc)!, 2), [false, false, false]);
    });

    test('a seat that has not declared riichi cuts from hand, whoever has', () {
      final sc = table(drawn: '9p');
      pond(sc, 1, 'E S W');
      pond(sc, 2, 'N 1m 2m');
      sc.seats[1]
        ..riichi = true
        ..riichiPondIndex = 0;
      final events = scenarioMjaiEvents(sc)!;
      expect(flagsOf(events, 1), [false, true, true]);
      expect(flagsOf(events, 2), [false, false, false]);
      expect(flagsOf(events, 3), isEmpty);
    });

    test('your own cuts of your draws stay tsumogiri, riichi or not', () {
      final sc = table(drawn: '9p');
      pond(sc, 0, 'E 9s N');
      expect(flagsOf(scenarioMjaiEvents(sc)!, 0), [true, true, true]);
      sc.seats[0]
        ..riichi = true
        ..riichiPondIndex = 1;
      expect(flagsOf(scenarioMjaiEvents(sc)!, 0), [true, true, true]);
    });
  });

  test('your pon is made on its target\'s cut, and paid for from your pond',
      () {
    final sc = table(hand: '123m 456m 789m 5s', drawn: '9p');
    sc.seats[0].melds.add(Meld(
        kind: MeldKind.triplet,
        low: TileType.haku,
        concealed: false,
        calledFromSeatOffset: 2));
    pond(sc, 0, 'E 9s');
    final events = scenarioMjaiEvents(sc)!;

    final i = events.indexWhere((e) => e['type'] == 'pon');
    expect(events[i - 1],
        {'type': 'dahai', 'actor': 2, 'pai': 'P', 'tsumogiri': false});
    expect(events[i]['consumed'], ['P', 'P']);
    expect(events[i + 1],
        {'type': 'dahai', 'actor': 0, 'pai': 'E', 'tsumogiri': false});
    expect(replayHand(events), mjai(sc.hand));
    expect(cutBy(events, 2), ['P']);
  });

  test('your kans draw their replacement and cut it', () {
    final sc = table(hand: '123m 456m 789m 5s', drawn: '9p')
      ..dora.add(TileType.pin1);
    sc.seats[0].melds
        .add(Meld(kind: MeldKind.kan, low: TileType.chun, concealed: true));
    pond(sc, 0, '9s');
    final events = scenarioMjaiEvents(sc)!;
    expect(events.where((e) => e['type'] == 'ankan').single['consumed'],
        ['C', 'C', 'C', 'C']);
    expect(
        events.where((e) => e['type'] == 'dora').single['dora_marker'], '1p');
    expect(replayHand(events), mjai(sc.hand));
  });

  test('a riichi is declared on its pond tile', () {
    final sc = table(drawn: '9p');
    pond(sc, 1, 'E S W');
    sc.seats[1]
      ..riichi = true
      ..riichiPondIndex = 1;
    final events = scenarioMjaiEvents(sc)!;
    final i = events.indexWhere((e) => e['type'] == 'reach');
    expect(events[i + 1]['pai'], 'S');
    expect(events[i + 2], {'type': 'reach_accepted', 'actor': 1});
  });

  test('no history when your pond cannot pay for your calls, or past 4 kans',
      () {
    final short = table(hand: '123m 456m 789m 5s', drawn: '9p');
    short.seats[0].melds.add(Meld(
        kind: MeldKind.triplet,
        low: TileType.haku,
        concealed: false,
        calledFromSeatOffset: 2));
    expect(scenarioMjaiEvents(short), isNull);

    final kans = table(drawn: '9p');
    for (final (seat, type) in [
      (1, TileType.ton),
      (1, TileType.nan),
      (2, TileType.shaa),
      (2, TileType.pei),
      (3, TileType.hatsu),
    ]) {
      kans.seats[seat].melds
          .add(Meld(kind: MeldKind.kan, low: type, concealed: true));
    }
    expect(scenarioMjaiEvents(kans), isNull);
  });
}
