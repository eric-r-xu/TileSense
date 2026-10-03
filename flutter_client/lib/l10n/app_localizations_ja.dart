// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'TileSense';

  @override
  String get languageTooltip => '言語';

  @override
  String get rulesetRiichi => 'リーチ';

  @override
  String get rulesetHongKong => '香港';

  @override
  String get rulesetTaiwanese => '台湾';

  @override
  String get windEast => 'トン';

  @override
  String get windSouth => 'ナン';

  @override
  String get windWest => 'シャー';

  @override
  String get windNorth => 'ペー';

  @override
  String get callChiRiichi => 'チー';

  @override
  String get callChiHongKong => 'チー';

  @override
  String get callChiTaiwanese => 'チー';

  @override
  String get callPonRiichi => 'ポン';

  @override
  String get callPonHongKong => 'ポン';

  @override
  String get callPonTaiwanese => 'ポン';

  @override
  String get callKanRiichi => 'カン';

  @override
  String get callKanHongKong => 'カン';

  @override
  String get callKanTaiwanese => 'カン';

  @override
  String get callRonRiichi => 'ロン';

  @override
  String get callRonHongKong => 'ロン';

  @override
  String get callRonTaiwanese => 'ロン';

  @override
  String get callTsumoRiichi => 'ツモ';

  @override
  String get callTsumoHongKong => 'ツモ';

  @override
  String get callTsumoTaiwanese => 'ツモ';

  @override
  String get hanchanCaveatRiichi =>
      '親が毎局流れた場合の数です。標準的なリーチ麻雀のルールでは、親が和了するか、流局時に聴牌していれば連荘となり、その局をやり直します。そのため、どちらの長さでも長引くことがあります。';

  @override
  String get hanchanCaveatChinese =>
      '親が毎局流れた場合の数です。親が和了するか流局になると連荘となり、その局をやり直します。そのため、どちらの長さでも長引くことがあります。';

  @override
  String get zoomOut => 'ズームアウト  (Ctrl/Cmd -)';

  @override
  String get zoomIn => 'ズームイン  (Ctrl/Cmd +)';

  @override
  String get zoomReset => 'ズームをリセット  (Ctrl/Cmd 0)';

  @override
  String get installTitle => 'TileSense をインストール';

  @override
  String get installBody =>
      'このブラウザはウェブページから全画面表示にできません。代わりに TileSense をウェブアプリとしてインストールすると、ブラウザのバーなしで全画面で開きます：\n\n• iPhone / iPad：共有をタップし、「ホーム画面に追加」\n• Chrome / Edge：アドレスバーのインストールアイコン、またはメニュー > 「アプリをインストール」';

  @override
  String get gotIt => 'OK';

  @override
  String get fullscreenExit => '全画面を終了';

  @override
  String get fullscreenTooltip =>
      '全画面表示。最も快適に使うには、TileSense をウェブアプリとしてインストールしてください（ブラウザのメニュー > インストール／ホーム画面に追加）。';

  @override
  String get fullscreen => '全画面';

  @override
  String get updateAvailableTitle => 'アップデートがあります';

  @override
  String get updateAvailableBody =>
      '新しいバージョンの TileSense が利用できます。今すぐアップデートしてください。';

  @override
  String get updateNow => '今すぐアップデート';

  @override
  String get upToDateTitle => '最新の状態です';

  @override
  String get upToDateBody => 'これが最新バージョンです。それでも再読み込みすると、すべてのファイルを再ダウンロードします。';

  @override
  String get refreshAnyway => 'それでも再読み込み';

  @override
  String get refreshTitle => 'TileSense を再読み込み';

  @override
  String get refreshUnknownBody =>
      '新しいバージョンがあるか確認できませんでした。再読み込みして最新のファイルをダウンロードしてください。';

  @override
  String get refresh => '再読み込み';

  @override
  String get notNow => '後で';

  @override
  String get updateTooltip => '新しいバージョンを確認してアプリを再読み込み';

  @override
  String get working => '処理中…';

  @override
  String get update => 'アップデート';

  @override
  String get rotatePrompt => '端末を横向きにして TileSense をプレイしてください';

  @override
  String minimumFaanSentence(int n) {
    return '、最低$n翻';
  }

  @override
  String minimumTaiSentence(int n) {
    return '、最低$n台';
  }

  @override
  String minimumFaanTag(int n) {
    return '最低$n翻';
  }

  @override
  String minimumTaiTag(int n) {
    return '最低$n台';
  }

  @override
  String get newGameConfirmTitle => '新しい対局を始めますか？';

  @override
  String get newGameConfirmBody => '進行中の対局は失われます。';

  @override
  String get keepPlaying => '続ける';

  @override
  String lengthChangeConfirmTitle(String length) {
    return '$lengthに切り替えますか？';
  }

  @override
  String get lengthChangeConfirm => '切り替える';

  @override
  String get newGame => '新しい対局';

  @override
  String get loadingTable => '卓を準備中…';

  @override
  String get loadingBuilder => '手牌ビルダーを読み込み中…';

  @override
  String get loadingMultiplayer => 'オンライン対戦を読み込み中…';

  @override
  String get start => '開始';

  @override
  String get menu => 'メニュー';

  @override
  String get menuTooltip =>
      'メインメニュー — この対局を一時停止します。「開始」で再開します。そこでルールを変えたり（新しい対局）、カスタム手牌＆状況ビルダーを開いたりできます';

  @override
  String playingRulesTooltip(String rules, String minimum) {
    return '$rulesルールでプレイ中$minimum。\n別のルールで遊ぶには、メインメニューに戻ってください。';
  }

  @override
  String rulesPdf(String rules) {
    return '$rulesルール（PDF・英語）';
  }

  @override
  String hanchanOnTooltip(String caveat) {
    return '半荘 — 東場と南場、8局以上。\n$caveat\nタップで東風戦（4局以上）に。';
  }

  @override
  String eastOnlyTooltipChinese(String caveat) {
    return '東風戦 — 東場のみ、4局以上。\n$caveat\nタップで半荘（東場と南場、8局以上）に。';
  }

  @override
  String eastOnlyTooltipRiichi(String caveat) {
    return '東風戦 — 東場のみ、4局以上。\n$caveat\nタップで半荘（東場と南場、8局以上）に。';
  }

  @override
  String get hanchan => '半荘';

  @override
  String get eastOnly => '東風戦';

  @override
  String get botSpeedCaption => 'ボット速度';

  @override
  String get botSpeedFastTooltip => 'ボットとツモが2倍速で進みます。\nタップで通常速度に。';

  @override
  String get botSpeedNormalTooltip => 'ボットとツモが通常速度で進みます。\nタップで2倍速に。';

  @override
  String get algorithmCaption => 'アルゴリズム';

  @override
  String get mortalBot => 'Mortal ボット';

  @override
  String algorithmTooltip(String style, String focus, String strategy) {
    return 'TileSense ガイド：$style · $focus · $strategy。\n対局の進行に合わせて自動設定：序盤は攻撃的・速度・点数重視でリードを築き、最後の2局はバランス・速度・順位重視で順位を守るか上げます。';
  }

  @override
  String get autoPlayCaption => 'オート';

  @override
  String get autoPlayOnTooltip =>
      'オート：オン — TileSensor がガイドに従ってあなたの席を打ちます（序盤は点数重視、最後の2局は順位重視）。\nタップで自分の手番に戻ります。';

  @override
  String get autoPlayOffTooltip =>
      'オート：オフ — あなたが打ちます。\nタップで TileSensor にガイドどおり打たせます。';

  @override
  String get on => 'オン';

  @override
  String get off => 'オフ';

  @override
  String get soundCaption => 'サウンド';

  @override
  String get soundOnTooltip => 'サウンド：オン — タップでミュート';

  @override
  String get soundOffTooltip => 'サウンド：オフ — タップでミュート解除';

  @override
  String get resumeCaption => '再開';

  @override
  String get pauseCaption => '一時停止';

  @override
  String get resume => '再開';

  @override
  String get pause => '一時停止';

  @override
  String get newCaption => '新規';

  @override
  String get pausedOverlay => '一時停止中\nタップまたは Esc キーで再開';

  @override
  String get rulesetSubtitleRiichi => '役・ドラ・リーチ';

  @override
  String get rulesetSubtitleHongKong => '翻・花牌・最低0〜3翻';

  @override
  String get rulesetSubtitleTaiwanese => '17枚・花牌・最低1〜5台';

  @override
  String get welcomeTo => 'ようこそ';

  @override
  String welcomeTagline(String rules) {
    return '$rules麻雀の判断力を磨こう\nあなたと同じ情報だけを見るガイドと一緒に。';
  }

  @override
  String get singlePlayer => 'ひとりで遊ぶ';

  @override
  String get singlePlayerSubtitle => 'ガイド付き';

  @override
  String get playOnline => 'オンライン対戦';

  @override
  String get playOnlineSubtitle => '友達と — 空席はボットが埋めます、ガイドなし';

  @override
  String get builder => 'カスタム手牌＆状況ビルダー';

  @override
  String get builderSubtitle => '好きな卓を作って TileSense に評価させる';

  @override
  String rejoinOnline(String code) {
    return 'オンライン対局に戻る · ルーム $code';
  }

  @override
  String get viewOnGitHub => 'GitHub で見る';

  @override
  String get builtWithFlutter => 'Flutter で作成';

  @override
  String get seatYou => 'あなた';

  @override
  String get seatRight => '下家';

  @override
  String get seatAcross => '対面';

  @override
  String get seatLeft => '上家';

  @override
  String get youStartAs => 'あなたの開始風';

  @override
  String get style => 'ルール';

  @override
  String get gameLength => '対局の長さ';

  @override
  String get lengthHanchan => '半荘';

  @override
  String get lengthEastOnly => '東風戦';

  @override
  String get minFaan => '最低翻数';

  @override
  String get minFaanTooltip => '和了に必要な最低翻数。\n0 なら役なし（雞糊）を含め、どんな完成形でも和了できます。';

  @override
  String get minTai => '最低台数';

  @override
  String get minTaiTooltip =>
      '和了に必要な最低台数。\n5 はサンディエゴのクラブ規定、1 と 3 はよくあるハウスルールです。';

  @override
  String get chooseCharacters => 'キャラクターを選択';

  @override
  String get dealerNoteYou => '東家が親です — あなたです。';

  @override
  String dealerNoteOther(String seat) {
    return '東家が親です — $seatです。';
  }

  @override
  String get randomizeCharacters => 'キャラクターと席をランダムに';

  @override
  String get sound => 'サウンド';

  @override
  String get back => '戻る';

  @override
  String get backToMainMenu => 'メインメニューに戻る';

  @override
  String get done => '完了';

  @override
  String get mainMenu => 'メインメニュー';

  @override
  String get rules => 'ルール';

  @override
  String get soundOn => 'サウンド オン';

  @override
  String get soundOff => 'サウンド オフ';

  @override
  String get bots2x => 'ボット 2倍速';

  @override
  String get bots1x => 'ボット 1倍速';

  @override
  String get autoPlayOn => 'オート オン';

  @override
  String get autoPlayOff => 'オート オフ';

  @override
  String get algorithm => 'アルゴリズム';

  @override
  String get pausedCaps => '一時停止中';

  @override
  String get menuCaps => 'メニュー';

  @override
  String get loadFailed => '読み込みを完了できませんでした。もう一度お試しください。';

  @override
  String get retry => '再試行';

  @override
  String get clientIdTitle => 'あなたのクライアント ID';

  @override
  String get clientIdShort => 'ID';

  @override
  String get clientIdHelp => '問題を報告する際はこれを添えてください。';

  @override
  String get close => '閉じる';

  @override
  String get copied => 'コピーしました';

  @override
  String get copy => 'コピー';

  @override
  String faanCount(int n) {
    return '$n翻';
  }

  @override
  String taiCount(int n) {
    return '$n台';
  }

  @override
  String badgeTooltip(String rules, String minimum) {
    return '$rulesルールでプレイ中$minimum。';
  }

  @override
  String badgeMinimum(String min) {
    return '、最低$min';
  }

  @override
  String get yakuRiichi => '立直';

  @override
  String get yakuDoubleRiichi => 'ダブル立直';

  @override
  String get yakuIppatsu => '一発';

  @override
  String get yakuMenzenTsumo => '門前清自摸和';

  @override
  String get yakuHaiteiRaoyue => '海底摸月';

  @override
  String get yakuHouteiRaoyui => '河底撈魚';

  @override
  String get yakuRinshanKaihou => '嶺上開花';

  @override
  String get yakuChankan => '槍槓';

  @override
  String get yakuTanyao => '断幺九';

  @override
  String get yakuRoundWind => '場風';

  @override
  String get yakuSeatWind => '自風';

  @override
  String get yakuShousangen => '小三元';

  @override
  String get yakuPinfu => '平和';

  @override
  String get yakuIipeiko => '一盃口';

  @override
  String get yakuRyanpeikou => '二盃口';

  @override
  String get yakuChiitoitsu => '七対子';

  @override
  String get yakuToitoi => '対々和';

  @override
  String get yakuSanankou => '三暗刻';

  @override
  String get yakuSankantsu => '三槓子';

  @override
  String get yakuSanshokuDoujun => '三色同順';

  @override
  String get yakuSanshokuDoukou => '三色同刻';

  @override
  String get yakuIttsu => '一気通貫';

  @override
  String get yakuHonroutou => '混老頭';

  @override
  String get yakuHonitsu => '混一色';

  @override
  String get yakuChinitsu => '清一色';

  @override
  String get yakuChanta => '混全帯幺九';

  @override
  String get yakuJunchan => '純全帯幺九';

  @override
  String get yakuDora => 'ドラ';

  @override
  String get yakuUraDora => '裏ドラ';

  @override
  String get yakuAkaDora => '赤ドラ';

  @override
  String get yakuKokushiMusou => '国士無双';

  @override
  String get yakuSuuankou => '四暗刻';

  @override
  String get yakuDaisangen => '大三元';

  @override
  String get yakuDaisuushii => '大四喜';

  @override
  String get yakuShousuushii => '小四喜';

  @override
  String get yakuTsuuiisou => '字一色';

  @override
  String get yakuChinroutou => '清老頭';

  @override
  String get yakuRyuuiisou => '緑一色';

  @override
  String get yakuChuurenPoutou => '九蓮宝燈';

  @override
  String get faanAllFlowers => '四花';

  @override
  String get faanAllSeasons => '四季';

  @override
  String get faanAllHonours => '字一色';

  @override
  String get faanAllSequences => '平糊';

  @override
  String get faanAllTerminals => '清幺九';

  @override
  String get faanAllTriplets => '対々糊';

  @override
  String get faanAllQuadruplets => '十八羅漢';

  @override
  String get faanAllQuadrupletsUpgrade => '十八羅漢（昇格）';

  @override
  String get faanAllConcealedTriplets => '坎坎糊';

  @override
  String get faanAllConcealedTripletsUpgrade => '坎坎糊（昇格）';

  @override
  String get faanBigFourWinds => '大四喜';

  @override
  String get faanBigThreeDragons => '大三元';

  @override
  String get faanBlessingOfEarth => '地糊';

  @override
  String get faanBlessingOfHeaven => '天糊';

  @override
  String get faanBlessingOfMan => '人糊';

  @override
  String get faanChickenHand => '鶏糊';

  @override
  String get faanConcealedHand => '門前清';

  @override
  String get faanDoubleKongReplacement => '槓上槓';

  @override
  String get faanFullFlush => '清一色';

  @override
  String get faanMixedFlush => '混一色';

  @override
  String get faanMixedTerminals => '混幺九';

  @override
  String get faanMoonUnderTheSea => '海底撈月';

  @override
  String get faanNineGates => '九子連環';

  @override
  String get faanNoFlowersOrSeasons => '無花';

  @override
  String get faanRobbingTheKong => '搶槓';

  @override
  String get faanRoundWind => '圏風';

  @override
  String get faanSeatWind => '門風';

  @override
  String get faanSelfPick => '自摸';

  @override
  String get faanSevenPairs => '七対';

  @override
  String get faanSmallFourWinds => '小四喜';

  @override
  String get faanSmallThreeDragons => '小三元';

  @override
  String get faanThirteenOrphans => '十三幺';

  @override
  String get faanWinByKongReplacement => '槓上開花';

  @override
  String get faanSevenFlowers => '七花';

  @override
  String get faanEightFlowers => '八仙過海';

  @override
  String get taiAllChowsWithFlowersOrHonors => '平胡（花・字牌あり）';

  @override
  String get taiAllChows => '平胡';

  @override
  String get taiAllPungs => '碰碰胡';

  @override
  String get taiAllFlowers => '八仙過海';

  @override
  String get taiBigFourWinds => '大四喜';

  @override
  String get taiBigThreeDragons => '大三元';

  @override
  String get taiBigThreeWinds => '大三風';

  @override
  String get taiBlessingsOfEarth => '地胡';

  @override
  String get taiBlessingsOfHeaven => '天胡';

  @override
  String get taiClosedWait => '嵌張';

  @override
  String get taiConcealedHand => '門前清';

  @override
  String get taiConcealedKong => '暗槓';

  @override
  String get taiFiveConcealedPungs => '五暗刻';

  @override
  String get taiFourConcealedPungs => '四暗刻';

  @override
  String get taiThreeConcealedPungs => '三暗刻';

  @override
  String get taiTwoConcealedPungs => '二暗刻';

  @override
  String get taiFlowerTile => '花牌';

  @override
  String get taiFullyConcealedHand => '門前清自摸';

  @override
  String get taiFullFlush => '清一色';

  @override
  String get taiHalfFlush => '混一色';

  @override
  String get taiLastTileDraw => '海底撈月';

  @override
  String get taiLittleFourWinds => '小四喜';

  @override
  String get taiLittleThreeDragons => '小三元';

  @override
  String get taiLittleThreeWinds => '小三風';

  @override
  String get taiMeldedHand => '全求人';

  @override
  String get taiMeldedKong => '明槓';

  @override
  String get taiNoFlowerOrHonorTiles => '無花無字';

  @override
  String get taiNoFlowerTiles => '無花';

  @override
  String get taiNoHonors => '無字';

  @override
  String get taiPureStraight => '一気通貫';

  @override
  String get taiRobbingTheKong => '搶槓';

  @override
  String get taiSelfDrawn => '自摸';

  @override
  String get taiSevenPairsAndAPung => '嚦咕嚦咕';

  @override
  String get taiSingleWait => '単騎';

  @override
  String get taiValueHonor => '役牌';

  @override
  String get taiWinWithin5Discards => '5巡以内の和了';

  @override
  String get taiWinWithin5To10Discards => '5〜10巡以内の和了';

  @override
  String get resultKyuushuKyuuhaiNineTerminalsHonors => '九種九牌';

  @override
  String get resultExhaustiveDraw => '流局';

  @override
  String get resultMultipleWins => '一炮多響';

  @override
  String get resultRobbingAKong => '搶槓';

  @override
  String get resultWinOnDiscard => '出銃和了';

  @override
  String get resultMultipleRon => 'ダブロン';

  @override
  String get resultChankan => '槍槓';

  @override
  String get resultRon => 'ロン';

  @override
  String get resultSelfDraw => '自摸和了';

  @override
  String get resultTsumo => 'ツモ';

  @override
  String get limitMangan => '満貫';

  @override
  String get limitHaneman => '跳満';

  @override
  String get limitBaiman => '倍満';

  @override
  String get limitSanbaiman => '三倍満';

  @override
  String get limitKazoeYakuman => '数え役満';

  @override
  String get limitYakuman => '役満';

  @override
  String get limit13FaanCap => '13翻以上（上限）';

  @override
  String get tileTon => '東';

  @override
  String get tileNan => '南';

  @override
  String get tileShaa => '西';

  @override
  String get tilePei => '北';

  @override
  String get tileHaku => '白';

  @override
  String get tileHatsu => '發';

  @override
  String get tileChun => '中';

  @override
  String get tilePlum => '梅';

  @override
  String get tileOrchid => '蘭';

  @override
  String get tileChrysanthemum => '菊';

  @override
  String get tileBamboo => '竹';

  @override
  String get tileSpring => '春';

  @override
  String get tileSummer => '夏';

  @override
  String get tileAutumn => '秋';

  @override
  String get tileWinter => '冬';

  @override
  String yakuYakuhai(String tile) {
    return '役牌（$tile）';
  }

  @override
  String faanHonorPung(String tile) {
    return '$tileの刻子';
  }

  @override
  String limitMultipleYakuman(int n) {
    return '$n倍役満';
  }

  @override
  String get bubbleRiichi => 'リーチ';

  @override
  String get bubbleRinshanRiichi => 'リンシャン';

  @override
  String get bubbleRinshanChinese => 'リンシャン';

  @override
  String get doraRowLabel => 'ドラ';

  @override
  String get uraRowLabel => '裏';

  @override
  String get noCalls => '鳴き';

  @override
  String get autoPlaySeatTooltip => 'オート — TileSensor があなたの席を打っています';

  @override
  String get furiten => 'フリテン';

  @override
  String secondsShort(int n) {
    return '$n秒';
  }

  @override
  String statusWall(int n) {
    return '残り $n';
  }

  @override
  String statusDealerRepeat(int n) {
    return '連荘 $n';
  }

  @override
  String statusHonba(int n) {
    return '$n本場';
  }

  @override
  String statusRiichiSticks(int n) {
    return '供託 $n';
  }

  @override
  String statusRound(String kanji, String wind, int hand) {
    return '$kanji$hand局';
  }

  @override
  String seatLabelYou(String name) {
    return '$name（あなた）';
  }

  @override
  String seatLabelBot(String name) {
    return '$name（ボット）';
  }

  @override
  String get seatBot => 'ボット';

  @override
  String seatNumber(int n) {
    return '$n番席';
  }

  @override
  String tileMan(int n) {
    return '$n萬';
  }

  @override
  String tilePin(int n) {
    return '$n筒';
  }

  @override
  String tileSou(int n) {
    return '$n索';
  }

  @override
  String get undoPass => 'パス';

  @override
  String get undoContinueDrawing => 'ツモを続ける';

  @override
  String undoRiichi(String tile) {
    return 'リーチ $tile';
  }

  @override
  String undoKan(String kan, String tile) {
    return '$kan $tile';
  }

  @override
  String get hideGuide => 'ガイドを隠す';

  @override
  String get showGuide => 'ガイドを表示';

  @override
  String get hideGuideFooter => 'タップでガイドを隠します。';

  @override
  String get showGuideFooter => 'タップでガイドを表示します。';

  @override
  String get sortCaption => '並べ替え';

  @override
  String get sortOff => 'オフ';

  @override
  String get sortOffTooltip =>
      '並べ替え：オフ — 自分の並び順。\n牌を長押ししてドラッグで移動。タップで「手牌」（牌順）に。';

  @override
  String get sortHand => '手牌';

  @override
  String get sortHandTooltip =>
      '並べ替え：手牌 — 牌順に並べ、ツモ牌は右に離して置きます。\nタップで「手牌＋ツモ」に。牌をドラッグすると自分の並び順になります。';

  @override
  String get sortHandDraw => '手牌＋ツモ';

  @override
  String get sortHandDrawTooltip =>
      '並べ替え：手牌＋ツモ — ツモ牌もそのまま手牌に並べます。\nタップでこの並びを固定（オフ）。牌をドラッグすると自分の並び順になります。';

  @override
  String get discardCaption => '打牌';

  @override
  String get discardSingle => 'シングル';

  @override
  String get discardDouble => 'ダブル';

  @override
  String get discardSingleTooltip =>
      '打牌：シングルタップ — 牌をタップすると打牌します。\nタップで「1回目で牌を上げ、2回目で打牌」に。';

  @override
  String get discardDoubleTooltip =>
      '打牌：ダブルタップ — 1回目で牌を上げ、2回目で打牌します。\nタップでシングルタップ打牌に。';

  @override
  String get autoWinCaption => 'オート和了';

  @override
  String get autoWinOnTooltip =>
      'オート和了：オン — 和了できるとロン・ツモを自動で宣言します。\nタップで自分で判断します。';

  @override
  String get autoWinOffTooltip => 'オート和了：オフ — 和了ボタンは自分で押します。\nタップでロン・ツモを自動宣言に。';

  @override
  String get autoPassCaption => 'オートパス';

  @override
  String get autoPassOnTooltip =>
      'オートパス：オン — 他家の捨て牌へのチー・ポン・カンは自動でパスします。ロンはあなたが判断します。\nタップで鳴きを自分で判断します。';

  @override
  String get autoPassOffTooltip =>
      'オートパス：オフ — すべての鳴きを確認します。\nタップでチー・ポン・カンを自動パスに。';

  @override
  String declareRiichiDiscard(String tile) {
    return 'リーチして $tile を打牌';
  }

  @override
  String justDiscard(String tile) {
    return '$tile を打牌するだけ';
  }

  @override
  String get flowerWin => '花和了';

  @override
  String get continueDrawing => 'ツモを続ける';

  @override
  String get passCaps => 'パス';

  @override
  String get kyuushuKyuuhai => '九種九牌';

  @override
  String get riichiAvailable => 'リーチ可能';

  @override
  String get riichiAvailableRecommended => 'リーチ可能 — おすすめ';

  @override
  String get undoTooltip =>
      'この局の直前の手と、それ以降をすべて取り消します。\nもう一度押すとさらに戻ります。(Ctrl/Cmd+Z)';

  @override
  String get takeBack => '取り消し  ';

  @override
  String get scoreNewGame => '新しい対局';

  @override
  String get scoreNext => '次へ';

  @override
  String scoreContinueLocked(int n) {
    return '続ける（$n）';
  }

  @override
  String get scoreContinue => '続ける';

  @override
  String get autoContinuePaused => '自動進行：一時停止中';

  @override
  String get autoContinueHeld => '自動進行：保留中 — 対局は一時停止中';

  @override
  String autoContinueIn(int n) {
    return '$n秒後に自動で続行';
  }

  @override
  String get showPanel => 'パネルを表示';

  @override
  String get seeThroughPanel => 'パネルを透かす';

  @override
  String get flowersSeasons => '花牌／季節牌';

  @override
  String indicatorRowOne(String label) {
    return '$label表示牌：';
  }

  @override
  String indicatorRowMany(String label) {
    return '$label表示牌：';
  }

  @override
  String plainRow(String label) {
    return '$label：';
  }

  @override
  String yakuLineTaiOne(String name, int n) {
    return '$name  $n台';
  }

  @override
  String yakuLineTaiMany(String name, int n) {
    return '$name  $n台';
  }

  @override
  String yakuLineFaan(String name, int n) {
    return '$name  $n翻';
  }

  @override
  String yakuLineHan(String name, int n) {
    return '$name  $n翻';
  }

  @override
  String yakuLineYakuman(String name) {
    return '$name  役満';
  }

  @override
  String scorePointOne(int n) {
    return '$n点';
  }

  @override
  String scorePointMany(int n) {
    return '$n点';
  }

  @override
  String scoreFaanChips(int faan, int points, String limit) {
    return '$faan翻 — $pointsチップ$limit';
  }

  @override
  String scoreLimitOnly(String limit, int points) {
    return '$limit — $points点';
  }

  @override
  String scoreHanFu(int han, int fu, String limit, int points) {
    return '$han翻$fu符$limit — $points点';
  }

  @override
  String limitSuffix(String limit) {
    return '（$limit）';
  }

  @override
  String get wallExhaustedNoPayments => '流局 — 精算なし';

  @override
  String get allNoten => '全員ノーテン';

  @override
  String get tenpaiRevealed => '聴牌者の手牌を公開';

  @override
  String get waits => '待ち';

  @override
  String get backToMenu => 'メニューに戻る';

  @override
  String get cantReachServer => 'オンライン対戦サーバーに接続できません — 再試行中…';

  @override
  String get noGuideOnline =>
      'オンライン対戦には TileSense ガイドはありません — ガイドを使うにはひとりで遊んでください。';

  @override
  String get yourName => 'あなたの名前';

  @override
  String get yourNameHelper => '既定はキャラクター名 — 編集すると自分の名前に';

  @override
  String get createARoom => 'ルームを作成';

  @override
  String get fullGameSwitch => '半荘戦（8局以上）';

  @override
  String get fullGameSwitchOn => 'オフで東風戦（4局以上）';

  @override
  String get fullGameSwitchOff => '東風戦 — 4局以上';

  @override
  String get createRoomButton => 'ルームを作成';

  @override
  String get joinARoom => 'ルームに参加';

  @override
  String get roomCode => 'ルームコード';

  @override
  String get join => '参加';

  @override
  String get chooseYourCharacter => 'キャラクターを選択';

  @override
  String get pace => 'ペース';

  @override
  String get paceFast => '速い';

  @override
  String get paceStandard => '標準';

  @override
  String get paceRelaxed => 'ゆっくり';

  @override
  String paceCaption(int turn, int call) {
    return '1手 $turn秒 · 鳴き $call秒';
  }

  @override
  String get minimumFaanToWin => '和了に必要な最低翻数';

  @override
  String get minimumTaiToWin => '和了に必要な最低台数';

  @override
  String get roomCodeShare => 'ルームコード — 他のプレイヤーに共有してください';

  @override
  String get copyCode => 'コードをコピー';

  @override
  String get roomCodeCopied => 'ルームコードをコピーしました';

  @override
  String roomFaanMin(int n) {
    return '最低$n翻';
  }

  @override
  String roomTaiMin(int n) {
    return '最低$n台';
  }

  @override
  String get roomFullGame => '半荘戦';

  @override
  String get roomEastOnly => '東風戦';

  @override
  String roomClocks(int turn, int call) {
    return '1手 $turn秒 · 鳴き $call秒';
  }

  @override
  String get startGameBots => '対局開始 — 空席はボットが埋めます';

  @override
  String get waitingForHost => 'ホストの開始を待っています…';

  @override
  String get leaveRoomButton => 'ルームを退出';

  @override
  String get emptySeat => '空席';

  @override
  String get host => 'ホスト';

  @override
  String get rejoiningGame => '対局に戻っています…';

  @override
  String gameStillGoing(String code) {
    return 'ルーム $code の対局はまだ続いています。';
  }

  @override
  String get rejoin => '戻る';

  @override
  String get leaveGameTitle => 'この対局を抜けますか？';

  @override
  String get leaveGameBody => '戻るまでボットがあなたの席を打ちます — 対局中はメインメニューから戻れます。';

  @override
  String get stay => '残る';

  @override
  String get leave => '退出';

  @override
  String get leaveRoom => 'ルームを退出';

  @override
  String get clientId => 'クライアント ID';

  @override
  String nowBotControlled(String name) {
    return '$name はボット操作になりました';
  }

  @override
  String get noGuideOnlineTooltip =>
      'TileSensor はオンライン対戦には参加しません。ガイドの有無で差がつかないようにするためです。\nひとりで遊べば一緒にいられます！';

  @override
  String roomLabel(String code) {
    return 'ルーム $code';
  }

  @override
  String get connectionLost => '接続が切れました — 再接続中…';

  @override
  String get backToStart => 'スタートに戻る';

  @override
  String get errorNotSeated => 'このルームに席がありません。';

  @override
  String get errorSeatBotControlled => 'この席はボットが操作しています。';

  @override
  String get errorMissingGuestId => '問題が発生しました。もう一度お試しください。';

  @override
  String get errorServerFull => 'サーバーが満員です。しばらくしてからお試しください。';

  @override
  String get errorMissingRoom => 'ルームコードを入力してください。';

  @override
  String get errorRoomNotFound => 'ルームが見つかりません。';

  @override
  String get errorRoomStarted => 'そのルームはすでに始まっています。';

  @override
  String get errorRoomFull => 'そのルームは満員です。';

  @override
  String get errorNotHost => '対局を始められるのはホストだけです。';

  @override
  String get errorRoomGone => 'そのルームはもう存在しません。';

  @override
  String get errorUnknownType => '問題が発生しました。もう一度お試しください。';

  @override
  String get errorMalformed => '問題が発生しました。もう一度お試しください。';

  @override
  String get errorBadRequest => '問題が発生しました。もう一度お試しください。';

  @override
  String get errorIllegalAction => '今その操作はできません。';

  @override
  String get errorNoActionExpected => 'あなたの番ではありません。';

  @override
  String get errorGameEnded => 'その対局は終了しました';

  @override
  String get guideTipTitle => 'ガイド\n';

  @override
  String get guideGreen => '緑の牌';

  @override
  String get guideGreenBody => 'おすすめの打牌';

  @override
  String get guideYellow => '黄色の牌';

  @override
  String get guideYellowBody => '今ツモった牌';

  @override
  String get guidePause => '対局を一時停止';

  @override
  String get guideHover => '\n見出しや設定にカーソルを合わせると説明が表示されます。';

  @override
  String get tipAutoTitle => 'オートプレイ\n';

  @override
  String get tipAutoBody => 'あなたの席を自動で打つときに従う判断と、下の候補の並び順を選びます。\n';

  @override
  String get tipAutoChoices =>
      '• TileSense（初期設定）：ガイドのおすすめを先頭に表示します。\n• Mortal：Mortal があなたの席を打ち、その推奨手を先頭に表示します。回答できない場合はガイドが判断します。';

  @override
  String get tipEvTitle => 'TileSense 期待値\n';

  @override
  String get tipFinishTitle => '和了確率';

  @override
  String get tipFinishBody =>
      'この局が終わるまでに和了する確率です。有効牌の残り枚数と残りツモ回数が多いほど高くなります。\n';

  @override
  String get tipFinishMore => '受け入れにカーソルを合わせる・EV (HMR) の数値を押すとグラフを表示';

  @override
  String get tipPayoutTitle => '和了時の得点';

  @override
  String get tipPayoutTw =>
      '各支払者が同額を払う点数に連荘ボーナスを加えます。聴牌時は正確な値、それ以前は表示された役からの推定です。\n';

  @override
  String get tipPayoutHk => '翻数をチップに換算します。聴牌時は正確な値、それ以前は表示された役からの推定です。\n';

  @override
  String get tipPayoutRiichi => '和了点に本場と供託リーチ棒を加えます。聴牌時は正確な値、それ以前は推定です。\n';

  @override
  String get tipPayoutMore => 'EV (HMR) の数値を押すと計算過程を表示';

  @override
  String get tipCutTitle => '打牌のリスク';

  @override
  String get tipCutChinese => '3組以上の副露がある相手への推定損失です。完全に安全な牌はありません。\n';

  @override
  String get tipCutRiichi =>
      '和了しなければ失うリーチ棒の分です。他家のリーチがあれば、この牌の放銃率と押し続ける巡数も含みます。\n';

  @override
  String get tipCutMore => 'リスクと安全度にカーソルを合わせる';

  @override
  String get tipFocusTitle => '重視する要素';

  @override
  String get tipFocusBody => '速度重視は打点の一部を和了率に振り向けます。バランス型は補正しません。\n';

  @override
  String get tipFocusMore => '重視する要素にカーソルを合わせる';

  @override
  String get tipFocusPlacementMore => '重視する要素・戦略・順位にカーソルを合わせる';

  @override
  String get tipEvHigher => '\n高いほど有利です。危険で打点の低い打牌は負の値になることもあります。';

  @override
  String get tipOrdinaryWide => '標準より広い受け入れ';

  @override
  String get tipOrdinaryWideBody => '進みやすくなりますが、標準的な手牌より速いとは見積もりません';

  @override
  String get tipOrdinaryTitle => '標準的な手牌';

  @override
  String get tipShantenLabel => '向聴数';

  @override
  String get tipUkeireLabel => '受け入れ';

  @override
  String get tipAwayLabel => '聴牌まで';

  @override
  String get tipAcceptsLabel => '有効牌';

  @override
  String get tipOrdinaryNote =>
      '\n中央値ではなく平均値です。守備も鳴きも行わず牌効率だけを追う一人打ちシミュレーションで、各向聴数の最善打牌の受け入れを測定しています。';

  @override
  String get tipSafetyTitle => '安全度\n';

  @override
  String get tipSafetyChinese => '副露している相手に対する打牌の危険度です。高いほど安全です。\n';

  @override
  String get tipSafetyRiichi => 'リーチに対する打牌の安全度です。0 は危険、15 は現物です。\n';

  @override
  String get tipNeverCertain => '絶対ではない';

  @override
  String get tipNeverCertainBody => 'フリテンがないため、相手が捨てた牌でも和了されることがあります';

  @override
  String get tipRatedWhen => '評価する条件';

  @override
  String get tipGenbutsu => '現物';

  @override
  String get tipGenbutsuBody => '相手自身の捨て牌や、リーチ後に通った牌ではロンされません';

  @override
  String get tipSuji => 'スジ';

  @override
  String get tipSujiBody => '相手の捨て牌と3つ離れた牌は比較的安全です';

  @override
  String get tipRatedRiichi => '誰かがリーチしている場合です。それ以外は「—」を表示します';

  @override
  String get tipDealInTitle => '打牌の放銃率';

  @override
  String get tipRating => '評価';

  @override
  String get tipTile => '牌';

  @override
  String get tipDealsIn => '放銃率';

  @override
  String get tipRating15 => '現物 — 相手の捨て牌';

  @override
  String get tipRating13 => '字牌、残り1枚';

  @override
  String get tipRating12 => '両スジ';

  @override
  String get tipRating11 => 'スジの老頭牌';

  @override
  String get tipRating9 => '字牌、残り2枚';

  @override
  String get tipRating8 => 'ノーチャンスの牌';

  @override
  String get tipRating7 => '片スジ';

  @override
  String get tipRating6 => 'スジの2・3・7・8、または残り3枚の字牌';

  @override
  String get tipRating3 => '無スジの2・3・7・8';

  @override
  String get tipRating2 => '無スジの中張牌';

  @override
  String get tipHkRating14 => '字牌、未見0枚';

  @override
  String get tipHkRating11 => '字牌、未見1枚';

  @override
  String get tipHkRating6 => '字牌、未見2枚以上';

  @override
  String get tipHkRating5 => '老頭牌';

  @override
  String get tipHkRating3 => '数牌';

  @override
  String get tipRiskTitle => 'リスク\n';

  @override
  String get tipDealInChance => '放銃率';

  @override
  String get tipDealInChanceBody => '牌の安全度から算出';

  @override
  String get tipDealInCost => '放銃時の損失';

  @override
  String get tipStyleWeight => '打ち方の重み';

  @override
  String get tipLaterTurns => '以後の巡目';

  @override
  String get tipHowLong => '期間';

  @override
  String get tipChineseHorizon => 'この局の予想残り時間です。リスクのない打牌には追加負担がありません';

  @override
  String get tipFormula => '計算式';

  @override
  String get tipDetailTitle => '詳細\n';

  @override
  String get tipDetailBody => 'この牌がその安全度になる理由です。\n';

  @override
  String get tipShows => '表示内容';

  @override
  String get tipShowsBody => '現物、スジ、字牌の残り枚数など';

  @override
  String get tipEmpty => '空欄';

  @override
  String get tipEmptyBody => '守備の対象がいないため、説明がありません';

  @override
  String get tipPlacementTitle => '順位\n';

  @override
  String get tipPlacementBody => 'その打牌が、他の3人より上位で終わる可能性をどう変えるかを示します。\n';

  @override
  String get tipUses => '使用する情報';

  @override
  String get tipUsesBody => '現在の持ち点と残り局数';

  @override
  String get tipNotPoints => '点数ではない';

  @override
  String get tipNotPointsBody => '見やすくするため1,000倍しています。他の候補との大小関係にのみ意味があります';

  @override
  String get tipHeuristic => '近似評価';

  @override
  String get tipHeuristicBody => 'シミュレーションではありません';

  @override
  String get tipWorthTitle => '8,000点の価値';

  @override
  String get tipSituation => '状況';

  @override
  String get tipHandsLeft => '残り局数';

  @override
  String get tipEven => '横並び';

  @override
  String get tipLead => '大きくリード';

  @override
  String get tipBehind => '大きく劣勢';

  @override
  String get tipEvenLast => '横並び、最終局';

  @override
  String get tipLeadLast => '大きくリード、最終局';

  @override
  String get tipPlacementNote => '\n接戦や終盤では点数の影響が大きく、余裕のあるリード時には小さくなります。\n';

  @override
  String get tipNoWin => 'この候補にはまだ得点を計算できる和了形がありません。\n';

  @override
  String get tipRiskRow => 'この打牌のリスク';

  @override
  String get tipFinishRow => '和了確率';

  @override
  String get tipPayoutRow => '和了時の得点';

  @override
  String get tipSticksRow => '本場と供託';

  @override
  String get tipAverageRow => '平均すると';

  @override
  String get tipLockRow => 'リーチ拘束分を引く';

  @override
  String get tipDealInRow => '放銃リスクを引く';

  @override
  String get tipCommitRow => '押し続ける負担を引く';

  @override
  String get tipHmrBody => '比較用の単純な数値です。おすすめの判断には影響しません。\n';

  @override
  String get tipHmrExcludes => '\n本場・供託・リスク費用・打ち方や重視要素の補正は含みません。\n';

  @override
  String get tipHmrSource => '\n次のツールの「E.V.」と同じ考え方です：';

  @override
  String get tipHmrSourceBody => '。ツモ和了のみの一人用練習ツールで、獲得点÷局数、つまり和了率×平均和了点です。';

  @override
  String get tipYakuBody =>
      '各バーは、この候補で和了した場合にその役が含まれる割合です。一度の和了には複数の役があることが多いため、合計は100%になりません。100%はすべての和了に含まれるという意味で、リーチ予定ならリーチは100%です。\n\n和了確率を掛けると、全体での成立確率になります。\n\nドラは役ではないため、平均の追加翻数として別に表示します。\n\n≈は推定値です。聴牌前は、受け入れを最大にする打牌を続けると仮定し、到達しやすい聴牌形を評価します。役牌や染め手など、意識して狙う役は計画に含めないため低く出ることがあります。4向聴以上では表示しません。';

  @override
  String get tipMortalBody =>
      'Mortal は公開されている深層学習の麻雀AIです。あなたの席から見える情報だけで判断します。★は推奨打牌（★Rは先にリーチ）、数字は残りの候補の優先順位です。Mortal の推奨牌は赤枠、ガイドの推奨牌は緑色です。緑色で赤枠なら両者が一致しています。\n\n';

  @override
  String get tipMortalAuto =>
      'オートプレイを Mortal にすると、その判断で打ち、候補も Mortal 順になります。TileSense（初期設定）ではガイド順で、Mortal は参考意見です。緑の牌は常にガイドの推奨です。Mortal が回答できない場合はガイドが判断します。\n\n';

  @override
  String get tipMortalSource =>
      'リーチ麻雀の一人用です。Mortal と学習済み重みは AGPL-3.0：ソース github.com/Equim-chan/Mortal、実行サービス github.com/eric-r-xu/TileSense (mortal_sidecar)。';

  @override
  String get tipYakuTitle => '役\n';

  @override
  String tipEvAverage(String unit) {
    return 'この打牌の平均的な価値を$unitで表します（EV＝期待値）。\n';
  }

  @override
  String tipShantenBody(String ready) {
    return '聴牌までに必要な牌の数です（0は$ready）。';
  }

  @override
  String tipUkeireBody(String effect) {
    return '$effectための残り有効牌、つまり役に立つツモの枚数です。\n';
  }

  @override
  String tipThreatSets(String count) {
    return '相手の副露が$count組以上の場合です。それ以外は「—」を表示します';
  }

  @override
  String tipChineseCost(String cost, String unit) {
    return '\n放銃の損失は$cost$unitとして計算します。';
  }

  @override
  String tipRiichiCost(String cost, String dealerCost) {
    return '$cost点（親には$dealerCost点）、本場ごとに300点を加算';
  }

  @override
  String tipRiichiCostNote(String cost, String dealerCost) {
    return '\n放銃の損失は$cost点（親には$dealerCost点）、本場ごとに300点を加算します。';
  }

  @override
  String tipRiskBody(String unit) {
    return 'この打牌の危険性により、期待値から差し引く$unitです。\n';
  }

  @override
  String tipStyleWeights(String weights, String styles) {
    return '$stylesの順に×$weights';
  }

  @override
  String tipCommitPercent(String percent) {
    return 'この打牌で押し続ける巡数ごとに、費用の$percent%を追加';
  }

  @override
  String tipRiichiHorizon(String turns) {
    return 'リーチが続く間、あなたの打牌約$turns回分です。現物には追加負担がありません';
  }

  @override
  String tipThisCut(String tile) {
    return '\nこの打牌 — $tile\n';
  }

  @override
  String tipFocusTilt(String focus) {
    return '$focusの補正';
  }

  @override
  String tipRankOrder(String name, String direction) {
    return '$name（$direction順）';
  }

  @override
  String tipRankDirection(String direction) {
    return '\n\n$direction方が有利です。見出しの矢印で示しています。';
  }

  @override
  String tipRankBody(String first, String second, String third) {
    return '打牌は$first、次に$second、最後に$thirdで並びます。表示される数値が同じなら同順位です。最上位の牌が緑色で、3項目すべて同じ牌も緑色になります。';
  }

  @override
  String get tipReady => '聴牌';

  @override
  String get tipTenpai => '聴牌';

  @override
  String get tipCloser => '聴牌に近づく';

  @override
  String get tipReduce => '向聴数を減らす';

  @override
  String get tipHigher => '高い';

  @override
  String get tipLower => '低い';

  @override
  String get tipHigherFirst => '高い';

  @override
  String get tipLowerFirst => '低い';

  @override
  String get tipPlacementLabel => '順位';

  @override
  String get tipPointsUnit => '点';

  @override
  String get tipChipsUnit => 'チップ';

  @override
  String get tipBalanced => 'バランス';

  @override
  String get tipSpeed => '速度';

  @override
  String get tipAggressive => '攻撃的';

  @override
  String get tipPoints => '点数';

  @override
  String get tipDefensive => '守備的';

  @override
  String get mathChance => '確率';

  @override
  String get mathFinish => '和了';

  @override
  String get mathPayout => '得点';

  @override
  String get mathWin => '和了';

  @override
  String get mathRisk => 'リスク';

  @override
  String get mathCut => '打牌';

  @override
  String get mathDealIn => '放銃';

  @override
  String get mathCost => '損失';

  @override
  String get mathWeight => '重み';

  @override
  String get mathStyle => '打ち方';

  @override
  String get mathCharge => '負担';

  @override
  String get mathLaterTurns => '以後の巡目';

  @override
  String get mathWorth => '価値';

  @override
  String get mathGain => '増減';

  @override
  String get mathScore => '持ち点';

  @override
  String get mathOthers => '他の3人';

  @override
  String get mathTheirs => '相手';

  @override
  String get mathSpread => 'ばらつき';

  @override
  String get mathHandsLeft => '残り局数';

  @override
  String get mathLogistic => 'ロジスティック関数';

  @override
  String mascotIntro(String mascot, String app) {
    return 'ぼくは$mascot。プレーリードッグとウーパールーパーの仲間。\nおすすめの打牌や鳴きを選ぶよ。\nオートプレイをオンにすると、きみの席を打つよ。\n打ち間違えたら、戻してもう一度。\n一緒に遊んで$appを磨こう！';
  }

  @override
  String get rulesetMcr => '国標麻雀 (MCR)';

  @override
  String get rulesetSubtitleMcr => '番・花牌・最低8番';

  @override
  String get mcrFullGame => '全荘 · 16局';

  @override
  String get mcrPractice => '東場練習 · 4局';

  @override
  String mcrScoreTotal(int fan, int flowers, int gain) {
    return '$fan番 + 花牌$flowers · +$gain点';
  }

  @override
  String yakuLineMcr(String name, int n) {
    return '$name  $n番';
  }

  @override
  String get tipPayoutMcr =>
      '番数＋花牌（F）：放銃者が F＋8、他の2人が各8、ツモなら全員が F＋8 を払います。聴牌時は正確な値で、花牌を除いて8番以上の待ちだけが和了できます。それ以前は推定です。\n';
}
