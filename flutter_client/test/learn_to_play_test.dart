import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/game/sfx.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/main.dart';
import 'package:tilesense/ui/learn_to_play_page.dart';

void main() {
  Future<void> boot(WidgetTester tester) async {
    Sfx.i.enabled = false;
    addTearDown(() => Sfx.i.enabled = true);
    await tester.binding.setSurfaceSize(kDesignSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TileSenseApp());
    await tester.pump(const Duration(milliseconds: 100));
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  setUp(() {
    LearnToPlay.autoShow = true;
    LearnToPlay.reset();
  });
  tearDown(() => LearnToPlay.autoShow = false);

  testWidgets('the first Start opens the lesson, then character select',
      (tester) async {
    await boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();

    expect(find.byKey(const Key('learnTitle')), findsOneWidget);
    expect(text(tester, 'learnStep'), '1 of 4');
    expect(find.byKey(const Key('charactersContinue')), findsNothing);

    for (final step in ['2', '3', '4']) {
      await tester.tap(find.byKey(const Key('learnNext')));
      await tester.pump();
      expect(text(tester, 'learnStep'), '$step of 4');
    }
    expect(find.byKey(const Key('learnNext')), findsNothing);
    expect(text(tester, 'learnBody'), contains('0 faan'),
        reason: 'Hong Kong is the default, and its minimum is 0');
    expect(find.byKey(const Key('learnRulesPdf')), findsOneWidget);

    await tester.tap(find.byKey(const Key('learnDone')));
    await tester.pump();
    expect(find.byKey(const Key('charactersContinue')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it is shown once: Start skips it afterwards', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('learnSkip')));
    await tester.pump();
    expect(find.byKey(const Key('charactersContinue')), findsOneWidget);

    await tester.tap(find.byKey(const Key('charactersBack')));
    await tester.pump();
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    expect(find.byKey(const Key('learnTitle')), findsNothing);
    expect(find.byKey(const Key('charactersContinue')), findsOneWidget);
  });

  testWidgets('Back steps back, and leaves from the first card without '
      'marking it seen', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Single Player'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('learnNext')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('learnBack')));
    await tester.pump();
    expect(text(tester, 'learnStep'), '1 of 4');

    await tester.tap(find.byKey(const Key('learnBack')));
    await tester.pump();
    expect(find.byKey(const Key('learnTitle')), findsNothing);
    expect(LearnToPlay.shouldAutoShow, isTrue);
  });

  testWidgets('the welcome link reopens it and returns to the welcome screen',
      (tester) async {
    LearnToPlay.markSeen();
    await boot(tester);
    await tester.tap(find.byKey(const Key('learnToPlay')));
    await tester.pump();
    expect(find.byKey(const Key('learnTitle')), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('learnNext')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('learnDone')));
    await tester.pump();
    expect(find.byKey(const Key('charactersContinue')), findsNothing);
    expect(find.text('Single Player'), findsOneWidget);
  });

  testWidgets('the last card speaks of the chosen ruleset', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('ruleset_taiwanese')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('learnToPlay')));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('learnNext')));
      await tester.pump();
    }
    expect(text(tester, 'learnBody'), contains('Taiwanese'));
    expect(text(tester, 'learnBody'), isNot(contains('0 faan')));
  });

  testWidgets('every card fits, in every language, on a desktop and a phone',
      (tester) async {
    addTearDown(() => AppLanguageController.instance
        .select(AppLanguage.english));
    for (final size in [kDesignSize, const Size(844, 390)]) {
      for (final language in AppLanguage.values) {
        AppLanguageController.instance.select(language);
        Sfx.i.enabled = false;
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(const TileSenseApp());
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const Key('learnToPlay')));
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          expect(tester.takeException(), isNull,
              reason: '${language.name} $size card ${i + 1}');
          if (i < 3) {
            await tester.ensureVisible(find.byKey(const Key('learnNext')));
            await tester.tap(find.byKey(const Key('learnNext')));
            await tester.pump();
          }
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Sfx.i.enabled = true;
  });
}
