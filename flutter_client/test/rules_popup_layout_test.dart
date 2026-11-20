import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';
import 'package:tilesense/main.dart';

import 'helpers.dart';
import 'loading_helpers.dart';

/// Switching rules on the title screen shows every style at once: the popup
/// lays them out side by side instead of in a column that scrolls.
void main() {
  preloadDeferredPages();

  for (final size in [
    kDesignSize,
    const Size(393, 852),
    const Size(640, 320),
    const Size(852, 393)
  ]) {
    testWidgets(
        'all seven rulesets fit the Rules popup without scrolling, $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TileSenseApp());
      await tester.pump(const Duration(milliseconds: 100));
      await openPopup(tester, 'rulesTile');

      final popup = tester.getRect(find.byKey(const Key('rulesPopup')));
      for (final r in Ruleset.values) {
        for (final prefix in ['ruleset_', 'rulesRead_', 'rulesPdf_']) {
          final rect = tester.getRect(find.byKey(Key('$prefix${r.name}')));
          expect(
              popup.contains(rect.topLeft) && popup.contains(rect.bottomRight),
              isTrue,
              reason: '$prefix${r.name} $rect is inside the popup $popup');
        }
      }
      expect(
          find.descendant(
              of: find.byKey(const Key('rulesPopup')),
              matching: find.byType(Scrollable)),
          findsNothing);
      expect(find.byKey(const Key('ruleset_fuzhou')).hitTestable(),
          findsOneWidget);
      // Side by side, not one per row.
      final tops = {
        for (final r in Ruleset.values)
          tester.getTopLeft(find.byKey(Key('ruleset_${r.name}'))).dy.round()
      };
      expect(tops.length, lessThan(Ruleset.values.length));
      expect(tester.takeException(), isNull);
    });
  }
}
