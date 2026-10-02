/// `context.l10n` — this screen's text in the current language.
library;

import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension ErrorText on AppLocalizations {
  /// A server error frame's `code` (see server/mp errorFrame), or this
  /// client's own, in the current language; [fallback] (the server's English
  /// message) for a code this client doesn't know yet.
  String errorText(String? code, String fallback) =>
      // English shows the server's own words, as it always has.
      localeName == 'en'
          ? fallback
          : switch (code) {
              'not_seated' => errorNotSeated,
              'seat_bot_controlled' => errorSeatBotControlled,
              'missing_guest_id' => errorMissingGuestId,
              'server_full' => errorServerFull,
              'missing_room_or_guest' => errorMissingRoom,
              'room_not_found' => errorRoomNotFound,
              'room_started' => errorRoomStarted,
              'room_full' => errorRoomFull,
              'not_host' => errorNotHost,
              'room_gone' => errorRoomGone,
              'unknown_type' => errorUnknownType,
              'malformed' => errorMalformed,
              'bad_request' => errorBadRequest,
              'illegal_action' => errorIllegalAction,
              'no_action_expected' => errorNoActionExpected,
              'game_ended' => errorGameEnded,
              _ => fallback,
            };
}

extension L10nContext on BuildContext {
  /// The current language's strings. English when nothing above this widget
  /// provides them (a widget test pumping a bare `MaterialApp`), rather than
  /// throwing.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

/// The current language's strings, for code with no [BuildContext] that still
/// builds display text (the game controllers' seat labels). The app rebuilds
/// whenever the language changes, so this is read fresh each time.
AppLocalizations get currentL10n =>
    lookupAppLocalizations(AppLanguageController.instance.value.locale);
