import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/logic/round.dart';
import 'package:tilesense/logic/tile.dart';
import 'package:tilesense/logic/wall.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/hand_view.dart';
import 'package:tilesense/ui/scoring_view.dart';
import 'package:tilesense/ui/tile_face.dart';
import 'helpers.dart';

const captureKey = Key('hkCapture');
Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['HK_SCREENSHOTS'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = Platform.environment['HK_SCREENSHOT_FONT'];
    if (font == null) return;
    final bytes = await File(font).readAsBytes();
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });
  setUp(() {
    // Screenshot capture runs real async work, including audio initialization.
    // Native audio plugins are unavailable in the widget-test runner.
    for (final channel in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers/events/tilesense-sfx',
      'xyz.luan/audioplayers/events/tilesense-voice',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    Sfx.i.enabled = false;
  });
  tearDown(() => Sfx.i.enabled = true);
  testWidgets('builder offers flowers and hides Japanese rule controls',
      (tester) async {
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        const RepaintBoundary(key: captureKey, child: TileSenseApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('openBuilder')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Random'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Your flowers (0)'));
    await tester.pump(const Duration(milliseconds: 100));
    final flower =
        find.byWidgetPredicate((w) => w is TileFace && w.type == TileType.plum);
    await tester.tap(flower.first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Your flowers (1)'), findsOneWidget);
    expect(find.text('Red 5'), findsNothing);
    expect(find.textContaining('Dora'), findsNothing);
    expect(find.text('RIICHI'), findsNothing);
    expect(find.text('FURITEN'), findsNothing);
    expect(find.text('Honba'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, 'hk-builder');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('flower-win action can be declined from the hand bar',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    game.togglePause();
    try {
      final r = Round.posed(
          dealer: 0,
          roundWind: Wind.east,
          wall: Wall.fromTiles(
              [Tile(900, TileType.autumn), Tile(901, TileType.pin8)]),
          startingPoints: List.filled(4, 1000));
      game.round = r;
      r.seats[0].hand = parseTiles('123m 456p 789s 22m 55p');
      r.seats[0].flowers = [
        for (var i = 35; i < 41; i++) Tile(800 + i, TileType.values[i])
      ];
      r.seats[3].hand = [Tile(903, TileType.man9)];
      r.turn = 3;
      r.discard(3, r.seats[3].hand.single);
      expect(r.canFlowerWin(0), isTrue);
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: HandView(game: game, onToggleGuide: () {}))));
      expect(find.text('FLOWER WIN'), findsOneWidget);
      await tester.tap(find.text('CONTINUE DRAWING'));
      await tester.pump();
      expect(r.canFlowerWin(0), isFalse);
      expect(r.seats[0].drawn!.type, TileType.pin8);
      expect(tester.takeException(), isNull);
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
  testWidgets('score view uses faan and renders a self-picked tile once',
      (tester) async {
    Sfx.i.enabled = false;
    final game = GameController(seed: 5);
    game.togglePause();
    try {
      final r = Round.posed(
          dealer: 0,
          roundWind: Wind.east,
          wall: Wall.fromTiles([Tile(990, TileType.man9)]),
          startingPoints: List.filled(4, 1000));
      final win = Tile(900, TileType.pin5);
      r.turn = 1;
      r.seats[1].hand = [...parseTiles('123m 456p 789s 22m 55p'), win];
      r.seats[1].drawn = win;
      r.declareTsumo(1);
      game.round = r;
      game.phase = GamePhase.roundEnd;
      await tester.binding.setSurfaceSize(kDesignSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(RepaintBoundary(
          key: captureKey,
          child: MaterialApp(home: Scaffold(body: ScoringView(game: game)))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byWidgetPredicate((w) => w is TileFace && w.tile == win),
          findsOneWidget);
      expect(find.textContaining('faan —'), findsOneWidget);
      expect(find.textContaining(' fu'), findsNothing);
      expect(find.textContaining('Dora'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, 'hk-scoring');
    } finally {
      game.dispose();
      Sfx.i.enabled = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}
