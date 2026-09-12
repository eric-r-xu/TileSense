import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/logic/efficiency_engine.dart';
import 'package:tilesense/logic/hand_parse.dart';
import 'package:tilesense/logic/scoring.dart';
import 'package:tilesense/logic/tile.dart';
import 'helpers.dart';
import 'hk_helpers.dart';

void main() {
  const hand = '123m 456p 789s 22m 55p N';
  test('ready value uses the supplied Hong Kong payment table', () {
    final report = hkReport(hand);
    final line = report.lines.singleWhere((l) => l.discard == TileType.pei);
    final rest = parseTiles('123m 456p 789s 22m 55p');
    var weighted = 0.0, copies = 0;
    for (final wait in waitTiles(rest)) {
      final n = 4 - rest.where((t) => t.type == wait).length;
      final scores = [
        for (final self in [false, true])
          scoreHand(
              rest,
              Tile(900, wait),
              [],
              ScoreContext(
                  roundWind: Wind.east,
                  seatWind: Wind.south,
                  isTsumo: self,
                  closed: true),
              isDealer: false)
      ];
      weighted += n * (.65 * scores[0].points + .35 * scores[1].points);
      copies += n;
    }
    expect(line.shanten, 0);
    expect(line.averagePoints, closeTo(weighted / copies, 1e-8));
    expect(line.expectedValue, greaterThan(0));
    expect(line.recommendRiichi, isFalse);
  });
  test('legacy riichi, indicators and deposits do not alter estimates', () {
    final plain = hkReport(hand), legacy = hkReport(hand, legacy: true);
    for (final line in plain.lines) {
      final other = legacy.lines.singleWhere((l) => l.discard == line.discard);
      expect(other.expectedValue, closeTo(line.expectedValue, 1e-8));
      expect(other.riichiLockCost, 0);
      expect(other.recommendRiichi, isFalse);
    }
  });
  test('no dealer multiplier when the hand has no wind sets', () {
    final plain = hkReport(hand), dealer = hkReport(hand, seat: Wind.east);
    for (final line in plain.lines) {
      expect(
          dealer.lines
              .singleWhere((l) => l.discard == line.discard)
              .averagePoints,
          line.averagePoints);
    }
  });
  test('more remaining draws increases win probability', () {
    final early = hkReport(hand, wall: 64)
        .lines
        .singleWhere((l) => l.discard == TileType.pei);
    final late = hkReport(hand, wall: 8)
        .lines
        .singleWhere((l) => l.discard == TileType.pei);
    expect(early.winProbability, greaterThan(late.winProbability));
    expect(early.winProbability, lessThan(1));
    expect(hkReport(hand, wall: 0).lines.every((l) => l.winProbability == 0),
        isTrue);
  });
  test('exposed-hand threat adds risk without guaranteed safe tiles', () {
    final report = hkReport(hand, threat: true);
    expect(report.defending, isTrue);
    expect(report.defense.any((r) => r.isSafe), isFalse);
    expect(report.lines.any((l) => l.dealInCost > 0), isTrue);
  });
  for (final focus in HandFocus.values) {
    for (final style in PlayStyle.values) {
      test('EV arithmetic and recommendation: ${focus.name}/${style.name}', () {
        final report = hkReport(hand, threat: true, focus: focus, style: style);
        for (final line in report.lines) {
          expect(
              line.expectedValue,
              closeTo(
                  line.winProbability * line.averagePoints +
                      line.valueTilt -
                      line.dealInCost -
                      line.commitmentCost,
                  1e-8));
        }
        final best = report.lines.singleWhere((l) => l.recommended);
        expect(
            report.lines
                .every((l) => l.expectedValue <= best.expectedValue + 1e-8),
            isTrue);
      });
    }
  }
}
