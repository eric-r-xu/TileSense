import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TileSense'**
  String get appTitle;

  /// No description provided for @languageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTooltip;

  /// No description provided for @rulesetRiichi.
  ///
  /// In en, this message translates to:
  /// **'Riichi'**
  String get rulesetRiichi;

  /// No description provided for @rulesetHongKong.
  ///
  /// In en, this message translates to:
  /// **'Hong Kong'**
  String get rulesetHongKong;

  /// No description provided for @rulesetTaiwanese.
  ///
  /// In en, this message translates to:
  /// **'Taiwanese'**
  String get rulesetTaiwanese;

  /// No description provided for @windEast.
  ///
  /// In en, this message translates to:
  /// **'East'**
  String get windEast;

  /// No description provided for @windSouth.
  ///
  /// In en, this message translates to:
  /// **'South'**
  String get windSouth;

  /// No description provided for @windWest.
  ///
  /// In en, this message translates to:
  /// **'West'**
  String get windWest;

  /// No description provided for @windNorth.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get windNorth;

  /// No description provided for @callChiRiichi.
  ///
  /// In en, this message translates to:
  /// **'Chi'**
  String get callChiRiichi;

  /// No description provided for @callChiHongKong.
  ///
  /// In en, this message translates to:
  /// **'Chow'**
  String get callChiHongKong;

  /// No description provided for @callChiTaiwanese.
  ///
  /// In en, this message translates to:
  /// **'Chow'**
  String get callChiTaiwanese;

  /// No description provided for @callPonRiichi.
  ///
  /// In en, this message translates to:
  /// **'Pon'**
  String get callPonRiichi;

  /// No description provided for @callPonHongKong.
  ///
  /// In en, this message translates to:
  /// **'Pung'**
  String get callPonHongKong;

  /// No description provided for @callPonTaiwanese.
  ///
  /// In en, this message translates to:
  /// **'Pung'**
  String get callPonTaiwanese;

  /// No description provided for @callKanRiichi.
  ///
  /// In en, this message translates to:
  /// **'Kan'**
  String get callKanRiichi;

  /// No description provided for @callKanHongKong.
  ///
  /// In en, this message translates to:
  /// **'Kong'**
  String get callKanHongKong;

  /// No description provided for @callKanTaiwanese.
  ///
  /// In en, this message translates to:
  /// **'Kong'**
  String get callKanTaiwanese;

  /// No description provided for @callRonRiichi.
  ///
  /// In en, this message translates to:
  /// **'Ron'**
  String get callRonRiichi;

  /// No description provided for @callRonHongKong.
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get callRonHongKong;

  /// No description provided for @callRonTaiwanese.
  ///
  /// In en, this message translates to:
  /// **'Hu'**
  String get callRonTaiwanese;

  /// No description provided for @callTsumoRiichi.
  ///
  /// In en, this message translates to:
  /// **'Tsumo'**
  String get callTsumoRiichi;

  /// No description provided for @callTsumoHongKong.
  ///
  /// In en, this message translates to:
  /// **'Self-pick'**
  String get callTsumoHongKong;

  /// No description provided for @callTsumoTaiwanese.
  ///
  /// In en, this message translates to:
  /// **'Self-pick'**
  String get callTsumoTaiwanese;

  /// No description provided for @hanchanCaveatRiichi.
  ///
  /// In en, this message translates to:
  /// **'That is with the dealership passing every hand. Under standard riichi rules a dealer who wins, or who is tenpai at an exhaustive draw, keeps it and the hand is replayed — so either length can run longer.'**
  String get hanchanCaveatRiichi;

  /// No description provided for @hanchanCaveatChinese.
  ///
  /// In en, this message translates to:
  /// **'That is with the dealership passing every hand. A dealer who wins, or any exhaustive draw, keeps it and the hand is replayed — so either length can run longer.'**
  String get hanchanCaveatChinese;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out  (Ctrl/Cmd -)'**
  String get zoomOut;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in  (Ctrl/Cmd +)'**
  String get zoomIn;

  /// No description provided for @zoomReset.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom  (Ctrl/Cmd 0)'**
  String get zoomReset;

  /// No description provided for @installTitle.
  ///
  /// In en, this message translates to:
  /// **'Install TileSense'**
  String get installTitle;

  /// No description provided for @installBody.
  ///
  /// In en, this message translates to:
  /// **'This browser can\'t go full screen from a web page. Install TileSense as a web app instead and it opens full screen, with no browser bars:\n\n• iPhone / iPad: tap Share, then \"Add to Home Screen\"\n• Chrome / Edge: use the install icon in the address bar, or menu > \"Install app\"'**
  String get installBody;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @fullscreenExit.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get fullscreenExit;

  /// No description provided for @fullscreenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Full screen. For the best experience, install TileSense as a web app (browser menu > Install / Add to Home Screen).'**
  String get fullscreenTooltip;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullscreen;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'A newer version of TileSense is ready. Update now to get it.'**
  String get updateAvailableBody;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @upToDateTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get upToDateTitle;

  /// No description provided for @upToDateBody.
  ///
  /// In en, this message translates to:
  /// **'This is the latest version. Refresh anyway to re-download every file.'**
  String get upToDateBody;

  /// No description provided for @refreshAnyway.
  ///
  /// In en, this message translates to:
  /// **'Refresh anyway'**
  String get refreshAnyway;

  /// No description provided for @refreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh TileSense'**
  String get refreshTitle;

  /// No description provided for @refreshUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t tell whether a newer version exists. Refresh to download the latest files.'**
  String get refreshUnknownBody;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @updateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Check for a newer version and refresh the app'**
  String get updateTooltip;

  /// No description provided for @working.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get working;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @rotatePrompt.
  ///
  /// In en, this message translates to:
  /// **'Rotate your device to landscape to play TileSense'**
  String get rotatePrompt;

  /// No description provided for @widenPrompt.
  ///
  /// In en, this message translates to:
  /// **'Make your browser window wider to play TileSense'**
  String get widenPrompt;

  /// No description provided for @minimumFaanSentence.
  ///
  /// In en, this message translates to:
  /// **', {n}-faan minimum'**
  String minimumFaanSentence(int n);

  /// No description provided for @minimumTaiSentence.
  ///
  /// In en, this message translates to:
  /// **', {n}-tai minimum'**
  String minimumTaiSentence(int n);

  /// No description provided for @minimumFaanTag.
  ///
  /// In en, this message translates to:
  /// **'{n} faan min'**
  String minimumFaanTag(int n);

  /// No description provided for @minimumTaiTag.
  ///
  /// In en, this message translates to:
  /// **'{n} tai min'**
  String minimumTaiTag(int n);

  /// No description provided for @newGameConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new game?'**
  String get newGameConfirmTitle;

  /// No description provided for @newGameConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The game in progress will be lost.'**
  String get newGameConfirmBody;

  /// No description provided for @keepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get keepPlaying;

  /// No description provided for @lengthChangeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to {length}?'**
  String lengthChangeConfirmTitle(String length);

  /// No description provided for @lengthChangeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get lengthChangeConfirm;

  /// No description provided for @newGame.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get newGame;

  /// No description provided for @loadingTable.
  ///
  /// In en, this message translates to:
  /// **'Preparing your table…'**
  String get loadingTable;

  /// No description provided for @loadingBuilder.
  ///
  /// In en, this message translates to:
  /// **'Loading hand builder…'**
  String get loadingBuilder;

  /// No description provided for @loadingMultiplayer.
  ///
  /// In en, this message translates to:
  /// **'Loading multiplayer…'**
  String get loadingMultiplayer;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @menuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Main menu — pauses this game; Start resumes it. Change the style there (a new game), or open the Custom Hand & Context Builder'**
  String get menuTooltip;

  /// No description provided for @playingRulesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Playing {rules} rules{minimum}.\nTo play another style, go back to the main menu.'**
  String playingRulesTooltip(String rules, String minimum);

  /// No description provided for @rulesPdf.
  ///
  /// In en, this message translates to:
  /// **'{rules} rules (PDF)'**
  String rulesPdf(String rules);

  /// No description provided for @hanchanOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hanchan — East and South (半庄) rounds, 8+ hands.\n{caveat}\nTap for East only (东风战), 4+ hands.'**
  String hanchanOnTooltip(String caveat);

  /// No description provided for @eastOnlyTooltipChinese.
  ///
  /// In en, this message translates to:
  /// **'East only — the East round, 4+ hands.\n{caveat}\nTap for hanchan (半庄): East and South (半庄), 8+ hands.'**
  String eastOnlyTooltipChinese(String caveat);

  /// No description provided for @eastOnlyTooltipRiichi.
  ///
  /// In en, this message translates to:
  /// **'East only (东风战/tonpuusen) — the East round, 4+ hands.\n{caveat}\nTap for hanchan (半庄): East and South (半庄), 8+ hands.'**
  String eastOnlyTooltipRiichi(String caveat);

  /// No description provided for @hanchan.
  ///
  /// In en, this message translates to:
  /// **'Hanchan'**
  String get hanchan;

  /// No description provided for @eastOnly.
  ///
  /// In en, this message translates to:
  /// **'East only'**
  String get eastOnly;

  /// No description provided for @botSpeedCaption.
  ///
  /// In en, this message translates to:
  /// **'BOT SPEED'**
  String get botSpeedCaption;

  /// No description provided for @botSpeedFastTooltip.
  ///
  /// In en, this message translates to:
  /// **'Bots and draws move at double speed.\nTap for normal speed.'**
  String get botSpeedFastTooltip;

  /// No description provided for @botSpeedNormalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Bots and draws move at normal speed.\nTap for double speed.'**
  String get botSpeedNormalTooltip;

  /// No description provided for @algorithmCaption.
  ///
  /// In en, this message translates to:
  /// **'ALGORITHM'**
  String get algorithmCaption;

  /// No description provided for @mortalBot.
  ///
  /// In en, this message translates to:
  /// **'Mortal bot'**
  String get mortalBot;

  /// No description provided for @algorithmTooltip.
  ///
  /// In en, this message translates to:
  /// **'TileSense guide, playing {style} · {focus} · {strategy}.\nSet for you as the game goes: Aggressive · Speed · Points early to build a lead; Balanced · Speed · Placement in the final two hands to protect or climb the standings.'**
  String algorithmTooltip(String style, String focus, String strategy);

  /// No description provided for @autoPlayCaption.
  ///
  /// In en, this message translates to:
  /// **'AUTO-PLAY'**
  String get autoPlayCaption;

  /// No description provided for @autoPlayOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-Play is on — TileSensor plays your seat by the guide: points early, placement in the final two hands.\nTap to take your seat back.'**
  String get autoPlayOnTooltip;

  /// No description provided for @autoPlayOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-Play is off — you play your seat.\nTap to let TileSensor play it by the guide.'**
  String get autoPlayOffTooltip;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @soundCaption.
  ///
  /// In en, this message translates to:
  /// **'SOUND'**
  String get soundCaption;

  /// No description provided for @soundOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sound on — tap to mute'**
  String get soundOnTooltip;

  /// No description provided for @soundOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sound off — tap to unmute'**
  String get soundOffTooltip;

  /// No description provided for @resumeCaption.
  ///
  /// In en, this message translates to:
  /// **'RESUME'**
  String get resumeCaption;

  /// No description provided for @pauseCaption.
  ///
  /// In en, this message translates to:
  /// **'PAUSE'**
  String get pauseCaption;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @newCaption.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newCaption;

  /// No description provided for @pausedOverlay.
  ///
  /// In en, this message translates to:
  /// **'PAUSED\ntap, or press Esc, to resume'**
  String get pausedOverlay;

  /// No description provided for @rulesetSubtitleRiichi.
  ///
  /// In en, this message translates to:
  /// **'yaku, dora, riichi'**
  String get rulesetSubtitleRiichi;

  /// No description provided for @rulesetSubtitleHongKong.
  ///
  /// In en, this message translates to:
  /// **'faan, flowers, 0–3 faan minimum'**
  String get rulesetSubtitleHongKong;

  /// No description provided for @rulesetSubtitleTaiwanese.
  ///
  /// In en, this message translates to:
  /// **'17 tiles, flowers, 1–5 tai minimum'**
  String get rulesetSubtitleTaiwanese;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Sharpen your {rules} Mahjong decisions\nwith a guide that sees only what you see.'**
  String welcomeTagline(String rules);

  /// No description provided for @singlePlayer.
  ///
  /// In en, this message translates to:
  /// **'Single Player'**
  String get singlePlayer;

  /// No description provided for @singlePlayerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Includes the TileSense guide'**
  String get singlePlayerSubtitle;

  /// No description provided for @playOnline.
  ///
  /// In en, this message translates to:
  /// **'Play Online'**
  String get playOnline;

  /// No description provided for @builder.
  ///
  /// In en, this message translates to:
  /// **'Hand Builder'**
  String get builder;

  /// No description provided for @builderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Have the TileSense guide score it'**
  String get builderSubtitle;

  /// No description provided for @rejoinOnline.
  ///
  /// In en, this message translates to:
  /// **'Rejoin your online game · Room {code}'**
  String rejoinOnline(String code);

  /// No description provided for @viewOnGitHub.
  ///
  /// In en, this message translates to:
  /// **'View on GitHub'**
  String get viewOnGitHub;

  /// No description provided for @builtWithFlutter.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter'**
  String get builtWithFlutter;

  /// No description provided for @seatYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get seatYou;

  /// No description provided for @seatRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get seatRight;

  /// No description provided for @seatAcross.
  ///
  /// In en, this message translates to:
  /// **'Across'**
  String get seatAcross;

  /// No description provided for @seatLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get seatLeft;

  /// No description provided for @youStartAs.
  ///
  /// In en, this message translates to:
  /// **'You start as'**
  String get youStartAs;

  /// No description provided for @style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get style;

  /// No description provided for @gameLength.
  ///
  /// In en, this message translates to:
  /// **'Game length'**
  String get gameLength;

  /// No description provided for @lengthHanchan.
  ///
  /// In en, this message translates to:
  /// **'半庄 Hanchan'**
  String get lengthHanchan;

  /// No description provided for @lengthEastOnly.
  ///
  /// In en, this message translates to:
  /// **'东风战 East only'**
  String get lengthEastOnly;

  /// No description provided for @minFaan.
  ///
  /// In en, this message translates to:
  /// **'Min faan'**
  String get minFaan;

  /// No description provided for @minFaanTooltip.
  ///
  /// In en, this message translates to:
  /// **'The fewest faan a hand needs to win.\n0 lets any complete hand, even a chicken hand, win.'**
  String get minFaanTooltip;

  /// No description provided for @minTai.
  ///
  /// In en, this message translates to:
  /// **'Min tai'**
  String get minTai;

  /// No description provided for @minTaiTooltip.
  ///
  /// In en, this message translates to:
  /// **'The fewest tai a hand needs to win.\n5 is the San Diego club sheet\'s rule; 1 and 3 are common house minimums.'**
  String get minTaiTooltip;

  /// No description provided for @chooseCharacters.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE YOUR CHARACTERS'**
  String get chooseCharacters;

  /// No description provided for @dealerNoteYou.
  ///
  /// In en, this message translates to:
  /// **'East deals first — that is you.'**
  String get dealerNoteYou;

  /// No description provided for @dealerNoteOther.
  ///
  /// In en, this message translates to:
  /// **'East deals first — that is {seat}.'**
  String dealerNoteOther(String seat);

  /// No description provided for @randomizeCharacters.
  ///
  /// In en, this message translates to:
  /// **'Randomize characters & seats'**
  String get randomizeCharacters;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backToMainMenu.
  ///
  /// In en, this message translates to:
  /// **'Back to the main menu'**
  String get backToMainMenu;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @mainMenu.
  ///
  /// In en, this message translates to:
  /// **'Main menu'**
  String get mainMenu;

  /// No description provided for @rules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rules;

  /// No description provided for @soundOn.
  ///
  /// In en, this message translates to:
  /// **'Sound on'**
  String get soundOn;

  /// No description provided for @soundOff.
  ///
  /// In en, this message translates to:
  /// **'Sound off'**
  String get soundOff;

  /// No description provided for @bots2x.
  ///
  /// In en, this message translates to:
  /// **'Bots 2x'**
  String get bots2x;

  /// No description provided for @bots1x.
  ///
  /// In en, this message translates to:
  /// **'Bots 1x'**
  String get bots1x;

  /// No description provided for @autoPlayOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-Play on'**
  String get autoPlayOn;

  /// No description provided for @autoPlayOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-Play off'**
  String get autoPlayOff;

  /// No description provided for @algorithm.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get algorithm;

  /// No description provided for @pausedCaps.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get pausedCaps;

  /// No description provided for @menuCaps.
  ///
  /// In en, this message translates to:
  /// **'MENU'**
  String get menuCaps;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t finish loading. Try again.'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @clientIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Your client ID'**
  String get clientIdTitle;

  /// No description provided for @clientIdShort.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get clientIdShort;

  /// No description provided for @clientIdHelp.
  ///
  /// In en, this message translates to:
  /// **'Include this if you report a problem.'**
  String get clientIdHelp;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @faanCount.
  ///
  /// In en, this message translates to:
  /// **'{n} faan'**
  String faanCount(int n);

  /// No description provided for @taiCount.
  ///
  /// In en, this message translates to:
  /// **'{n} tai'**
  String taiCount(int n);

  /// No description provided for @badgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Playing {rules} rules{minimum}.'**
  String badgeTooltip(String rules, String minimum);

  /// No description provided for @badgeMinimum.
  ///
  /// In en, this message translates to:
  /// **', {min} minimum'**
  String badgeMinimum(String min);

  /// No description provided for @yakuRiichi.
  ///
  /// In en, this message translates to:
  /// **'Riichi'**
  String get yakuRiichi;

  /// No description provided for @yakuDoubleRiichi.
  ///
  /// In en, this message translates to:
  /// **'Double Riichi'**
  String get yakuDoubleRiichi;

  /// No description provided for @yakuIppatsu.
  ///
  /// In en, this message translates to:
  /// **'Ippatsu'**
  String get yakuIppatsu;

  /// No description provided for @yakuMenzenTsumo.
  ///
  /// In en, this message translates to:
  /// **'Menzen Tsumo'**
  String get yakuMenzenTsumo;

  /// No description provided for @yakuHaiteiRaoyue.
  ///
  /// In en, this message translates to:
  /// **'Haitei Raoyue'**
  String get yakuHaiteiRaoyue;

  /// No description provided for @yakuHouteiRaoyui.
  ///
  /// In en, this message translates to:
  /// **'Houtei Raoyui'**
  String get yakuHouteiRaoyui;

  /// No description provided for @yakuRinshanKaihou.
  ///
  /// In en, this message translates to:
  /// **'Rinshan Kaihou'**
  String get yakuRinshanKaihou;

  /// No description provided for @yakuChankan.
  ///
  /// In en, this message translates to:
  /// **'Chankan'**
  String get yakuChankan;

  /// No description provided for @yakuTanyao.
  ///
  /// In en, this message translates to:
  /// **'Tanyao'**
  String get yakuTanyao;

  /// No description provided for @yakuRoundWind.
  ///
  /// In en, this message translates to:
  /// **'Round Wind'**
  String get yakuRoundWind;

  /// No description provided for @yakuSeatWind.
  ///
  /// In en, this message translates to:
  /// **'Seat Wind'**
  String get yakuSeatWind;

  /// No description provided for @yakuShousangen.
  ///
  /// In en, this message translates to:
  /// **'Shousangen'**
  String get yakuShousangen;

  /// No description provided for @yakuPinfu.
  ///
  /// In en, this message translates to:
  /// **'Pinfu'**
  String get yakuPinfu;

  /// No description provided for @yakuIipeiko.
  ///
  /// In en, this message translates to:
  /// **'Iipeiko'**
  String get yakuIipeiko;

  /// No description provided for @yakuRyanpeikou.
  ///
  /// In en, this message translates to:
  /// **'Ryanpeikou'**
  String get yakuRyanpeikou;

  /// No description provided for @yakuChiitoitsu.
  ///
  /// In en, this message translates to:
  /// **'Chiitoitsu'**
  String get yakuChiitoitsu;

  /// No description provided for @yakuToitoi.
  ///
  /// In en, this message translates to:
  /// **'Toitoi'**
  String get yakuToitoi;

  /// No description provided for @yakuSanankou.
  ///
  /// In en, this message translates to:
  /// **'Sanankou'**
  String get yakuSanankou;

  /// No description provided for @yakuSankantsu.
  ///
  /// In en, this message translates to:
  /// **'Sankantsu'**
  String get yakuSankantsu;

  /// No description provided for @yakuSanshokuDoujun.
  ///
  /// In en, this message translates to:
  /// **'Sanshoku Doujun'**
  String get yakuSanshokuDoujun;

  /// No description provided for @yakuSanshokuDoukou.
  ///
  /// In en, this message translates to:
  /// **'Sanshoku Doukou'**
  String get yakuSanshokuDoukou;

  /// No description provided for @yakuIttsu.
  ///
  /// In en, this message translates to:
  /// **'Ittsu'**
  String get yakuIttsu;

  /// No description provided for @yakuHonroutou.
  ///
  /// In en, this message translates to:
  /// **'Honroutou'**
  String get yakuHonroutou;

  /// No description provided for @yakuHonitsu.
  ///
  /// In en, this message translates to:
  /// **'Honitsu'**
  String get yakuHonitsu;

  /// No description provided for @yakuChinitsu.
  ///
  /// In en, this message translates to:
  /// **'Chinitsu'**
  String get yakuChinitsu;

  /// No description provided for @yakuChanta.
  ///
  /// In en, this message translates to:
  /// **'Chanta'**
  String get yakuChanta;

  /// No description provided for @yakuJunchan.
  ///
  /// In en, this message translates to:
  /// **'Junchan'**
  String get yakuJunchan;

  /// No description provided for @yakuDora.
  ///
  /// In en, this message translates to:
  /// **'Dora'**
  String get yakuDora;

  /// No description provided for @yakuUraDora.
  ///
  /// In en, this message translates to:
  /// **'Ura Dora'**
  String get yakuUraDora;

  /// No description provided for @yakuAkaDora.
  ///
  /// In en, this message translates to:
  /// **'Aka Dora'**
  String get yakuAkaDora;

  /// No description provided for @yakuKokushiMusou.
  ///
  /// In en, this message translates to:
  /// **'Kokushi Musou'**
  String get yakuKokushiMusou;

  /// No description provided for @yakuSuuankou.
  ///
  /// In en, this message translates to:
  /// **'Suuankou'**
  String get yakuSuuankou;

  /// No description provided for @yakuDaisangen.
  ///
  /// In en, this message translates to:
  /// **'Daisangen'**
  String get yakuDaisangen;

  /// No description provided for @yakuDaisuushii.
  ///
  /// In en, this message translates to:
  /// **'Daisuushii'**
  String get yakuDaisuushii;

  /// No description provided for @yakuShousuushii.
  ///
  /// In en, this message translates to:
  /// **'Shousuushii'**
  String get yakuShousuushii;

  /// No description provided for @yakuTsuuiisou.
  ///
  /// In en, this message translates to:
  /// **'Tsuuiisou'**
  String get yakuTsuuiisou;

  /// No description provided for @yakuChinroutou.
  ///
  /// In en, this message translates to:
  /// **'Chinroutou'**
  String get yakuChinroutou;

  /// No description provided for @yakuRyuuiisou.
  ///
  /// In en, this message translates to:
  /// **'Ryuuiisou'**
  String get yakuRyuuiisou;

  /// No description provided for @yakuChuurenPoutou.
  ///
  /// In en, this message translates to:
  /// **'Chuuren Poutou'**
  String get yakuChuurenPoutou;

  /// No description provided for @faanAllFlowers.
  ///
  /// In en, this message translates to:
  /// **'All Flowers'**
  String get faanAllFlowers;

  /// No description provided for @faanAllSeasons.
  ///
  /// In en, this message translates to:
  /// **'All Seasons'**
  String get faanAllSeasons;

  /// No description provided for @faanAllHonours.
  ///
  /// In en, this message translates to:
  /// **'All Honours'**
  String get faanAllHonours;

  /// No description provided for @faanAllSequences.
  ///
  /// In en, this message translates to:
  /// **'All Sequences'**
  String get faanAllSequences;

  /// No description provided for @faanAllTerminals.
  ///
  /// In en, this message translates to:
  /// **'All Terminals'**
  String get faanAllTerminals;

  /// No description provided for @faanAllTriplets.
  ///
  /// In en, this message translates to:
  /// **'All Triplets'**
  String get faanAllTriplets;

  /// No description provided for @faanAllQuadruplets.
  ///
  /// In en, this message translates to:
  /// **'All Quadruplets'**
  String get faanAllQuadruplets;

  /// No description provided for @faanAllQuadrupletsUpgrade.
  ///
  /// In en, this message translates to:
  /// **'All Quadruplets (upgrade)'**
  String get faanAllQuadrupletsUpgrade;

  /// No description provided for @faanAllConcealedTriplets.
  ///
  /// In en, this message translates to:
  /// **'All Concealed Triplets'**
  String get faanAllConcealedTriplets;

  /// No description provided for @faanAllConcealedTripletsUpgrade.
  ///
  /// In en, this message translates to:
  /// **'All Concealed Triplets (upgrade)'**
  String get faanAllConcealedTripletsUpgrade;

  /// No description provided for @faanBigFourWinds.
  ///
  /// In en, this message translates to:
  /// **'Big Four Winds'**
  String get faanBigFourWinds;

  /// No description provided for @faanBigThreeDragons.
  ///
  /// In en, this message translates to:
  /// **'Big Three Dragons'**
  String get faanBigThreeDragons;

  /// No description provided for @faanBlessingOfEarth.
  ///
  /// In en, this message translates to:
  /// **'Blessing of Earth'**
  String get faanBlessingOfEarth;

  /// No description provided for @faanBlessingOfHeaven.
  ///
  /// In en, this message translates to:
  /// **'Blessing of Heaven'**
  String get faanBlessingOfHeaven;

  /// No description provided for @faanBlessingOfMan.
  ///
  /// In en, this message translates to:
  /// **'Blessing of Man'**
  String get faanBlessingOfMan;

  /// No description provided for @faanChickenHand.
  ///
  /// In en, this message translates to:
  /// **'Chicken Hand'**
  String get faanChickenHand;

  /// No description provided for @faanConcealedHand.
  ///
  /// In en, this message translates to:
  /// **'Concealed Hand'**
  String get faanConcealedHand;

  /// No description provided for @faanDoubleKongReplacement.
  ///
  /// In en, this message translates to:
  /// **'Double Kong Replacement'**
  String get faanDoubleKongReplacement;

  /// No description provided for @faanFullFlush.
  ///
  /// In en, this message translates to:
  /// **'Full Flush'**
  String get faanFullFlush;

  /// No description provided for @faanMixedFlush.
  ///
  /// In en, this message translates to:
  /// **'Mixed Flush'**
  String get faanMixedFlush;

  /// No description provided for @faanMixedTerminals.
  ///
  /// In en, this message translates to:
  /// **'Mixed Terminals'**
  String get faanMixedTerminals;

  /// No description provided for @faanMoonUnderTheSea.
  ///
  /// In en, this message translates to:
  /// **'Moon Under the Sea'**
  String get faanMoonUnderTheSea;

  /// No description provided for @faanNineGates.
  ///
  /// In en, this message translates to:
  /// **'Nine Gates'**
  String get faanNineGates;

  /// No description provided for @faanNoFlowersOrSeasons.
  ///
  /// In en, this message translates to:
  /// **'No Flowers or Seasons'**
  String get faanNoFlowersOrSeasons;

  /// No description provided for @faanRobbingTheKong.
  ///
  /// In en, this message translates to:
  /// **'Robbing the Kong'**
  String get faanRobbingTheKong;

  /// No description provided for @faanRoundWind.
  ///
  /// In en, this message translates to:
  /// **'Round Wind'**
  String get faanRoundWind;

  /// No description provided for @faanSeatWind.
  ///
  /// In en, this message translates to:
  /// **'Seat Wind'**
  String get faanSeatWind;

  /// No description provided for @faanSelfPick.
  ///
  /// In en, this message translates to:
  /// **'Self-Pick'**
  String get faanSelfPick;

  /// No description provided for @faanSevenPairs.
  ///
  /// In en, this message translates to:
  /// **'Seven Pairs'**
  String get faanSevenPairs;

  /// No description provided for @faanSmallFourWinds.
  ///
  /// In en, this message translates to:
  /// **'Small Four Winds'**
  String get faanSmallFourWinds;

  /// No description provided for @faanSmallThreeDragons.
  ///
  /// In en, this message translates to:
  /// **'Small Three Dragons'**
  String get faanSmallThreeDragons;

  /// No description provided for @faanThirteenOrphans.
  ///
  /// In en, this message translates to:
  /// **'Thirteen Orphans'**
  String get faanThirteenOrphans;

  /// No description provided for @faanWinByKongReplacement.
  ///
  /// In en, this message translates to:
  /// **'Win by Kong Replacement'**
  String get faanWinByKongReplacement;

  /// No description provided for @faanSevenFlowers.
  ///
  /// In en, this message translates to:
  /// **'Seven Flowers'**
  String get faanSevenFlowers;

  /// No description provided for @faanEightFlowers.
  ///
  /// In en, this message translates to:
  /// **'Eight Flowers'**
  String get faanEightFlowers;

  /// No description provided for @taiAllChowsWithFlowersOrHonors.
  ///
  /// In en, this message translates to:
  /// **'All Chows with Flowers or Honors'**
  String get taiAllChowsWithFlowersOrHonors;

  /// No description provided for @taiAllChows.
  ///
  /// In en, this message translates to:
  /// **'All Chows'**
  String get taiAllChows;

  /// No description provided for @taiAllPungs.
  ///
  /// In en, this message translates to:
  /// **'All Pungs'**
  String get taiAllPungs;

  /// No description provided for @taiAllFlowers.
  ///
  /// In en, this message translates to:
  /// **'All Flowers'**
  String get taiAllFlowers;

  /// No description provided for @taiBigFourWinds.
  ///
  /// In en, this message translates to:
  /// **'Big Four Winds'**
  String get taiBigFourWinds;

  /// No description provided for @taiBigThreeDragons.
  ///
  /// In en, this message translates to:
  /// **'Big Three Dragons'**
  String get taiBigThreeDragons;

  /// No description provided for @taiBigThreeWinds.
  ///
  /// In en, this message translates to:
  /// **'Big Three Winds'**
  String get taiBigThreeWinds;

  /// No description provided for @taiBlessingsOfEarth.
  ///
  /// In en, this message translates to:
  /// **'Blessings of Earth'**
  String get taiBlessingsOfEarth;

  /// No description provided for @taiBlessingsOfHeaven.
  ///
  /// In en, this message translates to:
  /// **'Blessings of Heaven'**
  String get taiBlessingsOfHeaven;

  /// No description provided for @taiClosedWait.
  ///
  /// In en, this message translates to:
  /// **'Closed Wait'**
  String get taiClosedWait;

  /// No description provided for @taiConcealedHand.
  ///
  /// In en, this message translates to:
  /// **'Concealed Hand'**
  String get taiConcealedHand;

  /// No description provided for @taiConcealedKong.
  ///
  /// In en, this message translates to:
  /// **'Concealed Kong'**
  String get taiConcealedKong;

  /// No description provided for @taiFiveConcealedPungs.
  ///
  /// In en, this message translates to:
  /// **'Five Concealed Pungs'**
  String get taiFiveConcealedPungs;

  /// No description provided for @taiFourConcealedPungs.
  ///
  /// In en, this message translates to:
  /// **'Four Concealed Pungs'**
  String get taiFourConcealedPungs;

  /// No description provided for @taiThreeConcealedPungs.
  ///
  /// In en, this message translates to:
  /// **'Three Concealed Pungs'**
  String get taiThreeConcealedPungs;

  /// No description provided for @taiTwoConcealedPungs.
  ///
  /// In en, this message translates to:
  /// **'Two Concealed Pungs'**
  String get taiTwoConcealedPungs;

  /// No description provided for @taiFlowerTile.
  ///
  /// In en, this message translates to:
  /// **'Flower Tile'**
  String get taiFlowerTile;

  /// No description provided for @taiFullyConcealedHand.
  ///
  /// In en, this message translates to:
  /// **'Fully Concealed Hand'**
  String get taiFullyConcealedHand;

  /// No description provided for @taiFullFlush.
  ///
  /// In en, this message translates to:
  /// **'Full Flush'**
  String get taiFullFlush;

  /// No description provided for @taiHalfFlush.
  ///
  /// In en, this message translates to:
  /// **'Half Flush'**
  String get taiHalfFlush;

  /// No description provided for @taiLastTileDraw.
  ///
  /// In en, this message translates to:
  /// **'Last Tile Draw'**
  String get taiLastTileDraw;

  /// No description provided for @taiLittleFourWinds.
  ///
  /// In en, this message translates to:
  /// **'Little Four Winds'**
  String get taiLittleFourWinds;

  /// No description provided for @taiLittleThreeDragons.
  ///
  /// In en, this message translates to:
  /// **'Little Three Dragons'**
  String get taiLittleThreeDragons;

  /// No description provided for @taiLittleThreeWinds.
  ///
  /// In en, this message translates to:
  /// **'Little Three Winds'**
  String get taiLittleThreeWinds;

  /// No description provided for @taiMeldedHand.
  ///
  /// In en, this message translates to:
  /// **'Melded Hand'**
  String get taiMeldedHand;

  /// No description provided for @taiMeldedKong.
  ///
  /// In en, this message translates to:
  /// **'Melded Kong'**
  String get taiMeldedKong;

  /// No description provided for @taiNoFlowerOrHonorTiles.
  ///
  /// In en, this message translates to:
  /// **'No Flower or Honor Tiles'**
  String get taiNoFlowerOrHonorTiles;

  /// No description provided for @taiNoFlowerTiles.
  ///
  /// In en, this message translates to:
  /// **'No Flower Tiles'**
  String get taiNoFlowerTiles;

  /// No description provided for @taiNoHonors.
  ///
  /// In en, this message translates to:
  /// **'No Honors'**
  String get taiNoHonors;

  /// No description provided for @taiPureStraight.
  ///
  /// In en, this message translates to:
  /// **'Pure Straight'**
  String get taiPureStraight;

  /// No description provided for @taiRobbingTheKong.
  ///
  /// In en, this message translates to:
  /// **'Robbing the Kong'**
  String get taiRobbingTheKong;

  /// No description provided for @taiSelfDrawn.
  ///
  /// In en, this message translates to:
  /// **'Self-Drawn'**
  String get taiSelfDrawn;

  /// No description provided for @taiSevenPairsAndAPung.
  ///
  /// In en, this message translates to:
  /// **'Seven Pairs and a Pung'**
  String get taiSevenPairsAndAPung;

  /// No description provided for @taiSingleWait.
  ///
  /// In en, this message translates to:
  /// **'Single Wait'**
  String get taiSingleWait;

  /// No description provided for @taiValueHonor.
  ///
  /// In en, this message translates to:
  /// **'Value Honor'**
  String get taiValueHonor;

  /// No description provided for @taiWinWithin5Discards.
  ///
  /// In en, this message translates to:
  /// **'Win Within 5 Discards'**
  String get taiWinWithin5Discards;

  /// No description provided for @taiWinWithin5To10Discards.
  ///
  /// In en, this message translates to:
  /// **'Win Within 5 to 10 Discards'**
  String get taiWinWithin5To10Discards;

  /// No description provided for @resultKyuushuKyuuhaiNineTerminalsHonors.
  ///
  /// In en, this message translates to:
  /// **'Kyuushu Kyuuhai — nine terminals/honors'**
  String get resultKyuushuKyuuhaiNineTerminalsHonors;

  /// No description provided for @resultExhaustiveDraw.
  ///
  /// In en, this message translates to:
  /// **'Exhaustive Draw'**
  String get resultExhaustiveDraw;

  /// No description provided for @resultMultipleWins.
  ///
  /// In en, this message translates to:
  /// **'Multiple Wins'**
  String get resultMultipleWins;

  /// No description provided for @resultRobbingAKong.
  ///
  /// In en, this message translates to:
  /// **'Robbing a Kong'**
  String get resultRobbingAKong;

  /// No description provided for @resultWinOnDiscard.
  ///
  /// In en, this message translates to:
  /// **'Win on Discard'**
  String get resultWinOnDiscard;

  /// No description provided for @resultMultipleRon.
  ///
  /// In en, this message translates to:
  /// **'Multiple Ron'**
  String get resultMultipleRon;

  /// No description provided for @resultChankan.
  ///
  /// In en, this message translates to:
  /// **'Chankan'**
  String get resultChankan;

  /// No description provided for @resultRon.
  ///
  /// In en, this message translates to:
  /// **'Ron'**
  String get resultRon;

  /// No description provided for @resultSelfDraw.
  ///
  /// In en, this message translates to:
  /// **'Self Draw'**
  String get resultSelfDraw;

  /// No description provided for @resultTsumo.
  ///
  /// In en, this message translates to:
  /// **'Tsumo'**
  String get resultTsumo;

  /// No description provided for @limitMangan.
  ///
  /// In en, this message translates to:
  /// **'Mangan'**
  String get limitMangan;

  /// No description provided for @limitHaneman.
  ///
  /// In en, this message translates to:
  /// **'Haneman'**
  String get limitHaneman;

  /// No description provided for @limitBaiman.
  ///
  /// In en, this message translates to:
  /// **'Baiman'**
  String get limitBaiman;

  /// No description provided for @limitSanbaiman.
  ///
  /// In en, this message translates to:
  /// **'Sanbaiman'**
  String get limitSanbaiman;

  /// No description provided for @limitKazoeYakuman.
  ///
  /// In en, this message translates to:
  /// **'Kazoe Yakuman'**
  String get limitKazoeYakuman;

  /// No description provided for @limitYakuman.
  ///
  /// In en, this message translates to:
  /// **'Yakuman'**
  String get limitYakuman;

  /// No description provided for @limit13FaanCap.
  ///
  /// In en, this message translates to:
  /// **'13+ faan cap'**
  String get limit13FaanCap;

  /// No description provided for @tileTon.
  ///
  /// In en, this message translates to:
  /// **'East'**
  String get tileTon;

  /// No description provided for @tileNan.
  ///
  /// In en, this message translates to:
  /// **'South'**
  String get tileNan;

  /// No description provided for @tileShaa.
  ///
  /// In en, this message translates to:
  /// **'West'**
  String get tileShaa;

  /// No description provided for @tilePei.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get tilePei;

  /// No description provided for @tileHaku.
  ///
  /// In en, this message translates to:
  /// **'White Dragon'**
  String get tileHaku;

  /// No description provided for @tileHatsu.
  ///
  /// In en, this message translates to:
  /// **'Green Dragon'**
  String get tileHatsu;

  /// No description provided for @tileChun.
  ///
  /// In en, this message translates to:
  /// **'Red Dragon'**
  String get tileChun;

  /// No description provided for @tilePlum.
  ///
  /// In en, this message translates to:
  /// **'Plum'**
  String get tilePlum;

  /// No description provided for @tileOrchid.
  ///
  /// In en, this message translates to:
  /// **'Orchid'**
  String get tileOrchid;

  /// No description provided for @tileChrysanthemum.
  ///
  /// In en, this message translates to:
  /// **'Chrysanthemum'**
  String get tileChrysanthemum;

  /// No description provided for @tileBamboo.
  ///
  /// In en, this message translates to:
  /// **'Bamboo Flower'**
  String get tileBamboo;

  /// No description provided for @tileSpring.
  ///
  /// In en, this message translates to:
  /// **'Spring'**
  String get tileSpring;

  /// No description provided for @tileSummer.
  ///
  /// In en, this message translates to:
  /// **'Summer'**
  String get tileSummer;

  /// No description provided for @tileAutumn.
  ///
  /// In en, this message translates to:
  /// **'Autumn'**
  String get tileAutumn;

  /// No description provided for @tileWinter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get tileWinter;

  /// No description provided for @yakuYakuhai.
  ///
  /// In en, this message translates to:
  /// **'Yakuhai ({tile})'**
  String yakuYakuhai(String tile);

  /// No description provided for @faanHonorPung.
  ///
  /// In en, this message translates to:
  /// **'{tile} Pung'**
  String faanHonorPung(String tile);

  /// No description provided for @limitMultipleYakuman.
  ///
  /// In en, this message translates to:
  /// **'{n}× Yakuman'**
  String limitMultipleYakuman(int n);

  /// No description provided for @bubbleRiichi.
  ///
  /// In en, this message translates to:
  /// **'RIICHI'**
  String get bubbleRiichi;

  /// No description provided for @bubbleRinshanRiichi.
  ///
  /// In en, this message translates to:
  /// **'RINSHAN'**
  String get bubbleRinshanRiichi;

  /// No description provided for @bubbleRinshanChinese.
  ///
  /// In en, this message translates to:
  /// **'RINSHAN'**
  String get bubbleRinshanChinese;

  /// No description provided for @doraRowLabel.
  ///
  /// In en, this message translates to:
  /// **'DORA'**
  String get doraRowLabel;

  /// No description provided for @uraRowLabel.
  ///
  /// In en, this message translates to:
  /// **'URA'**
  String get uraRowLabel;

  /// No description provided for @noCalls.
  ///
  /// In en, this message translates to:
  /// **'calls'**
  String get noCalls;

  /// No description provided for @autoPlaySeatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-Play — TileSensor is playing your seat'**
  String get autoPlaySeatTooltip;

  /// No description provided for @furiten.
  ///
  /// In en, this message translates to:
  /// **'FURITEN'**
  String get furiten;

  /// No description provided for @noYaku.
  ///
  /// In en, this message translates to:
  /// **'NO YAKU'**
  String get noYaku;

  /// No description provided for @underFaan.
  ///
  /// In en, this message translates to:
  /// **'UNDER {n} FAAN'**
  String underFaan(int n);

  /// No description provided for @underTai.
  ///
  /// In en, this message translates to:
  /// **'UNDER {n} TAI'**
  String underTai(int n);

  /// No description provided for @underFan.
  ///
  /// In en, this message translates to:
  /// **'UNDER {n} FAN'**
  String underFan(int n);

  /// No description provided for @noWin.
  ///
  /// In en, this message translates to:
  /// **'NO WIN'**
  String get noWin;

  /// No description provided for @minimumRonOnlyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Ron unavailable: no wait reaches the minimum off a discard, but a self-draw can still win'**
  String get minimumRonOnlyTooltip;

  /// No description provided for @minimumDeadTooltip.
  ///
  /// In en, this message translates to:
  /// **'No wait reaches the minimum, even self-drawn, so this hand cannot win as it stands'**
  String get minimumDeadTooltip;

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'{n}s'**
  String secondsShort(int n);

  /// No description provided for @statusWall.
  ///
  /// In en, this message translates to:
  /// **'Wall {n}'**
  String statusWall(int n);

  /// No description provided for @statusDealerRepeat.
  ///
  /// In en, this message translates to:
  /// **'Dealer repeat {n}'**
  String statusDealerRepeat(int n);

  /// No description provided for @statusHonba.
  ///
  /// In en, this message translates to:
  /// **'Honba {n}'**
  String statusHonba(int n);

  /// No description provided for @statusRiichiSticks.
  ///
  /// In en, this message translates to:
  /// **'Riichi {n}'**
  String statusRiichiSticks(int n);

  /// No description provided for @statusRound.
  ///
  /// In en, this message translates to:
  /// **'{kanji} {wind} {hand}'**
  String statusRound(String kanji, String wind, int hand);

  /// No description provided for @seatLabelYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String seatLabelYou(String name);

  /// No description provided for @seatLabelBot.
  ///
  /// In en, this message translates to:
  /// **'{name} (bot)'**
  String seatLabelBot(String name);

  /// No description provided for @seatBot.
  ///
  /// In en, this message translates to:
  /// **'Bot'**
  String get seatBot;

  /// No description provided for @seatNumber.
  ///
  /// In en, this message translates to:
  /// **'Seat {n}'**
  String seatNumber(int n);

  /// No description provided for @tileMan.
  ///
  /// In en, this message translates to:
  /// **'{n} Man'**
  String tileMan(int n);

  /// No description provided for @tilePin.
  ///
  /// In en, this message translates to:
  /// **'{n} Pin'**
  String tilePin(int n);

  /// No description provided for @tileSou.
  ///
  /// In en, this message translates to:
  /// **'{n} Sou'**
  String tileSou(int n);

  /// No description provided for @undoPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get undoPass;

  /// No description provided for @undoContinueDrawing.
  ///
  /// In en, this message translates to:
  /// **'Continue drawing'**
  String get undoContinueDrawing;

  /// No description provided for @undoRiichi.
  ///
  /// In en, this message translates to:
  /// **'Riichi {tile}'**
  String undoRiichi(String tile);

  /// No description provided for @undoKan.
  ///
  /// In en, this message translates to:
  /// **'{kan} {tile}'**
  String undoKan(String kan, String tile);

  /// No description provided for @hideGuide.
  ///
  /// In en, this message translates to:
  /// **'Hide guide'**
  String get hideGuide;

  /// No description provided for @showGuide.
  ///
  /// In en, this message translates to:
  /// **'Show guide'**
  String get showGuide;

  /// No description provided for @hideGuideFooter.
  ///
  /// In en, this message translates to:
  /// **'Tap to hide my guide.'**
  String get hideGuideFooter;

  /// No description provided for @showGuideFooter.
  ///
  /// In en, this message translates to:
  /// **'Tap to show my guide.'**
  String get showGuideFooter;

  /// No description provided for @sortCaption.
  ///
  /// In en, this message translates to:
  /// **'SORT'**
  String get sortCaption;

  /// No description provided for @sortOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get sortOff;

  /// No description provided for @sortOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort: Off — your own order.\nLong-press a tile and drag it to move it. Tap for Hand (tile order).'**
  String get sortOffTooltip;

  /// No description provided for @sortHand.
  ///
  /// In en, this message translates to:
  /// **'Hand'**
  String get sortHand;

  /// No description provided for @sortHandTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort: Hand — tiles kept in tile order, your drawn tile apart on the right.\nTap for Hand+draw, or drag a tile to start your own order.'**
  String get sortHandTooltip;

  /// No description provided for @sortHandDraw.
  ///
  /// In en, this message translates to:
  /// **'Hand+draw'**
  String get sortHandDraw;

  /// No description provided for @sortHandDrawTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort: Hand+draw — your drawn tile is sorted straight into your hand.\nTap to freeze this order (Off), or drag a tile to start your own.'**
  String get sortHandDrawTooltip;

  /// No description provided for @discardCaption.
  ///
  /// In en, this message translates to:
  /// **'DISCARD'**
  String get discardCaption;

  /// No description provided for @discardSingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get discardSingle;

  /// No description provided for @discardDouble.
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get discardDouble;

  /// No description provided for @discardSingleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard: single tap — tapping a tile discards it.\nTap to raise a tile first and tap again to discard.'**
  String get discardSingleTooltip;

  /// No description provided for @discardDoubleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard: double tap — the first tap raises a tile, a second discards it.\nTap to discard with a single tap.'**
  String get discardDoubleTooltip;

  /// No description provided for @autoWinCaption.
  ///
  /// In en, this message translates to:
  /// **'AUTO-WIN'**
  String get autoWinCaption;

  /// No description provided for @autoWinOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-win: on — ron and tsumo are declared for you as soon as you can win.\nTap to decide yourself.'**
  String get autoWinOnTooltip;

  /// No description provided for @autoWinOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-win: off — press the win button yourself.\nTap to declare ron/tsumo automatically.'**
  String get autoWinOffTooltip;

  /// No description provided for @autoPassCaption.
  ///
  /// In en, this message translates to:
  /// **'AUTO-PASS'**
  String get autoPassCaption;

  /// No description provided for @autoPassOnTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-pass: on — chi, pon and kan on other players\' discards are passed for you. A ron is still yours to take.\nTap to decide calls yourself.'**
  String get autoPassOnTooltip;

  /// No description provided for @autoPassOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-pass: off — you are asked about every call.\nTap to pass chi, pon and kan automatically.'**
  String get autoPassOffTooltip;

  /// No description provided for @declareRiichiDiscard.
  ///
  /// In en, this message translates to:
  /// **'Declare Riichi and discard {tile}'**
  String declareRiichiDiscard(String tile);

  /// No description provided for @justDiscard.
  ///
  /// In en, this message translates to:
  /// **'Just discard {tile}'**
  String justDiscard(String tile);

  /// No description provided for @flowerWin.
  ///
  /// In en, this message translates to:
  /// **'FLOWER WIN'**
  String get flowerWin;

  /// No description provided for @continueDrawing.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE DRAWING'**
  String get continueDrawing;

  /// No description provided for @passCaps.
  ///
  /// In en, this message translates to:
  /// **'PASS'**
  String get passCaps;

  /// No description provided for @kyuushuKyuuhai.
  ///
  /// In en, this message translates to:
  /// **'KYUUSHU KYUUHAI'**
  String get kyuushuKyuuhai;

  /// No description provided for @riichiAvailable.
  ///
  /// In en, this message translates to:
  /// **'Riichi available'**
  String get riichiAvailable;

  /// No description provided for @riichiAvailableRecommended.
  ///
  /// In en, this message translates to:
  /// **'Riichi available — recommended'**
  String get riichiAvailableRecommended;

  /// No description provided for @undoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Take back your last move this hand, and everything after it.\nPress again to keep stepping back. (Ctrl/Cmd+Z)'**
  String get undoTooltip;

  /// No description provided for @takeBack.
  ///
  /// In en, this message translates to:
  /// **'Take back  '**
  String get takeBack;

  /// No description provided for @scoreNewGame.
  ///
  /// In en, this message translates to:
  /// **'New Game'**
  String get scoreNewGame;

  /// No description provided for @scoreNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get scoreNext;

  /// No description provided for @scoreContinueLocked.
  ///
  /// In en, this message translates to:
  /// **'Continue ({n})'**
  String scoreContinueLocked(int n);

  /// No description provided for @scoreContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get scoreContinue;

  /// No description provided for @autoContinuePaused.
  ///
  /// In en, this message translates to:
  /// **'Auto Continue paused'**
  String get autoContinuePaused;

  /// No description provided for @autoContinueHeld.
  ///
  /// In en, this message translates to:
  /// **'Auto Continue held — game paused'**
  String get autoContinueHeld;

  /// No description provided for @autoContinueIn.
  ///
  /// In en, this message translates to:
  /// **'Auto Continue in {n}s'**
  String autoContinueIn(int n);

  /// No description provided for @showPanel.
  ///
  /// In en, this message translates to:
  /// **'Show panel'**
  String get showPanel;

  /// No description provided for @seeThroughPanel.
  ///
  /// In en, this message translates to:
  /// **'See through panel'**
  String get seeThroughPanel;

  /// No description provided for @flowersSeasons.
  ///
  /// In en, this message translates to:
  /// **'Flowers / seasons'**
  String get flowersSeasons;

  /// No description provided for @indicatorRowOne.
  ///
  /// In en, this message translates to:
  /// **'{label} indicator:'**
  String indicatorRowOne(String label);

  /// No description provided for @indicatorRowMany.
  ///
  /// In en, this message translates to:
  /// **'{label} indicators:'**
  String indicatorRowMany(String label);

  /// No description provided for @plainRow.
  ///
  /// In en, this message translates to:
  /// **'{label}:'**
  String plainRow(String label);

  /// No description provided for @yakuLineTaiOne.
  ///
  /// In en, this message translates to:
  /// **'{name}  {n} pt'**
  String yakuLineTaiOne(String name, int n);

  /// No description provided for @yakuLineTaiMany.
  ///
  /// In en, this message translates to:
  /// **'{name}  {n} pts'**
  String yakuLineTaiMany(String name, int n);

  /// No description provided for @yakuLineFaan.
  ///
  /// In en, this message translates to:
  /// **'{name}  {n} faan'**
  String yakuLineFaan(String name, int n);

  /// No description provided for @yakuLineHan.
  ///
  /// In en, this message translates to:
  /// **'{name}  {n}'**
  String yakuLineHan(String name, int n);

  /// No description provided for @yakuLineYakuman.
  ///
  /// In en, this message translates to:
  /// **'{name}  yakuman'**
  String yakuLineYakuman(String name);

  /// No description provided for @scorePointOne.
  ///
  /// In en, this message translates to:
  /// **'{n} point'**
  String scorePointOne(int n);

  /// No description provided for @scorePointMany.
  ///
  /// In en, this message translates to:
  /// **'{n} points'**
  String scorePointMany(int n);

  /// No description provided for @scoreFaanChips.
  ///
  /// In en, this message translates to:
  /// **'{faan} faan — {points} chips{limit}'**
  String scoreFaanChips(int faan, int points, String limit);

  /// No description provided for @scoreLimitOnly.
  ///
  /// In en, this message translates to:
  /// **'{limit} — {points}'**
  String scoreLimitOnly(String limit, int points);

  /// No description provided for @scoreHanFu.
  ///
  /// In en, this message translates to:
  /// **'{han} han {fu} fu{limit} — {points}'**
  String scoreHanFu(int han, int fu, String limit, int points);

  /// No description provided for @limitSuffix.
  ///
  /// In en, this message translates to:
  /// **'  ({limit})'**
  String limitSuffix(String limit);

  /// No description provided for @wallExhaustedNoPayments.
  ///
  /// In en, this message translates to:
  /// **'Wall exhausted — no payments'**
  String get wallExhaustedNoPayments;

  /// No description provided for @allNoten.
  ///
  /// In en, this message translates to:
  /// **'All players noten'**
  String get allNoten;

  /// No description provided for @tenpaiRevealed.
  ///
  /// In en, this message translates to:
  /// **'Tenpai hands revealed'**
  String get tenpaiRevealed;

  /// No description provided for @waits.
  ///
  /// In en, this message translates to:
  /// **'waits'**
  String get waits;

  /// No description provided for @backToMenu.
  ///
  /// In en, this message translates to:
  /// **'Back to menu'**
  String get backToMenu;

  /// No description provided for @cantReachServer.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the multiplayer server — retrying…'**
  String get cantReachServer;

  /// No description provided for @noGuideOnline.
  ///
  /// In en, this message translates to:
  /// **'Multiplayer has no TileSense guide — play single player for it.'**
  String get noGuideOnline;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @yourNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Defaults to your character — edit to use your own'**
  String get yourNameHelper;

  /// No description provided for @createARoom.
  ///
  /// In en, this message translates to:
  /// **'Create a room'**
  String get createARoom;

  /// No description provided for @createRoomButton.
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get createRoomButton;

  /// No description provided for @joinARoom.
  ///
  /// In en, this message translates to:
  /// **'Join a room'**
  String get joinARoom;

  /// No description provided for @roomCode.
  ///
  /// In en, this message translates to:
  /// **'Room code'**
  String get roomCode;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @chooseYourCharacter.
  ///
  /// In en, this message translates to:
  /// **'Choose your character'**
  String get chooseYourCharacter;

  /// No description provided for @pace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get pace;

  /// No description provided for @paceFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get paceFast;

  /// No description provided for @paceStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get paceStandard;

  /// No description provided for @paceRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get paceRelaxed;

  /// No description provided for @paceCaption.
  ///
  /// In en, this message translates to:
  /// **'{turn}s per turn · {call}s to call'**
  String paceCaption(int turn, int call);

  /// No description provided for @minimumFaanToWin.
  ///
  /// In en, this message translates to:
  /// **'Minimum faan to win'**
  String get minimumFaanToWin;

  /// No description provided for @minimumTaiToWin.
  ///
  /// In en, this message translates to:
  /// **'Minimum tai to win'**
  String get minimumTaiToWin;

  /// No description provided for @roomCodeShare.
  ///
  /// In en, this message translates to:
  /// **'Room code — share this with the other players'**
  String get roomCodeShare;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @roomCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Room code copied'**
  String get roomCodeCopied;

  /// No description provided for @roomFaanMin.
  ///
  /// In en, this message translates to:
  /// **'{n}-faan min'**
  String roomFaanMin(int n);

  /// No description provided for @roomTaiMin.
  ///
  /// In en, this message translates to:
  /// **'{n}-tai min'**
  String roomTaiMin(int n);

  /// No description provided for @roomFullGame.
  ///
  /// In en, this message translates to:
  /// **'full game'**
  String get roomFullGame;

  /// No description provided for @roomEastOnly.
  ///
  /// In en, this message translates to:
  /// **'East-only'**
  String get roomEastOnly;

  /// No description provided for @roomClocks.
  ///
  /// In en, this message translates to:
  /// **'{turn}s turn · {call}s call'**
  String roomClocks(int turn, int call);

  /// No description provided for @startGameBots.
  ///
  /// In en, this message translates to:
  /// **'Start Game — bots fill any empty seats'**
  String get startGameBots;

  /// No description provided for @waitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to start…'**
  String get waitingForHost;

  /// No description provided for @leaveRoomButton.
  ///
  /// In en, this message translates to:
  /// **'Leave Room'**
  String get leaveRoomButton;

  /// No description provided for @emptySeat.
  ///
  /// In en, this message translates to:
  /// **'Empty seat'**
  String get emptySeat;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'HOST'**
  String get host;

  /// No description provided for @rejoiningGame.
  ///
  /// In en, this message translates to:
  /// **'Rejoining your game…'**
  String get rejoiningGame;

  /// No description provided for @gameStillGoing.
  ///
  /// In en, this message translates to:
  /// **'Your game in room {code} is still going.'**
  String gameStillGoing(String code);

  /// No description provided for @rejoin.
  ///
  /// In en, this message translates to:
  /// **'Rejoin'**
  String get rejoin;

  /// No description provided for @leaveGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this game?'**
  String get leaveGameTitle;

  /// No description provided for @leaveGameBody.
  ///
  /// In en, this message translates to:
  /// **'A bot plays your seat until you come back — Rejoin is on the main menu while the game is on.'**
  String get leaveGameBody;

  /// No description provided for @noPauseOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'Online games can\'t be paused. Pick Relaxed for more time per turn.'**
  String get noPauseOnlineHint;

  /// No description provided for @noPauseOnlineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Online games can\'t be paused. If you need to step away, a bot covers your seat after a timeout or disconnect, and you can rejoin from the main menu.'**
  String get noPauseOnlineTooltip;

  /// No description provided for @smallWindowHint.
  ///
  /// In en, this message translates to:
  /// **'The window is small, so the toolbar is in the Menu button by your hand. Enlarge the window for the full toolbar.'**
  String get smallWindowHint;

  /// No description provided for @smallWindowHintOnline.
  ///
  /// In en, this message translates to:
  /// **'The window is small, so sound, language and your ID are in the Menu button by your hand. Enlarge the window for the full toolbar.'**
  String get smallWindowHintOnline;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @leaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave room'**
  String get leaveRoom;

  /// No description provided for @clientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get clientId;

  /// No description provided for @nowBotControlled.
  ///
  /// In en, this message translates to:
  /// **'{name} is now bot-controlled'**
  String nowBotControlled(String name);

  /// No description provided for @noGuideOnlineTooltip.
  ///
  /// In en, this message translates to:
  /// **'TileSensor sits out multiplayer, so no seat gets a guide the others lack.\nPlay single player to have me along!'**
  String get noGuideOnlineTooltip;

  /// No description provided for @roomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room {code}'**
  String roomLabel(String code);

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — reconnecting…'**
  String get connectionLost;

  /// No description provided for @backToStart.
  ///
  /// In en, this message translates to:
  /// **'Back to start'**
  String get backToStart;

  /// No description provided for @errorNotSeated.
  ///
  /// In en, this message translates to:
  /// **'you are not seated in this room'**
  String get errorNotSeated;

  /// No description provided for @errorSeatBotControlled.
  ///
  /// In en, this message translates to:
  /// **'this seat is bot-controlled'**
  String get errorSeatBotControlled;

  /// No description provided for @errorMissingGuestId.
  ///
  /// In en, this message translates to:
  /// **'missing guestId'**
  String get errorMissingGuestId;

  /// No description provided for @errorServerFull.
  ///
  /// In en, this message translates to:
  /// **'server is full, try again shortly'**
  String get errorServerFull;

  /// No description provided for @errorMissingRoom.
  ///
  /// In en, this message translates to:
  /// **'missing roomCode or guestId'**
  String get errorMissingRoom;

  /// No description provided for @errorRoomNotFound.
  ///
  /// In en, this message translates to:
  /// **'room not found'**
  String get errorRoomNotFound;

  /// No description provided for @errorRoomStarted.
  ///
  /// In en, this message translates to:
  /// **'that room has already started'**
  String get errorRoomStarted;

  /// No description provided for @errorRoomFull.
  ///
  /// In en, this message translates to:
  /// **'room is full'**
  String get errorRoomFull;

  /// No description provided for @errorNotHost.
  ///
  /// In en, this message translates to:
  /// **'only the host can start the game'**
  String get errorNotHost;

  /// No description provided for @errorRoomGone.
  ///
  /// In en, this message translates to:
  /// **'room no longer exists'**
  String get errorRoomGone;

  /// No description provided for @errorUnknownType.
  ///
  /// In en, this message translates to:
  /// **'unknown message type'**
  String get errorUnknownType;

  /// No description provided for @errorMalformed.
  ///
  /// In en, this message translates to:
  /// **'malformed message'**
  String get errorMalformed;

  /// No description provided for @errorBadRequest.
  ///
  /// In en, this message translates to:
  /// **'bad request'**
  String get errorBadRequest;

  /// No description provided for @errorIllegalAction.
  ///
  /// In en, this message translates to:
  /// **'illegal action for the current turn'**
  String get errorIllegalAction;

  /// No description provided for @errorNoActionExpected.
  ///
  /// In en, this message translates to:
  /// **'no action expected right now'**
  String get errorNoActionExpected;

  /// No description provided for @errorGameEnded.
  ///
  /// In en, this message translates to:
  /// **'That game has ended'**
  String get errorGameEnded;

  /// No description provided for @guideTipTitle.
  ///
  /// In en, this message translates to:
  /// **'GUIDE\n'**
  String get guideTipTitle;

  /// No description provided for @guideGreen.
  ///
  /// In en, this message translates to:
  /// **'Green tile'**
  String get guideGreen;

  /// No description provided for @guideGreenBody.
  ///
  /// In en, this message translates to:
  /// **'the recommended discard'**
  String get guideGreenBody;

  /// No description provided for @guideYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow tile'**
  String get guideYellow;

  /// No description provided for @guideYellowBody.
  ///
  /// In en, this message translates to:
  /// **'the tile you just drew'**
  String get guideYellowBody;

  /// No description provided for @guidePause.
  ///
  /// In en, this message translates to:
  /// **'pause the game'**
  String get guidePause;

  /// No description provided for @guideHover.
  ///
  /// In en, this message translates to:
  /// **'\nHover a heading or a dial for what it means.'**
  String get guideHover;

  /// No description provided for @tipAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'AUTO-PLAY\n'**
  String get tipAutoTitle;

  /// No description provided for @tipAutoBody.
  ///
  /// In en, this message translates to:
  /// **'Who Auto-Play follows for your seat, and whose order the rows below are sorted in.\n'**
  String get tipAutoBody;

  /// No description provided for @tipAutoChoices.
  ///
  /// In en, this message translates to:
  /// **'• TileSense (default): the guide; its recommendation is on top.\n• Mortal bot: Mortal plays your seat, and its preferred move is on top. Any decision Mortal can\'t answer is played by the guide.'**
  String get tipAutoChoices;

  /// No description provided for @tipEvTitle.
  ///
  /// In en, this message translates to:
  /// **'TILESENSE EV\n'**
  String get tipEvTitle;

  /// No description provided for @tipFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'CHANCE OF FINISHING'**
  String get tipFinishTitle;

  /// No description provided for @tipFinishBody.
  ///
  /// In en, this message translates to:
  /// **'Odds you win before the hand ends. More live tiles and more draws left raise it.\n'**
  String get tipFinishBody;

  /// No description provided for @tipFinishMore.
  ///
  /// In en, this message translates to:
  /// **'hover Ukeire · tap the EV (HMR) number for the chart'**
  String get tipFinishMore;

  /// No description provided for @tipPayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'WHAT THE WIN PAYS'**
  String get tipPayoutTitle;

  /// No description provided for @tipPayoutTw.
  ///
  /// In en, this message translates to:
  /// **'A flat point total, the same from every payer, plus a dealer-streak bonus. Exact once ready; before that, estimated from the patterns shown.\n'**
  String get tipPayoutTw;

  /// No description provided for @tipPayoutHk.
  ///
  /// In en, this message translates to:
  /// **'Faan as chips. Exact once ready; before that, estimated from the patterns shown.\n'**
  String get tipPayoutHk;

  /// No description provided for @tipPayoutRiichi.
  ///
  /// In en, this message translates to:
  /// **'Points if it lands, plus honba and riichi sticks. Exact once tenpai; an estimate before.\n'**
  String get tipPayoutRiichi;

  /// No description provided for @tipPayoutMore.
  ///
  /// In en, this message translates to:
  /// **'tap the EV (HMR) number for the working'**
  String get tipPayoutMore;

  /// No description provided for @tipCutTitle.
  ///
  /// In en, this message translates to:
  /// **'WHAT THE CUT RISKS'**
  String get tipCutTitle;

  /// No description provided for @tipCutChinese.
  ///
  /// In en, this message translates to:
  /// **'Estimated loss to an opponent with 3+ exposed sets. No tile is fully safe.\n'**
  String get tipCutChinese;

  /// No description provided for @tipCutRiichi.
  ///
  /// In en, this message translates to:
  /// **'The riichi stick (lost unless you win). Against a live riichi, also how often this tile deals in and the turns it commits you to.\n'**
  String get tipCutRiichi;

  /// No description provided for @tipCutMore.
  ///
  /// In en, this message translates to:
  /// **'hover Risk and Safety'**
  String get tipCutMore;

  /// No description provided for @tipFocusTitle.
  ///
  /// In en, this message translates to:
  /// **'FOCUS'**
  String get tipFocusTitle;

  /// No description provided for @tipFocusBody.
  ///
  /// In en, this message translates to:
  /// **'Speed pays some payout for a better chance of finishing. Balanced adds no tilt.\n'**
  String get tipFocusBody;

  /// No description provided for @tipFocusMore.
  ///
  /// In en, this message translates to:
  /// **'hover FOCUS'**
  String get tipFocusMore;

  /// No description provided for @tipFocusPlacementMore.
  ///
  /// In en, this message translates to:
  /// **'hover FOCUS · STRATEGY and Placement for the rest'**
  String get tipFocusPlacementMore;

  /// No description provided for @tipEvHigher.
  ///
  /// In en, this message translates to:
  /// **'\nHigher is better. A dangerous, cheap cut can go negative.'**
  String get tipEvHigher;

  /// No description provided for @tipOrdinaryWide.
  ///
  /// In en, this message translates to:
  /// **'Wider than ordinary'**
  String get tipOrdinaryWide;

  /// No description provided for @tipOrdinaryWideBody.
  ///
  /// In en, this message translates to:
  /// **'steps forward faster, but never faster than an ordinary hand'**
  String get tipOrdinaryWideBody;

  /// No description provided for @tipOrdinaryTitle.
  ///
  /// In en, this message translates to:
  /// **'AN ORDINARY HAND HAS'**
  String get tipOrdinaryTitle;

  /// No description provided for @tipShantenLabel.
  ///
  /// In en, this message translates to:
  /// **'Shanten'**
  String get tipShantenLabel;

  /// No description provided for @tipUkeireLabel.
  ///
  /// In en, this message translates to:
  /// **'Ukeire'**
  String get tipUkeireLabel;

  /// No description provided for @tipAwayLabel.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get tipAwayLabel;

  /// No description provided for @tipAcceptsLabel.
  ///
  /// In en, this message translates to:
  /// **'Accepts'**
  String get tipAcceptsLabel;

  /// No description provided for @tipOrdinaryNote.
  ///
  /// In en, this message translates to:
  /// **'\nMeans, not medians: the average ukeire of the best discard at each shanten, measured over simulated solo games by a greedy efficiency player (no defence, no calls).'**
  String get tipOrdinaryNote;

  /// No description provided for @tipSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'SAFETY\n'**
  String get tipSafetyTitle;

  /// No description provided for @tipSafetyChinese.
  ///
  /// In en, this message translates to:
  /// **'How risky a tile is to cut against an opponent with an exposed hand. Higher = safer.\n'**
  String get tipSafetyChinese;

  /// No description provided for @tipSafetyRiichi.
  ///
  /// In en, this message translates to:
  /// **'How safe a tile is to cut against a riichi. 0 = dangerous, 15 = genbutsu.\n'**
  String get tipSafetyRiichi;

  /// No description provided for @tipNeverCertain.
  ///
  /// In en, this message translates to:
  /// **'Never certain'**
  String get tipNeverCertain;

  /// No description provided for @tipNeverCertainBody.
  ///
  /// In en, this message translates to:
  /// **'with no furiten, a tile an opponent discarded can still win'**
  String get tipNeverCertainBody;

  /// No description provided for @tipRatedWhen.
  ///
  /// In en, this message translates to:
  /// **'Rated when'**
  String get tipRatedWhen;

  /// No description provided for @tipGenbutsu.
  ///
  /// In en, this message translates to:
  /// **'Genbutsu'**
  String get tipGenbutsu;

  /// No description provided for @tipGenbutsuBody.
  ///
  /// In en, this message translates to:
  /// **'a tile that player discarded, or that passed them after their riichi, cannot win their hand'**
  String get tipGenbutsuBody;

  /// No description provided for @tipSuji.
  ///
  /// In en, this message translates to:
  /// **'Suji'**
  String get tipSuji;

  /// No description provided for @tipSujiBody.
  ///
  /// In en, this message translates to:
  /// **'a tile three away from one they discarded is safer'**
  String get tipSujiBody;

  /// No description provided for @tipRatedRiichi.
  ///
  /// In en, this message translates to:
  /// **'someone is in riichi — otherwise the column shows —'**
  String get tipRatedRiichi;

  /// No description provided for @tipDealInTitle.
  ///
  /// In en, this message translates to:
  /// **'CHANCE A CUT DEALS IN'**
  String get tipDealInTitle;

  /// No description provided for @tipRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get tipRating;

  /// No description provided for @tipTile.
  ///
  /// In en, this message translates to:
  /// **'Tile'**
  String get tipTile;

  /// No description provided for @tipDealsIn.
  ///
  /// In en, this message translates to:
  /// **'Deals in'**
  String get tipDealsIn;

  /// No description provided for @tipRating15.
  ///
  /// In en, this message translates to:
  /// **'Genbutsu — already discarded by that player'**
  String get tipRating15;

  /// No description provided for @tipRating13.
  ///
  /// In en, this message translates to:
  /// **'Honor, 1 live'**
  String get tipRating13;

  /// No description provided for @tipRating12.
  ///
  /// In en, this message translates to:
  /// **'Double suji'**
  String get tipRating12;

  /// No description provided for @tipRating11.
  ///
  /// In en, this message translates to:
  /// **'Suji terminal'**
  String get tipRating11;

  /// No description provided for @tipRating9.
  ///
  /// In en, this message translates to:
  /// **'Honor, 2 live'**
  String get tipRating9;

  /// No description provided for @tipRating8.
  ///
  /// In en, this message translates to:
  /// **'No-chance tile'**
  String get tipRating8;

  /// No description provided for @tipRating7.
  ///
  /// In en, this message translates to:
  /// **'Half suji'**
  String get tipRating7;

  /// No description provided for @tipRating6.
  ///
  /// In en, this message translates to:
  /// **'Suji 2/3/7/8, or honor with 3 live'**
  String get tipRating6;

  /// No description provided for @tipRating3.
  ///
  /// In en, this message translates to:
  /// **'Non-suji 2/3/7/8'**
  String get tipRating3;

  /// No description provided for @tipRating2.
  ///
  /// In en, this message translates to:
  /// **'Non-suji middle tile'**
  String get tipRating2;

  /// No description provided for @tipHkRating14.
  ///
  /// In en, this message translates to:
  /// **'Honor, none unseen'**
  String get tipHkRating14;

  /// No description provided for @tipHkRating11.
  ///
  /// In en, this message translates to:
  /// **'Honor, 1 unseen'**
  String get tipHkRating11;

  /// No description provided for @tipHkRating6.
  ///
  /// In en, this message translates to:
  /// **'Honor, 2 or more unseen'**
  String get tipHkRating6;

  /// No description provided for @tipHkRating5.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get tipHkRating5;

  /// No description provided for @tipHkRating3.
  ///
  /// In en, this message translates to:
  /// **'Suit tile'**
  String get tipHkRating3;

  /// No description provided for @tipRiskTitle.
  ///
  /// In en, this message translates to:
  /// **'RISK\n'**
  String get tipRiskTitle;

  /// No description provided for @tipDealInChance.
  ///
  /// In en, this message translates to:
  /// **'Deal-in chance'**
  String get tipDealInChance;

  /// No description provided for @tipDealInChanceBody.
  ///
  /// In en, this message translates to:
  /// **'from the tile\'s Safety rating'**
  String get tipDealInChanceBody;

  /// No description provided for @tipDealInCost.
  ///
  /// In en, this message translates to:
  /// **'Deal-in cost'**
  String get tipDealInCost;

  /// No description provided for @tipStyleWeight.
  ///
  /// In en, this message translates to:
  /// **'Style weight'**
  String get tipStyleWeight;

  /// No description provided for @tipLaterTurns.
  ///
  /// In en, this message translates to:
  /// **'Later turns'**
  String get tipLaterTurns;

  /// No description provided for @tipHowLong.
  ///
  /// In en, this message translates to:
  /// **'How long'**
  String get tipHowLong;

  /// No description provided for @tipChineseHorizon.
  ///
  /// In en, this message translates to:
  /// **'the hand\'s own expected length; a tile with no risk commits you to nothing'**
  String get tipChineseHorizon;

  /// No description provided for @tipFormula.
  ///
  /// In en, this message translates to:
  /// **'FORMULA'**
  String get tipFormula;

  /// No description provided for @tipDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'DETAIL\n'**
  String get tipDetailTitle;

  /// No description provided for @tipDetailBody.
  ///
  /// In en, this message translates to:
  /// **'Why this tile has the Safety rating it does.\n'**
  String get tipDetailBody;

  /// No description provided for @tipShows.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get tipShows;

  /// No description provided for @tipShowsBody.
  ///
  /// In en, this message translates to:
  /// **'genbutsu, suji, honor with copies left, and so on'**
  String get tipShowsBody;

  /// No description provided for @tipEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get tipEmpty;

  /// No description provided for @tipEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'nobody is being defended against, so there is nothing to explain'**
  String get tipEmptyBody;

  /// No description provided for @tipPlacementTitle.
  ///
  /// In en, this message translates to:
  /// **'PLACEMENT\n'**
  String get tipPlacementTitle;

  /// No description provided for @tipPlacementBody.
  ///
  /// In en, this message translates to:
  /// **'How a line moves your chance of finishing above the other three seats.\n'**
  String get tipPlacementBody;

  /// No description provided for @tipUses.
  ///
  /// In en, this message translates to:
  /// **'Uses'**
  String get tipUses;

  /// No description provided for @tipUsesBody.
  ///
  /// In en, this message translates to:
  /// **'the scores on the table and the hands left right now'**
  String get tipUsesBody;

  /// No description provided for @tipNotPoints.
  ///
  /// In en, this message translates to:
  /// **'Not points'**
  String get tipNotPoints;

  /// No description provided for @tipNotPointsBody.
  ///
  /// In en, this message translates to:
  /// **'scaled up ×1,000 so it reads at a glance; only its order against the other lines means anything'**
  String get tipNotPointsBody;

  /// No description provided for @tipHeuristic.
  ///
  /// In en, this message translates to:
  /// **'A heuristic'**
  String get tipHeuristic;

  /// No description provided for @tipHeuristicBody.
  ///
  /// In en, this message translates to:
  /// **'not a simulation'**
  String get tipHeuristicBody;

  /// No description provided for @tipWorthTitle.
  ///
  /// In en, this message translates to:
  /// **'WHAT 8,000 POINTS IS WORTH'**
  String get tipWorthTitle;

  /// No description provided for @tipSituation.
  ///
  /// In en, this message translates to:
  /// **'Situation'**
  String get tipSituation;

  /// No description provided for @tipHandsLeft.
  ///
  /// In en, this message translates to:
  /// **'Hands left'**
  String get tipHandsLeft;

  /// No description provided for @tipEven.
  ///
  /// In en, this message translates to:
  /// **'Even table'**
  String get tipEven;

  /// No description provided for @tipLead.
  ///
  /// In en, this message translates to:
  /// **'Big lead'**
  String get tipLead;

  /// No description provided for @tipBehind.
  ///
  /// In en, this message translates to:
  /// **'Far behind'**
  String get tipBehind;

  /// No description provided for @tipEvenLast.
  ///
  /// In en, this message translates to:
  /// **'Even table, last hand'**
  String get tipEvenLast;

  /// No description provided for @tipLeadLast.
  ///
  /// In en, this message translates to:
  /// **'Big lead, last hand'**
  String get tipLeadLast;

  /// No description provided for @tipPlacementNote.
  ///
  /// In en, this message translates to:
  /// **'\nPoints matter most in a close race and late in the game, and least when you are comfortably ahead.\n'**
  String get tipPlacementNote;

  /// No description provided for @tipNoWin.
  ///
  /// In en, this message translates to:
  /// **'This line has no winning hand to score yet.\n'**
  String get tipNoWin;

  /// No description provided for @tipRiskRow.
  ///
  /// In en, this message translates to:
  /// **'risk of this cut'**
  String get tipRiskRow;

  /// No description provided for @tipFinishRow.
  ///
  /// In en, this message translates to:
  /// **'chance of finishing'**
  String get tipFinishRow;

  /// No description provided for @tipPayoutRow.
  ///
  /// In en, this message translates to:
  /// **'what the win pays'**
  String get tipPayoutRow;

  /// No description provided for @tipSticksRow.
  ///
  /// In en, this message translates to:
  /// **'honba and sticks'**
  String get tipSticksRow;

  /// No description provided for @tipAverageRow.
  ///
  /// In en, this message translates to:
  /// **'so on average'**
  String get tipAverageRow;

  /// No description provided for @tipLockRow.
  ///
  /// In en, this message translates to:
  /// **'less riichi lock-in'**
  String get tipLockRow;

  /// No description provided for @tipDealInRow.
  ///
  /// In en, this message translates to:
  /// **'less deal-in risk'**
  String get tipDealInRow;

  /// No description provided for @tipCommitRow.
  ///
  /// In en, this message translates to:
  /// **'less turns committed'**
  String get tipCommitRow;

  /// No description provided for @tipHmrBody.
  ///
  /// In en, this message translates to:
  /// **'A plain comparison figure — it never changes the recommendation.\n'**
  String get tipHmrBody;

  /// No description provided for @tipHmrExcludes.
  ///
  /// In en, this message translates to:
  /// **'\nNo honba or sticks, no risk costs, no Style or Focus tilt.\n'**
  String get tipHmrExcludes;

  /// No description provided for @tipHmrSource.
  ///
  /// In en, this message translates to:
  /// **'\nMirrors the \"E.V.\" stat in '**
  String get tipHmrSource;

  /// No description provided for @tipHmrSourceBody.
  ///
  /// In en, this message translates to:
  /// **', a solo tsumo-only trainer: points won ÷ hands played, which is win rate × average win.'**
  String get tipHmrSourceBody;

  /// No description provided for @tipYakuBody.
  ///
  /// In en, this message translates to:
  /// **'Each bar: of the times this line wins, the share that include that yaku. One win usually has several yaku, so the bars don\'t add up to 100%. 100% means every win has it; Riichi is 100% when the plan is to riichi.\n\nMultiply by the chance to win for the overall odds.\n\nDora aren\'t yaku, so they\'re shown separately as the average extra han.\n\n≈ marks an estimate: short of tenpai, the guide assumes you keep cutting for the widest hand and scores the likeliest ready hands that leads to. It doesn\'t plan around yaku you\'d have to steer toward (yakuhai, flushes), so those can read low. More than 3 tiles away, nothing is shown yet.'**
  String get tipYakuBody;

  /// No description provided for @tipMortalBody.
  ///
  /// In en, this message translates to:
  /// **'What Mortal, an open-source deep-learning mahjong AI, would do in your seat, seeing only what your seat can see. ★ marks its discard (★R: it would declare riichi first); the numbers are its order of preference among the rest. Its pick is outlined in red and the guide\'s filled green; green with a red outline means they agree.\n\n'**
  String get tipMortalBody;

  /// No description provided for @tipMortalAuto.
  ///
  /// In en, this message translates to:
  /// **'With AUTO-PLAY on Mortal bot, Auto-Play plays these moves and the rows follow Mortal\'s order; on TileSense (the default) they follow the guide\'s, and this is a second opinion. The green tile is always the guide\'s pick. Whenever Mortal can\'t answer, the guide decides.\n\n'**
  String get tipMortalAuto;

  /// No description provided for @tipMortalSource.
  ///
  /// In en, this message translates to:
  /// **'Riichi, single player. Mortal and its weights are AGPL-3.0 — source: github.com/Equim-chan/Mortal; the service that runs it: github.com/eric-r-xu/TileSense (mortal_sidecar).'**
  String get tipMortalSource;

  /// No description provided for @tipYakuTitle.
  ///
  /// In en, this message translates to:
  /// **'YAKU\n'**
  String get tipYakuTitle;

  /// No description provided for @tipEvAverage.
  ///
  /// In en, this message translates to:
  /// **'The average {unit} this discard is worth to you (EV = Expected Value).\n'**
  String tipEvAverage(String unit);

  /// No description provided for @tipShantenBody.
  ///
  /// In en, this message translates to:
  /// **'How many tiles you are from a ready hand (0 means {ready}).'**
  String tipShantenBody(String ready);

  /// No description provided for @tipUkeireBody.
  ///
  /// In en, this message translates to:
  /// **'Live tiles that {effect} — how many draws help.\n'**
  String tipUkeireBody(String effect);

  /// No description provided for @tipThreatSets.
  ///
  /// In en, this message translates to:
  /// **'an opponent shows {count} or more exposed sets — otherwise the column shows —'**
  String tipThreatSets(String count);

  /// No description provided for @tipChineseCost.
  ///
  /// In en, this message translates to:
  /// **'\nA deal-in is charged {cost} {unit}.'**
  String tipChineseCost(String cost, String unit);

  /// No description provided for @tipRiichiCost.
  ///
  /// In en, this message translates to:
  /// **'{cost} points ({dealerCost} to a dealer), plus 300 a honba'**
  String tipRiichiCost(String cost, String dealerCost);

  /// No description provided for @tipRiichiCostNote.
  ///
  /// In en, this message translates to:
  /// **'\nA deal-in costs {cost} ({dealerCost} to a dealer), plus 300 a honba.'**
  String tipRiichiCostNote(String cost, String dealerCost);

  /// No description provided for @tipRiskBody.
  ///
  /// In en, this message translates to:
  /// **'{unit} taken off EV for the danger of this cut.\n'**
  String tipRiskBody(String unit);

  /// No description provided for @tipStyleWeights.
  ///
  /// In en, this message translates to:
  /// **'×{weights} for {styles}'**
  String tipStyleWeights(String weights, String styles);

  /// No description provided for @tipCommitPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of the charge again for each turn the cut commits you to'**
  String tipCommitPercent(String percent);

  /// No description provided for @tipRiichiHorizon.
  ///
  /// In en, this message translates to:
  /// **'as long as the riichi lasts, about {turns} of your discards; a genbutsu cut commits you to nothing'**
  String tipRiichiHorizon(String turns);

  /// No description provided for @tipThisCut.
  ///
  /// In en, this message translates to:
  /// **'\nTHIS CUT — {tile}\n'**
  String tipThisCut(String tile);

  /// No description provided for @tipFocusTilt.
  ///
  /// In en, this message translates to:
  /// **'{focus} tilt'**
  String tipFocusTilt(String focus);

  /// No description provided for @tipRankOrder.
  ///
  /// In en, this message translates to:
  /// **'{name} ({direction} first)'**
  String tipRankOrder(String name, String direction);

  /// No description provided for @tipRankDirection.
  ///
  /// In en, this message translates to:
  /// **'\n\n{direction} is better — the arrow on the heading. '**
  String tipRankDirection(String direction);

  /// No description provided for @tipRankBody.
  ///
  /// In en, this message translates to:
  /// **'Discards are ranked by {first}, then {second}, then {third}; values count as equal when they show the same number. The green tile is the top of that order, and every tile equal to it on all three is green too.'**
  String tipRankBody(String first, String second, String third);

  /// No description provided for @tipReady.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get tipReady;

  /// No description provided for @tipTenpai.
  ///
  /// In en, this message translates to:
  /// **'tenpai'**
  String get tipTenpai;

  /// No description provided for @tipCloser.
  ///
  /// In en, this message translates to:
  /// **'bring you closer to ready'**
  String get tipCloser;

  /// No description provided for @tipReduce.
  ///
  /// In en, this message translates to:
  /// **'reduce shanten'**
  String get tipReduce;

  /// No description provided for @tipHigher.
  ///
  /// In en, this message translates to:
  /// **'Higher'**
  String get tipHigher;

  /// No description provided for @tipLower.
  ///
  /// In en, this message translates to:
  /// **'Lower'**
  String get tipLower;

  /// No description provided for @tipHigherFirst.
  ///
  /// In en, this message translates to:
  /// **'higher'**
  String get tipHigherFirst;

  /// No description provided for @tipLowerFirst.
  ///
  /// In en, this message translates to:
  /// **'lower'**
  String get tipLowerFirst;

  /// No description provided for @tipPlacementLabel.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get tipPlacementLabel;

  /// No description provided for @tipPointsUnit.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get tipPointsUnit;

  /// No description provided for @tipChipsUnit.
  ///
  /// In en, this message translates to:
  /// **'chips'**
  String get tipChipsUnit;

  /// No description provided for @tipBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get tipBalanced;

  /// No description provided for @tipSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get tipSpeed;

  /// No description provided for @tipAggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get tipAggressive;

  /// No description provided for @tipPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get tipPoints;

  /// No description provided for @tipDefensive.
  ///
  /// In en, this message translates to:
  /// **'Defensive'**
  String get tipDefensive;

  /// No description provided for @mathChance.
  ///
  /// In en, this message translates to:
  /// **'chance'**
  String get mathChance;

  /// No description provided for @mathFinish.
  ///
  /// In en, this message translates to:
  /// **'finish'**
  String get mathFinish;

  /// No description provided for @mathPayout.
  ///
  /// In en, this message translates to:
  /// **'payout'**
  String get mathPayout;

  /// No description provided for @mathWin.
  ///
  /// In en, this message translates to:
  /// **'win'**
  String get mathWin;

  /// No description provided for @mathRisk.
  ///
  /// In en, this message translates to:
  /// **'risk'**
  String get mathRisk;

  /// No description provided for @mathCut.
  ///
  /// In en, this message translates to:
  /// **'cut'**
  String get mathCut;

  /// No description provided for @mathDealIn.
  ///
  /// In en, this message translates to:
  /// **'deal-in'**
  String get mathDealIn;

  /// No description provided for @mathCost.
  ///
  /// In en, this message translates to:
  /// **'cost'**
  String get mathCost;

  /// No description provided for @mathWeight.
  ///
  /// In en, this message translates to:
  /// **'weight'**
  String get mathWeight;

  /// No description provided for @mathStyle.
  ///
  /// In en, this message translates to:
  /// **'style'**
  String get mathStyle;

  /// No description provided for @mathCharge.
  ///
  /// In en, this message translates to:
  /// **'charge'**
  String get mathCharge;

  /// No description provided for @mathLaterTurns.
  ///
  /// In en, this message translates to:
  /// **'later turns'**
  String get mathLaterTurns;

  /// No description provided for @mathWorth.
  ///
  /// In en, this message translates to:
  /// **'worth'**
  String get mathWorth;

  /// No description provided for @mathGain.
  ///
  /// In en, this message translates to:
  /// **'gain'**
  String get mathGain;

  /// No description provided for @mathScore.
  ///
  /// In en, this message translates to:
  /// **'score'**
  String get mathScore;

  /// No description provided for @mathOthers.
  ///
  /// In en, this message translates to:
  /// **'3 other seats'**
  String get mathOthers;

  /// No description provided for @mathTheirs.
  ///
  /// In en, this message translates to:
  /// **'theirs'**
  String get mathTheirs;

  /// No description provided for @mathSpread.
  ///
  /// In en, this message translates to:
  /// **'spread'**
  String get mathSpread;

  /// No description provided for @mathHandsLeft.
  ///
  /// In en, this message translates to:
  /// **'hands left'**
  String get mathHandsLeft;

  /// No description provided for @mathLogistic.
  ///
  /// In en, this message translates to:
  /// **'logistic'**
  String get mathLogistic;

  /// No description provided for @mascotIntro.
  ///
  /// In en, this message translates to:
  /// **'I\'m {mascot}: part prairie dog, part axolotl.\nI pick your best discards and calls.\nTurn on Auto-Play and I\'ll play your seat.\nMisplayed? Take it back and try again.\nPlay along and level up your {app}.'**
  String mascotIntro(String mascot, String app);

  /// No description provided for @rulesetMcr.
  ///
  /// In en, this message translates to:
  /// **'MCR'**
  String get rulesetMcr;

  /// No description provided for @rulesetSubtitleMcr.
  ///
  /// In en, this message translates to:
  /// **'fan, flowers, 8 fan minimum'**
  String get rulesetSubtitleMcr;

  /// No description provided for @mcrFullGame.
  ///
  /// In en, this message translates to:
  /// **'Full game · 16 hands'**
  String get mcrFullGame;

  /// No description provided for @mcrPractice.
  ///
  /// In en, this message translates to:
  /// **'East practice · 4 hands'**
  String get mcrPractice;

  /// No description provided for @mcrScoreTotal.
  ///
  /// In en, this message translates to:
  /// **'{fan} fan + {flowers} flowers · +{gain} points'**
  String mcrScoreTotal(int fan, int flowers, int gain);

  /// No description provided for @yakuLineMcr.
  ///
  /// In en, this message translates to:
  /// **'{name}  {n} fan'**
  String yakuLineMcr(String name, int n);

  /// No description provided for @tipPayoutMcr.
  ///
  /// In en, this message translates to:
  /// **'Fan plus flowers (F): the discarder pays F + 8 and the others 8 each, or everyone pays F + 8 on a self-draw. Exact once ready, where only waits worth 8 fan without flowers can win; before that, an estimate.\n'**
  String get tipPayoutMcr;

  /// No description provided for @rulesetSichuan.
  ///
  /// In en, this message translates to:
  /// **'Sichuan'**
  String get rulesetSichuan;

  /// No description provided for @rulesetSubtitleSichuan.
  ///
  /// In en, this message translates to:
  /// **'bloody battle, void suit, no chows'**
  String get rulesetSubtitleSichuan;

  /// No description provided for @sichuanFullGame.
  ///
  /// In en, this message translates to:
  /// **'Full game · 8 hands'**
  String get sichuanFullGame;

  /// No description provided for @sichuanPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice · 4 hands'**
  String get sichuanPractice;

  /// No description provided for @voidSuitTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your void suit'**
  String get voidSuitTitle;

  /// No description provided for @voidSuitHint.
  ///
  /// In en, this message translates to:
  /// **'You must discard every tile of this suit before any other, and a hand still holding one can\'t win.'**
  String get voidSuitHint;

  /// No description provided for @voidSuitWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other players to choose…'**
  String get voidSuitWaiting;

  /// No description provided for @suitMan.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get suitMan;

  /// No description provided for @suitPin.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get suitPin;

  /// No description provided for @suitSou.
  ///
  /// In en, this message translates to:
  /// **'Bamboo'**
  String get suitSou;

  /// No description provided for @voidSuitSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get voidSuitSuggested;

  /// No description provided for @voidSuitBadge.
  ///
  /// In en, this message translates to:
  /// **'Void: {suit}'**
  String voidSuitBadge(String suit);

  /// No description provided for @voidSuitUnknown.
  ///
  /// In en, this message translates to:
  /// **'Void: ?'**
  String get voidSuitUnknown;

  /// No description provided for @voidFirstNotice.
  ///
  /// In en, this message translates to:
  /// **'Discard your void suit first'**
  String get voidFirstNotice;

  /// No description provided for @huOutBadge.
  ///
  /// In en, this message translates to:
  /// **'HU'**
  String get huOutBadge;

  /// No description provided for @sichuanPayHu.
  ///
  /// In en, this message translates to:
  /// **'Hu'**
  String get sichuanPayHu;

  /// No description provided for @sichuanPayKong.
  ///
  /// In en, this message translates to:
  /// **'Kong'**
  String get sichuanPayKong;

  /// No description provided for @sichuanPayReady.
  ///
  /// In en, this message translates to:
  /// **'Unready pays ready'**
  String get sichuanPayReady;

  /// No description provided for @sichuanPayPenalty.
  ///
  /// In en, this message translates to:
  /// **'Void-suit penalty'**
  String get sichuanPayPenalty;

  /// No description provided for @resultWallEnds.
  ///
  /// In en, this message translates to:
  /// **'Wall ends'**
  String get resultWallEnds;

  /// No description provided for @resultThreeHu.
  ///
  /// In en, this message translates to:
  /// **'Three players out'**
  String get resultThreeHu;

  /// No description provided for @scRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get scRoot;

  /// No description provided for @scAllPungs.
  ///
  /// In en, this message translates to:
  /// **'All Pungs'**
  String get scAllPungs;

  /// No description provided for @scFullFlush.
  ///
  /// In en, this message translates to:
  /// **'Full Flush'**
  String get scFullFlush;

  /// No description provided for @scSevenPairs.
  ///
  /// In en, this message translates to:
  /// **'Seven Pairs'**
  String get scSevenPairs;

  /// No description provided for @scGoldenSingleWait.
  ///
  /// In en, this message translates to:
  /// **'Golden Single Wait'**
  String get scGoldenSingleWait;

  /// No description provided for @scWinAfterKong.
  ///
  /// In en, this message translates to:
  /// **'Win after Kong'**
  String get scWinAfterKong;

  /// No description provided for @scRobbingTheKong.
  ///
  /// In en, this message translates to:
  /// **'Robbing the Kong'**
  String get scRobbingTheKong;

  /// No description provided for @scShootAfterKong.
  ///
  /// In en, this message translates to:
  /// **'Shoot after Kong'**
  String get scShootAfterKong;

  /// No description provided for @scUnderTheSea.
  ///
  /// In en, this message translates to:
  /// **'Under the Sea'**
  String get scUnderTheSea;

  /// No description provided for @statusHandNumber.
  ///
  /// In en, this message translates to:
  /// **'Hand {n}'**
  String statusHandNumber(int n);

  /// No description provided for @sichuanScoreTotal.
  ///
  /// In en, this message translates to:
  /// **'{fan} fan · hand value {value}'**
  String sichuanScoreTotal(int fan, int value);

  /// No description provided for @learnToPlay.
  ///
  /// In en, this message translates to:
  /// **'Learn to play'**
  String get learnToPlay;

  /// No description provided for @learnNewLink.
  ///
  /// In en, this message translates to:
  /// **'New to mahjong? Learn to play'**
  String get learnNewLink;

  /// No description provided for @learnStepOf.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String learnStepOf(int current, int total);

  /// No description provided for @learnNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get learnNext;

  /// No description provided for @learnSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get learnSkip;

  /// No description provided for @learnDone.
  ///
  /// In en, this message translates to:
  /// **'Let\'s play'**
  String get learnDone;

  /// No description provided for @learnGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'The goal'**
  String get learnGoalTitle;

  /// No description provided for @learnGoalBody.
  ///
  /// In en, this message translates to:
  /// **'Build a hand of 14 tiles made of four sets plus one pair. Each turn you draw a tile and discard one, working toward that shape. The first player to complete it wins the hand.'**
  String get learnGoalBody;

  /// No description provided for @learnTilesTitle.
  ///
  /// In en, this message translates to:
  /// **'The tiles'**
  String get learnTilesTitle;

  /// No description provided for @learnTilesBody.
  ///
  /// In en, this message translates to:
  /// **'There are three suits numbered 1 to 9 (characters, dots and bamboo), plus four winds and three dragons. Some rulesets, Hong Kong among them, add flower tiles: they score a bonus and are replaced from the wall.'**
  String get learnTilesBody;

  /// No description provided for @learnSetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sets and calls'**
  String get learnSetsTitle;

  /// No description provided for @learnSetsBody.
  ///
  /// In en, this message translates to:
  /// **'A set is a run of three in one suit (a chow), three identical tiles (a pong), or four identical tiles (a kong). You can claim another player\'s discard to finish a set, and a chow only from the player on your left. A claimed set is shown face up.'**
  String get learnSetsBody;

  /// No description provided for @learnWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Winning'**
  String get learnWinTitle;

  /// No description provided for @learnWinBodyHongKong.
  ///
  /// In en, this message translates to:
  /// **'Complete four sets and a pair, by drawing the last tile yourself or claiming a discard, and you win. With the default minimum of 0 faan, any complete hand wins, even the simplest. The guide at the table shows how far you are from a win.'**
  String get learnWinBodyHongKong;

  /// No description provided for @learnWinBodyOther.
  ///
  /// In en, this message translates to:
  /// **'Complete four sets and a pair to win, as long as the hand also meets {rules}\'s own requirements. The guide at the table shows how far you are from a win.'**
  String learnWinBodyOther(String rules);

  /// No description provided for @guideViewSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get guideViewSimple;

  /// No description provided for @guideViewFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get guideViewFull;

  /// No description provided for @guideViewToFullTip.
  ///
  /// In en, this message translates to:
  /// **'Simple guide. Tap for the full table (shanten, EV, safety).'**
  String get guideViewToFullTip;

  /// No description provided for @guideViewToSimpleTip.
  ///
  /// In en, this message translates to:
  /// **'Full guide. Tap for the simple view.'**
  String get guideViewToSimpleTip;

  /// No description provided for @guideStatusComplete.
  ///
  /// In en, this message translates to:
  /// **'Your hand is complete!'**
  String get guideStatusComplete;

  /// No description provided for @guideBestDiscard.
  ///
  /// In en, this message translates to:
  /// **'Best discard'**
  String get guideBestDiscard;

  /// No description provided for @guideOtherChoices.
  ///
  /// In en, this message translates to:
  /// **'OTHER CHOICES'**
  String get guideOtherChoices;

  /// No description provided for @guideOutlookWins.
  ///
  /// In en, this message translates to:
  /// **'Completes your hand!'**
  String get guideOutlookWins;

  /// No description provided for @guideOutlookWaiting.
  ///
  /// In en, this message translates to:
  /// **'Leaves you waiting for {n, plural, =1{1 tile} other{{n} tiles}} to win.'**
  String guideOutlookWaiting(int n);

  /// No description provided for @guideOutlookOnTrack.
  ///
  /// In en, this message translates to:
  /// **'Keeps you on track, with {n, plural, =1{1 helpful tile} other{{n} helpful tiles}} left.'**
  String guideOutlookOnTrack(int n);

  /// No description provided for @guideOutlookFurther.
  ///
  /// In en, this message translates to:
  /// **'Moves you further from winning.'**
  String get guideOutlookFurther;

  /// No description provided for @guideCallTake.
  ///
  /// In en, this message translates to:
  /// **'The guide would claim this tile.'**
  String get guideCallTake;

  /// No description provided for @guideCallPass.
  ///
  /// In en, this message translates to:
  /// **'The guide would pass on this tile.'**
  String get guideCallPass;

  /// No description provided for @handPromptWin.
  ///
  /// In en, this message translates to:
  /// **'You can win with the {tile}! Tap {call}.'**
  String handPromptWin(String tile, String call);

  /// No description provided for @handPromptTsumo.
  ///
  /// In en, this message translates to:
  /// **'Your hand is complete! Tap {call}.'**
  String handPromptTsumo(String call);

  /// No description provided for @handPromptCall.
  ///
  /// In en, this message translates to:
  /// **'You can {calls} the {tile}, or pass.'**
  String handPromptCall(String tile, String calls);

  /// No description provided for @handPromptDiscard.
  ///
  /// In en, this message translates to:
  /// **'Your turn: tap a tile to discard it.'**
  String get handPromptDiscard;

  /// No description provided for @guideAway.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 tile} other{{n} tiles}} away from winning'**
  String guideAway(int n);

  /// No description provided for @guideWinningTiles.
  ///
  /// In en, this message translates to:
  /// **'Winning tiles · {n} left'**
  String guideWinningTiles(int n);

  /// No description provided for @guideOutlookOnTrackFar.
  ///
  /// In en, this message translates to:
  /// **'Keeps you on track.'**
  String get guideOutlookOnTrackFar;

  /// No description provided for @glossaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Glossary'**
  String get glossaryTitle;

  /// No description provided for @glossarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search terms'**
  String get glossarySearchHint;

  /// No description provided for @glossaryNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No terms match your search.'**
  String get glossaryNoMatch;

  /// No description provided for @glossaryUnitHan.
  ///
  /// In en, this message translates to:
  /// **'Han'**
  String get glossaryUnitHan;

  /// No description provided for @glossaryUnitFaan.
  ///
  /// In en, this message translates to:
  /// **'Faan'**
  String get glossaryUnitFaan;

  /// No description provided for @glossaryUnitTai.
  ///
  /// In en, this message translates to:
  /// **'Tai'**
  String get glossaryUnitTai;

  /// No description provided for @glossaryUnitFan.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get glossaryUnitFan;

  /// No description provided for @glossaryTermSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get glossaryTermSet;

  /// No description provided for @glossaryDefSet.
  ///
  /// In en, this message translates to:
  /// **'Three tiles that go together: a run of three in one suit, or three identical tiles. Four identical tiles also count, as a kong.'**
  String get glossaryDefSet;

  /// No description provided for @glossaryTermPair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get glossaryTermPair;

  /// No description provided for @glossaryDefPair.
  ///
  /// In en, this message translates to:
  /// **'Two identical tiles. A winning hand is four sets and exactly one pair.'**
  String get glossaryDefPair;

  /// No description provided for @glossaryDefChi.
  ///
  /// In en, this message translates to:
  /// **'Claim another player\'s discard to finish a run of three in one suit. Only from the player on your left; the set is then shown face up.'**
  String get glossaryDefChi;

  /// No description provided for @glossaryDefPon.
  ///
  /// In en, this message translates to:
  /// **'Claim a discard that matches two tiles in your hand, from any player, to make three of a kind. The set is shown face up.'**
  String get glossaryDefPon;

  /// No description provided for @glossaryDefKan.
  ///
  /// In en, this message translates to:
  /// **'Four identical tiles. You then draw a replacement tile from the end of the wall.'**
  String get glossaryDefKan;

  /// No description provided for @glossaryTermDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get glossaryTermDiscard;

  /// No description provided for @glossaryDefDiscard.
  ///
  /// In en, this message translates to:
  /// **'The tile you throw away at the end of your turn, face up in front of you. Other players may be able to claim it.'**
  String get glossaryDefDiscard;

  /// No description provided for @glossaryDefTsumo.
  ///
  /// In en, this message translates to:
  /// **'Winning on a tile you drew yourself.'**
  String get glossaryDefTsumo;

  /// No description provided for @glossaryDefRon.
  ///
  /// In en, this message translates to:
  /// **'Winning on a tile another player discarded.'**
  String get glossaryDefRon;

  /// No description provided for @glossaryTermDealer.
  ///
  /// In en, this message translates to:
  /// **'Dealer'**
  String get glossaryTermDealer;

  /// No description provided for @glossaryDefDealer.
  ///
  /// In en, this message translates to:
  /// **'The player seated East, who plays first. Winning usually lets the dealer keep the seat for another hand.'**
  String get glossaryDefDealer;

  /// No description provided for @glossaryTermWinds.
  ///
  /// In en, this message translates to:
  /// **'Winds'**
  String get glossaryTermWinds;

  /// No description provided for @glossaryDefWinds.
  ///
  /// In en, this message translates to:
  /// **'Four tiles: East, South, West and North. They also name the seats and the round, and a set of your own seat wind or the round wind can be worth extra.'**
  String get glossaryDefWinds;

  /// No description provided for @glossaryTermDragons.
  ///
  /// In en, this message translates to:
  /// **'Dragons'**
  String get glossaryTermDragons;

  /// No description provided for @glossaryDefDragons.
  ///
  /// In en, this message translates to:
  /// **'Three tiles: White, Green and Red. A set of any dragon is worth extra.'**
  String get glossaryDefDragons;

  /// No description provided for @glossaryTermFlowers.
  ///
  /// In en, this message translates to:
  /// **'Flowers'**
  String get glossaryTermFlowers;

  /// No description provided for @glossaryDefFlowers.
  ///
  /// In en, this message translates to:
  /// **'Bonus tiles. When you draw one, you show it and take a replacement from the wall. Each one can add to a winning hand\'s score.'**
  String get glossaryDefFlowers;

  /// No description provided for @glossaryTermVoid.
  ///
  /// In en, this message translates to:
  /// **'Void suit'**
  String get glossaryTermVoid;

  /// No description provided for @glossaryDefVoid.
  ///
  /// In en, this message translates to:
  /// **'You give up one of the three suits at the start. While you hold any tile of it, you must discard those first.'**
  String get glossaryDefVoid;

  /// No description provided for @glossaryDefScore.
  ///
  /// In en, this message translates to:
  /// **'What a winning hand earns. More means a more valuable hand. Some tables set a minimum a hand must reach before it can win.'**
  String get glossaryDefScore;

  /// No description provided for @glossaryTermRiichi.
  ///
  /// In en, this message translates to:
  /// **'Riichi'**
  String get glossaryTermRiichi;

  /// No description provided for @glossaryDefRiichi.
  ///
  /// In en, this message translates to:
  /// **'Declare a closed hand one tile from winning by betting 1,000 points. Your hand is then locked: you can only discard each tile you draw. It earns extra score.'**
  String get glossaryDefRiichi;

  /// No description provided for @glossaryTermDora.
  ///
  /// In en, this message translates to:
  /// **'Dora'**
  String get glossaryTermDora;

  /// No description provided for @glossaryDefDora.
  ///
  /// In en, this message translates to:
  /// **'Bonus tiles chosen by an indicator tile on the table. Each one in a winning hand adds a han.'**
  String get glossaryDefDora;

  /// No description provided for @glossaryTermFuriten.
  ///
  /// In en, this message translates to:
  /// **'Furiten'**
  String get glossaryTermFuriten;

  /// No description provided for @glossaryDefFuriten.
  ///
  /// In en, this message translates to:
  /// **'You can\'t win off a discard if a tile that would complete your hand is among your own discards. A self-draw still wins.'**
  String get glossaryDefFuriten;

  /// No description provided for @glossaryTermReady.
  ///
  /// In en, this message translates to:
  /// **'Ready hand'**
  String get glossaryTermReady;

  /// No description provided for @glossaryDefReady.
  ///
  /// In en, this message translates to:
  /// **'A hand one tile from winning. The guide shows which tiles would finish it.'**
  String get glossaryDefReady;

  /// No description provided for @glossaryTermAway.
  ///
  /// In en, this message translates to:
  /// **'Tiles away'**
  String get glossaryTermAway;

  /// No description provided for @glossaryDefAway.
  ///
  /// In en, this message translates to:
  /// **'How many more tiles your hand needs before it can win. One tile away means ready. The guide\'s meter and its Away or Shanten column show it.'**
  String get glossaryDefAway;

  /// No description provided for @glossaryTermHelpful.
  ///
  /// In en, this message translates to:
  /// **'Helpful tiles'**
  String get glossaryTermHelpful;

  /// No description provided for @glossaryDefHelpful.
  ///
  /// In en, this message translates to:
  /// **'Tiles you could draw that move your hand closer to winning. The guide counts how many are still unseen.'**
  String get glossaryDefHelpful;

  /// No description provided for @learnTile.
  ///
  /// In en, this message translates to:
  /// **'Learn / Train'**
  String get learnTile;

  /// No description provided for @moreTile.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTile;

  /// No description provided for @practiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practiceTitle;

  /// No description provided for @practiceLink.
  ///
  /// In en, this message translates to:
  /// **'Practice hands'**
  String get practiceLink;

  /// No description provided for @practiceProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String practiceProgress(int current, int total);

  /// No description provided for @practiceAskWin.
  ///
  /// In en, this message translates to:
  /// **'This hand is one tile from winning. Which tile completes it?'**
  String get practiceAskWin;

  /// No description provided for @practiceAskDiscard.
  ///
  /// In en, this message translates to:
  /// **'You\'ve drawn a tile. Which discard leaves you one tile from winning?'**
  String get practiceAskDiscard;

  /// No description provided for @practiceAskClaim.
  ///
  /// In en, this message translates to:
  /// **'What can you do with this discard?'**
  String get practiceAskClaim;

  /// No description provided for @practiceDiscardedBy.
  ///
  /// In en, this message translates to:
  /// **'Discarded by: {seat}'**
  String practiceDiscardedBy(String seat);

  /// No description provided for @practiceYourHand.
  ///
  /// In en, this message translates to:
  /// **'Your hand'**
  String get practiceYourHand;

  /// No description provided for @practiceCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get practiceCorrect;

  /// No description provided for @practiceWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite.'**
  String get practiceWrong;

  /// No description provided for @practiceNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get practiceNext;

  /// No description provided for @practiceSeeResults.
  ///
  /// In en, this message translates to:
  /// **'See results'**
  String get practiceSeeResults;

  /// No description provided for @practiceResult.
  ///
  /// In en, this message translates to:
  /// **'You got {score} of {total} right.'**
  String practiceResult(int score, int total);

  /// No description provided for @practiceAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get practiceAgain;

  /// No description provided for @practiceOptionPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get practiceOptionPass;

  /// No description provided for @practiceWhyW1.
  ///
  /// In en, this message translates to:
  /// **'Three sets and the pair 55s are done. The 1p and 3p need a 2p in the middle to make the run 1-2-3.'**
  String get practiceWhyW1;

  /// No description provided for @practiceWhyW2.
  ///
  /// In en, this message translates to:
  /// **'The 1p and 2p can only become 1-2-3, so only a 3p wins. A wait on the edge like this has just one winning tile.'**
  String get practiceWhyW2;

  /// No description provided for @practiceWhyW3.
  ///
  /// In en, this message translates to:
  /// **'Four sets are done. The single 5s needs a second 5s to make the pair, so only a 5s wins.'**
  String get practiceWhyW3;

  /// No description provided for @practiceWhyD1.
  ///
  /// In en, this message translates to:
  /// **'Three sets, the pair 66p and 3p-4p all work together. The lone 9s joins nothing, so throw it: you\'re then one tile from winning, waiting for a 2p or a 5p.'**
  String get practiceWhyD1;

  /// No description provided for @practiceWhyD2.
  ///
  /// In en, this message translates to:
  /// **'The East tile joins nothing. Throw it and the 1s-2s waits for a 3s to finish.'**
  String get practiceWhyD2;

  /// No description provided for @practiceWhyD3.
  ///
  /// In en, this message translates to:
  /// **'The lone West joins nothing. Throw it and the 7s-8s waits for a 6s or a 9s.'**
  String get practiceWhyD3;

  /// No description provided for @practiceWhyC1.
  ///
  /// In en, this message translates to:
  /// **'You hold two 5p, and a third from any player makes three of a kind. That is a {call}.'**
  String practiceWhyC1(String call);

  /// No description provided for @practiceWhyC2.
  ///
  /// In en, this message translates to:
  /// **'The player on your left discarded the 5p, and it fits between your 4p and 6p to make a run. That is a {call}.'**
  String practiceWhyC2(String call);

  /// No description provided for @practiceWhyC3.
  ///
  /// In en, this message translates to:
  /// **'A run can only be claimed from the player on your left. This 5p came from someone else, so you can\'t use it for a run. Pass.'**
  String get practiceWhyC3;

  /// No description provided for @practiceWhyC4.
  ///
  /// In en, this message translates to:
  /// **'Nothing in your hand pairs with the East tile or forms a run with it, so there is nothing to claim. Pass.'**
  String get practiceWhyC4;

  /// No description provided for @practiceChoices.
  ///
  /// In en, this message translates to:
  /// **'Choose a tile'**
  String get practiceChoices;

  /// No description provided for @practiceLegend.
  ///
  /// In en, this message translates to:
  /// **'m = characters, p = dots, s = bamboo'**
  String get practiceLegend;

  /// No description provided for @nudgeFullGuide.
  ///
  /// In en, this message translates to:
  /// **'You\'ve won {n} hands. Ready for more detail? The full guide shows the numbers behind each suggestion.'**
  String nudgeFullGuide(int n);

  /// No description provided for @nudgeFullGuideAction.
  ///
  /// In en, this message translates to:
  /// **'Show the full guide'**
  String get nudgeFullGuideAction;

  /// No description provided for @nudgeMinimum.
  ///
  /// In en, this message translates to:
  /// **'You\'ve won {n} hands. Try a 1 faan minimum: a hand now needs a little extra to win.'**
  String nudgeMinimum(int n);

  /// No description provided for @nudgeMinimumAction.
  ///
  /// In en, this message translates to:
  /// **'Use a 1 faan minimum'**
  String get nudgeMinimumAction;

  /// No description provided for @nudgeRuleset.
  ///
  /// In en, this message translates to:
  /// **'You\'ve won {n} hands. Ready for a new challenge? Try {rules}.'**
  String nudgeRuleset(int n, String rules);

  /// No description provided for @nudgeRulesetAction.
  ///
  /// In en, this message translates to:
  /// **'Switch to {rules}'**
  String nudgeRulesetAction(String rules);

  /// No description provided for @nudgeNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get nudgeNotNow;

  /// No description provided for @nudgeStop.
  ///
  /// In en, this message translates to:
  /// **'Stop suggesting'**
  String get nudgeStop;

  /// No description provided for @quizTitle.
  ///
  /// In en, this message translates to:
  /// **'What would TileSensor do?'**
  String get quizTitle;

  /// No description provided for @quizAskDiscard.
  ///
  /// In en, this message translates to:
  /// **'It\'s your turn and you\'ve drawn. What do you do?'**
  String get quizAskDiscard;

  /// No description provided for @quizAskCall.
  ///
  /// In en, this message translates to:
  /// **'{seat} just discarded. What do you do?'**
  String quizAskCall(String seat);

  /// No description provided for @quizDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get quizDiscard;

  /// No description provided for @quizRiichi.
  ///
  /// In en, this message translates to:
  /// **'Riichi'**
  String get quizRiichi;

  /// No description provided for @quizYourHand.
  ///
  /// In en, this message translates to:
  /// **'Your hand'**
  String get quizYourHand;

  /// No description provided for @quizChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose one'**
  String get quizChoose;

  /// No description provided for @quizYouPicked.
  ///
  /// In en, this message translates to:
  /// **'You picked'**
  String get quizYouPicked;

  /// No description provided for @quizBestMove.
  ///
  /// In en, this message translates to:
  /// **'Best move'**
  String get quizBestMove;

  /// No description provided for @quizAgree.
  ///
  /// In en, this message translates to:
  /// **'TileSense and Mortal agree'**
  String get quizAgree;

  /// No description provided for @quizTileSenseSays.
  ///
  /// In en, this message translates to:
  /// **'Why TileSense likes it'**
  String get quizTileSenseSays;

  /// No description provided for @quizMortalSays.
  ///
  /// In en, this message translates to:
  /// **'What Mortal says'**
  String get quizMortalSays;

  /// No description provided for @quizShanten.
  ///
  /// In en, this message translates to:
  /// **'Shanten'**
  String get quizShanten;

  /// No description provided for @quizUkeire.
  ///
  /// In en, this message translates to:
  /// **'Ukeire'**
  String get quizUkeire;

  /// No description provided for @quizEv.
  ///
  /// In en, this message translates to:
  /// **'EV'**
  String get quizEv;

  /// No description provided for @quizRisk.
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get quizRisk;

  /// No description provided for @quizMortalRank.
  ///
  /// In en, this message translates to:
  /// **'Mortal ranks your pick {rank} of {total}.'**
  String quizMortalRank(int rank, int total);

  /// No description provided for @quizMortalPicked.
  ///
  /// In en, this message translates to:
  /// **'Mortal picked this too.'**
  String get quizMortalPicked;

  /// No description provided for @quizMortalRankFirst.
  ///
  /// In en, this message translates to:
  /// **'Mortal\'s top pick.'**
  String get quizMortalRankFirst;

  /// No description provided for @quizMortalKan.
  ///
  /// In en, this message translates to:
  /// **'Mortal declares the kan here too.'**
  String get quizMortalKan;

  /// No description provided for @quizMortalNoKan.
  ///
  /// In en, this message translates to:
  /// **'Mortal does not declare a kan here.'**
  String get quizMortalNoKan;

  /// No description provided for @quizMortalNote.
  ///
  /// In en, this message translates to:
  /// **'Mortal does not explain its choices; this is its ranking.'**
  String get quizMortalNote;

  /// No description provided for @quizSeat.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get quizSeat;

  /// No description provided for @quizDora.
  ///
  /// In en, this message translates to:
  /// **'Dora indicator'**
  String get quizDora;

  /// No description provided for @quizProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {number} of {total}'**
  String quizProgress(int number, int total);

  /// No description provided for @quizNext.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get quizNext;

  /// No description provided for @quizSeeResults.
  ///
  /// In en, this message translates to:
  /// **'See today\'s results'**
  String get quizSeeResults;

  /// No description provided for @quizResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s quiz is done'**
  String get quizResultsTitle;

  /// No description provided for @quizResultsScore.
  ///
  /// In en, this message translates to:
  /// **'You got {right} of {total} right.'**
  String quizResultsScore(int right, int total);

  /// No description provided for @quizDone.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for new puzzles.'**
  String get quizDone;

  /// No description provided for @quizLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Today\'s puzzle could not be loaded.'**
  String get quizLoadFailed;

  /// No description provided for @quizLink.
  ///
  /// In en, this message translates to:
  /// **'Daily quiz'**
  String get quizLink;

  /// No description provided for @quizCardToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s puzzles are ready'**
  String get quizCardToday;

  /// No description provided for @quizCardDone.
  ///
  /// In en, this message translates to:
  /// **'Done for today. Back tomorrow!'**
  String get quizCardDone;

  /// No description provided for @quizStreak.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String quizStreak(int days);

  /// No description provided for @loadingQuiz.
  ///
  /// In en, this message translates to:
  /// **'Loading the daily quiz…'**
  String get loadingQuiz;

  /// No description provided for @quizDama.
  ///
  /// In en, this message translates to:
  /// **'Dama'**
  String get quizDama;

  /// No description provided for @quizAskRiichi.
  ///
  /// In en, this message translates to:
  /// **'That cut leaves you ready. Riichi, or stay quiet (dama)?'**
  String get quizAskRiichi;

  /// No description provided for @quizMortalRiichi.
  ///
  /// In en, this message translates to:
  /// **'Mortal declares riichi here.'**
  String get quizMortalRiichi;

  /// No description provided for @quizMortalDama.
  ///
  /// In en, this message translates to:
  /// **'Mortal stays quiet (dama) here.'**
  String get quizMortalDama;

  /// No description provided for @quizSituation.
  ///
  /// In en, this message translates to:
  /// **'The situation'**
  String get quizSituation;

  /// No description provided for @quizRoundLine.
  ///
  /// In en, this message translates to:
  /// **'{wind} {hand}: {left, plural, =1{the last hand} other{{left} hands left}}.'**
  String quizRoundLine(String wind, int hand, int left);

  /// No description provided for @quizStageEarly.
  ///
  /// In en, this message translates to:
  /// **'Early in the hand'**
  String get quizStageEarly;

  /// No description provided for @quizStageMiddle.
  ///
  /// In en, this message translates to:
  /// **'Midway through the hand'**
  String get quizStageMiddle;

  /// No description provided for @quizStageLate.
  ///
  /// In en, this message translates to:
  /// **'Late in the hand'**
  String get quizStageLate;

  /// No description provided for @quizTimingLine.
  ///
  /// In en, this message translates to:
  /// **'{stage}: {wall} tiles left in the wall.'**
  String quizTimingLine(String stage, int wall);

  /// No description provided for @quizDealerYes.
  ///
  /// In en, this message translates to:
  /// **'You are the dealer: a win pays half again as much and the deal stays with you.'**
  String get quizDealerYes;

  /// No description provided for @quizDealerNo.
  ///
  /// In en, this message translates to:
  /// **'You are not the dealer.'**
  String get quizDealerNo;

  /// No description provided for @quizPlaceEven.
  ///
  /// In en, this message translates to:
  /// **'Scores are level at {points}, so placement is not in play.'**
  String quizPlaceEven(String points);

  /// No description provided for @quizPlaceLead.
  ///
  /// In en, this message translates to:
  /// **'Placement: {rank} of 4, {lead} points ahead of the next seat.'**
  String quizPlaceLead(int rank, String lead);

  /// No description provided for @quizPlaceBehind.
  ///
  /// In en, this message translates to:
  /// **'Placement: {rank} of 4, {gap} points behind 1st.'**
  String quizPlaceBehind(int rank, String gap);

  /// No description provided for @quizThreat.
  ///
  /// In en, this message translates to:
  /// **'{seat} is in riichi, declared {turns, plural, =1{this turn} other{{turns} turns ago}}.'**
  String quizThreat(String seat, int turns);

  /// No description provided for @quizNoThreat.
  ///
  /// In en, this message translates to:
  /// **'Nobody else is in riichi.'**
  String get quizNoThreat;

  /// No description provided for @quizFocusPlacement.
  ///
  /// In en, this message translates to:
  /// **'Final hands: TileSense weighs how each option moves your finishing place, not just your points.'**
  String get quizFocusPlacement;

  /// No description provided for @quizFocusPoints.
  ///
  /// In en, this message translates to:
  /// **'Plenty of hands left: TileSense plays for points.'**
  String get quizFocusPoints;

  /// No description provided for @rulesetSanma.
  ///
  /// In en, this message translates to:
  /// **'Sanma'**
  String get rulesetSanma;

  /// No description provided for @rulesetSanmaLong.
  ///
  /// In en, this message translates to:
  /// **'Sanma (3-player riichi mahjong)'**
  String get rulesetSanmaLong;

  /// No description provided for @rulesetSubtitleSanma.
  ///
  /// In en, this message translates to:
  /// **'3-player riichi: no chi, kita, no 2–8 man'**
  String get rulesetSubtitleSanma;

  /// No description provided for @sanmaTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sanma (三麻) is 3-player riichi mahjong: three players, 108 tiles (the 2–8 man are removed), no chi, and North tiles set aside as kita for an extra dora.'**
  String get sanmaTooltip;

  /// No description provided for @rulesWeb.
  ///
  /// In en, this message translates to:
  /// **'{rules} rules (web)'**
  String rulesWeb(String rules);

  /// No description provided for @kitaCaps.
  ///
  /// In en, this message translates to:
  /// **'KITA'**
  String get kitaCaps;

  /// No description provided for @bubbleKita.
  ///
  /// In en, this message translates to:
  /// **'KITA'**
  String get bubbleKita;

  /// No description provided for @undoKita.
  ///
  /// In en, this message translates to:
  /// **'Kita'**
  String get undoKita;

  /// No description provided for @yakuKita.
  ///
  /// In en, this message translates to:
  /// **'Kita'**
  String get yakuKita;

  /// No description provided for @emptySeatSanma.
  ///
  /// In en, this message translates to:
  /// **'No player: sanma is played by three'**
  String get emptySeatSanma;

  /// No description provided for @hanchanOnTooltipSanma.
  ///
  /// In en, this message translates to:
  /// **'Hanchan — East and South (半庄) rounds of 3-player sanma, 6+ hands (3 a round, one per player).\n{caveat}\nTap for East only (东风战), 3+ hands.'**
  String hanchanOnTooltipSanma(String caveat);

  /// No description provided for @eastOnlyTooltipSanma.
  ///
  /// In en, this message translates to:
  /// **'East only (东风战/tonpuusen) — the East round of 3-player sanma, 3+ hands.\n{caveat}\nTap for hanchan (半庄): East and South, 6+ hands.'**
  String eastOnlyTooltipSanma(String caveat);

  /// No description provided for @glossaryTermSanma.
  ///
  /// In en, this message translates to:
  /// **'Sanma'**
  String get glossaryTermSanma;

  /// No description provided for @glossaryDefSanma.
  ///
  /// In en, this message translates to:
  /// **'Three-player riichi mahjong (三麻). The 2–8 man are taken out, leaving 108 tiles; there is no chi; seats go East, South, West; everyone starts on 35,000. A self-draw is paid by the two others only, so it is worth less than the same hand by ron.'**
  String get glossaryDefSanma;

  /// No description provided for @glossaryTermKita.
  ///
  /// In en, this message translates to:
  /// **'Kita (North set aside)'**
  String get glossaryTermKita;

  /// No description provided for @glossaryDefKita.
  ///
  /// In en, this message translates to:
  /// **'In sanma, a North can be set aside instead of kept: it counts as a dora, and you draw a replacement from the dead wall. An opponent may ron it.'**
  String get glossaryDefKita;

  /// No description provided for @quizNoneSanma.
  ///
  /// In en, this message translates to:
  /// **'There is no daily quiz for Sanma yet. Switch to Riichi or Hong Kong to play it.'**
  String get quizNoneSanma;

  /// No description provided for @tourHandTitle.
  ///
  /// In en, this message translates to:
  /// **'Your hand'**
  String get tourHandTitle;

  /// No description provided for @tourHandBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a tile to raise it, then tap it again to discard it. To rearrange your hand, press and hold a tile, then drag it to a new spot.'**
  String get tourHandBody;

  /// No description provided for @tourButtonsTitle.
  ///
  /// In en, this message translates to:
  /// **'The buttons beside your hand'**
  String get tourButtonsTitle;

  /// No description provided for @tourButtonsBody.
  ///
  /// In en, this message translates to:
  /// **'Four switches for how your hand plays. Each is filled in when it is on.'**
  String get tourButtonsBody;

  /// No description provided for @tourLegendSortBody.
  ///
  /// In en, this message translates to:
  /// **'taps through three modes. Hand keeps your tiles in order with the drawn tile set apart on the right; Hand+draw sorts the drawn tile straight in; Off leaves every tile where you drag it.'**
  String get tourLegendSortBody;

  /// No description provided for @tourLegendDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'one tap to discard, or two (raise, then discard).'**
  String get tourLegendDiscardBody;

  /// No description provided for @tourLegendAutoWinBody.
  ///
  /// In en, this message translates to:
  /// **'declares a win for you the moment you can.'**
  String get tourLegendAutoWinBody;

  /// No description provided for @tourLegendAutoPassBody.
  ///
  /// In en, this message translates to:
  /// **'skips calls on other players\' tiles, so you aren\'t asked.'**
  String get tourLegendAutoPassBody;

  /// No description provided for @tourGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'TileSensor, your guide'**
  String get tourGuideTitle;

  /// No description provided for @tourGuideBody.
  ///
  /// In en, this message translates to:
  /// **'Tap TileSensor to show the guide. It ranks every discard, marks the best one in green and explains why. Tap again to hide it.'**
  String get tourGuideBody;

  /// No description provided for @tourRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'The rulebook'**
  String get tourRulesTitle;

  /// No description provided for @tourRulesBodyDesktop.
  ///
  /// In en, this message translates to:
  /// **'The book icon in the top bar opens the rulebook for this game: every scoring pattern with tile examples, plus how to win, minimums and payments. Search it any time.'**
  String get tourRulesBodyDesktop;

  /// No description provided for @tourRulesBodyPhone.
  ///
  /// In en, this message translates to:
  /// **'Open Menu, then Rules, for the rulebook for this game: every scoring pattern with tile examples, plus how to win, minimums and payments. Search it any time.'**
  String get tourRulesBodyPhone;

  /// No description provided for @tourRulesOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the rulebook'**
  String get tourRulesOpen;

  /// No description provided for @tourMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings and help'**
  String get tourMenuTitle;

  /// No description provided for @tourMenuBodyPhone.
  ///
  /// In en, this message translates to:
  /// **'The Menu button holds pause, sound, speed, Auto-Play and the glossary. You can replay this tour from there.'**
  String get tourMenuBodyPhone;

  /// No description provided for @tourMenuBodyDesktop.
  ///
  /// In en, this message translates to:
  /// **'Settings run along the top bar, with the glossary beside the ruleset. Menu, top left, takes you back to the main menu, where Learn replays this tour.'**
  String get tourMenuBodyDesktop;

  /// No description provided for @tourSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip tour'**
  String get tourSkip;

  /// No description provided for @tourNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tourNext;

  /// No description provided for @tourDone.
  ///
  /// In en, this message translates to:
  /// **'Start playing'**
  String get tourDone;

  /// No description provided for @tableTourLink.
  ///
  /// In en, this message translates to:
  /// **'Table tour: how to play the table'**
  String get tableTourLink;

  /// No description provided for @tableTourMenu.
  ///
  /// In en, this message translates to:
  /// **'How the table works'**
  String get tableTourMenu;

  /// No description provided for @tourStepOf.
  ///
  /// In en, this message translates to:
  /// **'{step} of {total}'**
  String tourStepOf(int step, int total);

  /// No description provided for @rulesTileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Choose which mahjong rules to play: Riichi, Sanma, Hong Kong, Taiwanese, MCR or Sichuan.'**
  String get rulesTileTooltip;

  /// No description provided for @rulesRead.
  ///
  /// In en, this message translates to:
  /// **'Read rules'**
  String get rulesRead;

  /// No description provided for @rulesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search rules'**
  String get rulesSearchHint;

  /// No description provided for @rulesClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get rulesClearSearch;

  /// No description provided for @rulesNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No rules match your search. Try another word.'**
  String get rulesNoMatch;

  /// No description provided for @rulesSummaryNotice.
  ///
  /// In en, this message translates to:
  /// **'Quick guide to TileSense’s rules, with every scoring pattern the app counts. The external reference is the source these rules follow.'**
  String get rulesSummaryNotice;

  /// No description provided for @rulesReferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the reference. Please try again.'**
  String get rulesReferenceFailed;

  /// MCR fan 1 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Big Four Winds'**
  String get mcrFanBigFourWinds;

  /// MCR fan 2 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Big Three Dragons'**
  String get mcrFanBigThreeDragons;

  /// MCR fan 3 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Green'**
  String get mcrFanAllGreen;

  /// MCR fan 4 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Nine Gates'**
  String get mcrFanNineGates;

  /// MCR fan 5 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Four Kongs'**
  String get mcrFanFourKongs;

  /// MCR fan 6 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Seven Shifted Pairs'**
  String get mcrFanSevenShiftedPairs;

  /// MCR fan 7 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Thirteen Orphans'**
  String get mcrFanThirteenOrphans;

  /// MCR fan 8 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Terminals'**
  String get mcrFanAllTerminals;

  /// MCR fan 9 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Little Four Winds'**
  String get mcrFanLittleFourWinds;

  /// MCR fan 10 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Little Three Dragons'**
  String get mcrFanLittleThreeDragons;

  /// MCR fan 11 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Honors'**
  String get mcrFanAllHonors;

  /// MCR fan 12 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Four Concealed Pungs'**
  String get mcrFanFourConcealedPungs;

  /// MCR fan 13 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Pure Terminal Chows'**
  String get mcrFanPureTerminalChows;

  /// MCR fan 14 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Quadruple Chow'**
  String get mcrFanQuadrupleChow;

  /// MCR fan 15 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Four Pure Shifted Pungs'**
  String get mcrFanFourPureShiftedPungs;

  /// MCR fan 16 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Four Shifted Chows'**
  String get mcrFanFourShiftedChows;

  /// MCR fan 17 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Three Kongs'**
  String get mcrFanThreeKongs;

  /// MCR fan 18 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Terminals and Honors'**
  String get mcrFanAllTerminalsAndHonors;

  /// MCR fan 19 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Seven Pairs'**
  String get mcrFanSevenPairs;

  /// MCR fan 20 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Greater Honors and Knitted Tiles'**
  String get mcrFanGreaterHonorsAndKnittedTiles;

  /// MCR fan 21 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Even Pungs'**
  String get mcrFanAllEvenPungs;

  /// MCR fan 22 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Full Flush'**
  String get mcrFanFullFlush;

  /// MCR fan 23 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Pure Triple Chow'**
  String get mcrFanPureTripleChow;

  /// MCR fan 24 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Pure Shifted Pungs'**
  String get mcrFanPureShiftedPungs;

  /// MCR fan 25 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Upper Tiles'**
  String get mcrFanUpperTiles;

  /// MCR fan 26 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Middle Tiles'**
  String get mcrFanMiddleTiles;

  /// MCR fan 27 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Lower Tiles'**
  String get mcrFanLowerTiles;

  /// MCR fan 28 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Pure Straight'**
  String get mcrFanPureStraight;

  /// MCR fan 29 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Three-Suited Terminal Chows'**
  String get mcrFanThreeSuitedTerminalChows;

  /// MCR fan 30 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Pure Shifted Chows'**
  String get mcrFanPureShiftedChows;

  /// MCR fan 31 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Fives'**
  String get mcrFanAllFives;

  /// MCR fan 32 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Triple Pung'**
  String get mcrFanTriplePung;

  /// MCR fan 33 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Three Concealed Pungs'**
  String get mcrFanThreeConcealedPungs;

  /// MCR fan 34 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Lesser Honors and Knitted Tiles'**
  String get mcrFanLesserHonorsAndKnittedTiles;

  /// MCR fan 35 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Knitted Straight'**
  String get mcrFanKnittedStraight;

  /// MCR fan 36 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Upper Four'**
  String get mcrFanUpperFour;

  /// MCR fan 37 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Lower Four'**
  String get mcrFanLowerFour;

  /// MCR fan 38 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Big Three Winds'**
  String get mcrFanBigThreeWinds;

  /// MCR fan 39 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Mixed Straight'**
  String get mcrFanMixedStraight;

  /// MCR fan 40 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Reversible Tiles'**
  String get mcrFanReversibleTiles;

  /// MCR fan 41 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Mixed Triple Chow'**
  String get mcrFanMixedTripleChow;

  /// MCR fan 42 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Mixed Shifted Pungs'**
  String get mcrFanMixedShiftedPungs;

  /// MCR fan 43 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Chicken Hand'**
  String get mcrFanChickenHand;

  /// MCR fan 44 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Last Tile Draw'**
  String get mcrFanLastTileDraw;

  /// MCR fan 45 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Last Tile Claim'**
  String get mcrFanLastTileClaim;

  /// MCR fan 46 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Out with Replacement Tile'**
  String get mcrFanOutWithReplacementTile;

  /// MCR fan 47 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Robbing the Kong'**
  String get mcrFanRobbingTheKong;

  /// MCR fan 48 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Two Concealed Kongs'**
  String get mcrFanTwoConcealedKongs;

  /// MCR fan 49 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Pungs'**
  String get mcrFanAllPungs;

  /// MCR fan 50 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Half Flush'**
  String get mcrFanHalfFlush;

  /// MCR fan 51 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Mixed Shifted Chows'**
  String get mcrFanMixedShiftedChows;

  /// MCR fan 52 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Types'**
  String get mcrFanAllTypes;

  /// MCR fan 53 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Melded Hand'**
  String get mcrFanMeldedHand;

  /// MCR fan 54 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Two Dragon Pungs'**
  String get mcrFanTwoDragonPungs;

  /// MCR fan 55 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Outside Hand'**
  String get mcrFanOutsideHand;

  /// MCR fan 56 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Fully Concealed'**
  String get mcrFanFullyConcealed;

  /// MCR fan 57 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Two Melded Kongs'**
  String get mcrFanTwoMeldedKongs;

  /// MCR fan 58 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Last Tile'**
  String get mcrFanLastTile;

  /// MCR fan 59 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Dragon Pung'**
  String get mcrFanDragonPung;

  /// MCR fan 60 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Prevalent Wind'**
  String get mcrFanPrevalentWind;

  /// MCR fan 61 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Seat Wind'**
  String get mcrFanSeatWind;

  /// MCR fan 62 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Concealed Hand'**
  String get mcrFanConcealedHand;

  /// MCR fan 63 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Chows'**
  String get mcrFanAllChows;

  /// MCR fan 64 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Tile Hog'**
  String get mcrFanTileHog;

  /// MCR fan 65 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Double Pung'**
  String get mcrFanDoublePung;

  /// MCR fan 66 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Two Concealed Pungs'**
  String get mcrFanTwoConcealedPungs;

  /// MCR fan 67 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Concealed Kong'**
  String get mcrFanConcealedKong;

  /// MCR fan 68 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'All Simples'**
  String get mcrFanAllSimples;

  /// MCR fan 69 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Pure Double Chow'**
  String get mcrFanPureDoubleChow;

  /// MCR fan 70 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Mixed Double Chow'**
  String get mcrFanMixedDoubleChow;

  /// MCR fan 71 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Short Straight'**
  String get mcrFanShortStraight;

  /// MCR fan 72 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Two Terminal Chows'**
  String get mcrFanTwoTerminalChows;

  /// MCR fan 73 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Pung of Terminals or Honors'**
  String get mcrFanPungOfTerminalsOrHonors;

  /// MCR fan 74 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Melded Kong'**
  String get mcrFanMeldedKong;

  /// MCR fan 75 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'One Voided Suit'**
  String get mcrFanOneVoidedSuit;

  /// MCR fan 76 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'No Honors'**
  String get mcrFanNoHonors;

  /// MCR fan 77 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Edge Wait'**
  String get mcrFanEdgeWait;

  /// MCR fan 78 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Closed Wait'**
  String get mcrFanClosedWait;

  /// MCR fan 79 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Single Wait'**
  String get mcrFanSingleWait;

  /// MCR fan 80 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Self-Drawn'**
  String get mcrFanSelfDrawn;

  /// MCR fan 81 (Appendix 1).
  ///
  /// In en, this message translates to:
  /// **'Flower Tiles'**
  String get mcrFanFlowerTiles;

  /// MCR: one melded and one concealed kong, scored together (fan 57).
  ///
  /// In en, this message translates to:
  /// **'Melded and Concealed Kongs'**
  String get mcrFanMeldedAndConcealedKongs;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
