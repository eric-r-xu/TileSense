import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'support/riichi_calibration_log.dart';

void main() {
  test('snapshots all candidates, labels only chosen actions and future tenpai',
      () {
    final log = RiichiCalibrationLog(seed: 7, metadata: {'policy': 'baseline'});
    final hand = ['1m', '5mr'];
    void record(int shanten) => log.record(
          state: {'hand': hand},
          candidates: [
            {'discard': '5m', 'shanten': shanten, 'winProbability': .123456789},
            {'discard': '1m', 'shanten': 2, 'winProbability': .1},
          ],
          chosenTile: '5mr',
          teacher: {
            'q': {'5mr': 1.23456789}
          },
        );
    record(1);
    record(0); // Reaches tenpai, then breaks it while folding.
    record(1);
    hand.clear();
    log.finishHand(
        won: false,
        dealIn: false,
        finalTenpai: false,
        endKind: 'exhaustiveDraw',
        netPoints: -1000);
    record(2); // Dealer repeats are a new hand even if kyoku is unchanged.
    log.finishHand(
        won: true,
        dealIn: false,
        finalTenpai: false,
        endKind: 'ron',
        netPoints: 9000,
        baseWinPoints: 8000);
    final rows =
        log.finishGame(fallbacks: 0).map((s) => jsonDecode(s) as Map).toList();
    expect(rows.length, 4);
    expect(rows.take(3).map((r) => r['outcome']['reachedTenpai']),
        [true, true, false]);
    expect(rows[0]['state']['hand'], ['1m', '5mr']);
    expect(rows[0]['candidates'].length, 2);
    expect(rows[0]['candidates'][1].containsKey('outcome'), isFalse);
    expect(rows[0]['chosen']['winProbability'], .123456789);
    expect(rows[0]['outcome']['baseWinPoints'], isNull);
    expect(rows[3]['outcome']['baseWinPoints'], 8000);
    expect(rows.map((r) => r['handIndex']), [0, 0, 0, 1]);
    expect(rows.every((r) => r['validGame'] == true), isTrue);
  });

  test('a later fallback invalidates earlier decisions in the game', () {
    final log = RiichiCalibrationLog(seed: 0, metadata: {});
    log.record(state: {}, candidates: [
      {'discard': '1m', 'shanten': 1}
    ], chosenTile: '1m', teacher: null, teacherError: 'offline');
    log.finishHand(
        won: false,
        dealIn: true,
        finalTenpai: false,
        endKind: 'ron',
        netPoints: -8000);
    final row = jsonDecode(log.finishGame(fallbacks: 1).single);
    expect(row['validGame'], false);
    expect(row['teacherError'], 'offline');
  });

  test('unfinished hands cannot masquerade as losses', () {
    final log = RiichiCalibrationLog(seed: 0, metadata: {});
    log.record(state: {}, candidates: [
      {'discard': '1m', 'shanten': 1}
    ], chosenTile: '1m', teacher: null);
    expect(() => log.finishGame(fallbacks: 0).toList(), throwsStateError);
  });
}
