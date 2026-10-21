import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/ui/bar_back_button.dart';
import 'package:tilesense/ui/language_button.dart';
import 'package:tilesense/ui/screen_scaffold.dart';
import 'package:tilesense/ui/theme.dart';

import 'l10n_helpers.dart';

/// The frame the welcome-adjacent screens share.
void main() {
  Future<void> pump(WidgetTester tester,
      {required VoidCallback onBack, Widget? footer, Widget? child}) {
    return pumpLocalized(
        tester,
        ScreenScaffold(
          backKey: const Key('testBack'),
          onBack: onBack,
          footer: footer,
          child: child ?? const SizedBox(key: Key('content'), height: 40),
        ),
        size: const Size(1600, 820));
  }

  testWidgets('has Back top-left, the language picker top-right, on the felt',
      (tester) async {
    var backs = 0;
    await pump(tester, onBack: () => backs++);

    final back = tester.getRect(find.byKey(const Key('testBack')));
    final language = tester.getRect(find.byType(LanguageButton));
    expect(back.left, lessThan(80));
    expect(back.top, lessThan(40));
    expect(language.right, greaterThan(1500));
    expect(language.top, lessThan(40));
    expect(
        tester
            .widget<Material>(find.descendant(
                of: find.byType(ScreenScaffold),
                matching: find.byType(Material).first))
            .color,
        AppColors.background);

    await tester.tap(find.byKey(const Key('testBack')));
    expect(backs, 1);
  });

  testWidgets('centres short content, and scrolls tall content',
      (tester) async {
    await pump(tester, onBack: () {});
    final c = tester.getCenter(find.byKey(const Key('content')));
    expect(c.dy, closeTo(410, 2), reason: 'centred on a tall canvas');

    await pump(tester,
        onBack: () {}, child: const SizedBox(key: Key('tall'), height: 2000));
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -600));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('tall'))).dy, lessThan(-300),
        reason: 'the page scrolls rather than overflowing');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a footer stays pinned under the content while it scrolls',
      (tester) async {
    await pump(tester,
        onBack: () {},
        footer: BackFooter(
            buttonKey: const Key('footerBack'),
            label: 'Back to menu',
            tooltip: 'Back',
            onPressed: () {}),
        child: const SizedBox(key: Key('tall'), height: 2000));
    final before = tester.getRect(find.byKey(const Key('footerBack')));
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -600));
    await tester.pump();
    expect(tester.getRect(find.byKey(const Key('footerBack'))), before);
    expect(before.bottom, greaterThan(760));
  });

  testWidgets('without a footer nothing is pinned', (tester) async {
    await pump(tester, onBack: () {});
    expect(find.byType(BackFooter), findsNothing);
  });
}
