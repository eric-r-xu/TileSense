// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'TileSense';

  @override
  String get languageTooltip => '语言';

  @override
  String get rulesetRiichi => '立直';

  @override
  String get rulesetHongKong => '香港';

  @override
  String get rulesetTaiwanese => '台湾';

  @override
  String get windEast => '东风';

  @override
  String get windSouth => '南风';

  @override
  String get windWest => '西风';

  @override
  String get windNorth => '北风';

  @override
  String get callChiRiichi => '吃';

  @override
  String get callChiHongKong => '上';

  @override
  String get callChiTaiwanese => '吃';

  @override
  String get callPonRiichi => '碰';

  @override
  String get callPonHongKong => '碰';

  @override
  String get callPonTaiwanese => '碰';

  @override
  String get callKanRiichi => '杠';

  @override
  String get callKanHongKong => '杠';

  @override
  String get callKanTaiwanese => '杠';

  @override
  String get callRonRiichi => '荣和';

  @override
  String get callRonHongKong => '食糊';

  @override
  String get callRonTaiwanese => '胡';

  @override
  String get callTsumoRiichi => '自摸';

  @override
  String get callTsumoHongKong => '自摸';

  @override
  String get callTsumoTaiwanese => '自摸';

  @override
  String get hanchanCaveatRiichi =>
      '以上是每局都轮庄时的局数。按标准立直规则，庄家和牌或荒牌流局时听牌就会连庄并重打该局——所以两种长度都可能更长。';

  @override
  String get hanchanCaveatChinese =>
      '以上是每局都轮庄时的局数。庄家和牌或任何荒牌流局都会连庄并重打该局——所以两种长度都可能更长。';

  @override
  String get zoomOut => '缩小  (Ctrl/Cmd -)';

  @override
  String get zoomIn => '放大  (Ctrl/Cmd +)';

  @override
  String get zoomReset => '重置缩放  (Ctrl/Cmd 0)';

  @override
  String get installTitle => '安装 TileSense';

  @override
  String get installBody =>
      '此浏览器无法让网页全屏显示。请改为将 TileSense 安装为网页应用，它会全屏打开，没有浏览器栏：\n\n• iPhone / iPad：点“分享”，再点“添加到主屏幕”\n• Chrome / Edge：点地址栏中的安装图标，或菜单 > “安装应用”';

  @override
  String get gotIt => '知道了';

  @override
  String get fullscreenExit => '退出全屏';

  @override
  String get fullscreenTooltip =>
      '全屏。为获得最佳体验，请将 TileSense 安装为网页应用（浏览器菜单 > 安装／添加到主屏幕）。';

  @override
  String get fullscreen => '全屏';

  @override
  String get updateAvailableTitle => '有可用更新';

  @override
  String get updateAvailableBody => '新版 TileSense 已就绪。立即更新即可获取。';

  @override
  String get updateNow => '立即更新';

  @override
  String get upToDateTitle => '已是最新版本';

  @override
  String get upToDateBody => '这已是最新版本。仍可刷新以重新下载所有文件。';

  @override
  String get refreshAnyway => '仍然刷新';

  @override
  String get refreshTitle => '刷新 TileSense';

  @override
  String get refreshUnknownBody => '无法确定是否有新版本。刷新以下载最新文件。';

  @override
  String get refresh => '刷新';

  @override
  String get notNow => '暂不';

  @override
  String get updateTooltip => '检查新版本并刷新应用';

  @override
  String get working => '处理中…';

  @override
  String get update => '更新';

  @override
  String get rotatePrompt => '请将设备横置以使用 TileSense';

  @override
  String get widenPrompt => '请将浏览器窗口调宽以使用 TileSense';

  @override
  String minimumFaanSentence(int n) {
    return '，最低$n番';
  }

  @override
  String minimumTaiSentence(int n) {
    return '，最低$n台';
  }

  @override
  String minimumFaanTag(int n) {
    return '最低$n番';
  }

  @override
  String minimumTaiTag(int n) {
    return '最低$n台';
  }

  @override
  String minimumFanTag(int n) {
    return '最低$n番';
  }

  @override
  String get newGameConfirmTitle => '开始新对局？';

  @override
  String get newGameConfirmBody => '进行中的对局将会丢失。';

  @override
  String get keepPlaying => '继续对局';

  @override
  String lengthChangeConfirmTitle(String length) {
    return '切换为$length？';
  }

  @override
  String get lengthChangeConfirm => '切换';

  @override
  String get newGame => '新对局';

  @override
  String get loadingTable => '正在准备牌桌…';

  @override
  String get loadingBuilder => '正在加载手牌构建器…';

  @override
  String get loadingMultiplayer => '正在加载联机对战…';

  @override
  String get start => '开始';

  @override
  String get menu => '菜单';

  @override
  String get menuTooltip => '主菜单——暂停本局；点“开始”继续。可在那里更换玩法（开始新对局），或打开自定义手牌与情境构建器';

  @override
  String playingRulesTooltip(String rules, String minimum) {
    return '正在使用$rules规则$minimum。\n要换别的玩法，请回到主菜单。';
  }

  @override
  String rulesPdf(String rules) {
    return '$rules规则（PDF，英文）';
  }

  @override
  String hanchanOnTooltip(String caveat) {
    return '半庄——东风圈和南风圈，8局以上。\n$caveat\n点按切换为东风战，4局以上。';
  }

  @override
  String eastOnlyTooltipChinese(String caveat) {
    return '东风战——只打东风圈，4局以上。\n$caveat\n点按切换为半庄：东风圈和南风圈，8局以上。';
  }

  @override
  String eastOnlyTooltipRiichi(String caveat) {
    return '东风战——只打东风圈，4局以上。\n$caveat\n点按切换为半庄：东风圈和南风圈，8局以上。';
  }

  @override
  String get hanchan => '半庄';

  @override
  String get eastOnly => '东风战';

  @override
  String get botSpeedCaption => '电脑速度';

  @override
  String get botSpeedFastTooltip => '电脑和摸牌以两倍速进行。\n点按恢复正常速度。';

  @override
  String get botSpeedNormalTooltip => '电脑和摸牌以正常速度进行。\n点按切换为两倍速。';

  @override
  String get algorithmCaption => '算法';

  @override
  String get mortalBot => 'Mortal 机器人';

  @override
  String algorithmTooltip(String style, String focus, String strategy) {
    return 'TileSense 指南：$style · $focus · $strategy。\n随对局自动调整：前期采用进攻・速度・点数以建立领先；最后两局采用平衡・速度・顺位以守住或提升排名。';
  }

  @override
  String get autoPlayCaption => '自动打牌';

  @override
  String get autoPlayOnTooltip =>
      '自动打牌已开启——TileSensor 按指南替你打牌：前期重得分，最后两局重名次。\n点按收回座位。';

  @override
  String get autoPlayOffTooltip => '自动打牌已关闭——你自己打牌。\n点按让 TileSensor 按指南替你打。';

  @override
  String get on => '开';

  @override
  String get off => '关';

  @override
  String get soundCaption => '声音';

  @override
  String get soundOnTooltip => '声音已开——点按静音';

  @override
  String get soundOffTooltip => '声音已关——点按取消静音';

  @override
  String get resumeCaption => '继续';

  @override
  String get pauseCaption => '暂停';

  @override
  String get resume => '继续';

  @override
  String get pause => '暂停';

  @override
  String get newCaption => '新局';

  @override
  String get pausedOverlay => '已暂停\n点按或按 Esc 继续';

  @override
  String get rulesetSubtitleRiichi => '役、宝牌、立直';

  @override
  String get rulesetSubtitleHongKong => '番、花牌、最低0–3番';

  @override
  String get rulesetSubtitleTaiwanese => '17张、花牌、最低1–5台';

  @override
  String welcomeTagline(String rules) {
    return '磨练你的$rules麻将决策\n指南只看你看得到的信息。';
  }

  @override
  String get singlePlayer => '单人游戏';

  @override
  String get singlePlayerSubtitle => '含 TileSense 指南';

  @override
  String get playOnline => '联机对战';

  @override
  String get builder => '手牌构建器';

  @override
  String get builderSubtitle => '让 TileSense 指南评分';

  @override
  String rejoinOnline(String code) {
    return '重新加入联机对局 · 房间 $code';
  }

  @override
  String get viewOnGitHub => '在 GitHub 上查看';

  @override
  String get builtWithFlutter => '使用 Flutter 构建';

  @override
  String get seatYou => '你';

  @override
  String get seatRight => '下家';

  @override
  String get seatAcross => '对家';

  @override
  String get seatLeft => '上家';

  @override
  String get youStartAs => '你的起始风位';

  @override
  String get style => '玩法';

  @override
  String get gameLength => '对局长度';

  @override
  String get lengthHanchan => '半庄';

  @override
  String get lengthEastOnly => '东风战';

  @override
  String get minFaan => '最低番数';

  @override
  String get minFaanTooltip => '和牌所需的最少番数。\n0 表示任何完整牌型（包括鸡糊）都能和牌。';

  @override
  String get minTai => '最低台数';

  @override
  String get minTaiTooltip => '和牌所需的最少台数。\n5 是圣地亚哥俱乐部规则；1 和 3 是常见的自定最低台数。';

  @override
  String get chooseCharacters => '选择角色';

  @override
  String get dealerNoteYou => '东家先坐庄——就是你。';

  @override
  String dealerNoteOther(String seat) {
    return '东家先坐庄——是$seat。';
  }

  @override
  String get randomizeCharacters => '随机角色与座位';

  @override
  String get sound => '声音';

  @override
  String get back => '返回';

  @override
  String get backToMainMenu => '返回主菜单';

  @override
  String get done => '完成';

  @override
  String get mainMenu => '主菜单';

  @override
  String get rules => '规则';

  @override
  String get soundOn => '声音开';

  @override
  String get soundOff => '声音关';

  @override
  String get bots2x => '电脑 2倍速';

  @override
  String get bots1x => '电脑 1倍速';

  @override
  String get autoPlayOn => '自动打牌 开';

  @override
  String get autoPlayOff => '自动打牌 关';

  @override
  String get algorithm => '算法';

  @override
  String get pausedCaps => '已暂停';

  @override
  String get menuCaps => '菜单';

  @override
  String get loadFailed => '无法完成加载，请重试。';

  @override
  String get retry => '重试';

  @override
  String get clientIdTitle => '你的客户端 ID';

  @override
  String get clientIdShort => 'ID';

  @override
  String get clientIdHelp => '报告问题时请附上此 ID。';

  @override
  String get close => '关闭';

  @override
  String get copied => '已复制';

  @override
  String get copy => '复制';

  @override
  String faanCount(int n) {
    return '$n番';
  }

  @override
  String taiCount(int n) {
    return '$n台';
  }

  @override
  String badgeTooltip(String rules, String minimum) {
    return '正在使用$rules规则$minimum。';
  }

  @override
  String badgeMinimum(String min) {
    return '，最低$min';
  }

  @override
  String get yakuRiichi => '立直';

  @override
  String get yakuDoubleRiichi => '两立直';

  @override
  String get yakuIppatsu => '一发';

  @override
  String get yakuMenzenTsumo => '门前清自摸和';

  @override
  String get yakuHaiteiRaoyue => '海底摸月';

  @override
  String get yakuHouteiRaoyui => '河底捞鱼';

  @override
  String get yakuRinshanKaihou => '岭上开花';

  @override
  String get yakuChankan => '抢杠';

  @override
  String get yakuTanyao => '断幺九';

  @override
  String get yakuRoundWind => '场风';

  @override
  String get yakuSeatWind => '自风';

  @override
  String get yakuShousangen => '小三元';

  @override
  String get yakuPinfu => '平和';

  @override
  String get yakuIipeiko => '一杯口';

  @override
  String get yakuRyanpeikou => '二杯口';

  @override
  String get yakuChiitoitsu => '七对子';

  @override
  String get yakuToitoi => '对对和';

  @override
  String get yakuSanankou => '三暗刻';

  @override
  String get yakuSankantsu => '三杠子';

  @override
  String get yakuSanshokuDoujun => '三色同顺';

  @override
  String get yakuSanshokuDoukou => '三色同刻';

  @override
  String get yakuIttsu => '一气通贯';

  @override
  String get yakuHonroutou => '混老头';

  @override
  String get yakuHonitsu => '混一色';

  @override
  String get yakuChinitsu => '清一色';

  @override
  String get yakuChanta => '混全带幺九';

  @override
  String get yakuJunchan => '纯全带幺九';

  @override
  String get yakuDora => '宝牌';

  @override
  String get yakuUraDora => '里宝牌';

  @override
  String get yakuAkaDora => '赤宝牌';

  @override
  String get yakuKokushiMusou => '国士无双';

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
  String get yakuChinroutou => '清老头';

  @override
  String get yakuRyuuiisou => '绿一色';

  @override
  String get yakuChuurenPoutou => '九莲宝灯';

  @override
  String get faanAllFlowers => '四花齐';

  @override
  String get faanAllSeasons => '四季齐';

  @override
  String get faanAllHonours => '字一色';

  @override
  String get faanAllSequences => '平糊';

  @override
  String get faanAllTerminals => '清幺九';

  @override
  String get faanAllTriplets => '对对糊';

  @override
  String get faanAllQuadruplets => '十八罗汉';

  @override
  String get faanAllQuadrupletsUpgrade => '十八罗汉（升级）';

  @override
  String get faanAllConcealedTriplets => '坎坎胡';

  @override
  String get faanAllConcealedTripletsUpgrade => '坎坎胡（升级）';

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
  String get faanChickenHand => '鸡糊';

  @override
  String get faanConcealedHand => '门前清';

  @override
  String get faanDoubleKongReplacement => '杠上杠';

  @override
  String get faanFullFlush => '清一色';

  @override
  String get faanMixedFlush => '混一色';

  @override
  String get faanMixedTerminals => '混幺九';

  @override
  String get faanMoonUnderTheSea => '海底捞月';

  @override
  String get faanNineGates => '九子连环';

  @override
  String get faanNoFlowersOrSeasons => '无花';

  @override
  String get faanRobbingTheKong => '抢杠';

  @override
  String get faanRoundWind => '圈风';

  @override
  String get faanSeatWind => '门风';

  @override
  String get faanSelfPick => '自摸';

  @override
  String get faanSevenPairs => '七对';

  @override
  String get faanSmallFourWinds => '小四喜';

  @override
  String get faanSmallThreeDragons => '小三元';

  @override
  String get faanThirteenOrphans => '十三幺';

  @override
  String get faanWinByKongReplacement => '杠上开花';

  @override
  String get faanSevenFlowers => '七花';

  @override
  String get faanEightFlowers => '八仙过海';

  @override
  String get taiAllChowsWithFlowersOrHonors => '平胡（带花或字）';

  @override
  String get taiAllChows => '平胡';

  @override
  String get taiAllPungs => '碰碰胡';

  @override
  String get taiAllFlowers => '八仙过海';

  @override
  String get taiBigFourWinds => '大四喜';

  @override
  String get taiBigThreeDragons => '大三元';

  @override
  String get taiBigThreeWinds => '大三风';

  @override
  String get taiBlessingsOfEarth => '地胡';

  @override
  String get taiBlessingsOfHeaven => '天胡';

  @override
  String get taiClosedWait => '中洞';

  @override
  String get taiConcealedHand => '门清';

  @override
  String get taiConcealedKong => '暗杠';

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
  String get taiFullyConcealedHand => '门清自摸';

  @override
  String get taiFullFlush => '清一色';

  @override
  String get taiHalfFlush => '混一色';

  @override
  String get taiLastTileDraw => '海底捞月';

  @override
  String get taiLittleFourWinds => '小四喜';

  @override
  String get taiLittleThreeDragons => '小三元';

  @override
  String get taiLittleThreeWinds => '小三风';

  @override
  String get taiMeldedHand => '全求人';

  @override
  String get taiMeldedKong => '明杠';

  @override
  String get taiNoFlowerOrHonorTiles => '无花无字';

  @override
  String get taiNoFlowerTiles => '无花';

  @override
  String get taiNoHonors => '无字';

  @override
  String get taiPureStraight => '一条龙';

  @override
  String get taiRobbingTheKong => '抢杠';

  @override
  String get taiSelfDrawn => '自摸';

  @override
  String get taiSevenPairsAndAPung => '呖咕呖咕';

  @override
  String get taiSingleWait => '独听';

  @override
  String get taiValueHonor => '字牌刻';

  @override
  String get taiWinWithin5Discards => '五巡内胡牌';

  @override
  String get taiWinWithin5To10Discards => '五至十巡内胡牌';

  @override
  String get resultKyuushuKyuuhaiNineTerminalsHonors => '九种九牌';

  @override
  String get resultExhaustiveDraw => '荒牌流局';

  @override
  String get resultMultipleWins => '一炮多响';

  @override
  String get resultRobbingAKong => '抢杠';

  @override
  String get resultWinOnDiscard => '放炮和牌';

  @override
  String get resultMultipleRon => '一炮多响';

  @override
  String get resultChankan => '抢杠';

  @override
  String get resultRon => '荣和';

  @override
  String get resultSelfDraw => '自摸';

  @override
  String get resultTsumo => '自摸';

  @override
  String get limitMangan => '满贯';

  @override
  String get limitHaneman => '跳满';

  @override
  String get limitBaiman => '倍满';

  @override
  String get limitSanbaiman => '三倍满';

  @override
  String get limitKazoeYakuman => '累计役满';

  @override
  String get limitYakuman => '役满';

  @override
  String get limit13FaanCap => '13番以上封顶';

  @override
  String get tileTon => '东';

  @override
  String get tileNan => '南';

  @override
  String get tileShaa => '西';

  @override
  String get tilePei => '北';

  @override
  String get tileHaku => '白板';

  @override
  String get tileHatsu => '发财';

  @override
  String get tileChun => '红中';

  @override
  String get tilePlum => '梅';

  @override
  String get tileOrchid => '兰';

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
    return '$tile刻子';
  }

  @override
  String limitMultipleYakuman(int n) {
    return '$n倍役满';
  }

  @override
  String get bubbleRiichi => '立直';

  @override
  String get bubbleRinshanRiichi => '岭上开花';

  @override
  String get bubbleRinshanChinese => '杠上开花';

  @override
  String get doraRowLabel => '宝牌';

  @override
  String get uraRowLabel => '里宝';

  @override
  String get noCalls => '副露';

  @override
  String get autoPlaySeatTooltip => '自动打牌——TileSensor 正在替你打牌';

  @override
  String get furiten => '振听';

  @override
  String get noYaku => '无役';

  @override
  String underFaan(int n) {
    return '不足$n番';
  }

  @override
  String underTai(int n) {
    return '不足$n台';
  }

  @override
  String underFan(int n) {
    return '不足$n番';
  }

  @override
  String get noWin => '无法和牌';

  @override
  String get minimumRonOnlyTooltip => '无法荣和：任何听牌点炮都达不到最低要求，自摸仍可和牌';

  @override
  String get minimumDeadTooltip => '任何听牌即使自摸也达不到最低要求，此手牌目前无法和牌';

  @override
  String secondsShort(int n) {
    return '$n秒';
  }

  @override
  String statusWall(int n) {
    return '牌墙 $n';
  }

  @override
  String statusDealerRepeat(int n) {
    return '连庄 $n';
  }

  @override
  String statusHonba(int n) {
    return '本场 $n';
  }

  @override
  String statusRiichiSticks(int n) {
    return '立直棒 $n';
  }

  @override
  String statusRound(String kanji, String wind, int hand) {
    return '$wind$hand局';
  }

  @override
  String seatLabelYou(String name) {
    return '$name（你）';
  }

  @override
  String seatLabelBot(String name) {
    return '$name（电脑）';
  }

  @override
  String get seatBot => '电脑';

  @override
  String seatNumber(int n) {
    return '$n号座';
  }

  @override
  String tileMan(int n) {
    return '$n万';
  }

  @override
  String tilePin(int n) {
    return '$n筒';
  }

  @override
  String tileSou(int n) {
    return '$n条';
  }

  @override
  String get undoPass => '过';

  @override
  String get undoContinueDrawing => '继续摸牌';

  @override
  String undoRiichi(String tile) {
    return '立直 $tile';
  }

  @override
  String undoKan(String kan, String tile) {
    return '$kan $tile';
  }

  @override
  String get hideGuide => '隐藏指南';

  @override
  String get showGuide => '显示指南';

  @override
  String get hideGuideFooter => '点按隐藏我的指南。';

  @override
  String get showGuideFooter => '点按显示我的指南。';

  @override
  String get sortCaption => '排序';

  @override
  String get sortOff => '关';

  @override
  String get sortOffTooltip => '排序：关——按你自己的顺序。\n长按牌并拖动即可移动。点按切换为“手牌”（按牌序）。';

  @override
  String get sortHand => '手牌';

  @override
  String get sortHandTooltip =>
      '排序：手牌——按牌序排列，摸到的牌单独放在右边。\n点按切换为“手牌+摸牌”，或拖动一张牌改用自己的顺序。';

  @override
  String get sortHandDraw => '手牌+摸牌';

  @override
  String get sortHandDrawTooltip =>
      '排序：手牌+摸牌——摸到的牌直接排进手牌。\n点按固定当前顺序（关），或拖动一张牌改用自己的顺序。';

  @override
  String get discardCaption => '出牌';

  @override
  String get discardSingle => '单击';

  @override
  String get discardDouble => '双击';

  @override
  String get discardSingleTooltip => '出牌：单击——点一下牌即打出。\n点按切换为先点起牌、再点一次打出。';

  @override
  String get discardDoubleTooltip => '出牌：双击——第一次点起牌，第二次打出。\n点按切换为单击出牌。';

  @override
  String get autoWinCaption => '自动和牌';

  @override
  String get autoWinOnTooltip => '自动和牌：开——一旦可以和牌，就自动替你宣告荣和或自摸。\n点按改为自己决定。';

  @override
  String get autoWinOffTooltip => '自动和牌：关——自己按和牌按钮。\n点按改为自动宣告荣和/自摸。';

  @override
  String get autoPassCaption => '自动过';

  @override
  String get autoPassOnTooltip =>
      '自动过：开——别人打出的牌可吃、碰、杠时自动替你过。荣和仍由你决定。\n点按改为自己决定是否鸣牌。';

  @override
  String get autoPassOffTooltip => '自动过：关——每次可鸣牌都会询问你。\n点按改为自动过掉吃、碰、杠。';

  @override
  String declareRiichiDiscard(String tile) {
    return '立直并打出 $tile';
  }

  @override
  String justDiscard(String tile) {
    return '只打出 $tile';
  }

  @override
  String get flowerWin => '花胡';

  @override
  String get continueDrawing => '继续摸牌';

  @override
  String get passCaps => '过';

  @override
  String get kyuushuKyuuhai => '九种九牌';

  @override
  String get riichiAvailable => '可以立直';

  @override
  String get riichiAvailableRecommended => '可以立直——推荐';

  @override
  String get undoTooltip => '撤回本局你的上一步及之后的一切。\n再按一次继续往回退。(Ctrl/Cmd+Z)';

  @override
  String get takeBack => '撤回  ';

  @override
  String get scoreNewGame => '新对局';

  @override
  String get scoreNext => '下一页';

  @override
  String scoreContinueLocked(int n) {
    return '继续（$n）';
  }

  @override
  String get scoreContinue => '继续';

  @override
  String get autoContinuePaused => '自动继续已暂停';

  @override
  String get autoContinueHeld => '自动继续暂缓——对局已暂停';

  @override
  String autoContinueIn(int n) {
    return '$n秒后自动继续';
  }

  @override
  String get showPanel => '显示面板';

  @override
  String get seeThroughPanel => '面板透明';

  @override
  String get flowersSeasons => '花牌／季节牌';

  @override
  String indicatorRowOne(String label) {
    return '$label指示牌：';
  }

  @override
  String indicatorRowMany(String label) {
    return '$label指示牌：';
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
    return '$name  $n番';
  }

  @override
  String yakuLineHan(String name, int n) {
    return '$name  $n番';
  }

  @override
  String yakuLineYakuman(String name) {
    return '$name  役满';
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
    return '$faan番——$points筹码$limit';
  }

  @override
  String scoreLimitOnly(String limit, int points) {
    return '$limit——$points点';
  }

  @override
  String scoreHanFu(int han, int fu, String limit, int points) {
    return '$han番$fu符$limit——$points点';
  }

  @override
  String limitSuffix(String limit) {
    return '（$limit）';
  }

  @override
  String get wallExhaustedNoPayments => '荒牌——不结算';

  @override
  String get allNoten => '全员未听牌';

  @override
  String get tenpaiRevealed => '公开听牌者的手牌';

  @override
  String get waits => '听';

  @override
  String get backToMenu => '返回菜单';

  @override
  String get cantReachServer => '无法连接联机服务器——正在重试…';

  @override
  String get noGuideOnline => '联机对战没有 TileSense 指南——想用指南请玩单人游戏。';

  @override
  String get yourName => '你的名字';

  @override
  String get yourNameHelper => '默认使用角色名——可编辑为你自己的名字';

  @override
  String get createARoom => '创建房间';

  @override
  String get createRoomButton => '创建房间';

  @override
  String get joinARoom => '加入房间';

  @override
  String get roomCode => '房间代码';

  @override
  String get join => '加入';

  @override
  String get chooseYourCharacter => '选择你的角色';

  @override
  String get pace => '节奏';

  @override
  String get paceFast => '快';

  @override
  String get paceStandard => '标准';

  @override
  String get paceRelaxed => '悠闲';

  @override
  String paceCaption(int turn, int call) {
    return '每回合 $turn 秒 · 鸣牌 $call 秒';
  }

  @override
  String get minimumFaanToWin => '和牌最少番数';

  @override
  String get minimumTaiToWin => '和牌最少台数';

  @override
  String get roomCodeShare => '房间代码——分享给其他玩家';

  @override
  String get copyCode => '复制代码';

  @override
  String get roomCodeCopied => '已复制房间代码';

  @override
  String roomFaanMin(int n) {
    return '最低$n番';
  }

  @override
  String roomTaiMin(int n) {
    return '最低$n台';
  }

  @override
  String get roomFullGame => '半庄';

  @override
  String get roomEastOnly => '东风战';

  @override
  String roomClocks(int turn, int call) {
    return '回合 $turn 秒 · 鸣牌 $call 秒';
  }

  @override
  String get startGameBots => '开始对局——空位由电脑补上';

  @override
  String get waitingForHost => '等待房主开始…';

  @override
  String get leaveRoomButton => '离开房间';

  @override
  String get emptySeat => '空位';

  @override
  String get host => '房主';

  @override
  String get rejoiningGame => '正在重新加入对局…';

  @override
  String gameStillGoing(String code) {
    return '房间 $code 的对局仍在进行。';
  }

  @override
  String get rejoin => '重新加入';

  @override
  String get leaveGameTitle => '离开本局？';

  @override
  String get leaveGameBody => '你回来之前由电脑替你打——对局进行期间可在主菜单重新加入。';

  @override
  String get noPauseOnlineHint => '在线对局无法暂停。想要每回合更多时间，请选择“悠闲”。';

  @override
  String get noPauseOnlineTooltip =>
      '在线对局无法暂停。如需离开，超时或断线后由电脑代打你的座位，你可从主菜单重新加入。';

  @override
  String get smallWindowHint => '窗口较小，工具栏已收进手牌旁的菜单按钮。放大窗口即可恢复完整工具栏。';

  @override
  String get smallWindowHintOnline =>
      '窗口较小，声音、语言和你的 ID 已收进手牌旁的菜单按钮。放大窗口即可恢复完整工具栏。';

  @override
  String get stay => '留下';

  @override
  String get leave => '离开';

  @override
  String get leaveRoom => '离开房间';

  @override
  String get clientId => '客户端 ID';

  @override
  String nowBotControlled(String name) {
    return '$name 已改由电脑操控';
  }

  @override
  String get noGuideOnlineTooltip =>
      'TileSensor 不参加联机对战，这样谁都不会有别人没有的指南。\n玩单人游戏就能带上我！';

  @override
  String roomLabel(String code) {
    return '房间 $code';
  }

  @override
  String get connectionLost => '连接已断开——正在重新连接…';

  @override
  String get backToStart => '返回开始画面';

  @override
  String get errorNotSeated => '你不在这个房间的座位上。';

  @override
  String get errorSeatBotControlled => '这个座位由电脑操控。';

  @override
  String get errorMissingGuestId => '出了点问题，请重试。';

  @override
  String get errorServerFull => '服务器已满，请稍后再试。';

  @override
  String get errorMissingRoom => '请输入房间代码。';

  @override
  String get errorRoomNotFound => '找不到该房间。';

  @override
  String get errorRoomStarted => '该房间已经开始。';

  @override
  String get errorRoomFull => '该房间已满。';

  @override
  String get errorNotHost => '只有房主可以开始对局。';

  @override
  String get errorRoomGone => '该房间已不存在。';

  @override
  String get errorUnknownType => '出了点问题，请重试。';

  @override
  String get errorMalformed => '出了点问题，请重试。';

  @override
  String get errorBadRequest => '出了点问题，请重试。';

  @override
  String get errorIllegalAction => '现在不能这样操作。';

  @override
  String get errorNoActionExpected => '还没轮到你。';

  @override
  String get errorGameEnded => '该对局已结束';

  @override
  String get guideTipTitle => '指南\n';

  @override
  String get guideGreen => '绿色牌';

  @override
  String get guideGreenBody => '建议打出的牌';

  @override
  String get guideYellow => '黄色牌';

  @override
  String get guideYellowBody => '刚摸到的牌';

  @override
  String get guidePause => '暂停对局';

  @override
  String get guideHover => '\n将鼠标悬停在标题或设置上可查看说明。';

  @override
  String get tipAutoTitle => '自动打牌\n';

  @override
  String get tipAutoBody => '选择自动打牌采用的建议，以及下方候选项的排序依据。\n';

  @override
  String get tipAutoChoices =>
      '• TileSense（默认）：由指南打牌，首行显示指南的建议。\n• Mortal：由 Mortal 打牌，首行显示其建议。Mortal 无法回答时由指南决定。';

  @override
  String get tipEvTitle => 'TileSense 期望值\n';

  @override
  String get tipFinishTitle => '和牌概率';

  @override
  String get tipFinishBody => '本局结束前和牌的概率。剩余有效牌和摸牌次数越多，概率越高。\n';

  @override
  String get tipFinishMore => '悬停查看进张说明；点击 EV (HMR) 数值查看图表';

  @override
  String get tipPayoutTitle => '和牌收益';

  @override
  String get tipPayoutTw => '每位付款者支付相同点数，再加连庄奖励。听牌时为准确值，未听牌时按所示牌型估算。\n';

  @override
  String get tipPayoutHk => '将番数换算为筹码。听牌时为准确值，未听牌时按所示牌型估算。\n';

  @override
  String get tipPayoutRiichi => '和牌得点，加上本场和立直棒。听牌时为准确值，未听牌时为估算值。\n';

  @override
  String get tipPayoutMore => '点击 EV (HMR) 数值查看计算过程';

  @override
  String get tipCutTitle => '打牌风险';

  @override
  String get tipCutChinese => '对手有三组以上明露面子时的预期损失。没有绝对安全的牌。\n';

  @override
  String get tipCutRiichi => '立直棒的成本（未和牌则损失）。面对立直时，还计入此牌的放铳概率和继续进攻所需的巡数。\n';

  @override
  String get tipCutMore => '悬停查看风险和安全度';

  @override
  String get tipFocusTitle => '侧重点';

  @override
  String get tipFocusBody => '速度优先会牺牲部分收益以提高和牌概率。平衡模式不作偏向调整。\n';

  @override
  String get tipFocusMore => '悬停查看侧重点';

  @override
  String get tipFocusPlacementMore => '悬停查看侧重点、策略和顺位的其余说明';

  @override
  String get tipEvHigher => '\n越高越好。风险高、收益低的打牌可能为负值。';

  @override
  String get tipOrdinaryWide => '比通常更宽';

  @override
  String get tipOrdinaryWideBody => '推进更快，但估算速度不超过普通手牌';

  @override
  String get tipOrdinaryTitle => '普通手牌的平均值';

  @override
  String get tipShantenLabel => '向听数';

  @override
  String get tipUkeireLabel => '进张';

  @override
  String get tipAwayLabel => '距听牌';

  @override
  String get tipAcceptsLabel => '有效进张';

  @override
  String get tipOrdinaryNote =>
      '\n这是平均数，不是中位数：通过只追求牌效率、不防守也不鸣牌的单人模拟，测得各向听数下最佳打牌的平均进张。';

  @override
  String get tipSafetyTitle => '安全度\n';

  @override
  String get tipSafetyChinese => '面对有明露面子的对手时，打出此牌的风险。越高越安全。\n';

  @override
  String get tipSafetyRiichi => '面对立直时打出此牌的安全度。0 为危险，15 为现物。\n';

  @override
  String get tipNeverCertain => '没有绝对安全';

  @override
  String get tipNeverCertainBody => '没有振听规则，对手打过的牌仍可能让其和牌';

  @override
  String get tipRatedWhen => '评估条件';

  @override
  String get tipGenbutsu => '现物';

  @override
  String get tipGenbutsuBody => '对手打过的牌，或其立直后放过的牌，不会让其荣和';

  @override
  String get tipSuji => '筋';

  @override
  String get tipSujiBody => '与对手舍牌相差三的牌相对安全';

  @override
  String get tipRatedRiichi => '有人立直时才评估，否则显示 —';

  @override
  String get tipDealInTitle => '打牌放铳概率';

  @override
  String get tipRating => '评级';

  @override
  String get tipTile => '牌';

  @override
  String get tipDealsIn => '放铳率';

  @override
  String get tipRating15 => '现物 — 对手已打过的牌';

  @override
  String get tipRating13 => '字牌，剩余1张';

  @override
  String get tipRating12 => '双筋';

  @override
  String get tipRating11 => '筋幺九牌';

  @override
  String get tipRating9 => '字牌，剩余2张';

  @override
  String get tipRating8 => '无机会牌';

  @override
  String get tipRating7 => '半筋';

  @override
  String get tipRating6 => '筋2/3/7/8，或剩余3张的字牌';

  @override
  String get tipRating3 => '无筋2/3/7/8';

  @override
  String get tipRating2 => '无筋中张牌';

  @override
  String get tipHkRating14 => '字牌，未见0张';

  @override
  String get tipHkRating11 => '字牌，未见1张';

  @override
  String get tipHkRating6 => '字牌，未见2张以上';

  @override
  String get tipHkRating5 => '幺九牌';

  @override
  String get tipHkRating3 => '数牌';

  @override
  String get tipRiskTitle => '风险\n';

  @override
  String get tipDealInChance => '放铳概率';

  @override
  String get tipDealInChanceBody => '根据此牌的安全度计算';

  @override
  String get tipDealInCost => '放铳损失';

  @override
  String get tipStyleWeight => '风格权重';

  @override
  String get tipLaterTurns => '后续巡数';

  @override
  String get tipHowLong => '持续时间';

  @override
  String get tipChineseHorizon => '按本局预计剩余时间计算；无风险的打牌不产生额外成本';

  @override
  String get tipFormula => '公式';

  @override
  String get tipDetailTitle => '详情\n';

  @override
  String get tipDetailBody => '说明此牌获得该安全度评级的原因。\n';

  @override
  String get tipShows => '显示内容';

  @override
  String get tipShowsBody => '现物、筋、字牌剩余张数等';

  @override
  String get tipEmpty => '为空时';

  @override
  String get tipEmptyBody => '没有防守对象，因此没有说明';

  @override
  String get tipPlacementTitle => '顺位\n';

  @override
  String get tipPlacementBody => '此打法如何改变你最终领先其他三家的概率。\n';

  @override
  String get tipUses => '依据';

  @override
  String get tipUsesBody => '当前各家点数和剩余局数';

  @override
  String get tipNotPoints => '不是点数';

  @override
  String get tipNotPointsBody => '为便于阅读放大1,000倍；仅与其他打法的相对排序有意义';

  @override
  String get tipHeuristic => '启发式估算';

  @override
  String get tipHeuristicBody => '不是模拟结果';

  @override
  String get tipWorthTitle => '8,000点的价值';

  @override
  String get tipSituation => '局势';

  @override
  String get tipHandsLeft => '剩余局数';

  @override
  String get tipEven => '点数接近';

  @override
  String get tipLead => '大幅领先';

  @override
  String get tipBehind => '大幅落后';

  @override
  String get tipEvenLast => '点数接近，最后一局';

  @override
  String get tipLeadLast => '大幅领先，最后一局';

  @override
  String get tipPlacementNote => '\n点数在局势接近和对局末期时最重要，在大幅领先时影响最小。\n';

  @override
  String get tipNoWin => '此打法尚无可计分的和牌形。\n';

  @override
  String get tipRiskRow => '此牌风险';

  @override
  String get tipFinishRow => '和牌概率';

  @override
  String get tipPayoutRow => '和牌收益';

  @override
  String get tipSticksRow => '本场与立直棒';

  @override
  String get tipAverageRow => '平均收益';

  @override
  String get tipLockRow => '减去立直锁定成本';

  @override
  String get tipDealInRow => '减去放铳风险';

  @override
  String get tipCommitRow => '减去后续巡数成本';

  @override
  String get tipHmrBody => '仅用于比较的数值，不会影响建议。\n';

  @override
  String get tipHmrExcludes => '\n不计本场、立直棒、风险成本或风格与侧重点调整。\n';

  @override
  String get tipHmrSource => '\n对应以下工具的「E.V.」统计：';

  @override
  String get tipHmrSourceBody => '，这是一款仅限自摸的单人练习工具：总得点 ÷ 对局数，即和牌率 × 平均和牌得点。';

  @override
  String get tipYakuBody =>
      '每条柱形表示：此打法和牌时包含该役的比例。一次和牌通常包含多个役，因此总和不为100%。100%表示每次和牌都有该役；计划立直时，立直为100%。\n\n乘以和牌概率，即为总体出现概率。\n\n宝牌不是役，因此另列为平均额外番数。\n\n≈表示估算：未听牌时，指南假定持续选择进张最宽的打法，并对最可能到达的听牌形计分。它不会主动规划役牌或染手等需要刻意追求的役，因此这些役可能偏低。距离听牌超过三张时暂不显示。';

  @override
  String get tipMortalBody =>
      'Mortal 是开源深度学习麻将 AI，只使用你所在座位可见的信息。★标出其建议打牌（★R表示先立直）；数字表示其他候选项的优先顺序。Mortal 的建议用红框标出，指南的建议填充绿色；绿色加红框表示两者一致。\n\n';

  @override
  String get tipMortalAuto =>
      '自动打牌选择 Mortal 时，会按其建议行动，列表也按其偏好排序。选择 TileSense（默认）时，按指南排序，Mortal 仅供参考。绿色牌始终是指南的建议。Mortal 无法回答时由指南决定。\n\n';

  @override
  String get tipMortalSource =>
      '适用于单人立直麻将。Mortal 及其模型权重采用 AGPL-3.0：源码 github.com/Equim-chan/Mortal；运行服务 github.com/eric-r-xu/TileSense (mortal_sidecar)。';

  @override
  String get tipYakuTitle => '役\n';

  @override
  String tipEvAverage(String unit) {
    return '此打牌对你的平均价值，以$unit计（EV＝期望值）。\n';
  }

  @override
  String tipShantenBody(String ready) {
    return '距离听牌所需的张数（0表示$ready）。';
  }

  @override
  String tipUkeireBody(String effect) {
    return '能$effect的剩余有效牌，即有帮助的摸牌数量。\n';
  }

  @override
  String tipThreatSets(String count) {
    return '对手有$count组以上明露面子，否则显示 —';
  }

  @override
  String tipChineseCost(String cost, String unit) {
    return '\n放铳损失按$cost$unit计算。';
  }

  @override
  String tipRiichiCost(String cost, String dealerCost) {
    return '$cost点（对庄家为$dealerCost点），每本场另加300点';
  }

  @override
  String tipRiichiCostNote(String cost, String dealerCost) {
    return '\n放铳损失为$cost点（对庄家为$dealerCost点），每本场另加300点。';
  }

  @override
  String tipRiskBody(String unit) {
    return '因打出此牌的风险而从期望值中扣除的$unit。\n';
  }

  @override
  String tipStyleWeights(String weights, String styles) {
    return '$styles对应×$weights';
  }

  @override
  String tipCommitPercent(String percent) {
    return '此打牌每需继续一巡，再加计成本的$percent%';
  }

  @override
  String tipRiichiHorizon(String turns) {
    return '按立直持续时间计算，约为你打牌$turns次；打现物不产生额外成本';
  }

  @override
  String tipThisCut(String tile) {
    return '\n此打牌 — $tile\n';
  }

  @override
  String tipFocusTilt(String focus) {
    return '$focus调整';
  }

  @override
  String tipRankOrder(String name, String direction) {
    return '$name（$direction优先）';
  }

  @override
  String tipRankDirection(String direction) {
    return '\n\n$direction越好，标题箭头表示该方向。';
  }

  @override
  String tipRankBody(String first, String second, String third) {
    return '打牌先按$first，再按$second，最后按$third排序；显示数值相同则视为相等。首选牌显示绿色，三项均与首选相同的牌也显示绿色。';
  }

  @override
  String get tipReady => '听牌';

  @override
  String get tipTenpai => '听牌';

  @override
  String get tipCloser => '更接近听牌';

  @override
  String get tipReduce => '减少向听数';

  @override
  String get tipHigher => '越高';

  @override
  String get tipLower => '越低';

  @override
  String get tipHigherFirst => '较高';

  @override
  String get tipLowerFirst => '较低';

  @override
  String get tipPlacementLabel => '顺位';

  @override
  String get tipPointsUnit => '点';

  @override
  String get tipChipsUnit => '筹码';

  @override
  String get tipBalanced => '平衡';

  @override
  String get tipSpeed => '速度';

  @override
  String get tipAggressive => '进攻';

  @override
  String get tipPoints => '点数';

  @override
  String get tipDefensive => '防守';

  @override
  String get mathChance => '概率';

  @override
  String get mathFinish => '和牌';

  @override
  String get mathPayout => '收益';

  @override
  String get mathWin => '和牌';

  @override
  String get mathRisk => '风险';

  @override
  String get mathCut => '打牌';

  @override
  String get mathDealIn => '放铳';

  @override
  String get mathCost => '损失';

  @override
  String get mathWeight => '权重';

  @override
  String get mathStyle => '风格';

  @override
  String get mathCharge => '成本';

  @override
  String get mathLaterTurns => '后续巡数';

  @override
  String get mathWorth => '价值';

  @override
  String get mathGain => '增减';

  @override
  String get mathScore => '点数';

  @override
  String get mathOthers => '其他三家';

  @override
  String get mathTheirs => '对手';

  @override
  String get mathSpread => '分散尺度';

  @override
  String get mathHandsLeft => '剩余局数';

  @override
  String get mathLogistic => '逻辑函数';

  @override
  String mascotIntro(String mascot, String app) {
    return '我是$mascot，一半草原犬鼠，一半美西螈。\n我会帮你选择最佳打牌和鸣牌。\n开启自动打牌，我就替你打。\n打错了？撤回再试一次。\n一起玩，提升你的$app！';
  }

  @override
  String get rulesetMcr => '国标麻将 (MCR)';

  @override
  String get rulesetSubtitleMcr => '番、花牌、最低8番';

  @override
  String get mcrFullGame => '全场 · 16局';

  @override
  String get mcrPractice => '东风练习 · 4局';

  @override
  String mcrScoreTotal(int fan, int flowers, int gain) {
    return '$fan番 + 花牌$flowers · +$gain分';
  }

  @override
  String yakuLineMcr(String name, int n) {
    return '$name  $n番';
  }

  @override
  String get tipPayoutMcr =>
      '番数加花牌（F）：点炮者付 F＋8，其他两家各付 8；自摸则每家付 F＋8。听牌时为准确值，且不计花牌达到8番的听牌才能和牌；之前为估计值。\n';

  @override
  String get rulesetSichuan => '四川麻将';

  @override
  String get rulesetSubtitleSichuan => '血战到底、定缺、不能吃';

  @override
  String get sichuanFullGame => '全场 · 8局';

  @override
  String get sichuanPractice => '练习 · 4局';

  @override
  String get voidSuitTitle => '选择定缺花色';

  @override
  String get voidSuitHint => '必须先打完这一门的牌才能打其他牌，手中仍有这一门的牌时不能和牌。';

  @override
  String get voidSuitWaiting => '等待其他玩家选择…';

  @override
  String get suitMan => '万';

  @override
  String get suitPin => '筒';

  @override
  String get suitSou => '条';

  @override
  String get voidSuitSuggested => '推荐';

  @override
  String voidSuitBadge(String suit) {
    return '缺：$suit';
  }

  @override
  String get voidSuitUnknown => '缺：?';

  @override
  String get voidFirstNotice => '请先打出定缺的牌';

  @override
  String get huOutBadge => '胡';

  @override
  String get sichuanPayHu => '胡牌';

  @override
  String get sichuanPayKong => '杠';

  @override
  String get sichuanPayReady => '查叫';

  @override
  String get sichuanPayPenalty => '定缺罚分';

  @override
  String get resultWallEnds => '牌墙结束';

  @override
  String get resultThreeHu => '三家胡牌';

  @override
  String get scRoot => '根';

  @override
  String get scAllPungs => '对对胡';

  @override
  String get scFullFlush => '清一色';

  @override
  String get scSevenPairs => '七对';

  @override
  String get scGoldenSingleWait => '金钩钓';

  @override
  String get scWinAfterKong => '杠上开花';

  @override
  String get scRobbingTheKong => '抢杠胡';

  @override
  String get scShootAfterKong => '杠上炮';

  @override
  String get scUnderTheSea => '海底';

  @override
  String statusHandNumber(int n) {
    return '第$n局';
  }

  @override
  String sichuanScoreTotal(int fan, int value) {
    return '$fan番 · 牌值$value分';
  }

  @override
  String get learnToPlay => '新手教学';

  @override
  String get learnNewLink => '第一次玩麻将？看看怎么玩';

  @override
  String learnStepOf(int current, int total) {
    return '$current / $total';
  }

  @override
  String get learnNext => '下一步';

  @override
  String get learnSkip => '跳过';

  @override
  String get learnDone => '开始游戏';

  @override
  String get learnGoalTitle => '目标';

  @override
  String get learnGoalBody =>
      '凑成14张牌的手牌：四组牌加一对将。每回合摸一张牌、打出一张牌，一步步凑成这个牌型。最先凑成的人赢下这一局。';

  @override
  String get learnTilesTitle => '牌的种类';

  @override
  String get learnTilesBody =>
      '有三种花色，数字1到9（万子、筒子、条子），另有四种风牌和三种箭牌。部分规则（例如香港麻将）还加入花牌：花牌带来奖励番数，并从牌墙补牌。';

  @override
  String get learnSetsTitle => '牌组与吃碰杠';

  @override
  String get learnSetsBody =>
      '一组牌可以是同花色的三张顺子（上），三张相同的牌（碰），或四张相同的牌（杠）。你可以要别人打出的牌来完成一组，但“上”只能要上家（左手边）的牌。要来的牌组要亮在桌面上。';

  @override
  String get learnWinTitle => '胡牌';

  @override
  String get learnWinBodyHongKong =>
      '凑齐四组牌和一对将，无论是自己摸到最后一张，还是要别人打出的牌，就胡牌了。默认最低0番，所以只要牌型完整，再简单的牌也能胡。牌桌上的提示会告诉你离胡牌还差几张。';

  @override
  String learnWinBodyOther(String rules) {
    return '凑齐四组牌和一对将，并且满足$rules自己的要求，就能胡牌。牌桌上的提示会告诉你离胡牌还差几张。';
  }

  @override
  String get guideViewSimple => '简单';

  @override
  String get guideViewFull => '完整';

  @override
  String get guideViewToFullTip => '简单提示。点击查看完整表格（向听、期望值、安全度）。';

  @override
  String get guideViewToSimpleTip => '完整提示。点击切换为简单视图。';

  @override
  String get guideStatusComplete => '你的牌已经凑齐了！';

  @override
  String get guideBestDiscard => '最佳打牌';

  @override
  String get guideOtherChoices => '其他选择';

  @override
  String get guideOutlookWins => '凑齐你的手牌！';

  @override
  String guideOutlookWaiting(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n张',
    );
    return '打出后听$_temp0牌就能胡。';
  }

  @override
  String guideOutlookOnTrack(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n张',
    );
    return '保持进度，还有$_temp0有用的牌。';
  }

  @override
  String get guideOutlookFurther => '会让你离胡牌更远。';

  @override
  String get guideCallTake => '提示会要这张牌。';

  @override
  String get guideCallPass => '提示会放过这张牌。';

  @override
  String handPromptWin(String tile, String call) {
    return '你可以用$tile胡牌！点击“$call”。';
  }

  @override
  String handPromptTsumo(String call) {
    return '你的牌已凑齐！点击“$call”。';
  }

  @override
  String handPromptCall(String tile, String calls) {
    return '你可以$calls$tile，也可以放过。';
  }

  @override
  String get handPromptDiscard => '轮到你了：点击一张牌打出。';

  @override
  String guideAway(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n张',
    );
    return '离胡牌还差$_temp0';
  }

  @override
  String guideWinningTiles(int n) {
    return '能胡的牌 · 还剩$n张';
  }

  @override
  String get guideOutlookOnTrackFar => '保持进度。';

  @override
  String get glossaryTitle => '术语表';

  @override
  String get glossarySearchHint => '搜索术语';

  @override
  String get glossaryNoMatch => '没有匹配的术语。';

  @override
  String get glossaryUnitHan => '翻';

  @override
  String get glossaryUnitFaan => '番';

  @override
  String get glossaryUnitTai => '台';

  @override
  String get glossaryUnitFan => '番';

  @override
  String get glossaryTermSet => '牌组';

  @override
  String get glossaryDefSet => '凑在一起的三张牌：同花色的三张顺子，或三张相同的牌。四张相同的牌也算，叫做杠。';

  @override
  String get glossaryTermPair => '将（对子）';

  @override
  String get glossaryDefPair => '两张相同的牌。胡牌的牌型是四组牌加一对将。';

  @override
  String get glossaryDefChi => '要别人打出的牌，凑成同花色的三张顺子。只能要上家（左手边）的牌，凑好的牌组要亮在桌面上。';

  @override
  String get glossaryDefPon => '要一张与你手中两张相同的牌，可以要任何人打出的，凑成三张相同的牌。凑好的牌组要亮在桌面上。';

  @override
  String get glossaryDefKan => '四张相同的牌。杠完之后，要从牌墙末端补一张牌。';

  @override
  String get glossaryTermDiscard => '打牌';

  @override
  String get glossaryDefDiscard => '每回合结束时打出的那张牌，亮在你面前。其他玩家有时可以要这张牌。';

  @override
  String get glossaryDefTsumo => '胡的是自己摸到的牌。';

  @override
  String get glossaryDefRon => '胡的是别人打出的牌。';

  @override
  String get glossaryTermDealer => '庄家';

  @override
  String get glossaryDefDealer => '坐在东位、最先出牌的玩家。胡牌通常能让庄家继续坐庄。';

  @override
  String get glossaryTermWinds => '风牌';

  @override
  String get glossaryDefWinds => '东、南、西、北四种牌，也用来称呼座位和圈风。自己座位的风或圈风的牌组可能有加分。';

  @override
  String get glossaryTermDragons => '箭牌';

  @override
  String get glossaryDefDragons => '白板、发财、红中三种牌。任何箭牌的牌组都有加分。';

  @override
  String get glossaryTermFlowers => '花牌';

  @override
  String get glossaryDefFlowers => '奖励牌。摸到后亮出来，再从牌墙补一张牌。每张花牌都可能为胡牌加分。';

  @override
  String get glossaryTermVoid => '缺门';

  @override
  String get glossaryDefVoid => '开局时放弃三种花色中的一种。只要你手里还有这门的牌，就必须先打出它们。';

  @override
  String get glossaryDefScore => '胡牌所得的价值。越多，牌越值钱。有些牌桌规定了胡牌所需的最低值。';

  @override
  String get glossaryTermRiichi => '立直';

  @override
  String get glossaryDefRiichi =>
      '牌是门清、再差一张就胡时，押上1,000点宣告。之后手牌锁定，只能打出摸到的牌。立直会带来额外得分。';

  @override
  String get glossaryTermDora => '宝牌';

  @override
  String get glossaryDefDora => '由桌上的宝牌指示牌决定的奖励牌。胡牌时手里每有一张，加一番（翻）。';

  @override
  String get glossaryTermFuriten => '振听';

  @override
  String get glossaryDefFuriten => '如果能胡的牌在自己的打牌里，就不能胡别人打出的牌。自摸仍然可以胡。';

  @override
  String get glossaryTermReady => '听牌';

  @override
  String get glossaryDefReady => '再差一张就能胡的牌。提示会告诉你哪些牌能胡。';

  @override
  String get glossaryTermAway => '还差几张';

  @override
  String get glossaryDefAway =>
      '手牌还需要几张才能胡牌。还差一张就是听牌。提示的进度条和“Away”或“Shanten”一列会显示。';

  @override
  String get glossaryTermHelpful => '有用的牌';

  @override
  String get glossaryDefHelpful => '摸到后能让手牌更接近胡牌的牌。提示会统计还有多少张没出现。';

  @override
  String get learnTile => '学习／训练';

  @override
  String get moreTile => '更多';

  @override
  String get practiceTitle => '练习题';

  @override
  String get practiceLink => '练习题';

  @override
  String practiceProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get practiceAskWin => '这手牌再差一张就能胡。哪张牌能凑齐？';

  @override
  String get practiceAskDiscard => '你摸了一张牌。打出哪张，能让手牌再差一张就胡？';

  @override
  String get practiceAskClaim => '对这张打出的牌，你能做什么？';

  @override
  String practiceDiscardedBy(String seat) {
    return '打牌的人：$seat';
  }

  @override
  String get practiceYourHand => '你的手牌';

  @override
  String get practiceCorrect => '答对了！';

  @override
  String get practiceWrong => '不太对。';

  @override
  String get practiceNext => '下一题';

  @override
  String get practiceSeeResults => '查看结果';

  @override
  String practiceResult(int score, int total) {
    return '共$total题，你答对了$score题。';
  }

  @override
  String get practiceAgain => '再来一次';

  @override
  String get practiceOptionPass => '放过';

  @override
  String get practiceWhyW1 => '三组牌和将牌55s已经凑好。1p和3p中间需要一张2p，才能凑成1-2-3顺子。';

  @override
  String get practiceWhyW2 => '1p和2p只能凑成1-2-3，所以只有3p能胡。这样的边张听牌，只有一种牌能胡。';

  @override
  String get practiceWhyW3 => '四组牌已经凑好。单独的5s还要再来一张5s凑成将，所以只有5s能胡。';

  @override
  String get practiceWhyD1 =>
      '三组牌、将牌66p和3p-4p都能配合。单独的9s和别的牌没有联系，打出它，你就再差一张就胡，听2p或5p。';

  @override
  String get practiceWhyD2 => '东和别的牌没有联系。打出它，1s-2s就听3s。';

  @override
  String get practiceWhyD3 => '单独的西和别的牌没有联系。打出它，7s-8s就听6s或9s。';

  @override
  String practiceWhyC1(String call) {
    return '你有两张5p，从任何人那里再要一张，就凑成三张相同的牌。这叫$call。';
  }

  @override
  String practiceWhyC2(String call) {
    return '你左手边的玩家打出了5p，正好补在你的4p和6p中间凑成顺子。这叫$call。';
  }

  @override
  String get practiceWhyC3 => '顺子只能要左手边玩家的牌。这张5p是别人打的，不能用来凑顺子，所以放过。';

  @override
  String get practiceWhyC4 => '你手里没有能和东配对的牌，也凑不成顺子，所以没什么可要的。放过。';

  @override
  String get practiceChoices => '选择一张牌';

  @override
  String get practiceLegend => 'm＝万子，p＝筒子，s＝条子';

  @override
  String nudgeFullGuide(int n) {
    return '你已经胡了$n手牌。想看更多细节吗？完整提示会显示每条建议背后的数字。';
  }

  @override
  String get nudgeFullGuideAction => '显示完整提示';

  @override
  String nudgeMinimum(int n) {
    return '你已经胡了$n手牌。试试最低1番吧：现在手牌需要多一点价值才能胡。';
  }

  @override
  String get nudgeMinimumAction => '改用最低1番';

  @override
  String nudgeRuleset(int n, String rules) {
    return '你已经胡了$n手牌。想来点新挑战吗？试试$rules。';
  }

  @override
  String nudgeRulesetAction(String rules) {
    return '切换到$rules';
  }

  @override
  String get nudgeNotNow => '暂时不要';

  @override
  String get nudgeStop => '不再提示';

  @override
  String get quizTitle => 'TileSensor会怎么打？';

  @override
  String get quizAskDiscard => '轮到你了，你刚摸了一张牌。你怎么做？';

  @override
  String quizAskCall(String seat) {
    return '$seat刚打出一张牌。你怎么做？';
  }

  @override
  String get quizDiscard => '打牌';

  @override
  String get quizRiichi => '立直';

  @override
  String get quizYourHand => '你的手牌';

  @override
  String get quizChoose => '请选择一项';

  @override
  String get quizYouPicked => '你的选择';

  @override
  String get quizBestMove => '最佳选择';

  @override
  String get quizAgree => 'TileSense与Mortal一致';

  @override
  String get quizTileSenseSays => 'TileSense为何推荐';

  @override
  String get quizMortalSays => 'Mortal的评价';

  @override
  String get quizShanten => '向听数';

  @override
  String get quizUkeire => '进张';

  @override
  String get quizEv => '期望值';

  @override
  String get quizRisk => '风险';

  @override
  String quizMortalRank(int rank, int total) {
    return 'Mortal把你的选择排在$total个选项中的第$rank位。';
  }

  @override
  String get quizMortalPicked => 'Mortal也选了这一手。';

  @override
  String get quizMortalRankFirst => '这是Mortal的首选。';

  @override
  String get quizMortalKan => 'Mortal在这里也会杠。';

  @override
  String get quizMortalNoKan => 'Mortal在这里不会杠。';

  @override
  String get quizMortalNote => 'Mortal不会解释原因，这是它的排名。';

  @override
  String get quizSeat => '座位';

  @override
  String get quizDora => '宝牌指示牌';

  @override
  String quizProgress(int number, int total) {
    return '第$number题，共$total题';
  }

  @override
  String get quizNext => '下一题';

  @override
  String get quizSeeResults => '查看今天的结果';

  @override
  String get quizResultsTitle => '今天的题目已完成';

  @override
  String quizResultsScore(int right, int total) {
    return '$total题中答对了$right题。';
  }

  @override
  String get quizDone => '明天再来挑战新题目。';

  @override
  String get quizLoadFailed => '无法载入今天的题目。';

  @override
  String get quizLink => '每日一题';

  @override
  String get quizCardToday => '今天的题目已准备好';

  @override
  String get quizCardDone => '今天已完成，明天再来！';

  @override
  String quizStreak(int days) {
    return '连续$days天';
  }

  @override
  String get loadingQuiz => '正在载入每日一题…';

  @override
  String get quizDama => '默听';

  @override
  String get quizAskRiichi => '这样打牌就听牌了。你要立直，还是默听？';

  @override
  String get quizMortalRiichi => 'Mortal在这里会立直。';

  @override
  String get quizMortalDama => 'Mortal在这里会默听。';

  @override
  String get quizSituation => '局面';

  @override
  String quizRoundLine(String wind, int hand, int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: '还剩$left局',
      one: '最后一局',
    );
    return '$wind$hand局：$_temp0。';
  }

  @override
  String get quizStageEarly => '本局前期';

  @override
  String get quizStageMiddle => '本局中期';

  @override
  String get quizStageLate => '本局后期';

  @override
  String quizTimingLine(String stage, int wall) {
    return '$stage：牌山还剩$wall张。';
  }

  @override
  String get quizDealerYes => '你是庄家：和牌点数是闲家的1.5倍，并且可以连庄。';

  @override
  String get quizDealerNo => '你不是庄家。';

  @override
  String quizPlaceEven(String points) {
    return '四家都是$points点，名次不受影响。';
  }

  @override
  String quizPlaceLead(int rank, String lead) {
    return '名次：四家中第$rank，领先下一家$lead点。';
  }

  @override
  String quizPlaceBehind(int rank, String gap) {
    return '名次：四家中第$rank，落后第一名$gap点。';
  }

  @override
  String quizThreat(String seat, int turns) {
    return '$seat正在立直（$turns巡前宣告）。';
  }

  @override
  String get quizNoThreat => '其他人都没有立直。';

  @override
  String get quizFocusPlacement => '最后几局：TileSense会考虑每个选择对最终名次的影响，而不只看点数。';

  @override
  String get quizFocusPoints => '还有很多局：TileSense以点数为重。';

  @override
  String get rulesetSanma => '三人麻将';

  @override
  String get rulesetSanmaLong => '三麻（三人日本麻将）';

  @override
  String get rulesetSubtitleSanma => '三人立直麻将：不能吃、拔北、去掉二至八万';

  @override
  String get sanmaTooltip =>
      '三麻是三人玩的日本立直麻将：三名玩家，108张牌（去掉二至八万），不能吃，北风牌可以拔出当作宝牌。';

  @override
  String rulesWeb(String rules) {
    return '$rules规则（网页，英文）';
  }

  @override
  String get kitaCaps => '拔北';

  @override
  String get bubbleKita => '拔北';

  @override
  String get undoKita => '拔北';

  @override
  String get yakuKita => '拔北宝牌';

  @override
  String get emptySeatSanma => '空位：三麻只有三名玩家';

  @override
  String hanchanOnTooltipSanma(String caveat) {
    return '半庄——三人麻将的东风圈和南风圈，6局以上（每圈3局）。\n$caveat\n点按切换为东风战，3局以上。';
  }

  @override
  String eastOnlyTooltipSanma(String caveat) {
    return '东风战——三人麻将只打东风圈，3局以上。\n$caveat\n点按切换为半庄：东风圈和南风圈，6局以上。';
  }

  @override
  String get glossaryTermSanma => '三麻';

  @override
  String get glossaryDefSanma =>
      '三人玩的日本立直麻将。去掉二至八万，共108张牌；不能吃；座位为东、南、西；每人起始35,000点。自摸只由另外两人支付，所以比同一手牌荣和便宜。';

  @override
  String get glossaryTermKita => '拔北';

  @override
  String get glossaryDefKita =>
      '三麻中可以把北风牌拔出来而不留在手里：它算作一张宝牌，并从王牌补摸一张。其他玩家可以荣和这张北。';

  @override
  String get quizNoneSanma => '三人麻将还没有每日一题。切换到日本麻将或香港麻将即可挑战。';

  @override
  String get tourHandTitle => '你的手牌';

  @override
  String get tourHandBody => '点按一张牌把它抬起，再点一次就打出。想调整顺序，长按一张牌，然后拖到新的位置。';

  @override
  String get tourButtonsTitle => '手牌旁边的按钮';

  @override
  String get tourButtonsBody => '四个开关决定手牌怎么操作。打开时会填满颜色。';

  @override
  String get tourLegendSortBody =>
      '点按在三种模式间切换。“手牌”让牌保持排序，摸到的牌放在右边；“手牌+摸牌”把摸到的牌直接排进去；“关”让每张牌留在你拖放的位置。';

  @override
  String get tourLegendDiscardBody => '点一次就打牌，或者点两次（先抬起再打出）。';

  @override
  String get tourLegendAutoWinBody => '一能和牌就自动替你宣告。';

  @override
  String get tourLegendAutoPassBody => '自动放弃其他玩家打出的牌的吃碰杠，不再询问。';

  @override
  String get tourGuideTitle => '你的向导 TileSensor';

  @override
  String get tourGuideBody =>
      '点按 TileSensor 打开向导。它为每一张可打的牌排序，用绿色标出最佳选择并说明原因。再点一次即可隐藏。';

  @override
  String get tourRulesTitle => '规则手册';

  @override
  String get tourRulesBodyDesktop =>
      '顶部栏的书本图标可打开本局的规则手册：每个计分牌型都有牌例，还有和牌条件、起和要求与支付，随时可以搜索。';

  @override
  String get tourRulesBodyPhone =>
      '打开菜单，再点“规则”，即可阅读本局的规则手册：每个计分牌型都有牌例，还有和牌条件、起和要求与支付，随时可以搜索。';

  @override
  String get tourRulesOpen => '打开规则手册';

  @override
  String get tourMenuTitle => '设置和帮助';

  @override
  String get tourMenuBodyPhone => '菜单按钮里有暂停、声音、速度、自动打牌和术语表。也可以在那里重看这段导览。';

  @override
  String get tourMenuBodyDesktop =>
      '设置排在顶部栏，术语表在规则名称旁边。左上角的菜单返回主菜单，可在“学习”里重看这段导览。';

  @override
  String get tourSkip => '跳过导览';

  @override
  String get tourNext => '下一步';

  @override
  String get tourDone => '开始打牌';

  @override
  String get tableTourLink => '牌桌导览：怎样操作牌桌';

  @override
  String get tableTourMenu => '牌桌怎么用';

  @override
  String tourStepOf(int step, int total) {
    return '第$step步，共$total步';
  }

  @override
  String get rulesTileTooltip => '选择要玩的麻将规则：日本麻将、三人麻将、香港、台湾、国标或四川。';

  @override
  String get rulesRead => '阅读规则';

  @override
  String get rulesSearchHint => '搜索规则';

  @override
  String get rulesClearSearch => '清除搜索';

  @override
  String get rulesNoMatch => '没有匹配的规则，请尝试其他词语。';

  @override
  String get rulesSummaryNotice =>
      'TileSense 规则简介，并列出应用计算的所有番种。译文由 TileSense 提供，规则以外部参考资料（英文）为准。';

  @override
  String get rulesReferenceFailed => '无法打开参考资料，请重试。';

  @override
  String get mcrFanBigFourWinds => '大四喜';

  @override
  String get mcrFanBigThreeDragons => '大三元';

  @override
  String get mcrFanAllGreen => '绿一色';

  @override
  String get mcrFanNineGates => '九莲宝灯';

  @override
  String get mcrFanFourKongs => '四杠';

  @override
  String get mcrFanSevenShiftedPairs => '连七对';

  @override
  String get mcrFanThirteenOrphans => '十三幺';

  @override
  String get mcrFanAllTerminals => '清幺九';

  @override
  String get mcrFanLittleFourWinds => '小四喜';

  @override
  String get mcrFanLittleThreeDragons => '小三元';

  @override
  String get mcrFanAllHonors => '字一色';

  @override
  String get mcrFanFourConcealedPungs => '四暗刻';

  @override
  String get mcrFanPureTerminalChows => '一色双龙会';

  @override
  String get mcrFanQuadrupleChow => '一色四同顺';

  @override
  String get mcrFanFourPureShiftedPungs => '一色四节高';

  @override
  String get mcrFanFourShiftedChows => '一色四步高';

  @override
  String get mcrFanThreeKongs => '三杠';

  @override
  String get mcrFanAllTerminalsAndHonors => '混幺九';

  @override
  String get mcrFanSevenPairs => '七对';

  @override
  String get mcrFanGreaterHonorsAndKnittedTiles => '七星不靠';

  @override
  String get mcrFanAllEvenPungs => '全双刻';

  @override
  String get mcrFanFullFlush => '清一色';

  @override
  String get mcrFanPureTripleChow => '一色三同顺';

  @override
  String get mcrFanPureShiftedPungs => '一色三节高';

  @override
  String get mcrFanUpperTiles => '全大';

  @override
  String get mcrFanMiddleTiles => '全中';

  @override
  String get mcrFanLowerTiles => '全小';

  @override
  String get mcrFanPureStraight => '清龙';

  @override
  String get mcrFanThreeSuitedTerminalChows => '三色双龙会';

  @override
  String get mcrFanPureShiftedChows => '一色三步高';

  @override
  String get mcrFanAllFives => '全带五';

  @override
  String get mcrFanTriplePung => '三同刻';

  @override
  String get mcrFanThreeConcealedPungs => '三暗刻';

  @override
  String get mcrFanLesserHonorsAndKnittedTiles => '全不靠';

  @override
  String get mcrFanKnittedStraight => '组合龙';

  @override
  String get mcrFanUpperFour => '大于五';

  @override
  String get mcrFanLowerFour => '小于五';

  @override
  String get mcrFanBigThreeWinds => '三风刻';

  @override
  String get mcrFanMixedStraight => '花龙';

  @override
  String get mcrFanReversibleTiles => '推不倒';

  @override
  String get mcrFanMixedTripleChow => '三色三同顺';

  @override
  String get mcrFanMixedShiftedPungs => '三色三节高';

  @override
  String get mcrFanChickenHand => '无番和';

  @override
  String get mcrFanLastTileDraw => '妙手回春';

  @override
  String get mcrFanLastTileClaim => '海底捞月';

  @override
  String get mcrFanOutWithReplacementTile => '杠上开花';

  @override
  String get mcrFanRobbingTheKong => '抢杠和';

  @override
  String get mcrFanTwoConcealedKongs => '双暗杠';

  @override
  String get mcrFanAllPungs => '碰碰和';

  @override
  String get mcrFanHalfFlush => '混一色';

  @override
  String get mcrFanMixedShiftedChows => '三色三步高';

  @override
  String get mcrFanAllTypes => '五门齐';

  @override
  String get mcrFanMeldedHand => '全求人';

  @override
  String get mcrFanTwoDragonPungs => '双箭刻';

  @override
  String get mcrFanOutsideHand => '全带幺';

  @override
  String get mcrFanFullyConcealed => '不求人';

  @override
  String get mcrFanTwoMeldedKongs => '双明杠';

  @override
  String get mcrFanLastTile => '和绝张';

  @override
  String get mcrFanDragonPung => '箭刻';

  @override
  String get mcrFanPrevalentWind => '圈风刻';

  @override
  String get mcrFanSeatWind => '门风刻';

  @override
  String get mcrFanConcealedHand => '门前清';

  @override
  String get mcrFanAllChows => '平和';

  @override
  String get mcrFanTileHog => '四归一';

  @override
  String get mcrFanDoublePung => '双同刻';

  @override
  String get mcrFanTwoConcealedPungs => '双暗刻';

  @override
  String get mcrFanConcealedKong => '暗杠';

  @override
  String get mcrFanAllSimples => '断幺';

  @override
  String get mcrFanPureDoubleChow => '一般高';

  @override
  String get mcrFanMixedDoubleChow => '喜相逢';

  @override
  String get mcrFanShortStraight => '连六';

  @override
  String get mcrFanTwoTerminalChows => '老少副';

  @override
  String get mcrFanPungOfTerminalsOrHonors => '幺九刻';

  @override
  String get mcrFanMeldedKong => '明杠';

  @override
  String get mcrFanOneVoidedSuit => '缺一门';

  @override
  String get mcrFanNoHonors => '无字';

  @override
  String get mcrFanEdgeWait => '边张';

  @override
  String get mcrFanClosedWait => '嵌张';

  @override
  String get mcrFanSingleWait => '单钓将';

  @override
  String get mcrFanSelfDrawn => '自摸';

  @override
  String get mcrFanFlowerTiles => '花牌';

  @override
  String get mcrFanMeldedAndConcealedKongs => '明暗杠';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'TileSense';

  @override
  String get languageTooltip => '語言';

  @override
  String get rulesetRiichi => '立直';

  @override
  String get rulesetHongKong => '香港';

  @override
  String get rulesetTaiwanese => '台灣';

  @override
  String get windEast => '東風';

  @override
  String get windSouth => '南風';

  @override
  String get windWest => '西風';

  @override
  String get windNorth => '北風';

  @override
  String get callChiRiichi => '吃';

  @override
  String get callChiHongKong => '上';

  @override
  String get callChiTaiwanese => '吃';

  @override
  String get callPonRiichi => '碰';

  @override
  String get callPonHongKong => '碰';

  @override
  String get callPonTaiwanese => '碰';

  @override
  String get callKanRiichi => '槓';

  @override
  String get callKanHongKong => '槓';

  @override
  String get callKanTaiwanese => '槓';

  @override
  String get callRonRiichi => '榮和';

  @override
  String get callRonHongKong => '食糊';

  @override
  String get callRonTaiwanese => '胡';

  @override
  String get callTsumoRiichi => '自摸';

  @override
  String get callTsumoHongKong => '自摸';

  @override
  String get callTsumoTaiwanese => '自摸';

  @override
  String get hanchanCaveatRiichi =>
      '以上是每局都輪莊時的局數。按標準立直規則，莊家和牌或荒牌流局時聽牌就會連莊並重打該局——所以兩種長度都可能更長。';

  @override
  String get hanchanCaveatChinese =>
      '以上是每局都輪莊時的局數。莊家和牌或任何荒牌流局都會連莊並重打該局——所以兩種長度都可能更長。';

  @override
  String get zoomOut => '縮小  (Ctrl/Cmd -)';

  @override
  String get zoomIn => '放大  (Ctrl/Cmd +)';

  @override
  String get zoomReset => '重設縮放  (Ctrl/Cmd 0)';

  @override
  String get installTitle => '安裝 TileSense';

  @override
  String get installBody =>
      '此瀏覽器無法讓網頁全螢幕顯示。請改為將 TileSense 安裝為網頁應用程式，它會以全螢幕開啟，沒有瀏覽器列：\n\n• iPhone / iPad：點「分享」，再點「加入主畫面」\n• Chrome / Edge：點網址列中的安裝圖示，或選單 > 「安裝應用程式」';

  @override
  String get gotIt => '知道了';

  @override
  String get fullscreenExit => '結束全螢幕';

  @override
  String get fullscreenTooltip =>
      '全螢幕。為獲得最佳體驗，請將 TileSense 安裝為網頁應用程式（瀏覽器選單 > 安裝／加入主畫面）。';

  @override
  String get fullscreen => '全螢幕';

  @override
  String get updateAvailableTitle => '有可用更新';

  @override
  String get updateAvailableBody => '新版 TileSense 已就緒。立即更新即可取得。';

  @override
  String get updateNow => '立即更新';

  @override
  String get upToDateTitle => '已是最新版本';

  @override
  String get upToDateBody => '這已是最新版本。仍可重新整理以重新下載所有檔案。';

  @override
  String get refreshAnyway => '仍然重新整理';

  @override
  String get refreshTitle => '重新整理 TileSense';

  @override
  String get refreshUnknownBody => '無法確定是否有新版本。重新整理以下載最新檔案。';

  @override
  String get refresh => '重新整理';

  @override
  String get notNow => '暫不';

  @override
  String get updateTooltip => '檢查新版本並重新整理應用程式';

  @override
  String get working => '處理中…';

  @override
  String get update => '更新';

  @override
  String get rotatePrompt => '請將裝置橫放以使用 TileSense';

  @override
  String get widenPrompt => '請將瀏覽器視窗調寬以使用 TileSense';

  @override
  String minimumFaanSentence(int n) {
    return '，最低$n番';
  }

  @override
  String minimumTaiSentence(int n) {
    return '，最低$n台';
  }

  @override
  String minimumFaanTag(int n) {
    return '最低$n番';
  }

  @override
  String minimumTaiTag(int n) {
    return '最低$n台';
  }

  @override
  String minimumFanTag(int n) {
    return '最低$n番';
  }

  @override
  String get newGameConfirmTitle => '開始新對局？';

  @override
  String get newGameConfirmBody => '進行中的對局將會遺失。';

  @override
  String get keepPlaying => '繼續對局';

  @override
  String lengthChangeConfirmTitle(String length) {
    return '切換為$length？';
  }

  @override
  String get lengthChangeConfirm => '切換';

  @override
  String get newGame => '新對局';

  @override
  String get loadingTable => '正在準備牌桌…';

  @override
  String get loadingBuilder => '正在載入手牌建構器…';

  @override
  String get loadingMultiplayer => '正在載入連線對戰…';

  @override
  String get start => '開始';

  @override
  String get menu => '選單';

  @override
  String get menuTooltip => '主選單——暫停本局；點「開始」繼續。可在那裡更換玩法（開始新對局），或打開自訂手牌與情境建構器';

  @override
  String playingRulesTooltip(String rules, String minimum) {
    return '正在使用$rules規則$minimum。\n要換別的玩法，請回到主選單。';
  }

  @override
  String rulesPdf(String rules) {
    return '$rules規則（PDF，英文）';
  }

  @override
  String hanchanOnTooltip(String caveat) {
    return '半莊——東風圈和南風圈，8局以上。\n$caveat\n點按切換為東風戰，4局以上。';
  }

  @override
  String eastOnlyTooltipChinese(String caveat) {
    return '東風戰——只打東風圈，4局以上。\n$caveat\n點按切換為半莊：東風圈和南風圈，8局以上。';
  }

  @override
  String eastOnlyTooltipRiichi(String caveat) {
    return '東風戰——只打東風圈，4局以上。\n$caveat\n點按切換為半莊：東風圈和南風圈，8局以上。';
  }

  @override
  String get hanchan => '半莊';

  @override
  String get eastOnly => '東風戰';

  @override
  String get botSpeedCaption => '電腦速度';

  @override
  String get botSpeedFastTooltip => '電腦和摸牌以兩倍速進行。\n點按恢復正常速度。';

  @override
  String get botSpeedNormalTooltip => '電腦和摸牌以正常速度進行。\n點按切換為兩倍速。';

  @override
  String get algorithmCaption => '演算法';

  @override
  String get mortalBot => 'Mortal 機器人';

  @override
  String algorithmTooltip(String style, String focus, String strategy) {
    return 'TileSense 指南：$style · $focus · $strategy。\n隨對局自動調整：前期採用進攻・速度・點數以建立領先；最後兩局採用平衡・速度・順位以守住或提升排名。';
  }

  @override
  String get autoPlayCaption => '自動打牌';

  @override
  String get autoPlayOnTooltip =>
      '自動打牌已開啟——TileSensor 按指南替你打牌：前期重得分，最後兩局重名次。\n點按收回座位。';

  @override
  String get autoPlayOffTooltip => '自動打牌已關閉——你自己打牌。\n點按讓 TileSensor 按指南替你打。';

  @override
  String get on => '開';

  @override
  String get off => '關';

  @override
  String get soundCaption => '聲音';

  @override
  String get soundOnTooltip => '聲音已開——點按靜音';

  @override
  String get soundOffTooltip => '聲音已關——點按取消靜音';

  @override
  String get resumeCaption => '繼續';

  @override
  String get pauseCaption => '暫停';

  @override
  String get resume => '繼續';

  @override
  String get pause => '暫停';

  @override
  String get newCaption => '新局';

  @override
  String get pausedOverlay => '已暫停\n點按或按 Esc 繼續';

  @override
  String get rulesetSubtitleRiichi => '役、寶牌、立直';

  @override
  String get rulesetSubtitleHongKong => '番、花牌、最低0–3番';

  @override
  String get rulesetSubtitleTaiwanese => '17張、花牌、最低1–5台';

  @override
  String welcomeTagline(String rules) {
    return '磨練你的$rules麻將決策\n指南只看你看得到的資訊。';
  }

  @override
  String get singlePlayer => '單人遊戲';

  @override
  String get singlePlayerSubtitle => '含 TileSense 指南';

  @override
  String get playOnline => '連線對戰';

  @override
  String get builder => '手牌建構器';

  @override
  String get builderSubtitle => '讓 TileSense 指南評分';

  @override
  String rejoinOnline(String code) {
    return '重新加入連線對局 · 房間 $code';
  }

  @override
  String get viewOnGitHub => '在 GitHub 上查看';

  @override
  String get builtWithFlutter => '使用 Flutter 建構';

  @override
  String get seatYou => '你';

  @override
  String get seatRight => '下家';

  @override
  String get seatAcross => '對家';

  @override
  String get seatLeft => '上家';

  @override
  String get youStartAs => '你的起始風位';

  @override
  String get style => '玩法';

  @override
  String get gameLength => '對局長度';

  @override
  String get lengthHanchan => '半莊';

  @override
  String get lengthEastOnly => '東風戰';

  @override
  String get minFaan => '最低番數';

  @override
  String get minFaanTooltip => '和牌所需的最少番數。\n0 表示任何完整牌型（包括雞糊）都能和牌。';

  @override
  String get minTai => '最低台數';

  @override
  String get minTaiTooltip => '和牌所需的最少台數。\n5 是聖地牙哥俱樂部規則；1 和 3 是常見的自訂最低台數。';

  @override
  String get chooseCharacters => '選擇角色';

  @override
  String get dealerNoteYou => '東家先坐莊——就是你。';

  @override
  String dealerNoteOther(String seat) {
    return '東家先坐莊——是$seat。';
  }

  @override
  String get randomizeCharacters => '隨機角色與座位';

  @override
  String get sound => '聲音';

  @override
  String get back => '返回';

  @override
  String get backToMainMenu => '返回主選單';

  @override
  String get done => '完成';

  @override
  String get mainMenu => '主選單';

  @override
  String get rules => '規則';

  @override
  String get soundOn => '聲音開';

  @override
  String get soundOff => '聲音關';

  @override
  String get bots2x => '電腦 2倍速';

  @override
  String get bots1x => '電腦 1倍速';

  @override
  String get autoPlayOn => '自動打牌 開';

  @override
  String get autoPlayOff => '自動打牌 關';

  @override
  String get algorithm => '演算法';

  @override
  String get pausedCaps => '已暫停';

  @override
  String get menuCaps => '選單';

  @override
  String get loadFailed => '無法完成載入，請重試。';

  @override
  String get retry => '重試';

  @override
  String get clientIdTitle => '你的用戶端 ID';

  @override
  String get clientIdShort => 'ID';

  @override
  String get clientIdHelp => '回報問題時請附上此 ID。';

  @override
  String get close => '關閉';

  @override
  String get copied => '已複製';

  @override
  String get copy => '複製';

  @override
  String faanCount(int n) {
    return '$n番';
  }

  @override
  String taiCount(int n) {
    return '$n台';
  }

  @override
  String badgeTooltip(String rules, String minimum) {
    return '正在使用$rules規則$minimum。';
  }

  @override
  String badgeMinimum(String min) {
    return '，最低$min';
  }

  @override
  String get yakuRiichi => '立直';

  @override
  String get yakuDoubleRiichi => '兩立直';

  @override
  String get yakuIppatsu => '一發';

  @override
  String get yakuMenzenTsumo => '門前清自摸和';

  @override
  String get yakuHaiteiRaoyue => '海底摸月';

  @override
  String get yakuHouteiRaoyui => '河底撈魚';

  @override
  String get yakuRinshanKaihou => '嶺上開花';

  @override
  String get yakuChankan => '搶槓';

  @override
  String get yakuTanyao => '斷幺九';

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
  String get yakuChiitoitsu => '七對子';

  @override
  String get yakuToitoi => '對對和';

  @override
  String get yakuSanankou => '三暗刻';

  @override
  String get yakuSankantsu => '三槓子';

  @override
  String get yakuSanshokuDoujun => '三色同順';

  @override
  String get yakuSanshokuDoukou => '三色同刻';

  @override
  String get yakuIttsu => '一氣通貫';

  @override
  String get yakuHonroutou => '混老頭';

  @override
  String get yakuHonitsu => '混一色';

  @override
  String get yakuChinitsu => '清一色';

  @override
  String get yakuChanta => '混全帶幺九';

  @override
  String get yakuJunchan => '純全帶幺九';

  @override
  String get yakuDora => '寶牌';

  @override
  String get yakuUraDora => '裏寶牌';

  @override
  String get yakuAkaDora => '赤寶牌';

  @override
  String get yakuKokushiMusou => '國士無雙';

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
  String get yakuRyuuiisou => '綠一色';

  @override
  String get yakuChuurenPoutou => '九蓮寶燈';

  @override
  String get faanAllFlowers => '四花齊';

  @override
  String get faanAllSeasons => '四季齊';

  @override
  String get faanAllHonours => '字一色';

  @override
  String get faanAllSequences => '平糊';

  @override
  String get faanAllTerminals => '清幺九';

  @override
  String get faanAllTriplets => '對對糊';

  @override
  String get faanAllQuadruplets => '十八羅漢';

  @override
  String get faanAllQuadrupletsUpgrade => '十八羅漢（升級）';

  @override
  String get faanAllConcealedTriplets => '坎坎胡';

  @override
  String get faanAllConcealedTripletsUpgrade => '坎坎胡（升級）';

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
  String get faanChickenHand => '雞糊';

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
  String get faanRoundWind => '圈風';

  @override
  String get faanSeatWind => '門風';

  @override
  String get faanSelfPick => '自摸';

  @override
  String get faanSevenPairs => '七對';

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
  String get taiAllChowsWithFlowersOrHonors => '平胡（帶花或字）';

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
  String get taiClosedWait => '中洞';

  @override
  String get taiConcealedHand => '門清';

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
  String get taiFullyConcealedHand => '門清自摸';

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
  String get taiPureStraight => '一條龍';

  @override
  String get taiRobbingTheKong => '搶槓';

  @override
  String get taiSelfDrawn => '自摸';

  @override
  String get taiSevenPairsAndAPung => '嚦咕嚦咕';

  @override
  String get taiSingleWait => '獨聽';

  @override
  String get taiValueHonor => '字牌刻';

  @override
  String get taiWinWithin5Discards => '五巡內胡牌';

  @override
  String get taiWinWithin5To10Discards => '五至十巡內胡牌';

  @override
  String get resultKyuushuKyuuhaiNineTerminalsHonors => '九種九牌';

  @override
  String get resultExhaustiveDraw => '荒牌流局';

  @override
  String get resultMultipleWins => '一炮多響';

  @override
  String get resultRobbingAKong => '搶槓';

  @override
  String get resultWinOnDiscard => '放槍和牌';

  @override
  String get resultMultipleRon => '一炮多響';

  @override
  String get resultChankan => '搶槓';

  @override
  String get resultRon => '榮和';

  @override
  String get resultSelfDraw => '自摸';

  @override
  String get resultTsumo => '自摸';

  @override
  String get limitMangan => '滿貫';

  @override
  String get limitHaneman => '跳滿';

  @override
  String get limitBaiman => '倍滿';

  @override
  String get limitSanbaiman => '三倍滿';

  @override
  String get limitKazoeYakuman => '累計役滿';

  @override
  String get limitYakuman => '役滿';

  @override
  String get limit13FaanCap => '13番以上封頂';

  @override
  String get tileTon => '東';

  @override
  String get tileNan => '南';

  @override
  String get tileShaa => '西';

  @override
  String get tilePei => '北';

  @override
  String get tileHaku => '白板';

  @override
  String get tileHatsu => '發財';

  @override
  String get tileChun => '紅中';

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
    return '$tile刻子';
  }

  @override
  String limitMultipleYakuman(int n) {
    return '$n倍役滿';
  }

  @override
  String get bubbleRiichi => '立直';

  @override
  String get bubbleRinshanRiichi => '嶺上開花';

  @override
  String get bubbleRinshanChinese => '槓上開花';

  @override
  String get doraRowLabel => '寶牌';

  @override
  String get uraRowLabel => '裏寶';

  @override
  String get noCalls => '副露';

  @override
  String get autoPlaySeatTooltip => '自動打牌——TileSensor 正在替你打牌';

  @override
  String get furiten => '振聽';

  @override
  String get noYaku => '無役';

  @override
  String underFaan(int n) {
    return '不足$n番';
  }

  @override
  String underTai(int n) {
    return '不足$n台';
  }

  @override
  String underFan(int n) {
    return '不足$n番';
  }

  @override
  String get noWin => '無法和牌';

  @override
  String get minimumRonOnlyTooltip => '無法榮和：任何聽牌放槍都達不到最低要求，自摸仍可和牌';

  @override
  String get minimumDeadTooltip => '任何聽牌即使自摸也達不到最低要求，此手牌目前無法和牌';

  @override
  String secondsShort(int n) {
    return '$n秒';
  }

  @override
  String statusWall(int n) {
    return '牌牆 $n';
  }

  @override
  String statusDealerRepeat(int n) {
    return '連莊 $n';
  }

  @override
  String statusHonba(int n) {
    return '本場 $n';
  }

  @override
  String statusRiichiSticks(int n) {
    return '立直棒 $n';
  }

  @override
  String statusRound(String kanji, String wind, int hand) {
    return '$wind$hand局';
  }

  @override
  String seatLabelYou(String name) {
    return '$name（你）';
  }

  @override
  String seatLabelBot(String name) {
    return '$name（電腦）';
  }

  @override
  String get seatBot => '電腦';

  @override
  String seatNumber(int n) {
    return '$n號座';
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
    return '$n條';
  }

  @override
  String get undoPass => '過';

  @override
  String get undoContinueDrawing => '繼續摸牌';

  @override
  String undoRiichi(String tile) {
    return '立直 $tile';
  }

  @override
  String undoKan(String kan, String tile) {
    return '$kan $tile';
  }

  @override
  String get hideGuide => '隱藏指南';

  @override
  String get showGuide => '顯示指南';

  @override
  String get hideGuideFooter => '點按隱藏我的指南。';

  @override
  String get showGuideFooter => '點按顯示我的指南。';

  @override
  String get sortCaption => '排序';

  @override
  String get sortOff => '關';

  @override
  String get sortOffTooltip => '排序：關——按你自己的順序。\n長按牌並拖動即可移動。點按切換為「手牌」（按牌序）。';

  @override
  String get sortHand => '手牌';

  @override
  String get sortHandTooltip =>
      '排序：手牌——按牌序排列，摸到的牌單獨放在右邊。\n點按切換為「手牌+摸牌」，或拖動一張牌改用自己的順序。';

  @override
  String get sortHandDraw => '手牌+摸牌';

  @override
  String get sortHandDrawTooltip =>
      '排序：手牌+摸牌——摸到的牌直接排進手牌。\n點按固定目前順序（關），或拖動一張牌改用自己的順序。';

  @override
  String get discardCaption => '出牌';

  @override
  String get discardSingle => '單擊';

  @override
  String get discardDouble => '雙擊';

  @override
  String get discardSingleTooltip => '出牌：單擊——點一下牌即打出。\n點按切換為先點起牌、再點一次打出。';

  @override
  String get discardDoubleTooltip => '出牌：雙擊——第一次點起牌，第二次打出。\n點按切換為單擊出牌。';

  @override
  String get autoWinCaption => '自動和牌';

  @override
  String get autoWinOnTooltip => '自動和牌：開——一旦可以和牌，就自動替你宣告榮和或自摸。\n點按改為自己決定。';

  @override
  String get autoWinOffTooltip => '自動和牌：關——自己按和牌按鈕。\n點按改為自動宣告榮和/自摸。';

  @override
  String get autoPassCaption => '自動過';

  @override
  String get autoPassOnTooltip =>
      '自動過：開——別人打出的牌可吃、碰、槓時自動替你過。榮和仍由你決定。\n點按改為自己決定是否鳴牌。';

  @override
  String get autoPassOffTooltip => '自動過：關——每次可鳴牌都會詢問你。\n點按改為自動過掉吃、碰、槓。';

  @override
  String declareRiichiDiscard(String tile) {
    return '立直並打出 $tile';
  }

  @override
  String justDiscard(String tile) {
    return '只打出 $tile';
  }

  @override
  String get flowerWin => '花胡';

  @override
  String get continueDrawing => '繼續摸牌';

  @override
  String get passCaps => '過';

  @override
  String get kyuushuKyuuhai => '九種九牌';

  @override
  String get riichiAvailable => '可以立直';

  @override
  String get riichiAvailableRecommended => '可以立直——推薦';

  @override
  String get undoTooltip => '撤回本局你的上一步及之後的一切。\n再按一次繼續往回退。(Ctrl/Cmd+Z)';

  @override
  String get takeBack => '撤回  ';

  @override
  String get scoreNewGame => '新對局';

  @override
  String get scoreNext => '下一頁';

  @override
  String scoreContinueLocked(int n) {
    return '繼續（$n）';
  }

  @override
  String get scoreContinue => '繼續';

  @override
  String get autoContinuePaused => '自動繼續已暫停';

  @override
  String get autoContinueHeld => '自動繼續暫緩——對局已暫停';

  @override
  String autoContinueIn(int n) {
    return '$n秒後自動繼續';
  }

  @override
  String get showPanel => '顯示面板';

  @override
  String get seeThroughPanel => '面板透明';

  @override
  String get flowersSeasons => '花牌／季節牌';

  @override
  String indicatorRowOne(String label) {
    return '$label指示牌：';
  }

  @override
  String indicatorRowMany(String label) {
    return '$label指示牌：';
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
    return '$name  $n番';
  }

  @override
  String yakuLineHan(String name, int n) {
    return '$name  $n番';
  }

  @override
  String yakuLineYakuman(String name) {
    return '$name  役滿';
  }

  @override
  String scorePointOne(int n) {
    return '$n點';
  }

  @override
  String scorePointMany(int n) {
    return '$n點';
  }

  @override
  String scoreFaanChips(int faan, int points, String limit) {
    return '$faan番——$points籌碼$limit';
  }

  @override
  String scoreLimitOnly(String limit, int points) {
    return '$limit——$points點';
  }

  @override
  String scoreHanFu(int han, int fu, String limit, int points) {
    return '$han番$fu符$limit——$points點';
  }

  @override
  String limitSuffix(String limit) {
    return '（$limit）';
  }

  @override
  String get wallExhaustedNoPayments => '荒牌——不結算';

  @override
  String get allNoten => '全員未聽牌';

  @override
  String get tenpaiRevealed => '公開聽牌者的手牌';

  @override
  String get waits => '聽';

  @override
  String get backToMenu => '返回選單';

  @override
  String get cantReachServer => '無法連線至連線伺服器——正在重試…';

  @override
  String get noGuideOnline => '連線對戰沒有 TileSense 指南——想用指南請玩單人遊戲。';

  @override
  String get yourName => '你的名字';

  @override
  String get yourNameHelper => '預設使用角色名——可編輯為你自己的名字';

  @override
  String get createARoom => '建立房間';

  @override
  String get createRoomButton => '建立房間';

  @override
  String get joinARoom => '加入房間';

  @override
  String get roomCode => '房間代碼';

  @override
  String get join => '加入';

  @override
  String get chooseYourCharacter => '選擇你的角色';

  @override
  String get pace => '節奏';

  @override
  String get paceFast => '快';

  @override
  String get paceStandard => '標準';

  @override
  String get paceRelaxed => '悠閒';

  @override
  String paceCaption(int turn, int call) {
    return '每回合 $turn 秒 · 鳴牌 $call 秒';
  }

  @override
  String get minimumFaanToWin => '和牌最少番數';

  @override
  String get minimumTaiToWin => '和牌最少台數';

  @override
  String get roomCodeShare => '房間代碼——分享給其他玩家';

  @override
  String get copyCode => '複製代碼';

  @override
  String get roomCodeCopied => '已複製房間代碼';

  @override
  String roomFaanMin(int n) {
    return '最低$n番';
  }

  @override
  String roomTaiMin(int n) {
    return '最低$n台';
  }

  @override
  String get roomFullGame => '半莊';

  @override
  String get roomEastOnly => '東風戰';

  @override
  String roomClocks(int turn, int call) {
    return '回合 $turn 秒 · 鳴牌 $call 秒';
  }

  @override
  String get startGameBots => '開始對局——空位由電腦補上';

  @override
  String get waitingForHost => '等待房主開始…';

  @override
  String get leaveRoomButton => '離開房間';

  @override
  String get emptySeat => '空位';

  @override
  String get host => '房主';

  @override
  String get rejoiningGame => '正在重新加入對局…';

  @override
  String gameStillGoing(String code) {
    return '房間 $code 的對局仍在進行。';
  }

  @override
  String get rejoin => '重新加入';

  @override
  String get leaveGameTitle => '離開本局？';

  @override
  String get leaveGameBody => '你回來之前由電腦替你打——對局進行期間可在主選單重新加入。';

  @override
  String get noPauseOnlineHint => '線上對局無法暫停。想要每回合更多時間，請選擇「悠閒」。';

  @override
  String get noPauseOnlineTooltip =>
      '線上對局無法暫停。如需離開，逾時或斷線後由電腦代打你的座位，你可從主選單重新加入。';

  @override
  String get smallWindowHint => '視窗較小，工具列已收進手牌旁的選單按鈕。放大視窗即可恢復完整工具列。';

  @override
  String get smallWindowHintOnline =>
      '視窗較小，聲音、語言和你的 ID 已收進手牌旁的選單按鈕。放大視窗即可恢復完整工具列。';

  @override
  String get stay => '留下';

  @override
  String get leave => '離開';

  @override
  String get leaveRoom => '離開房間';

  @override
  String get clientId => '用戶端 ID';

  @override
  String nowBotControlled(String name) {
    return '$name 已改由電腦操控';
  }

  @override
  String get noGuideOnlineTooltip =>
      'TileSensor 不參加連線對戰，這樣誰都不會有別人沒有的指南。\n玩單人遊戲就能帶上我！';

  @override
  String roomLabel(String code) {
    return '房間 $code';
  }

  @override
  String get connectionLost => '連線已中斷——正在重新連線…';

  @override
  String get backToStart => '返回開始畫面';

  @override
  String get errorNotSeated => '你不在這個房間的座位上。';

  @override
  String get errorSeatBotControlled => '這個座位由電腦操控。';

  @override
  String get errorMissingGuestId => '出了點問題，請重試。';

  @override
  String get errorServerFull => '伺服器已滿，請稍後再試。';

  @override
  String get errorMissingRoom => '請輸入房間代碼。';

  @override
  String get errorRoomNotFound => '找不到該房間。';

  @override
  String get errorRoomStarted => '該房間已經開始。';

  @override
  String get errorRoomFull => '該房間已滿。';

  @override
  String get errorNotHost => '只有房主可以開始對局。';

  @override
  String get errorRoomGone => '該房間已不存在。';

  @override
  String get errorUnknownType => '出了點問題，請重試。';

  @override
  String get errorMalformed => '出了點問題，請重試。';

  @override
  String get errorBadRequest => '出了點問題，請重試。';

  @override
  String get errorIllegalAction => '現在不能這樣操作。';

  @override
  String get errorNoActionExpected => '還沒輪到你。';

  @override
  String get errorGameEnded => '該對局已結束';

  @override
  String get guideTipTitle => '指南\n';

  @override
  String get guideGreen => '綠色牌';

  @override
  String get guideGreenBody => '建議打出的牌';

  @override
  String get guideYellow => '黃色牌';

  @override
  String get guideYellowBody => '剛摸到的牌';

  @override
  String get guidePause => '暫停對局';

  @override
  String get guideHover => '\n將滑鼠停在標題或設定上可查看說明。';

  @override
  String get tipAutoTitle => '自動打牌\n';

  @override
  String get tipAutoBody => '選擇自動打牌採用的建議，以及下方候選項的排序依據。\n';

  @override
  String get tipAutoChoices =>
      '• TileSense（預設）：由指南打牌，首行顯示指南的建議。\n• Mortal：由 Mortal 打牌，首行顯示其建議。Mortal 無法回答時由指南決定。';

  @override
  String get tipEvTitle => 'TileSense 期望值\n';

  @override
  String get tipFinishTitle => '和牌機率';

  @override
  String get tipFinishBody => '本局結束前和牌的機率。剩餘有效牌和摸牌次數越多，機率越高。\n';

  @override
  String get tipFinishMore => '停留查看進張說明；點擊 EV (HMR) 數值查看圖表';

  @override
  String get tipPayoutTitle => '和牌收益';

  @override
  String get tipPayoutTw => '每位付款者支付相同點數，再加連莊獎勵。聽牌時為準確值，未聽牌時按所示牌型估算。\n';

  @override
  String get tipPayoutHk => '將番數換算為籌碼。聽牌時為準確值，未聽牌時按所示牌型估算。\n';

  @override
  String get tipPayoutRiichi => '和牌得點，加上本場和立直棒。聽牌時為準確值，未聽牌時為估算值。\n';

  @override
  String get tipPayoutMore => '點擊 EV (HMR) 數值查看計算過程';

  @override
  String get tipCutTitle => '打牌風險';

  @override
  String get tipCutChinese => '對手有三組以上明露面子時的預期損失。沒有絕對安全的牌。\n';

  @override
  String get tipCutRiichi => '立直棒的成本（未和牌則損失）。面對立直時，還計入此牌的放銃機率和繼續進攻所需的巡數。\n';

  @override
  String get tipCutMore => '停留查看風險和安全度';

  @override
  String get tipFocusTitle => '側重點';

  @override
  String get tipFocusBody => '速度優先會犧牲部分收益以提高和牌機率。平衡模式不作偏向調整。\n';

  @override
  String get tipFocusMore => '停留查看側重點';

  @override
  String get tipFocusPlacementMore => '停留查看側重點、策略和順位的其餘說明';

  @override
  String get tipEvHigher => '\n越高越好。風險高、收益低的打牌可能為負值。';

  @override
  String get tipOrdinaryWide => '比通常更寬';

  @override
  String get tipOrdinaryWideBody => '推進更快，但估算速度不超過普通手牌';

  @override
  String get tipOrdinaryTitle => '普通手牌的平均值';

  @override
  String get tipShantenLabel => '向聽數';

  @override
  String get tipUkeireLabel => '進張';

  @override
  String get tipAwayLabel => '距聽牌';

  @override
  String get tipAcceptsLabel => '有效進張';

  @override
  String get tipOrdinaryNote =>
      '\n這是平均數，不是中位數：透過只追求牌效率、不防守也不鳴牌的單人模擬，測得各向聽數下最佳打牌的平均進張。';

  @override
  String get tipSafetyTitle => '安全度\n';

  @override
  String get tipSafetyChinese => '面對有明露面子的對手時，打出此牌的風險。越高越安全。\n';

  @override
  String get tipSafetyRiichi => '面對立直時打出此牌的安全度。0 為危險，15 為現物。\n';

  @override
  String get tipNeverCertain => '沒有絕對安全';

  @override
  String get tipNeverCertainBody => '沒有振聽規則，對手打過的牌仍可能讓其和牌';

  @override
  String get tipRatedWhen => '評估條件';

  @override
  String get tipGenbutsu => '現物';

  @override
  String get tipGenbutsuBody => '對手打過的牌，或其立直後放過的牌，不會讓其榮和';

  @override
  String get tipSuji => '筋';

  @override
  String get tipSujiBody => '與對手捨牌相差三的牌相對安全';

  @override
  String get tipRatedRiichi => '有人立直時才評估，否則顯示 —';

  @override
  String get tipDealInTitle => '打牌放銃機率';

  @override
  String get tipRating => '評級';

  @override
  String get tipTile => '牌';

  @override
  String get tipDealsIn => '放銃率';

  @override
  String get tipRating15 => '現物 — 對手已打過的牌';

  @override
  String get tipRating13 => '字牌，剩餘1張';

  @override
  String get tipRating12 => '雙筋';

  @override
  String get tipRating11 => '筋么九牌';

  @override
  String get tipRating9 => '字牌，剩餘2張';

  @override
  String get tipRating8 => '無機會牌';

  @override
  String get tipRating7 => '半筋';

  @override
  String get tipRating6 => '筋2/3/7/8，或剩餘3張的字牌';

  @override
  String get tipRating3 => '無筋2/3/7/8';

  @override
  String get tipRating2 => '無筋中張牌';

  @override
  String get tipHkRating14 => '字牌，未見0張';

  @override
  String get tipHkRating11 => '字牌，未見1張';

  @override
  String get tipHkRating6 => '字牌，未見2張以上';

  @override
  String get tipHkRating5 => '么九牌';

  @override
  String get tipHkRating3 => '數牌';

  @override
  String get tipRiskTitle => '風險\n';

  @override
  String get tipDealInChance => '放銃機率';

  @override
  String get tipDealInChanceBody => '根據此牌的安全度計算';

  @override
  String get tipDealInCost => '放銃損失';

  @override
  String get tipStyleWeight => '風格權重';

  @override
  String get tipLaterTurns => '後續巡數';

  @override
  String get tipHowLong => '持續時間';

  @override
  String get tipChineseHorizon => '按本局預計剩餘時間計算；無風險的打牌不產生額外成本';

  @override
  String get tipFormula => '公式';

  @override
  String get tipDetailTitle => '詳情\n';

  @override
  String get tipDetailBody => '說明此牌獲得該安全度評級的原因。\n';

  @override
  String get tipShows => '顯示內容';

  @override
  String get tipShowsBody => '現物、筋、字牌剩餘張數等';

  @override
  String get tipEmpty => '為空時';

  @override
  String get tipEmptyBody => '沒有防守對象，因此沒有說明';

  @override
  String get tipPlacementTitle => '順位\n';

  @override
  String get tipPlacementBody => '此打法如何改變你最終領先其他三家的機率。\n';

  @override
  String get tipUses => '依據';

  @override
  String get tipUsesBody => '目前各家點數和剩餘局數';

  @override
  String get tipNotPoints => '不是點數';

  @override
  String get tipNotPointsBody => '為便於閱讀放大1,000倍；僅與其他打法的相對排序有意義';

  @override
  String get tipHeuristic => '啟發式估算';

  @override
  String get tipHeuristicBody => '不是模擬結果';

  @override
  String get tipWorthTitle => '8,000點的價值';

  @override
  String get tipSituation => '局勢';

  @override
  String get tipHandsLeft => '剩餘局數';

  @override
  String get tipEven => '點數接近';

  @override
  String get tipLead => '大幅領先';

  @override
  String get tipBehind => '大幅落後';

  @override
  String get tipEvenLast => '點數接近，最後一局';

  @override
  String get tipLeadLast => '大幅領先，最後一局';

  @override
  String get tipPlacementNote => '\n點數在局勢接近和對局末期時最重要，在大幅領先時影響最小。\n';

  @override
  String get tipNoWin => '此打法尚無可計分的和牌形。\n';

  @override
  String get tipRiskRow => '此牌風險';

  @override
  String get tipFinishRow => '和牌機率';

  @override
  String get tipPayoutRow => '和牌收益';

  @override
  String get tipSticksRow => '本場與立直棒';

  @override
  String get tipAverageRow => '平均收益';

  @override
  String get tipLockRow => '減去立直鎖定成本';

  @override
  String get tipDealInRow => '減去放銃風險';

  @override
  String get tipCommitRow => '減去後續巡數成本';

  @override
  String get tipHmrBody => '僅用於比較的數值，不會影響建議。\n';

  @override
  String get tipHmrExcludes => '\n不計本場、立直棒、風險成本或風格與側重點調整。\n';

  @override
  String get tipHmrSource => '\n對應以下工具的「E.V.」統計：';

  @override
  String get tipHmrSourceBody => '，這是一款僅限自摸的單人練習工具：總得點 ÷ 對局數，即和牌率 × 平均和牌得點。';

  @override
  String get tipYakuBody =>
      '每條柱形表示：此打法和牌時包含該役的比例。一次和牌通常包含多個役，因此總和不為100%。100%表示每次和牌都有該役；計畫立直時，立直為100%。\n\n乘以和牌機率，即為總體出現機率。\n\n寶牌不是役，因此另列為平均額外番數。\n\n≈表示估算：未聽牌時，指南假定持續選擇進張最寬的打法，並對最可能到達的聽牌形計分。它不會主動規劃役牌或染手等需要刻意追求的役，因此這些役可能偏低。距離聽牌超過三張時暫不顯示。';

  @override
  String get tipMortalBody =>
      'Mortal 是開源深度學習麻將 AI，只使用你所在座位可見的資訊。★標出其建議打牌（★R表示先立直）；數字表示其他候選項的優先順序。Mortal 的建議用紅框標出，指南的建議填充綠色；綠色加紅框表示兩者一致。\n\n';

  @override
  String get tipMortalAuto =>
      '自動打牌選擇 Mortal 時，會按其建議行動，列表也按其偏好排序。選擇 TileSense（預設）時，按指南排序，Mortal 僅供參考。綠色牌始終是指南的建議。Mortal 無法回答時由指南決定。\n\n';

  @override
  String get tipMortalSource =>
      '適用於單人立直麻將。Mortal 及其模型權重採用 AGPL-3.0：原始碼 github.com/Equim-chan/Mortal；執行服務 github.com/eric-r-xu/TileSense (mortal_sidecar)。';

  @override
  String get tipYakuTitle => '役\n';

  @override
  String tipEvAverage(String unit) {
    return '此打牌對你的平均價值，以$unit計（EV＝期望值）。\n';
  }

  @override
  String tipShantenBody(String ready) {
    return '距離聽牌所需的張數（0表示$ready）。';
  }

  @override
  String tipUkeireBody(String effect) {
    return '能$effect的剩餘有效牌，即有幫助的摸牌數量。\n';
  }

  @override
  String tipThreatSets(String count) {
    return '對手有$count組以上明露面子，否則顯示 —';
  }

  @override
  String tipChineseCost(String cost, String unit) {
    return '\n放銃損失按$cost$unit計算。';
  }

  @override
  String tipRiichiCost(String cost, String dealerCost) {
    return '$cost點（對莊家為$dealerCost點），每本場另加300點';
  }

  @override
  String tipRiichiCostNote(String cost, String dealerCost) {
    return '\n放銃損失為$cost點（對莊家為$dealerCost點），每本場另加300點。';
  }

  @override
  String tipRiskBody(String unit) {
    return '因打出此牌的風險而從期望值中扣除的$unit。\n';
  }

  @override
  String tipStyleWeights(String weights, String styles) {
    return '$styles對應×$weights';
  }

  @override
  String tipCommitPercent(String percent) {
    return '此打牌每需繼續一巡，再加計成本的$percent%';
  }

  @override
  String tipRiichiHorizon(String turns) {
    return '按立直持續時間計算，約為你打牌$turns次；打現物不產生額外成本';
  }

  @override
  String tipThisCut(String tile) {
    return '\n此打牌 — $tile\n';
  }

  @override
  String tipFocusTilt(String focus) {
    return '$focus調整';
  }

  @override
  String tipRankOrder(String name, String direction) {
    return '$name（$direction優先）';
  }

  @override
  String tipRankDirection(String direction) {
    return '\n\n$direction越好，標題箭頭表示該方向。';
  }

  @override
  String tipRankBody(String first, String second, String third) {
    return '打牌先按$first，再按$second，最後按$third排序；顯示數值相同則視為相等。首選牌顯示綠色，三項均與首選相同的牌也顯示綠色。';
  }

  @override
  String get tipReady => '聽牌';

  @override
  String get tipTenpai => '聽牌';

  @override
  String get tipCloser => '更接近聽牌';

  @override
  String get tipReduce => '減少向聽數';

  @override
  String get tipHigher => '越高';

  @override
  String get tipLower => '越低';

  @override
  String get tipHigherFirst => '較高';

  @override
  String get tipLowerFirst => '較低';

  @override
  String get tipPlacementLabel => '順位';

  @override
  String get tipPointsUnit => '點';

  @override
  String get tipChipsUnit => '籌碼';

  @override
  String get tipBalanced => '平衡';

  @override
  String get tipSpeed => '速度';

  @override
  String get tipAggressive => '進攻';

  @override
  String get tipPoints => '點數';

  @override
  String get tipDefensive => '防守';

  @override
  String get mathChance => '機率';

  @override
  String get mathFinish => '和牌';

  @override
  String get mathPayout => '收益';

  @override
  String get mathWin => '和牌';

  @override
  String get mathRisk => '風險';

  @override
  String get mathCut => '打牌';

  @override
  String get mathDealIn => '放銃';

  @override
  String get mathCost => '損失';

  @override
  String get mathWeight => '權重';

  @override
  String get mathStyle => '風格';

  @override
  String get mathCharge => '成本';

  @override
  String get mathLaterTurns => '後續巡數';

  @override
  String get mathWorth => '價值';

  @override
  String get mathGain => '增減';

  @override
  String get mathScore => '點數';

  @override
  String get mathOthers => '其他三家';

  @override
  String get mathTheirs => '對手';

  @override
  String get mathSpread => '分散尺度';

  @override
  String get mathHandsLeft => '剩餘局數';

  @override
  String get mathLogistic => '邏輯函數';

  @override
  String mascotIntro(String mascot, String app) {
    return '我是$mascot，一半草原犬鼠，一半美西螈。\n我會幫你選擇最佳打牌和鳴牌。\n開啟自動打牌，我就替你打。\n打錯了？撤回再試一次。\n一起玩，提升你的$app！';
  }

  @override
  String get rulesetMcr => '國標麻將 (MCR)';

  @override
  String get rulesetSubtitleMcr => '番、花牌、最低8番';

  @override
  String get mcrFullGame => '全場 · 16局';

  @override
  String get mcrPractice => '東風練習 · 4局';

  @override
  String mcrScoreTotal(int fan, int flowers, int gain) {
    return '$fan番 + 花牌$flowers · +$gain分';
  }

  @override
  String yakuLineMcr(String name, int n) {
    return '$name  $n番';
  }

  @override
  String get tipPayoutMcr =>
      '番數加花牌（F）：放槍者付 F＋8，其他兩家各付 8；自摸則每家付 F＋8。聽牌時為準確值，且不計花牌達到8番的聽牌才能和牌；之前為估計值。\n';

  @override
  String get rulesetSichuan => '四川麻將';

  @override
  String get rulesetSubtitleSichuan => '血戰到底、定缺、不能吃';

  @override
  String get sichuanFullGame => '全場 · 8局';

  @override
  String get sichuanPractice => '練習 · 4局';

  @override
  String get voidSuitTitle => '選擇定缺花色';

  @override
  String get voidSuitHint => '必須先打完這一門的牌才能打其他牌，手中仍有這一門的牌時不能和牌。';

  @override
  String get voidSuitWaiting => '等待其他玩家選擇…';

  @override
  String get suitMan => '萬';

  @override
  String get suitPin => '筒';

  @override
  String get suitSou => '條';

  @override
  String get voidSuitSuggested => '推薦';

  @override
  String voidSuitBadge(String suit) {
    return '缺：$suit';
  }

  @override
  String get voidSuitUnknown => '缺：?';

  @override
  String get voidFirstNotice => '請先打出定缺的牌';

  @override
  String get huOutBadge => '胡';

  @override
  String get sichuanPayHu => '胡牌';

  @override
  String get sichuanPayKong => '槓';

  @override
  String get sichuanPayReady => '查叫';

  @override
  String get sichuanPayPenalty => '定缺罰分';

  @override
  String get resultWallEnds => '牌牆結束';

  @override
  String get resultThreeHu => '三家胡牌';

  @override
  String get scRoot => '根';

  @override
  String get scAllPungs => '對對胡';

  @override
  String get scFullFlush => '清一色';

  @override
  String get scSevenPairs => '七對';

  @override
  String get scGoldenSingleWait => '金鉤釣';

  @override
  String get scWinAfterKong => '槓上開花';

  @override
  String get scRobbingTheKong => '搶槓胡';

  @override
  String get scShootAfterKong => '槓上炮';

  @override
  String get scUnderTheSea => '海底';

  @override
  String statusHandNumber(int n) {
    return '第$n局';
  }

  @override
  String sichuanScoreTotal(int fan, int value) {
    return '$fan番 · 牌值$value分';
  }

  @override
  String get learnToPlay => '新手教學';

  @override
  String get learnNewLink => '第一次玩麻將？看看怎麼玩';

  @override
  String learnStepOf(int current, int total) {
    return '$current / $total';
  }

  @override
  String get learnNext => '下一步';

  @override
  String get learnSkip => '跳過';

  @override
  String get learnDone => '開始遊戲';

  @override
  String get learnGoalTitle => '目標';

  @override
  String get learnGoalBody =>
      '湊成14張牌的手牌：四組牌加一對將。每回合摸一張牌、打出一張牌，一步步湊成這個牌型。最先湊成的人贏下這一局。';

  @override
  String get learnTilesTitle => '牌的種類';

  @override
  String get learnTilesBody =>
      '有三種花色，數字1到9（萬子、筒子、條子），另有四種風牌和三種箭牌。部分規則（例如香港麻雀）還加入花牌：花牌帶來獎勵番數，並從牌牆補牌。';

  @override
  String get learnSetsTitle => '牌組與吃碰槓';

  @override
  String get learnSetsBody =>
      '一組牌可以是同花色的三張順子（上），三張相同的牌（碰），或四張相同的牌（槓）。你可以要別人打出的牌來完成一組，但「上」只能要上家（左手邊）的牌。要來的牌組要亮在桌面上。';

  @override
  String get learnWinTitle => '食糊';

  @override
  String get learnWinBodyHongKong =>
      '湊齊四組牌和一對將，無論是自己摸到最後一張，還是要別人打出的牌，就食糊了。預設最低0番，所以只要牌型完整，再簡單的牌也能食糊。牌桌上的提示會告訴你離食糊還差幾張。';

  @override
  String learnWinBodyOther(String rules) {
    return '湊齊四組牌和一對將，並且滿足$rules自己的要求，就能食糊。牌桌上的提示會告訴你離食糊還差幾張。';
  }

  @override
  String get guideViewSimple => '簡單';

  @override
  String get guideViewFull => '完整';

  @override
  String get guideViewToFullTip => '簡單提示。點擊查看完整表格（向聽、期望值、安全度）。';

  @override
  String get guideViewToSimpleTip => '完整提示。點擊切換為簡單檢視。';

  @override
  String get guideStatusComplete => '你的牌已經湊齊了！';

  @override
  String get guideBestDiscard => '最佳打牌';

  @override
  String get guideOtherChoices => '其他選擇';

  @override
  String get guideOutlookWins => '湊齊你的手牌！';

  @override
  String guideOutlookWaiting(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n張',
    );
    return '打出後聽$_temp0牌就能食糊。';
  }

  @override
  String guideOutlookOnTrack(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n張',
    );
    return '保持進度，還有$_temp0有用的牌。';
  }

  @override
  String get guideOutlookFurther => '會讓你離食糊更遠。';

  @override
  String get guideCallTake => '提示會要這張牌。';

  @override
  String get guideCallPass => '提示會放過這張牌。';

  @override
  String handPromptWin(String tile, String call) {
    return '你可以用$tile食糊！點擊「$call」。';
  }

  @override
  String handPromptTsumo(String call) {
    return '你的牌已湊齊！點擊「$call」。';
  }

  @override
  String handPromptCall(String tile, String calls) {
    return '你可以$calls$tile，也可以放過。';
  }

  @override
  String get handPromptDiscard => '輪到你了：點擊一張牌打出。';

  @override
  String guideAway(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n張',
    );
    return '離食糊還差$_temp0';
  }

  @override
  String guideWinningTiles(int n) {
    return '能食糊的牌 · 還剩$n張';
  }

  @override
  String get guideOutlookOnTrackFar => '保持進度。';

  @override
  String get glossaryTitle => '術語表';

  @override
  String get glossarySearchHint => '搜尋術語';

  @override
  String get glossaryNoMatch => '沒有符合的術語。';

  @override
  String get glossaryUnitHan => '翻';

  @override
  String get glossaryUnitFaan => '番';

  @override
  String get glossaryUnitTai => '台';

  @override
  String get glossaryUnitFan => '番';

  @override
  String get glossaryTermSet => '牌組';

  @override
  String get glossaryDefSet => '湊在一起的三張牌：同花色的三張順子，或三張相同的牌。四張相同的牌也算，叫做槓。';

  @override
  String get glossaryTermPair => '將（對子）';

  @override
  String get glossaryDefPair => '兩張相同的牌。食糊的牌型是四組牌加一對將。';

  @override
  String get glossaryDefChi => '要別人打出的牌，湊成同花色的三張順子。只能要上家（左手邊）的牌，湊好的牌組要亮在桌面上。';

  @override
  String get glossaryDefPon => '要一張與你手中兩張相同的牌，可以要任何人打出的，湊成三張相同的牌。湊好的牌組要亮在桌面上。';

  @override
  String get glossaryDefKan => '四張相同的牌。槓完之後，要從牌牆末端補一張牌。';

  @override
  String get glossaryTermDiscard => '打牌';

  @override
  String get glossaryDefDiscard => '每回合結束時打出的那張牌，亮在你面前。其他玩家有時可以要這張牌。';

  @override
  String get glossaryDefTsumo => '糊的是自己摸到的牌。';

  @override
  String get glossaryDefRon => '糊的是別人打出的牌。';

  @override
  String get glossaryTermDealer => '莊家';

  @override
  String get glossaryDefDealer => '坐在東位、最先出牌的玩家。食糊通常能讓莊家繼續坐莊。';

  @override
  String get glossaryTermWinds => '風牌';

  @override
  String get glossaryDefWinds => '東、南、西、北四種牌，也用來稱呼座位和圈風。自己座位的風或圈風的牌組可能有加分。';

  @override
  String get glossaryTermDragons => '箭牌';

  @override
  String get glossaryDefDragons => '白板、發財、紅中三種牌。任何箭牌的牌組都有加分。';

  @override
  String get glossaryTermFlowers => '花牌';

  @override
  String get glossaryDefFlowers => '獎勵牌。摸到後亮出來，再從牌牆補一張牌。每張花牌都可能為糊牌加分。';

  @override
  String get glossaryTermVoid => '缺門';

  @override
  String get glossaryDefVoid => '開局時放棄三種花色中的一種。只要你手裡還有這門的牌，就必須先打出它們。';

  @override
  String get glossaryDefScore => '糊牌所得的價值。越多，牌越值錢。有些牌桌規定了食糊所需的最低值。';

  @override
  String get glossaryTermRiichi => '立直';

  @override
  String get glossaryDefRiichi =>
      '牌是門清、再差一張就糊時，押上1,000點宣告。之後手牌鎖定，只能打出摸到的牌。立直會帶來額外得分。';

  @override
  String get glossaryTermDora => '寶牌';

  @override
  String get glossaryDefDora => '由桌上的寶牌指示牌決定的獎勵牌。糊牌時手裡每有一張，加一翻。';

  @override
  String get glossaryTermFuriten => '振聽';

  @override
  String get glossaryDefFuriten => '如果能糊的牌在自己的打牌裡，就不能糊別人打出的牌。自摸仍然可以食糊。';

  @override
  String get glossaryTermReady => '聽牌';

  @override
  String get glossaryDefReady => '再差一張就能糊的牌。提示會告訴你哪些牌能糊。';

  @override
  String get glossaryTermAway => '還差幾張';

  @override
  String get glossaryDefAway =>
      '手牌還需要幾張才能食糊。還差一張就是聽牌。提示的進度條和「Away」或「Shanten」一列會顯示。';

  @override
  String get glossaryTermHelpful => '有用的牌';

  @override
  String get glossaryDefHelpful => '摸到後能讓手牌更接近食糊的牌。提示會統計還有多少張沒出現。';

  @override
  String get learnTile => '學習／訓練';

  @override
  String get moreTile => '更多';

  @override
  String get practiceTitle => '練習題';

  @override
  String get practiceLink => '練習題';

  @override
  String practiceProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get practiceAskWin => '這手牌再差一張就能食糊。哪張牌能湊齊？';

  @override
  String get practiceAskDiscard => '你摸了一張牌。打出哪張，能讓手牌再差一張就食糊？';

  @override
  String get practiceAskClaim => '對這張打出的牌，你能做什麼？';

  @override
  String practiceDiscardedBy(String seat) {
    return '打牌的人：$seat';
  }

  @override
  String get practiceYourHand => '你的手牌';

  @override
  String get practiceCorrect => '答對了！';

  @override
  String get practiceWrong => '不太對。';

  @override
  String get practiceNext => '下一題';

  @override
  String get practiceSeeResults => '查看結果';

  @override
  String practiceResult(int score, int total) {
    return '共$total題，你答對了$score題。';
  }

  @override
  String get practiceAgain => '再來一次';

  @override
  String get practiceOptionPass => '放過';

  @override
  String get practiceWhyW1 => '三組牌和將牌55s已經湊好。1p和3p中間需要一張2p，才能湊成1-2-3順子。';

  @override
  String get practiceWhyW2 => '1p和2p只能湊成1-2-3，所以只有3p能糊。這樣的邊張聽牌，只有一種牌能糊。';

  @override
  String get practiceWhyW3 => '四組牌已經湊好。單獨的5s還要再來一張5s湊成將，所以只有5s能糊。';

  @override
  String get practiceWhyD1 =>
      '三組牌、將牌66p和3p-4p都能配合。單獨的9s和別的牌沒有聯繫，打出它，你就再差一張就糊，聽2p或5p。';

  @override
  String get practiceWhyD2 => '東和別的牌沒有聯繫。打出它，1s-2s就聽3s。';

  @override
  String get practiceWhyD3 => '單獨的西和別的牌沒有聯繫。打出它，7s-8s就聽6s或9s。';

  @override
  String practiceWhyC1(String call) {
    return '你有兩張5p，從任何人那裡再要一張，就湊成三張相同的牌。這叫$call。';
  }

  @override
  String practiceWhyC2(String call) {
    return '你左手邊的玩家打出了5p，正好補在你的4p和6p中間湊成順子。這叫$call。';
  }

  @override
  String get practiceWhyC3 => '順子只能要左手邊玩家的牌。這張5p是別人打的，不能用來湊順子，所以放過。';

  @override
  String get practiceWhyC4 => '你手裡沒有能和東配對的牌，也湊不成順子，所以沒什麼可要的。放過。';

  @override
  String get practiceChoices => '選擇一張牌';

  @override
  String get practiceLegend => 'm＝萬子，p＝筒子，s＝條子';

  @override
  String nudgeFullGuide(int n) {
    return '你已經食糊了$n手牌。想看更多細節嗎？完整提示會顯示每條建議背後的數字。';
  }

  @override
  String get nudgeFullGuideAction => '顯示完整提示';

  @override
  String nudgeMinimum(int n) {
    return '你已經食糊了$n手牌。試試最低1番吧：現在手牌需要多一點價值才能食糊。';
  }

  @override
  String get nudgeMinimumAction => '改用最低1番';

  @override
  String nudgeRuleset(int n, String rules) {
    return '你已經食糊了$n手牌。想來點新挑戰嗎？試試$rules。';
  }

  @override
  String nudgeRulesetAction(String rules) {
    return '切換到$rules';
  }

  @override
  String get nudgeNotNow => '暫時不要';

  @override
  String get nudgeStop => '不再提示';

  @override
  String get quizTitle => 'TileSensor會怎麼打？';

  @override
  String get quizAskDiscard => '輪到你了，你剛摸了一張牌。你怎麼做？';

  @override
  String quizAskCall(String seat) {
    return '$seat剛打出一張牌。你怎麼做？';
  }

  @override
  String get quizDiscard => '打牌';

  @override
  String get quizRiichi => '立直';

  @override
  String get quizYourHand => '你的手牌';

  @override
  String get quizChoose => '请選擇一項';

  @override
  String get quizYouPicked => '你的選擇';

  @override
  String get quizBestMove => '最佳選擇';

  @override
  String get quizAgree => 'TileSense與Mortal一致';

  @override
  String get quizTileSenseSays => 'TileSense為何推薦';

  @override
  String get quizMortalSays => 'Mortal的評價';

  @override
  String get quizShanten => '向聽數';

  @override
  String get quizUkeire => '進張';

  @override
  String get quizEv => '期望值';

  @override
  String get quizRisk => '風險';

  @override
  String quizMortalRank(int rank, int total) {
    return 'Mortal把你的選擇排在$total個選項中的第$rank位。';
  }

  @override
  String get quizMortalPicked => 'Mortal也選了這一手。';

  @override
  String get quizMortalRankFirst => '這是Mortal的首選。';

  @override
  String get quizMortalKan => 'Mortal在這裡也會槓。';

  @override
  String get quizMortalNoKan => 'Mortal在這裡不會槓。';

  @override
  String get quizMortalNote => 'Mortal不會解釋原因，這是它的排名。';

  @override
  String get quizSeat => '座位';

  @override
  String get quizDora => '寶牌指示牌';

  @override
  String quizProgress(int number, int total) {
    return '第$number題，共$total題';
  }

  @override
  String get quizNext => '下一題';

  @override
  String get quizSeeResults => '查看今天的結果';

  @override
  String get quizResultsTitle => '今天的題目已完成';

  @override
  String quizResultsScore(int right, int total) {
    return '$total題中答對了$right題。';
  }

  @override
  String get quizDone => '明天再來挑戰新題目。';

  @override
  String get quizLoadFailed => '無法載入今天的題目。';

  @override
  String get quizLink => '每日一題';

  @override
  String get quizCardToday => '今天的題目已準備好';

  @override
  String get quizCardDone => '今天已完成，明天再來！';

  @override
  String quizStreak(int days) {
    return '連續$days天';
  }

  @override
  String get loadingQuiz => '正在載入每日一題…';

  @override
  String get quizDama => '默聽';

  @override
  String get quizAskRiichi => '這樣打牌就聽牌了。你要立直，還是默聽？';

  @override
  String get quizMortalRiichi => 'Mortal在這裡會立直。';

  @override
  String get quizMortalDama => 'Mortal在這裡會默聽。';

  @override
  String get quizSituation => '局面';

  @override
  String quizRoundLine(String wind, int hand, int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: '還剩$left局',
      one: '最後一局',
    );
    return '$wind$hand局：$_temp0。';
  }

  @override
  String get quizStageEarly => '本局前期';

  @override
  String get quizStageMiddle => '本局中期';

  @override
  String get quizStageLate => '本局後期';

  @override
  String quizTimingLine(String stage, int wall) {
    return '$stage：牌山還剩$wall張。';
  }

  @override
  String get quizDealerYes => '你是莊家：和牌點數是閒家的1.5倍，並且可以連莊。';

  @override
  String get quizDealerNo => '你不是莊家。';

  @override
  String quizPlaceEven(String points) {
    return '四家都是$points點，名次不受影響。';
  }

  @override
  String quizPlaceLead(int rank, String lead) {
    return '名次：四家中第$rank，領先下一家$lead點。';
  }

  @override
  String quizPlaceBehind(int rank, String gap) {
    return '名次：四家中第$rank，落後第一名$gap點。';
  }

  @override
  String quizThreat(String seat, int turns) {
    return '$seat正在立直（$turns巡前宣告）。';
  }

  @override
  String get quizNoThreat => '其他人都沒有立直。';

  @override
  String get quizFocusPlacement => '最後幾局：TileSense會考慮每個選擇對最終名次的影響，而不只看點數。';

  @override
  String get quizFocusPoints => '還有很多局：TileSense以點數為重。';

  @override
  String get rulesetSanma => '三人麻將';

  @override
  String get rulesetSanmaLong => '三麻（三人日本麻將）';

  @override
  String get rulesetSubtitleSanma => '三人立直麻將：不能吃、拔北、去掉二至八萬';

  @override
  String get sanmaTooltip =>
      '三麻是三人玩的日本立直麻將：三名玩家，108張牌（去掉二至八萬），不能吃，北風牌可以拔出當作寶牌。';

  @override
  String rulesWeb(String rules) {
    return '$rules規則（網頁，英文）';
  }

  @override
  String get kitaCaps => '拔北';

  @override
  String get bubbleKita => '拔北';

  @override
  String get undoKita => '拔北';

  @override
  String get yakuKita => '拔北寶牌';

  @override
  String get emptySeatSanma => '空位：三麻只有三名玩家';

  @override
  String hanchanOnTooltipSanma(String caveat) {
    return '半莊——三人麻將的東風圈和南風圈，6局以上（每圈3局）。\n$caveat\n點按切換為東風戰，3局以上。';
  }

  @override
  String eastOnlyTooltipSanma(String caveat) {
    return '東風戰——三人麻將只打東風圈，3局以上。\n$caveat\n點按切換為半莊：東風圈和南風圈，6局以上。';
  }

  @override
  String get glossaryTermSanma => '三麻';

  @override
  String get glossaryDefSanma =>
      '三人玩的日本立直麻將。去掉二至八萬，共108張牌；不能吃；座位為東、南、西；每人起始35,000點。自摸只由另外兩人支付，所以比同一手牌榮和便宜。';

  @override
  String get glossaryTermKita => '拔北';

  @override
  String get glossaryDefKita =>
      '三麻中可以把北風牌拔出來而不留在手裡：它算作一張寶牌，並從王牌補摸一張。其他玩家可以榮和這張北。';

  @override
  String get quizNoneSanma => '三人麻將還沒有每日一題。切換到日本麻將或香港麻將即可挑戰。';

  @override
  String get tourHandTitle => '你的手牌';

  @override
  String get tourHandBody => '點按一張牌把它抬起，再點一次就打出。想調整順序，長按一張牌，然後拖到新的位置。';

  @override
  String get tourButtonsTitle => '手牌旁邊的按鈕';

  @override
  String get tourButtonsBody => '四個開關決定手牌怎麼操作。打開時會填滿顏色。';

  @override
  String get tourLegendSortBody =>
      '點按在三種模式間切換。「手牌」讓牌保持排序，摸到的牌放在右邊；「手牌+摸牌」把摸到的牌直接排進去；「關」讓每張牌留在你拖放的位置。';

  @override
  String get tourLegendDiscardBody => '點一次就打牌，或者點兩次（先抬起再打出）。';

  @override
  String get tourLegendAutoWinBody => '一能和牌就自動替你宣告。';

  @override
  String get tourLegendAutoPassBody => '自動放棄其他玩家打出的牌的吃碰槓，不再詢問。';

  @override
  String get tourGuideTitle => '你的嚮導 TileSensor';

  @override
  String get tourGuideBody =>
      '點按 TileSensor 打開嚮導。它為每一張可打的牌排序，用綠色標出最佳選擇並說明原因。再點一次即可隱藏。';

  @override
  String get tourRulesTitle => '規則手冊';

  @override
  String get tourRulesBodyDesktop =>
      '頂部欄的書本圖示可開啟本局的規則手冊：每個計分牌型都有牌例，還有和牌條件、起和要求與支付，隨時可以搜尋。';

  @override
  String get tourRulesBodyPhone =>
      '開啟選單，再點「規則」，即可閱讀本局的規則手冊：每個計分牌型都有牌例，還有和牌條件、起和要求與支付，隨時可以搜尋。';

  @override
  String get tourRulesOpen => '開啟規則手冊';

  @override
  String get tourMenuTitle => '設定和說明';

  @override
  String get tourMenuBodyPhone => '選單按鈕裡有暫停、聲音、速度、自動打牌和術語表。也可以在那裡重看這段導覽。';

  @override
  String get tourMenuBodyDesktop =>
      '設定排在頂部欄，術語表在規則名稱旁邊。左上角的選單返回主選單，可在「學習」裡重看這段導覽。';

  @override
  String get tourSkip => '跳過導覽';

  @override
  String get tourNext => '下一步';

  @override
  String get tourDone => '開始打牌';

  @override
  String get tableTourLink => '牌桌導覽：怎樣操作牌桌';

  @override
  String get tableTourMenu => '牌桌怎麼用';

  @override
  String tourStepOf(int step, int total) {
    return '第$step步，共$total步';
  }

  @override
  String get rulesTileTooltip => '選擇要玩的麻將規則：日本麻將、三人麻將、香港、台灣、國標或四川。';

  @override
  String get rulesRead => '閱讀規則';

  @override
  String get rulesSearchHint => '搜尋規則';

  @override
  String get rulesClearSearch => '清除搜尋';

  @override
  String get rulesNoMatch => '沒有符合的規則，請嘗試其他詞語。';

  @override
  String get rulesSummaryNotice =>
      'TileSense 規則簡介，並列出應用程式計算的所有番種。譯文由 TileSense 提供，規則以外部參考資料（英文）為準。';

  @override
  String get rulesReferenceFailed => '無法開啟參考資料，請重試。';

  @override
  String get mcrFanBigFourWinds => '大四喜';

  @override
  String get mcrFanBigThreeDragons => '大三元';

  @override
  String get mcrFanAllGreen => '綠一色';

  @override
  String get mcrFanNineGates => '九蓮寶燈';

  @override
  String get mcrFanFourKongs => '四槓';

  @override
  String get mcrFanSevenShiftedPairs => '連七對';

  @override
  String get mcrFanThirteenOrphans => '十三幺';

  @override
  String get mcrFanAllTerminals => '清幺九';

  @override
  String get mcrFanLittleFourWinds => '小四喜';

  @override
  String get mcrFanLittleThreeDragons => '小三元';

  @override
  String get mcrFanAllHonors => '字一色';

  @override
  String get mcrFanFourConcealedPungs => '四暗刻';

  @override
  String get mcrFanPureTerminalChows => '一色雙龍會';

  @override
  String get mcrFanQuadrupleChow => '一色四同順';

  @override
  String get mcrFanFourPureShiftedPungs => '一色四節高';

  @override
  String get mcrFanFourShiftedChows => '一色四步高';

  @override
  String get mcrFanThreeKongs => '三槓';

  @override
  String get mcrFanAllTerminalsAndHonors => '混幺九';

  @override
  String get mcrFanSevenPairs => '七對';

  @override
  String get mcrFanGreaterHonorsAndKnittedTiles => '七星不靠';

  @override
  String get mcrFanAllEvenPungs => '全雙刻';

  @override
  String get mcrFanFullFlush => '清一色';

  @override
  String get mcrFanPureTripleChow => '一色三同順';

  @override
  String get mcrFanPureShiftedPungs => '一色三節高';

  @override
  String get mcrFanUpperTiles => '全大';

  @override
  String get mcrFanMiddleTiles => '全中';

  @override
  String get mcrFanLowerTiles => '全小';

  @override
  String get mcrFanPureStraight => '清龍';

  @override
  String get mcrFanThreeSuitedTerminalChows => '三色雙龍會';

  @override
  String get mcrFanPureShiftedChows => '一色三步高';

  @override
  String get mcrFanAllFives => '全帶五';

  @override
  String get mcrFanTriplePung => '三同刻';

  @override
  String get mcrFanThreeConcealedPungs => '三暗刻';

  @override
  String get mcrFanLesserHonorsAndKnittedTiles => '全不靠';

  @override
  String get mcrFanKnittedStraight => '組合龍';

  @override
  String get mcrFanUpperFour => '大於五';

  @override
  String get mcrFanLowerFour => '小於五';

  @override
  String get mcrFanBigThreeWinds => '三風刻';

  @override
  String get mcrFanMixedStraight => '花龍';

  @override
  String get mcrFanReversibleTiles => '推不倒';

  @override
  String get mcrFanMixedTripleChow => '三色三同順';

  @override
  String get mcrFanMixedShiftedPungs => '三色三節高';

  @override
  String get mcrFanChickenHand => '無番和';

  @override
  String get mcrFanLastTileDraw => '妙手回春';

  @override
  String get mcrFanLastTileClaim => '海底撈月';

  @override
  String get mcrFanOutWithReplacementTile => '槓上開花';

  @override
  String get mcrFanRobbingTheKong => '搶槓和';

  @override
  String get mcrFanTwoConcealedKongs => '雙暗槓';

  @override
  String get mcrFanAllPungs => '碰碰和';

  @override
  String get mcrFanHalfFlush => '混一色';

  @override
  String get mcrFanMixedShiftedChows => '三色三步高';

  @override
  String get mcrFanAllTypes => '五門齊';

  @override
  String get mcrFanMeldedHand => '全求人';

  @override
  String get mcrFanTwoDragonPungs => '雙箭刻';

  @override
  String get mcrFanOutsideHand => '全帶幺';

  @override
  String get mcrFanFullyConcealed => '不求人';

  @override
  String get mcrFanTwoMeldedKongs => '雙明槓';

  @override
  String get mcrFanLastTile => '和絕張';

  @override
  String get mcrFanDragonPung => '箭刻';

  @override
  String get mcrFanPrevalentWind => '圈風刻';

  @override
  String get mcrFanSeatWind => '門風刻';

  @override
  String get mcrFanConcealedHand => '門前清';

  @override
  String get mcrFanAllChows => '平和';

  @override
  String get mcrFanTileHog => '四歸一';

  @override
  String get mcrFanDoublePung => '雙同刻';

  @override
  String get mcrFanTwoConcealedPungs => '雙暗刻';

  @override
  String get mcrFanConcealedKong => '暗槓';

  @override
  String get mcrFanAllSimples => '斷幺';

  @override
  String get mcrFanPureDoubleChow => '一般高';

  @override
  String get mcrFanMixedDoubleChow => '喜相逢';

  @override
  String get mcrFanShortStraight => '連六';

  @override
  String get mcrFanTwoTerminalChows => '老少副';

  @override
  String get mcrFanPungOfTerminalsOrHonors => '幺九刻';

  @override
  String get mcrFanMeldedKong => '明槓';

  @override
  String get mcrFanOneVoidedSuit => '缺一門';

  @override
  String get mcrFanNoHonors => '無字';

  @override
  String get mcrFanEdgeWait => '邊張';

  @override
  String get mcrFanClosedWait => '嵌張';

  @override
  String get mcrFanSingleWait => '單釣將';

  @override
  String get mcrFanSelfDrawn => '自摸';

  @override
  String get mcrFanFlowerTiles => '花牌';

  @override
  String get mcrFanMeldedAndConcealedKongs => '明暗槓';
}
