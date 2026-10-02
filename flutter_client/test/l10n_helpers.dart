import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilesense/l10n/app_language.dart';
import 'package:tilesense/l10n/l10n.dart';
import 'package:tilesense/main.dart' show kDesignSize;

/// Pumps [home] on its own, wired to the app's language the way
/// `TileSenseApp` is, so switching languages rebuilds it in place.
Future<void> pumpLocalized(WidgetTester tester, Widget home,
    {Size size = kDesignSize}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ValueListenableBuilder<AppLanguage>(
    valueListenable: AppLanguageController.instance,
    builder: (_, language, __) => MaterialApp(
      locale: language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}
