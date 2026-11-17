import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/mahjong_core.dart';
import 'package:tilesense/game/game_controller.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/l10n/mahjong_terms.dart';
import 'package:tilesense/ui/hand_view.dart';

/// Render the action combinations directly: rules legality is covered by the
/// engine tests; these check that every offered control is visible and tappable.
class _ActionGame extends GameController {
  _ActionGame(Ruleset ruleset, this.l10n) : super(seed: 4, ruleset: ruleset) {
    paused = true;
    round.phase = RoundPhase.discarding;
    for (final seat in round.activeSeats) {
      seat.flowers.clear();
    }
  }

  final AppLocalizations l10n;
  String mode = 'call';
  bool undoOffered = false;
  int taps = 0;

  @override
  bool get awaitingHumanCall => mode == 'call';
  @override
  bool get awaitingHumanVoidSuit => mode == 'void';
  @override
  bool get isHumanTurn => mode == 'turn';
  @override
  bool get canUndo => undoOffered;
  @override
  String get undoLabel => ' ${l10n.tileDisplayName(TileType.pin5)}';
  @override
  bool get humanFuriten => false;
  @override
  MinimumShortfall get humanMinimumShortfall => MinimumShortfall.none;
  @override
  CallOption get humanCallOption => CallOption(0, {
        CallType.ron,
        CallType.pon,
        CallType.kan,
        if (!ruleset.isSanma && !ruleset.isSichuan) CallType.chi,
      });
  @override
  List<TileType> get humanChiRuns =>
      [TileType.pin3, TileType.pin4, TileType.pin5];
  @override
  bool get humanCanTsumo => mode == 'turn';
  @override
  bool get humanCanKita => mode == 'turn' && ruleset.isSanma;
  @override
  bool get humanCanRiichi => mode == 'turn' && ruleset.isJapanese;
  @override
  bool get humanCanDeclareKyuushu => false;
  @override
  List<TileType> get humanClosedKanTypes =>
      mode == 'turn' ? [TileType.pin5, TileType.sou5] : [];
  @override
  List<TileType> get humanAddedKanTypes =>
      mode == 'turn' ? [TileType.pin9] : [];
  @override
  void answerCall(CallType choice, {TileType? chiLow}) {
    taps++;
  }

  @override
  void humanClosedKan(TileType type) {
    taps++;
  }

  @override
  void humanAddKan(TileType type) {
    taps++;
  }

  @override
  void humanTsumo() {
    taps++;
  }

  @override
  void humanKita() {
    taps++;
  }

  @override
  void humanDeclareVoidSuit(int suit) {
    taps++;
  }

  @override
  void undo() {
    taps++;
  }
}

void main() {
  setUpAll(() async {
    // Use actual font metrics: the test binding's square font can hide the
    // 53px phone buttons that overflowed the old 48px action row.
    final cache = File(Platform.resolvedExecutable).parent.parent.parent.parent;
    final files = Directory('${cache.path}/artifacts/material_fonts')
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.uri.pathSegments.last.startsWith('Roboto-') &&
            f.path.endsWith('.ttf'))
        .toList();
    expect(files, isNotEmpty);
    final loader = FontLoader('Roboto');
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  });
  setUp(() => Sfx.i.enabled = false);
  tearDown(() => Sfx.i.enabled = true);

  Future<void> pumpBar(WidgetTester tester, _ActionGame game, Locale locale,
      {double scale = 1.35, double width = 1600}) async {
    await tester.binding.setSurfaceSize(Size(width, 820));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 820),
            textScaler: TextScaler.linear(scale),
            disableAnimations: true),
        child: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: HandView(game: game))),
      ),
    ));
    await tester.pump();
  }

  Future<void> checkButtons(WidgetTester tester, _ActionGame game) async {
    final bar = tester.getRect(find.byKey(const Key('handActionBar')));
    final buttons = find.descendant(
        of: find.byKey(const Key('handActionBar')),
        matching: find.byWidgetPredicate(
            (w) => w is ElevatedButton || w is OutlinedButton));
    expect(buttons, findsWidgets);
    final rects = <Rect>[];
    for (final element in buttons.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.top, greaterThanOrEqualTo(bar.top - 0.1));
      expect(rect.bottom, lessThanOrEqualTo(bar.bottom + 0.1),
          reason: 'the bottom of an action button is clipped');
      expect(rect.left, greaterThanOrEqualTo(bar.left - 0.1));
      expect(rect.right, lessThanOrEqualTo(bar.right + 0.1));
      for (final other in rects) {
        expect(rect.overlaps(other), isFalse,
            reason: 'Undo and the call choices must have separate hit areas');
      }
      rects.add(rect);
      final before = game.taps;
      // The lower edge was outside the old clipped row's hit-test bounds.
      await tester.tapAt(Offset(rect.center.dx, rect.bottom - 2));
      expect(game.taps, before + 1);
    }
    expect(tester.takeException(), isNull);
  }

  for (final ruleset in Ruleset.values) {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('${ruleset.name}: full action buttons in $locale',
          (tester) async {
        final game = _ActionGame(ruleset, lookupAppLocalizations(locale));
        try {
          for (final scale in [1.0, 1.35]) {
            for (final undo in [false, true]) {
              game.undoOffered = undo;
              for (final mode in [
                'call',
                'turn',
                if (ruleset.isSichuan) 'void'
              ]) {
                game.mode = mode;
                await pumpBar(tester, game, locale, scale: scale);
                await checkButtons(tester, game);
                if (mode == 'turn') {
                  expect(
                      find.textContaining(game.l10n.tilePin(5)), findsWidgets);
                  expect(find.textContaining('5p'), findsNothing);
                }
              }
            }
          }
        } finally {
          game.dispose();
          await tester.pumpWidget(const SizedBox());
          await tester.binding.setSurfaceSize(null);
        }
      });
    }
  }

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('crowded $locale call choices wrap without clipping',
        (tester) async {
      final game = _ActionGame(Ruleset.riichi, lookupAppLocalizations(locale))
        ..undoOffered = true;
      try {
        await pumpBar(tester, game, locale, width: 700);
        await checkButtons(tester, game);
        expect(tester.getRect(find.byKey(const Key('handActionBar'))).height,
            greaterThan(64),
            reason: 'the row must grow for wrapped choices');
      } finally {
        game.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.binding.setSurfaceSize(null);
      }
    });
  }
}
