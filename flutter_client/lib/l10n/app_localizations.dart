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

  /// No description provided for @welcomeTo.
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get welcomeTo;

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
  /// **'Includes the guide'**
  String get singlePlayerSubtitle;

  /// No description provided for @playOnline.
  ///
  /// In en, this message translates to:
  /// **'Play Online'**
  String get playOnline;

  /// No description provided for @playOnlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'With friends — bots fill empty seats, no guide'**
  String get playOnlineSubtitle;

  /// No description provided for @builder.
  ///
  /// In en, this message translates to:
  /// **'Custom Hand & Context Builder'**
  String get builder;

  /// No description provided for @builderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pose any table and have TileSense score it'**
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
