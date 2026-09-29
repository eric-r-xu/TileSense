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
