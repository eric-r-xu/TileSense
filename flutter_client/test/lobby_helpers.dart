import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahjong_core/ruleset.dart';

/// Open the create-room dropdown [dropdown] and choose its item [item].
///
/// Fixed pumps rather than `pumpAndSettle`: the online page animates
/// continuously, so it never settles (see `pumpLoadedPage`). The item is
/// found `.last` because the selected one is built twice while the menu is
/// open — once in the closed button, once in the menu.
Future<void> pickLobbyDropdown(WidgetTester tester, Key dropdown, Key item) async {
  await tester.tap(find.byKey(dropdown));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(item).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Choose [ruleset] in the online lobby's Rules dropdown.
Future<void> pickOnlineRuleset(WidgetTester tester, Ruleset ruleset) =>
    pickLobbyDropdown(tester, const Key('onlineRulesetDropdown'),
        Key('onlineRuleset_${ruleset.name}'));

/// The ruleset the online lobby's Rules dropdown shows.
Ruleset onlineRulesetShown(WidgetTester tester) => tester
    .widget<DropdownButton<Ruleset>>(
        find.byKey(const Key('onlineRulesetDropdown')))
    .value!;
