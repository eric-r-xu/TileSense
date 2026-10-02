/// Which language the app's text is in — a per-device choice, separate from
/// (and the same for) every ruleset. The first visit follows the browser's
/// language; an explicit pick (see `LanguageButton`) is remembered and always
/// wins after that.
library;

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import '../telemetry/src/platform_web.dart'
    if (dart.library.io) '../telemetry/src/platform_stub.dart' as platform;

enum AppLanguage {
  english(Locale('en'), 'English'),
  japanese(Locale('ja'), '日本語'),
  simplifiedChinese(Locale('zh'), '简体中文'),
  traditionalChinese(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), '繁體中文');

  const AppLanguage(this.locale, this.nativeName);

  final Locale locale;

  /// The language's name in itself, so anyone can find their own in a list.
  final String nativeName;

  /// The first of the browser's preferred [locales] we have, or English:
  /// `ja` is Japanese; Chinese is Traditional when its script says Hant or
  /// its region is Taiwan, Hong Kong or Macau, and Simplified otherwise.
  static AppLanguage fromLocales(List<Locale> locales) {
    for (final l in locales) {
      switch (l.languageCode) {
        case 'en':
          return english;
        case 'ja':
          return japanese;
        case 'zh':
          final traditional = l.scriptCode == 'Hant' ||
              const {'TW', 'HK', 'MO'}.contains(l.countryCode);
          return traditional ? traditionalChinese : simplifiedChinese;
      }
    }
    return english;
  }
}

/// The app's current [AppLanguage]; `TileSenseApp` rebuilds on every change,
/// so switching applies at once, mid-game included.
class AppLanguageController extends ValueNotifier<AppLanguage> {
  /// [read]/[write] default to the device's `localStorage` (a no-op off the
  /// web) and [browserLocales] to the platform's; tests pass their own.
  AppLanguageController({
    String? Function(String key)? read,
    void Function(String key, String value)? write,
    List<Locale> Function()? browserLocales,
  })  : _write = write ?? platform.localStorageSet,
        super(_initial(read ?? platform.localStorageGet,
            browserLocales ?? () => PlatformDispatcher.instance.locales));

  static const storageKey = 'ts_language';

  /// The one the app uses.
  static final AppLanguageController instance = AppLanguageController();

  final void Function(String key, String value) _write;

  static AppLanguage _initial(
      String? Function(String) read, List<Locale> Function() browser) {
    final saved = read(storageKey);
    for (final l in AppLanguage.values) {
      if (l.name == saved) return l;
    }
    return AppLanguage.fromLocales(browser());
  }

  /// Switches to [language] and remembers it on this device.
  void select(AppLanguage language) {
    _write(storageKey, language.name);
    value = language;
  }
}
