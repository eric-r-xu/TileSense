// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TileSense';

  @override
  String get languageTooltip => 'Language';

  @override
  String get rulesetRiichi => 'Riichi';

  @override
  String get rulesetHongKong => 'Hong Kong';

  @override
  String get rulesetTaiwanese => 'Taiwanese';

  @override
  String get windEast => 'East';

  @override
  String get windSouth => 'South';

  @override
  String get windWest => 'West';

  @override
  String get windNorth => 'North';

  @override
  String get callChiRiichi => 'Chi';

  @override
  String get callChiHongKong => 'Chow';

  @override
  String get callChiTaiwanese => 'Chow';

  @override
  String get callPonRiichi => 'Pon';

  @override
  String get callPonHongKong => 'Pung';

  @override
  String get callPonTaiwanese => 'Pung';

  @override
  String get callKanRiichi => 'Kan';

  @override
  String get callKanHongKong => 'Kong';

  @override
  String get callKanTaiwanese => 'Kong';

  @override
  String get callRonRiichi => 'Ron';

  @override
  String get callRonHongKong => 'Win';

  @override
  String get callRonTaiwanese => 'Hu';

  @override
  String get callTsumoRiichi => 'Tsumo';

  @override
  String get callTsumoHongKong => 'Self-pick';

  @override
  String get callTsumoTaiwanese => 'Self-pick';

  @override
  String get hanchanCaveatRiichi =>
      'That is with the dealership passing every hand. Under standard riichi rules a dealer who wins, or who is tenpai at an exhaustive draw, keeps it and the hand is replayed — so either length can run longer.';

  @override
  String get hanchanCaveatChinese =>
      'That is with the dealership passing every hand. A dealer who wins, or any exhaustive draw, keeps it and the hand is replayed — so either length can run longer.';

  @override
  String get zoomOut => 'Zoom out  (Ctrl/Cmd -)';

  @override
  String get zoomIn => 'Zoom in  (Ctrl/Cmd +)';

  @override
  String get zoomReset => 'Reset zoom  (Ctrl/Cmd 0)';

  @override
  String get installTitle => 'Install TileSense';

  @override
  String get installBody =>
      'This browser can\'t go full screen from a web page. Install TileSense as a web app instead and it opens full screen, with no browser bars:\n\n• iPhone / iPad: tap Share, then \"Add to Home Screen\"\n• Chrome / Edge: use the install icon in the address bar, or menu > \"Install app\"';

  @override
  String get gotIt => 'Got it';

  @override
  String get fullscreenExit => 'Exit full screen';

  @override
  String get fullscreenTooltip =>
      'Full screen. For the best experience, install TileSense as a web app (browser menu > Install / Add to Home Screen).';

  @override
  String get fullscreen => 'Full screen';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateAvailableBody =>
      'A newer version of TileSense is ready. Update now to get it.';

  @override
  String get updateNow => 'Update now';

  @override
  String get upToDateTitle => 'You\'re up to date';

  @override
  String get upToDateBody =>
      'This is the latest version. Refresh anyway to re-download every file.';

  @override
  String get refreshAnyway => 'Refresh anyway';

  @override
  String get refreshTitle => 'Refresh TileSense';

  @override
  String get refreshUnknownBody =>
      'Couldn\'t tell whether a newer version exists. Refresh to download the latest files.';

  @override
  String get refresh => 'Refresh';

  @override
  String get notNow => 'Not now';

  @override
  String get updateTooltip => 'Check for a newer version and refresh the app';

  @override
  String get working => 'Working…';

  @override
  String get update => 'Update';

  @override
  String get rotatePrompt =>
      'Rotate your device to landscape to play TileSense';

  @override
  String minimumFaanSentence(int n) {
    return ', $n-faan minimum';
  }

  @override
  String minimumTaiSentence(int n) {
    return ', $n-tai minimum';
  }

  @override
  String minimumFaanTag(int n) {
    return '$n faan min';
  }

  @override
  String minimumTaiTag(int n) {
    return '$n tai min';
  }

  @override
  String get newGameConfirmTitle => 'Start a new game?';

  @override
  String get newGameConfirmBody => 'The game in progress will be lost.';

  @override
  String get keepPlaying => 'Keep playing';

  @override
  String get newGame => 'New game';

  @override
  String get loadingTable => 'Preparing your table…';

  @override
  String get loadingBuilder => 'Loading hand builder…';

  @override
  String get loadingMultiplayer => 'Loading multiplayer…';

  @override
  String get start => 'Start';

  @override
  String get menu => 'Menu';

  @override
  String get menuTooltip =>
      'Main menu — pauses this game; Start resumes it. Change the style there (a new game), or open the Custom Hand & Context Builder';

  @override
  String playingRulesTooltip(String rules, String minimum) {
    return 'Playing $rules rules$minimum.\nTo play another style, go back to the main menu.';
  }

  @override
  String rulesPdf(String rules) {
    return '$rules rules (PDF)';
  }

  @override
  String hanchanOnTooltip(String caveat) {
    return 'Hanchan — East and South (半庄) rounds, 8+ hands.\n$caveat\nTap for East only (东风战), 4+ hands.';
  }

  @override
  String eastOnlyTooltipChinese(String caveat) {
    return 'East only — the East round, 4+ hands.\n$caveat\nTap for hanchan (半庄): East and South (半庄), 8+ hands.';
  }

  @override
  String eastOnlyTooltipRiichi(String caveat) {
    return 'East only (东风战/tonpuusen) — the East round, 4+ hands.\n$caveat\nTap for hanchan (半庄): East and South (半庄), 8+ hands.';
  }

  @override
  String get hanchan => 'Hanchan';

  @override
  String get eastOnly => 'East only';

  @override
  String get botSpeedCaption => 'BOT SPEED';

  @override
  String get botSpeedFastTooltip =>
      'Bots and draws move at double speed.\nTap for normal speed.';

  @override
  String get botSpeedNormalTooltip =>
      'Bots and draws move at normal speed.\nTap for double speed.';

  @override
  String get algorithmCaption => 'ALGORITHM';

  @override
  String get mortalBot => 'Mortal bot';

  @override
  String algorithmTooltip(String style, String focus, String strategy) {
    return 'TileSense guide, playing $style · $focus · $strategy.\nSet for you as the game goes: Aggressive · Speed · Points early to build a lead; Balanced · Speed · Placement in the final two hands to protect or climb the standings.';
  }

  @override
  String get autoPlayCaption => 'AUTO-PLAY';

  @override
  String get autoPlayOnTooltip =>
      'Auto-Play is on — TileSensor plays your seat by the guide: points early, placement in the final two hands.\nTap to take your seat back.';

  @override
  String get autoPlayOffTooltip =>
      'Auto-Play is off — you play your seat.\nTap to let TileSensor play it by the guide.';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get soundCaption => 'SOUND';

  @override
  String get soundOnTooltip => 'Sound on — tap to mute';

  @override
  String get soundOffTooltip => 'Sound off — tap to unmute';

  @override
  String get resumeCaption => 'RESUME';

  @override
  String get pauseCaption => 'PAUSE';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get newCaption => 'NEW';

  @override
  String get pausedOverlay => 'PAUSED\ntap, or press Esc, to resume';

  @override
  String get rulesetSubtitleRiichi => 'yaku, dora, riichi';

  @override
  String get rulesetSubtitleHongKong => 'faan, flowers, 0–3 faan minimum';

  @override
  String get rulesetSubtitleTaiwanese => '17 tiles, flowers, 1–5 tai minimum';

  @override
  String get welcomeTo => 'Welcome to';

  @override
  String welcomeTagline(String rules) {
    return 'Sharpen your $rules Mahjong decisions\nwith a guide that sees only what you see.';
  }

  @override
  String get singlePlayer => 'Single Player';

  @override
  String get singlePlayerSubtitle => 'Includes the guide';

  @override
  String get playOnline => 'Play Online';

  @override
  String get playOnlineSubtitle =>
      'With friends — bots fill empty seats, no guide';

  @override
  String get builder => 'Custom Hand & Context Builder';

  @override
  String get builderSubtitle => 'Pose any table and have TileSense score it';

  @override
  String rejoinOnline(String code) {
    return 'Rejoin your online game · Room $code';
  }

  @override
  String get viewOnGitHub => 'View on GitHub';

  @override
  String get builtWithFlutter => 'Built with Flutter';

  @override
  String get seatYou => 'You';

  @override
  String get seatRight => 'Right';

  @override
  String get seatAcross => 'Across';

  @override
  String get seatLeft => 'Left';

  @override
  String get youStartAs => 'You start as';

  @override
  String get style => 'Style';

  @override
  String get gameLength => 'Game length';

  @override
  String get lengthHanchan => '半庄 Hanchan';

  @override
  String get lengthEastOnly => '东风战 East only';

  @override
  String get minFaan => 'Min faan';

  @override
  String get minFaanTooltip =>
      'The fewest faan a hand needs to win.\n0 lets any complete hand, even a chicken hand, win.';

  @override
  String get minTai => 'Min tai';

  @override
  String get minTaiTooltip =>
      'The fewest tai a hand needs to win.\n5 is the San Diego club sheet\'s rule; 1 and 3 are common house minimums.';

  @override
  String get chooseCharacters => 'CHOOSE YOUR CHARACTERS';

  @override
  String get dealerNoteYou => 'East deals first — that is you.';

  @override
  String dealerNoteOther(String seat) {
    return 'East deals first — that is $seat.';
  }

  @override
  String get randomizeCharacters => 'Randomize characters & seats';

  @override
  String get sound => 'Sound';

  @override
  String get back => 'Back';

  @override
  String get backToMainMenu => 'Back to the main menu';

  @override
  String get done => 'Done';

  @override
  String get mainMenu => 'Main menu';

  @override
  String get rules => 'Rules';

  @override
  String get soundOn => 'Sound on';

  @override
  String get soundOff => 'Sound off';

  @override
  String get bots2x => 'Bots 2x';

  @override
  String get bots1x => 'Bots 1x';

  @override
  String get autoPlayOn => 'Auto-Play on';

  @override
  String get autoPlayOff => 'Auto-Play off';

  @override
  String get algorithm => 'Algorithm';

  @override
  String get pausedCaps => 'PAUSED';

  @override
  String get menuCaps => 'MENU';

  @override
  String get loadFailed => 'Couldn’t finish loading. Try again.';

  @override
  String get retry => 'Retry';

  @override
  String get clientIdTitle => 'Your client ID';

  @override
  String get clientIdShort => 'ID';

  @override
  String get clientIdHelp => 'Include this if you report a problem.';

  @override
  String get close => 'Close';

  @override
  String get copied => 'Copied';

  @override
  String get copy => 'Copy';

  @override
  String faanCount(int n) {
    return '$n faan';
  }

  @override
  String taiCount(int n) {
    return '$n tai';
  }

  @override
  String badgeTooltip(String rules, String minimum) {
    return 'Playing $rules rules$minimum.';
  }

  @override
  String badgeMinimum(String min) {
    return ', $min minimum';
  }

  @override
  String get yakuRiichi => 'Riichi';

  @override
  String get yakuDoubleRiichi => 'Double Riichi';

  @override
  String get yakuIppatsu => 'Ippatsu';

  @override
  String get yakuMenzenTsumo => 'Menzen Tsumo';

  @override
  String get yakuHaiteiRaoyue => 'Haitei Raoyue';

  @override
  String get yakuHouteiRaoyui => 'Houtei Raoyui';

  @override
  String get yakuRinshanKaihou => 'Rinshan Kaihou';

  @override
  String get yakuChankan => 'Chankan';

  @override
  String get yakuTanyao => 'Tanyao';

  @override
  String get yakuRoundWind => 'Round Wind';

  @override
  String get yakuSeatWind => 'Seat Wind';

  @override
  String get yakuShousangen => 'Shousangen';

  @override
  String get yakuPinfu => 'Pinfu';

  @override
  String get yakuIipeiko => 'Iipeiko';

  @override
  String get yakuRyanpeikou => 'Ryanpeikou';

  @override
  String get yakuChiitoitsu => 'Chiitoitsu';

  @override
  String get yakuToitoi => 'Toitoi';

  @override
  String get yakuSanankou => 'Sanankou';

  @override
  String get yakuSankantsu => 'Sankantsu';

  @override
  String get yakuSanshokuDoujun => 'Sanshoku Doujun';

  @override
  String get yakuSanshokuDoukou => 'Sanshoku Doukou';

  @override
  String get yakuIttsu => 'Ittsu';

  @override
  String get yakuHonroutou => 'Honroutou';

  @override
  String get yakuHonitsu => 'Honitsu';

  @override
  String get yakuChinitsu => 'Chinitsu';

  @override
  String get yakuChanta => 'Chanta';

  @override
  String get yakuJunchan => 'Junchan';

  @override
  String get yakuDora => 'Dora';

  @override
  String get yakuUraDora => 'Ura Dora';

  @override
  String get yakuAkaDora => 'Aka Dora';

  @override
  String get yakuKokushiMusou => 'Kokushi Musou';

  @override
  String get yakuSuuankou => 'Suuankou';

  @override
  String get yakuDaisangen => 'Daisangen';

  @override
  String get yakuDaisuushii => 'Daisuushii';

  @override
  String get yakuShousuushii => 'Shousuushii';

  @override
  String get yakuTsuuiisou => 'Tsuuiisou';

  @override
  String get yakuChinroutou => 'Chinroutou';

  @override
  String get yakuRyuuiisou => 'Ryuuiisou';

  @override
  String get yakuChuurenPoutou => 'Chuuren Poutou';

  @override
  String get faanAllFlowers => 'All Flowers';

  @override
  String get faanAllSeasons => 'All Seasons';

  @override
  String get faanAllHonours => 'All Honours';

  @override
  String get faanAllSequences => 'All Sequences';

  @override
  String get faanAllTerminals => 'All Terminals';

  @override
  String get faanAllTriplets => 'All Triplets';

  @override
  String get faanAllQuadruplets => 'All Quadruplets';

  @override
  String get faanAllQuadrupletsUpgrade => 'All Quadruplets (upgrade)';

  @override
  String get faanAllConcealedTriplets => 'All Concealed Triplets';

  @override
  String get faanAllConcealedTripletsUpgrade =>
      'All Concealed Triplets (upgrade)';

  @override
  String get faanBigFourWinds => 'Big Four Winds';

  @override
  String get faanBigThreeDragons => 'Big Three Dragons';

  @override
  String get faanBlessingOfEarth => 'Blessing of Earth';

  @override
  String get faanBlessingOfHeaven => 'Blessing of Heaven';

  @override
  String get faanBlessingOfMan => 'Blessing of Man';

  @override
  String get faanChickenHand => 'Chicken Hand';

  @override
  String get faanConcealedHand => 'Concealed Hand';

  @override
  String get faanDoubleKongReplacement => 'Double Kong Replacement';

  @override
  String get faanFullFlush => 'Full Flush';

  @override
  String get faanMixedFlush => 'Mixed Flush';

  @override
  String get faanMixedTerminals => 'Mixed Terminals';

  @override
  String get faanMoonUnderTheSea => 'Moon Under the Sea';

  @override
  String get faanNineGates => 'Nine Gates';

  @override
  String get faanNoFlowersOrSeasons => 'No Flowers or Seasons';

  @override
  String get faanRobbingTheKong => 'Robbing the Kong';

  @override
  String get faanRoundWind => 'Round Wind';

  @override
  String get faanSeatWind => 'Seat Wind';

  @override
  String get faanSelfPick => 'Self-Pick';

  @override
  String get faanSevenPairs => 'Seven Pairs';

  @override
  String get faanSmallFourWinds => 'Small Four Winds';

  @override
  String get faanSmallThreeDragons => 'Small Three Dragons';

  @override
  String get faanThirteenOrphans => 'Thirteen Orphans';

  @override
  String get faanWinByKongReplacement => 'Win by Kong Replacement';

  @override
  String get faanSevenFlowers => 'Seven Flowers';

  @override
  String get faanEightFlowers => 'Eight Flowers';

  @override
  String get taiAllChowsWithFlowersOrHonors =>
      'All Chows with Flowers or Honors';

  @override
  String get taiAllChows => 'All Chows';

  @override
  String get taiAllPungs => 'All Pungs';

  @override
  String get taiAllFlowers => 'All Flowers';

  @override
  String get taiBigFourWinds => 'Big Four Winds';

  @override
  String get taiBigThreeDragons => 'Big Three Dragons';

  @override
  String get taiBigThreeWinds => 'Big Three Winds';

  @override
  String get taiBlessingsOfEarth => 'Blessings of Earth';

  @override
  String get taiBlessingsOfHeaven => 'Blessings of Heaven';

  @override
  String get taiClosedWait => 'Closed Wait';

  @override
  String get taiConcealedHand => 'Concealed Hand';

  @override
  String get taiConcealedKong => 'Concealed Kong';

  @override
  String get taiFiveConcealedPungs => 'Five Concealed Pungs';

  @override
  String get taiFourConcealedPungs => 'Four Concealed Pungs';

  @override
  String get taiThreeConcealedPungs => 'Three Concealed Pungs';

  @override
  String get taiTwoConcealedPungs => 'Two Concealed Pungs';

  @override
  String get taiFlowerTile => 'Flower Tile';

  @override
  String get taiFullyConcealedHand => 'Fully Concealed Hand';

  @override
  String get taiFullFlush => 'Full Flush';

  @override
  String get taiHalfFlush => 'Half Flush';

  @override
  String get taiLastTileDraw => 'Last Tile Draw';

  @override
  String get taiLittleFourWinds => 'Little Four Winds';

  @override
  String get taiLittleThreeDragons => 'Little Three Dragons';

  @override
  String get taiLittleThreeWinds => 'Little Three Winds';

  @override
  String get taiMeldedHand => 'Melded Hand';

  @override
  String get taiMeldedKong => 'Melded Kong';

  @override
  String get taiNoFlowerOrHonorTiles => 'No Flower or Honor Tiles';

  @override
  String get taiNoFlowerTiles => 'No Flower Tiles';

  @override
  String get taiNoHonors => 'No Honors';

  @override
  String get taiPureStraight => 'Pure Straight';

  @override
  String get taiRobbingTheKong => 'Robbing the Kong';

  @override
  String get taiSelfDrawn => 'Self-Drawn';

  @override
  String get taiSevenPairsAndAPung => 'Seven Pairs and a Pung';

  @override
  String get taiSingleWait => 'Single Wait';

  @override
  String get taiValueHonor => 'Value Honor';

  @override
  String get taiWinWithin5Discards => 'Win Within 5 Discards';

  @override
  String get taiWinWithin5To10Discards => 'Win Within 5 to 10 Discards';

  @override
  String get resultKyuushuKyuuhaiNineTerminalsHonors =>
      'Kyuushu Kyuuhai — nine terminals/honors';

  @override
  String get resultExhaustiveDraw => 'Exhaustive Draw';

  @override
  String get resultMultipleWins => 'Multiple Wins';

  @override
  String get resultRobbingAKong => 'Robbing a Kong';

  @override
  String get resultWinOnDiscard => 'Win on Discard';

  @override
  String get resultMultipleRon => 'Multiple Ron';

  @override
  String get resultChankan => 'Chankan';

  @override
  String get resultRon => 'Ron';

  @override
  String get resultSelfDraw => 'Self Draw';

  @override
  String get resultTsumo => 'Tsumo';

  @override
  String get limitMangan => 'Mangan';

  @override
  String get limitHaneman => 'Haneman';

  @override
  String get limitBaiman => 'Baiman';

  @override
  String get limitSanbaiman => 'Sanbaiman';

  @override
  String get limitKazoeYakuman => 'Kazoe Yakuman';

  @override
  String get limitYakuman => 'Yakuman';

  @override
  String get limit13FaanCap => '13+ faan cap';

  @override
  String get tileTon => 'East';

  @override
  String get tileNan => 'South';

  @override
  String get tileShaa => 'West';

  @override
  String get tilePei => 'North';

  @override
  String get tileHaku => 'White Dragon';

  @override
  String get tileHatsu => 'Green Dragon';

  @override
  String get tileChun => 'Red Dragon';

  @override
  String get tilePlum => 'Plum';

  @override
  String get tileOrchid => 'Orchid';

  @override
  String get tileChrysanthemum => 'Chrysanthemum';

  @override
  String get tileBamboo => 'Bamboo Flower';

  @override
  String get tileSpring => 'Spring';

  @override
  String get tileSummer => 'Summer';

  @override
  String get tileAutumn => 'Autumn';

  @override
  String get tileWinter => 'Winter';

  @override
  String yakuYakuhai(String tile) {
    return 'Yakuhai ($tile)';
  }

  @override
  String faanHonorPung(String tile) {
    return '$tile Pung';
  }

  @override
  String limitMultipleYakuman(int n) {
    return '$n× Yakuman';
  }

  @override
  String get bubbleRiichi => 'RIICHI';

  @override
  String get bubbleRinshanRiichi => 'RINSHAN';

  @override
  String get bubbleRinshanChinese => 'RINSHAN';

  @override
  String get doraRowLabel => 'DORA';

  @override
  String get uraRowLabel => 'URA';

  @override
  String get noCalls => 'calls';

  @override
  String get autoPlaySeatTooltip =>
      'Auto-Play — TileSensor is playing your seat';

  @override
  String get furiten => 'FURITEN';

  @override
  String secondsShort(int n) {
    return '${n}s';
  }

  @override
  String statusWall(int n) {
    return 'Wall $n';
  }

  @override
  String statusDealerRepeat(int n) {
    return 'Dealer repeat $n';
  }

  @override
  String statusHonba(int n) {
    return 'Honba $n';
  }

  @override
  String statusRiichiSticks(int n) {
    return 'Riichi $n';
  }

  @override
  String statusRound(String kanji, String wind, int hand) {
    return '$kanji $wind $hand';
  }

  @override
  String seatLabelYou(String name) {
    return '$name (you)';
  }

  @override
  String seatLabelBot(String name) {
    return '$name (bot)';
  }

  @override
  String get seatBot => 'Bot';

  @override
  String seatNumber(int n) {
    return 'Seat $n';
  }

  @override
  String tileMan(int n) {
    return '$n Man';
  }

  @override
  String tilePin(int n) {
    return '$n Pin';
  }

  @override
  String tileSou(int n) {
    return '$n Sou';
  }

  @override
  String get undoPass => 'Pass';

  @override
  String get undoContinueDrawing => 'Continue drawing';

  @override
  String undoRiichi(String tile) {
    return 'Riichi $tile';
  }

  @override
  String undoKan(String kan, String tile) {
    return '$kan $tile';
  }

  @override
  String get hideGuide => 'Hide guide';

  @override
  String get showGuide => 'Show guide';

  @override
  String get hideGuideFooter => 'Tap to hide my guide.';

  @override
  String get showGuideFooter => 'Tap to show my guide.';

  @override
  String get sortCaption => 'SORT';

  @override
  String get sortOff => 'Off';

  @override
  String get sortOffTooltip =>
      'Sort: Off — your own order.\nLong-press a tile and drag it to move it. Tap for Hand (tile order).';

  @override
  String get sortHand => 'Hand';

  @override
  String get sortHandTooltip =>
      'Sort: Hand — tiles kept in tile order, your drawn tile apart on the right.\nTap for Hand+draw, or drag a tile to start your own order.';

  @override
  String get sortHandDraw => 'Hand+draw';

  @override
  String get sortHandDrawTooltip =>
      'Sort: Hand+draw — your drawn tile is sorted straight into your hand.\nTap to freeze this order (Off), or drag a tile to start your own.';

  @override
  String get discardCaption => 'DISCARD';

  @override
  String get discardSingle => 'Single';

  @override
  String get discardDouble => 'Double';

  @override
  String get discardSingleTooltip =>
      'Discard: single tap — tapping a tile discards it.\nTap to raise a tile first and tap again to discard.';

  @override
  String get discardDoubleTooltip =>
      'Discard: double tap — the first tap raises a tile, a second discards it.\nTap to discard with a single tap.';

  @override
  String get autoWinCaption => 'AUTO-WIN';

  @override
  String get autoWinOnTooltip =>
      'Auto-win: on — ron and tsumo are declared for you as soon as you can win.\nTap to decide yourself.';

  @override
  String get autoWinOffTooltip =>
      'Auto-win: off — press the win button yourself.\nTap to declare ron/tsumo automatically.';

  @override
  String get autoPassCaption => 'AUTO-PASS';

  @override
  String get autoPassOnTooltip =>
      'Auto-pass: on — chi, pon and kan on other players\' discards are passed for you. A ron is still yours to take.\nTap to decide calls yourself.';

  @override
  String get autoPassOffTooltip =>
      'Auto-pass: off — you are asked about every call.\nTap to pass chi, pon and kan automatically.';

  @override
  String declareRiichiDiscard(String tile) {
    return 'Declare Riichi and discard $tile';
  }

  @override
  String justDiscard(String tile) {
    return 'Just discard $tile';
  }

  @override
  String get flowerWin => 'FLOWER WIN';

  @override
  String get continueDrawing => 'CONTINUE DRAWING';

  @override
  String get passCaps => 'PASS';

  @override
  String get kyuushuKyuuhai => 'KYUUSHU KYUUHAI';

  @override
  String get riichiAvailable => 'Riichi available';

  @override
  String get riichiAvailableRecommended => 'Riichi available — recommended';

  @override
  String get undoTooltip =>
      'Take back your last move this hand, and everything after it.\nPress again to keep stepping back. (Ctrl/Cmd+Z)';

  @override
  String get takeBack => 'Take back  ';

  @override
  String get scoreNewGame => 'New Game';

  @override
  String get scoreNext => 'Next';

  @override
  String scoreContinueLocked(int n) {
    return 'Continue ($n)';
  }

  @override
  String get scoreContinue => 'Continue';

  @override
  String get autoContinuePaused => 'Auto Continue paused';

  @override
  String get autoContinueHeld => 'Auto Continue held — game paused';

  @override
  String autoContinueIn(int n) {
    return 'Auto Continue in ${n}s';
  }

  @override
  String get showPanel => 'Show panel';

  @override
  String get seeThroughPanel => 'See through panel';

  @override
  String get flowersSeasons => 'Flowers / seasons';

  @override
  String indicatorRowOne(String label) {
    return '$label indicator:';
  }

  @override
  String indicatorRowMany(String label) {
    return '$label indicators:';
  }

  @override
  String plainRow(String label) {
    return '$label:';
  }

  @override
  String yakuLineTaiOne(String name, int n) {
    return '$name  $n pt';
  }

  @override
  String yakuLineTaiMany(String name, int n) {
    return '$name  $n pts';
  }

  @override
  String yakuLineFaan(String name, int n) {
    return '$name  $n faan';
  }

  @override
  String yakuLineHan(String name, int n) {
    return '$name  $n';
  }

  @override
  String yakuLineYakuman(String name) {
    return '$name  yakuman';
  }

  @override
  String scorePointOne(int n) {
    return '$n point';
  }

  @override
  String scorePointMany(int n) {
    return '$n points';
  }

  @override
  String scoreFaanChips(int faan, int points, String limit) {
    return '$faan faan — $points chips$limit';
  }

  @override
  String scoreLimitOnly(String limit, int points) {
    return '$limit — $points';
  }

  @override
  String scoreHanFu(int han, int fu, String limit, int points) {
    return '$han han $fu fu$limit — $points';
  }

  @override
  String limitSuffix(String limit) {
    return '  ($limit)';
  }

  @override
  String get wallExhaustedNoPayments => 'Wall exhausted — no payments';

  @override
  String get allNoten => 'All players noten';

  @override
  String get tenpaiRevealed => 'Tenpai hands revealed';

  @override
  String get waits => 'waits';

  @override
  String get backToMenu => 'Back to menu';

  @override
  String get cantReachServer =>
      'Can\'t reach the multiplayer server — retrying…';

  @override
  String get noGuideOnline =>
      'Multiplayer has no TileSense guide — play single player for it.';

  @override
  String get yourName => 'Your name';

  @override
  String get yourNameHelper =>
      'Defaults to your character — edit to use your own';

  @override
  String get createARoom => 'Create a room';

  @override
  String get fullGameSwitch => 'Full game — hanchan/半庄 (8+ hands)';

  @override
  String get fullGameSwitchOn => 'Off switches to East-only/东风战 (4+ hands)';

  @override
  String get fullGameSwitchOff => 'East-only/东风战 — 4+ hands';

  @override
  String get createRoomButton => 'Create Room';

  @override
  String get joinARoom => 'Join a room';

  @override
  String get roomCode => 'Room code';

  @override
  String get join => 'Join';

  @override
  String get chooseYourCharacter => 'Choose your character';

  @override
  String get pace => 'Pace';

  @override
  String get paceFast => 'Fast';

  @override
  String get paceStandard => 'Standard';

  @override
  String get paceRelaxed => 'Relaxed';

  @override
  String paceCaption(int turn, int call) {
    return '${turn}s per turn · ${call}s to call';
  }

  @override
  String get minimumFaanToWin => 'Minimum faan to win';

  @override
  String get minimumTaiToWin => 'Minimum tai to win';

  @override
  String get roomCodeShare => 'Room code — share this with the other players';

  @override
  String get copyCode => 'Copy code';

  @override
  String get roomCodeCopied => 'Room code copied';

  @override
  String roomFaanMin(int n) {
    return '$n-faan min';
  }

  @override
  String roomTaiMin(int n) {
    return '$n-tai min';
  }

  @override
  String get roomFullGame => 'full game';

  @override
  String get roomEastOnly => 'East-only';

  @override
  String roomClocks(int turn, int call) {
    return '${turn}s turn · ${call}s call';
  }

  @override
  String get startGameBots => 'Start Game — bots fill any empty seats';

  @override
  String get waitingForHost => 'Waiting for the host to start…';

  @override
  String get leaveRoomButton => 'Leave Room';

  @override
  String get emptySeat => 'Empty seat';

  @override
  String get host => 'HOST';

  @override
  String get rejoiningGame => 'Rejoining your game…';

  @override
  String gameStillGoing(String code) {
    return 'Your game in room $code is still going.';
  }

  @override
  String get rejoin => 'Rejoin';

  @override
  String get leaveGameTitle => 'Leave this game?';

  @override
  String get leaveGameBody =>
      'A bot plays your seat until you come back — Rejoin is on the main menu while the game is on.';

  @override
  String get stay => 'Stay';

  @override
  String get leave => 'Leave';

  @override
  String get leaveRoom => 'Leave room';

  @override
  String get clientId => 'Client ID';

  @override
  String nowBotControlled(String name) {
    return '$name is now bot-controlled';
  }

  @override
  String get noGuideOnlineTooltip =>
      'TileSensor sits out multiplayer, so no seat gets a guide the others lack.\nPlay single player to have me along!';

  @override
  String roomLabel(String code) {
    return 'Room $code';
  }

  @override
  String get connectionLost => 'Connection lost — reconnecting…';

  @override
  String get backToStart => 'Back to start';

  @override
  String get errorNotSeated => 'you are not seated in this room';

  @override
  String get errorSeatBotControlled => 'this seat is bot-controlled';

  @override
  String get errorMissingGuestId => 'missing guestId';

  @override
  String get errorServerFull => 'server is full, try again shortly';

  @override
  String get errorMissingRoom => 'missing roomCode or guestId';

  @override
  String get errorRoomNotFound => 'room not found';

  @override
  String get errorRoomStarted => 'that room has already started';

  @override
  String get errorRoomFull => 'room is full';

  @override
  String get errorNotHost => 'only the host can start the game';

  @override
  String get errorRoomGone => 'room no longer exists';

  @override
  String get errorUnknownType => 'unknown message type';

  @override
  String get errorMalformed => 'malformed message';

  @override
  String get errorBadRequest => 'bad request';

  @override
  String get errorIllegalAction => 'illegal action for the current turn';

  @override
  String get errorNoActionExpected => 'no action expected right now';

  @override
  String get errorGameEnded => 'That game has ended';

  @override
  String get guideTipTitle => 'GUIDE\n';

  @override
  String get guideGreen => 'Green tile';

  @override
  String get guideGreenBody => 'the recommended discard';

  @override
  String get guideYellow => 'Yellow tile';

  @override
  String get guideYellowBody => 'the tile you just drew';

  @override
  String get guidePause => 'pause the game';

  @override
  String get guideHover => '\nHover a heading or a dial for what it means.';

  @override
  String get tipAutoTitle => 'AUTO-PLAY\n';

  @override
  String get tipAutoBody =>
      'Who Auto-Play follows for your seat, and whose order the rows below are sorted in.\n';

  @override
  String get tipAutoChoices =>
      '• TileSense (default): the guide; its recommendation is on top.\n• Mortal bot: Mortal plays your seat, and its preferred move is on top. Any decision Mortal can\'t answer is played by the guide.';

  @override
  String get tipEvTitle => 'TILESENSE EV\n';

  @override
  String get tipFinishTitle => 'CHANCE OF FINISHING';

  @override
  String get tipFinishBody =>
      'Odds you win before the hand ends. More live tiles and more draws left raise it.\n';

  @override
  String get tipFinishMore =>
      'hover Ukeire · tap the EV (HMR) number for the chart';

  @override
  String get tipPayoutTitle => 'WHAT THE WIN PAYS';

  @override
  String get tipPayoutTw =>
      'A flat point total, the same from every payer, plus a dealer-streak bonus. Exact once ready; before that, estimated from the patterns shown.\n';

  @override
  String get tipPayoutHk =>
      'Faan as chips. Exact once ready; before that, estimated from the patterns shown.\n';

  @override
  String get tipPayoutRiichi =>
      'Points if it lands, plus honba and riichi sticks. Exact once tenpai; an estimate before.\n';

  @override
  String get tipPayoutMore => 'tap the EV (HMR) number for the working';

  @override
  String get tipCutTitle => 'WHAT THE CUT RISKS';

  @override
  String get tipCutChinese =>
      'Estimated loss to an opponent with 3+ exposed sets. No tile is fully safe.\n';

  @override
  String get tipCutRiichi =>
      'The riichi stick (lost unless you win). Against a live riichi, also how often this tile deals in and the turns it commits you to.\n';

  @override
  String get tipCutMore => 'hover Risk and Safety';

  @override
  String get tipFocusTitle => 'FOCUS';

  @override
  String get tipFocusBody =>
      'Speed pays some payout for a better chance of finishing. Balanced adds no tilt.\n';

  @override
  String get tipFocusMore => 'hover FOCUS';

  @override
  String get tipFocusPlacementMore =>
      'hover FOCUS · STRATEGY and Placement for the rest';

  @override
  String get tipEvHigher =>
      '\nHigher is better. A dangerous, cheap cut can go negative.';

  @override
  String get tipOrdinaryWide => 'Wider than ordinary';

  @override
  String get tipOrdinaryWideBody =>
      'steps forward faster, but never faster than an ordinary hand';

  @override
  String get tipOrdinaryTitle => 'AN ORDINARY HAND HAS';

  @override
  String get tipShantenLabel => 'Shanten';

  @override
  String get tipUkeireLabel => 'Ukeire';

  @override
  String get tipAwayLabel => 'Away';

  @override
  String get tipAcceptsLabel => 'Accepts';

  @override
  String get tipOrdinaryNote =>
      '\nMeans, not medians: the average ukeire of the best discard at each shanten, measured over simulated solo games by a greedy efficiency player (no defence, no calls).';

  @override
  String get tipSafetyTitle => 'SAFETY\n';

  @override
  String get tipSafetyChinese =>
      'How risky a tile is to cut against an opponent with an exposed hand. Higher = safer.\n';

  @override
  String get tipSafetyRiichi =>
      'How safe a tile is to cut against a riichi. 0 = dangerous, 15 = genbutsu.\n';

  @override
  String get tipNeverCertain => 'Never certain';

  @override
  String get tipNeverCertainBody =>
      'with no furiten, a tile an opponent discarded can still win';

  @override
  String get tipRatedWhen => 'Rated when';

  @override
  String get tipGenbutsu => 'Genbutsu';

  @override
  String get tipGenbutsuBody =>
      'a tile that player discarded, or that passed them after their riichi, cannot win their hand';

  @override
  String get tipSuji => 'Suji';

  @override
  String get tipSujiBody =>
      'a tile three away from one they discarded is safer';

  @override
  String get tipRatedRiichi =>
      'someone is in riichi — otherwise the column shows —';

  @override
  String get tipDealInTitle => 'CHANCE A CUT DEALS IN';

  @override
  String get tipRating => 'Rating';

  @override
  String get tipTile => 'Tile';

  @override
  String get tipDealsIn => 'Deals in';

  @override
  String get tipRating15 => 'Genbutsu — already discarded by that player';

  @override
  String get tipRating13 => 'Honor, 1 live';

  @override
  String get tipRating12 => 'Double suji';

  @override
  String get tipRating11 => 'Suji terminal';

  @override
  String get tipRating9 => 'Honor, 2 live';

  @override
  String get tipRating8 => 'No-chance tile';

  @override
  String get tipRating7 => 'Half suji';

  @override
  String get tipRating6 => 'Suji 2/3/7/8, or honor with 3 live';

  @override
  String get tipRating3 => 'Non-suji 2/3/7/8';

  @override
  String get tipRating2 => 'Non-suji middle tile';

  @override
  String get tipHkRating14 => 'Honor, none unseen';

  @override
  String get tipHkRating11 => 'Honor, 1 unseen';

  @override
  String get tipHkRating6 => 'Honor, 2 or more unseen';

  @override
  String get tipHkRating5 => 'Terminal';

  @override
  String get tipHkRating3 => 'Suit tile';

  @override
  String get tipRiskTitle => 'RISK\n';

  @override
  String get tipDealInChance => 'Deal-in chance';

  @override
  String get tipDealInChanceBody => 'from the tile\'s Safety rating';

  @override
  String get tipDealInCost => 'Deal-in cost';

  @override
  String get tipStyleWeight => 'Style weight';

  @override
  String get tipLaterTurns => 'Later turns';

  @override
  String get tipHowLong => 'How long';

  @override
  String get tipChineseHorizon =>
      'the hand\'s own expected length; a tile with no risk commits you to nothing';

  @override
  String get tipFormula => 'FORMULA';

  @override
  String get tipDetailTitle => 'DETAIL\n';

  @override
  String get tipDetailBody => 'Why this tile has the Safety rating it does.\n';

  @override
  String get tipShows => 'Shows';

  @override
  String get tipShowsBody =>
      'genbutsu, suji, honor with copies left, and so on';

  @override
  String get tipEmpty => 'Empty';

  @override
  String get tipEmptyBody =>
      'nobody is being defended against, so there is nothing to explain';

  @override
  String get tipPlacementTitle => 'PLACEMENT\n';

  @override
  String get tipPlacementBody =>
      'How a line moves your chance of finishing above the other three seats.\n';

  @override
  String get tipUses => 'Uses';

  @override
  String get tipUsesBody =>
      'the scores on the table and the hands left right now';

  @override
  String get tipNotPoints => 'Not points';

  @override
  String get tipNotPointsBody =>
      'scaled up ×1,000 so it reads at a glance; only its order against the other lines means anything';

  @override
  String get tipHeuristic => 'A heuristic';

  @override
  String get tipHeuristicBody => 'not a simulation';

  @override
  String get tipWorthTitle => 'WHAT 8,000 POINTS IS WORTH';

  @override
  String get tipSituation => 'Situation';

  @override
  String get tipHandsLeft => 'Hands left';

  @override
  String get tipEven => 'Even table';

  @override
  String get tipLead => 'Big lead';

  @override
  String get tipBehind => 'Far behind';

  @override
  String get tipEvenLast => 'Even table, last hand';

  @override
  String get tipLeadLast => 'Big lead, last hand';

  @override
  String get tipPlacementNote =>
      '\nPoints matter most in a close race and late in the game, and least when you are comfortably ahead.\n';

  @override
  String get tipNoWin => 'This line has no winning hand to score yet.\n';

  @override
  String get tipRiskRow => 'risk of this cut';

  @override
  String get tipFinishRow => 'chance of finishing';

  @override
  String get tipPayoutRow => 'what the win pays';

  @override
  String get tipSticksRow => 'honba and sticks';

  @override
  String get tipAverageRow => 'so on average';

  @override
  String get tipLockRow => 'less riichi lock-in';

  @override
  String get tipDealInRow => 'less deal-in risk';

  @override
  String get tipCommitRow => 'less turns committed';

  @override
  String get tipHmrBody =>
      'A plain comparison figure — it never changes the recommendation.\n';

  @override
  String get tipHmrExcludes =>
      '\nNo honba or sticks, no risk costs, no Style or Focus tilt.\n';

  @override
  String get tipHmrSource => '\nMirrors the \"E.V.\" stat in ';

  @override
  String get tipHmrSourceBody =>
      ', a solo tsumo-only trainer: points won ÷ hands played, which is win rate × average win.';

  @override
  String get tipYakuBody =>
      'Each bar: of the times this line wins, the share that include that yaku. One win usually has several yaku, so the bars don\'t add up to 100%. 100% means every win has it; Riichi is 100% when the plan is to riichi.\n\nMultiply by the chance to win for the overall odds.\n\nDora aren\'t yaku, so they\'re shown separately as the average extra han.\n\n≈ marks an estimate: short of tenpai, the guide assumes you keep cutting for the widest hand and scores the likeliest ready hands that leads to. It doesn\'t plan around yaku you\'d have to steer toward (yakuhai, flushes), so those can read low. More than 3 tiles away, nothing is shown yet.';

  @override
  String get tipMortalBody =>
      'What Mortal, an open-source deep-learning mahjong AI, would do in your seat, seeing only what your seat can see. ★ marks its discard (★R: it would declare riichi first); the numbers are its order of preference among the rest. Its pick is outlined in red and the guide\'s filled green; green with a red outline means they agree.\n\n';

  @override
  String get tipMortalAuto =>
      'With AUTO-PLAY on Mortal bot, Auto-Play plays these moves and the rows follow Mortal\'s order; on TileSense (the default) they follow the guide\'s, and this is a second opinion. The green tile is always the guide\'s pick. Whenever Mortal can\'t answer, the guide decides.\n\n';

  @override
  String get tipMortalSource =>
      'Riichi, single player. Mortal and its weights are AGPL-3.0 — source: github.com/Equim-chan/Mortal; the service that runs it: github.com/eric-r-xu/TileSense (mortal_sidecar).';

  @override
  String get tipYakuTitle => 'YAKU\n';

  @override
  String tipEvAverage(String unit) {
    return 'The average $unit this discard is worth to you (EV = Expected Value).\n';
  }

  @override
  String tipShantenBody(String ready) {
    return 'How many tiles you are from a ready hand (0 means $ready).';
  }

  @override
  String tipUkeireBody(String effect) {
    return 'Live tiles that $effect — how many draws help.\n';
  }

  @override
  String tipThreatSets(String count) {
    return 'an opponent shows $count or more exposed sets — otherwise the column shows —';
  }

  @override
  String tipChineseCost(String cost, String unit) {
    return '\nA deal-in is charged $cost $unit.';
  }

  @override
  String tipRiichiCost(String cost, String dealerCost) {
    return '$cost points ($dealerCost to a dealer), plus 300 a honba';
  }

  @override
  String tipRiichiCostNote(String cost, String dealerCost) {
    return '\nA deal-in costs $cost ($dealerCost to a dealer), plus 300 a honba.';
  }

  @override
  String tipRiskBody(String unit) {
    return '$unit taken off EV for the danger of this cut.\n';
  }

  @override
  String tipStyleWeights(String weights, String styles) {
    return '×$weights for $styles';
  }

  @override
  String tipCommitPercent(String percent) {
    return '$percent% of the charge again for each turn the cut commits you to';
  }

  @override
  String tipRiichiHorizon(String turns) {
    return 'as long as the riichi lasts, about $turns of your discards; a genbutsu cut commits you to nothing';
  }

  @override
  String tipThisCut(String tile) {
    return '\nTHIS CUT — $tile\n';
  }

  @override
  String tipFocusTilt(String focus) {
    return '$focus tilt';
  }

  @override
  String tipRankOrder(String name, String direction) {
    return '$name ($direction first)';
  }

  @override
  String tipRankDirection(String direction) {
    return '\n\n$direction is better — the arrow on the heading. ';
  }

  @override
  String tipRankBody(String first, String second, String third) {
    return 'Discards are ranked by $first, then $second, then $third; values count as equal when they show the same number. The green tile is the top of that order, and every tile equal to it on all three is green too.';
  }

  @override
  String get tipReady => 'ready';

  @override
  String get tipTenpai => 'tenpai';

  @override
  String get tipCloser => 'bring you closer to ready';

  @override
  String get tipReduce => 'reduce shanten';

  @override
  String get tipHigher => 'Higher';

  @override
  String get tipLower => 'Lower';

  @override
  String get tipHigherFirst => 'higher';

  @override
  String get tipLowerFirst => 'lower';

  @override
  String get tipPlacementLabel => 'Placement';

  @override
  String get tipPointsUnit => 'points';

  @override
  String get tipChipsUnit => 'chips';

  @override
  String get tipBalanced => 'Balanced';

  @override
  String get tipSpeed => 'Speed';

  @override
  String get tipAggressive => 'Aggressive';

  @override
  String get tipPoints => 'Points';

  @override
  String get tipDefensive => 'Defensive';

  @override
  String get mathChance => 'chance';

  @override
  String get mathFinish => 'finish';

  @override
  String get mathPayout => 'payout';

  @override
  String get mathWin => 'win';

  @override
  String get mathRisk => 'risk';

  @override
  String get mathCut => 'cut';

  @override
  String get mathDealIn => 'deal-in';

  @override
  String get mathCost => 'cost';

  @override
  String get mathWeight => 'weight';

  @override
  String get mathStyle => 'style';

  @override
  String get mathCharge => 'charge';

  @override
  String get mathLaterTurns => 'later turns';

  @override
  String get mathWorth => 'worth';

  @override
  String get mathGain => 'gain';

  @override
  String get mathScore => 'score';

  @override
  String get mathOthers => '3 other seats';

  @override
  String get mathTheirs => 'theirs';

  @override
  String get mathSpread => 'spread';

  @override
  String get mathHandsLeft => 'hands left';

  @override
  String get mathLogistic => 'logistic';

  @override
  String mascotIntro(String mascot, String app) {
    return 'I\'m $mascot: part prairie dog, part axolotl.\nI pick your best discards and calls.\nTurn on Auto-Play and I\'ll play your seat.\nMisplayed? Take it back and try again.\nPlay along and level up your $app.';
  }
}
