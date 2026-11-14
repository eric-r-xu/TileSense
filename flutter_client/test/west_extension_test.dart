import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/online_game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/efficiency_engine.dart';

void main() {
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  GameController start() {
    final game = GameController(seed: 5)..paused = true;
    addTearDown(game.dispose);
    return game;
  }

  // Supply settled scores and an exhaustive-draw result without playing
  // hundreds of unrelated decisions to reach the match-ending boundary.
  void finishHand(GameController game,
      {List<int> points = const [29000, 27000, 24000, 20000],
      bool dealerTenpai = false}) {
    for (var seat = 0; seat < 4; seat++) {
      game.round.seats[seat].points = points[seat];
    }
    game.round.phase = RoundPhase.finished;
    game.round.result = RoundResult(
      kind: RoundEndKind.exhaustiveDraw,
      winners: const [],
      pointDeltas: const {},
      label: 'Exhaustive draw',
      tenpaiAtDraw: [if (dealerTenpai) game.round.dealer],
    );
    game.phase = GamePhase.roundEnd;
    game.continueFromRoundEnd();
  }

  void reachSouth4(GameController game) {
    for (var hand = 0; hand < 7; hand++) {
      finishHand(game);
    }
    expect(game.roundNumber, 7);
    expect(game.roundWind, Wind.south);
    expect(game.handInWind, 4);
  }

  test('South 4 below target deals West 1 with West wind and carried honba',
      () {
    final game = start();
    reachSouth4(game);
    finishHand(game);

    expect(game.phase, GamePhase.playing);
    expect(game.roundNumber, 8);
    expect(game.handInWind, 1);
    expect(game.roundWind, Wind.west);
    expect(game.round.roundWind, Wind.west);
    expect(game.round.dealer, 0);
    expect(game.honba, 8);
    expect(game.tablePoints, [29000, 27000, 24000, 20000]);

    finishHand(game, points: [30000, 26000, 24000, 20000]);
    expect(game.phase, GamePhase.gameEnd);
  });

  test('South 4 at exactly 30,000 ends without a West hand', () {
    final game = start();
    reachSouth4(game);
    finishHand(game, points: [30000, 26000, 24000, 20000]);
    expect(game.phase, GamePhase.gameEnd);
    expect(game.round.roundWind, Wind.south);
  });

  test('South 4 repeats before entering West', () {
    final game = start();
    reachSouth4(game);
    finishHand(game, dealerTenpai: true);
    expect(game.phase, GamePhase.playing);
    expect(game.roundNumber, 7);
    expect(game.roundWind, Wind.south);
    expect(game.dealerRepeat, 1);

    finishHand(game);
    expect(game.phase, GamePhase.playing);
    expect(game.roundNumber, 8);
    expect(game.round.roundWind, Wind.west);
  });

  test('West 4 can repeat, then ends without a North extension', () {
    final game = start();
    reachSouth4(game);
    for (var hand = 0; hand < 4; hand++) {
      finishHand(game);
    }
    expect(game.roundNumber, 11);
    expect(game.roundWind, Wind.west);
    expect(game.handInWind, 4);

    finishHand(game, dealerTenpai: true);
    expect(game.phase, GamePhase.playing);
    expect(game.roundNumber, 11);
    finishHand(game);
    expect(game.phase, GamePhase.gameEnd);
    expect(game.round.roundWind, Wind.west);
  });

  test('online West rounds use the final-hand guide settings', () {
    final game = OnlineGameController();
    addTearDown(game.dispose);
    game.round = Round.posed(
      dealer: 0,
      roundWind: Wind.west,
      wall: Wall.posed(remaining: 0, dora: const []),
      startingPoints: const [29000, 27000, 24000, 20000],
    );
    expect(game.playStyle, PlayStyle.balanced);
  });
}
