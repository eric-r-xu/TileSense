/// Simplified Chinese rules text, following [EnRulesText] section for
/// section, with each ruleset's own words as on the score screen (荣和,
/// 食糊, 胡; 番 and 台).
library;

import 'package:mahjong_core/ruleset.dart';

import 'rules_content.dart';
import 'rules_text.dart';

class ZhRulesText extends RulesText {
  const ZhRulesText();

  // 多种规则共用的句子。
  static const _drawDiscard = '摸一张，再打一张。';
  static const _hold13 = '摸牌之间手中保持13张。';
  static const _priority = '和牌优先于杠和碰，杠和碰优先于吃。';
  static const _hiddenKongs = '暗杠在本局结束前保持背面朝上。';
  static const _openPdf = '详细规则请查看 PDF。';

  @override
  List<RuleSection> riichi({required bool sanma}) => [
        RuleSection(
            'setup',
            '牌与目标',
            sanma
                ? const [
                    '三人使用108张牌，去掉二至八万。',
                    '对家空位。',
                    _hold13,
                    '以四组面子加一对雀头和牌。',
                    '七对子和国士无双是特殊和牌型。',
                    '起始点数为35,000点。',
                  ]
                : const [
                    '四人使用136张牌，含赤五。',
                    _hold13,
                    '以四组面子加一对雀头和牌。',
                    '面子是同花色三张相连的牌或三张相同的牌；杠子是四张相同的牌。',
                    '七对子和国士无双是特殊和牌型。',
                    '起始点数为25,000点。',
                  ]),
        RuleSection(
            'calls',
            '摸牌、打牌与鸣牌',
            sanma
                ? const [
                    _drawDiscard,
                    '可以碰和杠，但不能吃。',
                    '开杠后从王牌摸岭上牌。',
                    '碰或明杠后手牌副露，可计的役也随之改变。',
                  ]
                : const [
                    _drawDiscard,
                    '吃只能取上家的牌组成顺子；碰组成刻子，杠组成杠子。',
                    '和牌优先。',
                    '开杠后从王牌摸岭上牌。',
                    '吃、碰、明杠会使手牌副露，可计的役也随之改变。',
                  ]),
        const RuleSection('winning', '和牌：役与振听', [
          '摸到自己的牌和牌为自摸，和别人打出的牌为荣和。',
          '至少需要一个役，只有宝牌不能和牌。',
          '振听：听的牌中有任何一张在自己的牌河里，就不能荣和，但仍可自摸。',
          '放过荣和也会暂时不能荣和；立直后持续到本局结束。',
        ]),
        const RuleSection('riichi', '立直与宝牌', [
          '门清听牌且点数足够时，可以宣告立直并支付1,000点立直棒。',
          '之后手牌锁定：除允许的杠外，摸什么打什么。',
          '役和宝牌增加番数，符表示手牌结构。',
          '宝牌指示牌决定宝牌，赤五也加番。',
          '立直和牌时还会翻开里宝牌。',
        ]),
        if (sanma)
          const RuleSection('kita', '拔北', [
            '轮到自己时，可以拔出北算一番宝牌，再摸一张补牌。',
            '宝牌或里宝牌指示牌指向北时，同样加番。',
            '立直后只能拔刚摸到的北。',
            '拔北会使一发和第一巡的役失效。',
            '别人可以荣和拔出的北，但这不算抢杠。',
            '拔北和开杠共用八次补牌。',
            '一万为指示牌时宝牌是九万，反之亦然。',
          ]),
        RuleSection(
            'payments',
            '点数与支付',
            sanma
                ? const [
                    '番和符决定点数，点数表之上还有满贯等封顶和役满。',
                    '荣和由放铳者支付。',
                    '自摸时两位对手按四人麻将的份额支付，空位的那份无人支付（自摸损）。',
                    '荒牌流局时，未听牌者共向听牌者支付2,000点。',
                    '中途流局只有九种九牌。',
                  ]
                : const [
                    '番和符决定点数，点数表之上还有满贯等封顶和役满。',
                    '荣和由放铳者支付；自摸由所有对手支付，庄家付得更多。',
                    '本场增加每笔支付，和牌者收取桌上的立直棒。',
                    '荒牌流局时，未听牌者共向听牌者支付3,000点。',
                    '少见的符和部分双倍役满规则为近似处理。',
                  ]),
        RuleSection(
            'game',
            '庄家与对局长度',
            sanma
                ? const [
                    '半庄为东场和南场各三局；东风战为三局。',
                    '庄家连庄会延长对局。',
                  ]
                : const [
                    '半庄为东场和南场各四局；东风战为四局。',
                    '庄家和牌，或荒牌流局时庄家听牌，即可连庄。',
                  ]),
        RuleSection('source', '关于本简介', [
          '这是 TileSense 规则的速查；上面的列表涵盖计分时计算的所有役、符和满贯等级。',
          if (sanma) '三麻参考 Japanese Mahjong Wiki 的三麻说明。',
          '详情请查看外部参考资料。',
        ]),
      ];

  @override
  List<RuleSection> hongKong(String minimum) => [
        const RuleSection('setup', '牌与目标', [
          '四人使用144张牌，含八张花牌和季牌。',
          _hold13,
          '以四组面子加一对眼、七对或十三幺食糊。',
          '花牌摊开后从牌墙尾部补牌（开杠补牌也一样）；没有王牌。',
        ]),
        const RuleSection('calls', '摸牌、打牌与鸣牌', [
          _drawDiscard,
          '上（吃）只能取上家的牌组成顺子；碰组成刻子，杠组成杠子。',
          '食糊优先于杠和碰，杠和碰优先于上。',
          '加杠可以被抢杠，暗杠不能。',
          '多人可以同时食同一张牌。',
          '最后一张打出的牌只能用来食糊。',
        ]),
        RuleSection('winning', '食糊与起和番数', [
          minimum,
          '不够起和番数的牌不能食糊。',
          '起和为0番时，没有任何番种的完整牌（鸡糊）也可以食糊。',
          '自摸本身加番，所以食别人的牌不够番时，自摸也可能够。',
          '没有立直和振听。',
        ]),
        const RuleSection('scoring', '番与花牌', [
          '独立的番种相加；较高的番种取代较低的番种。',
          '花牌和季牌也可加番。',
          '摊开第七或第八张花牌时，可在补牌前选择花糊（3番或8番）。',
          '所有番种列在下方。',
        ]),
        const RuleSection('payments', '支付', [
          '0至13番依次为1、2、4、8、16、24、32、48、64、96、128、192、256、384分，更高也封顶在384分。',
          '食别人打出的牌：只由放铳者向每位食糊者支付两倍。',
          '自摸：每位对手各付番值。',
          '流局不转移分数；没有庄家加倍或连庄加分。',
        ]),
        const RuleSection('game', '庄家与对局长度', [
          '庄家食糊或流局都连庄，否则轮庄。',
          '打东南两圈（预定八局）或只打东圈（四局），连庄会延长对局。',
          '筹码为负也不会结束对局。',
        ]),
        const RuleSection('source', '关于本简介', [
          '依据 danma《香港麻雀正统牌型》1.0 版，采用新式“放铳者全包”的支付方式。',
          _openPdf,
        ]),
      ];

  @override
  List<RuleSection> taiwanese(String minimum) => [
        const RuleSection('setup', '牌与目标', [
          '四人使用144张牌，含花牌和季牌。',
          '摸牌之间手中保持16张。',
          '以17张胡牌：五组面子加一对眼，或七个不同的对子加一副刻子。',
          '杠仍算一组面子。',
          '花牌自动摊开并补牌。',
        ]),
        const RuleSection('calls', '摸牌、打牌与鸣牌', [
          _drawDiscard,
          '吃只能取上家的牌组成顺子；碰和杠取相同的牌。',
          '胡牌优先。',
          _hiddenKongs,
          '没有立直、宝牌或赤五加分。',
          '最后一张打出的牌只能用来胡牌。',
        ]),
        RuleSection('winning', '胡牌与起胡台数', [
          minimum,
          '起胡台数是 TileSense 的自订规则；不够台数的牌不能胡。',
          '放过可以胡的牌后，到自己下次摸牌前不能胡这些听牌。',
          '自己以前打出的牌不会造成立直式的振听。',
        ]),
        const RuleSection('scoring', '累加的台数与花牌', [
          '各番种加上固定台数（即原表的分数），而不是用港式的倍数表。',
          '花牌加的台也计入起胡台数。',
          '集齐八张花牌可特殊胡牌。',
          '所有番种列在下方。',
        ]),
        const RuleSection('payments', '支付与连庄加台', [
          '自摸：每位对手各付全部台数。',
          '胡别人打出的牌：只由放铳者支付。',
          '连庄加台：庄家此前连续胡牌0、1、2、3次或以上，分别加0、2、4、6台。',
          '庄家胡牌或放铳时适用；流局会归零。',
        ]),
        const RuleSection('game', '庄家与对局长度', [
          '庄家胡牌或流局都连庄，否则轮庄。',
          '可以打东南两圈或较短的东风圈，连庄会延长对局。',
        ]),
        const RuleSection('source', '关于本简介', [
          '依据圣地亚哥麻将俱乐部的台湾麻将小册子（Nathanael J. Reynolds 设计），并加上 TileSense 可调的起胡台数。',
        ]),
      ];

  @override
  List<RuleSection> mcr() => const [
        RuleSection('setup', '牌与目标', [
          '四人使用144张牌，含八张花牌。',
          _hold13,
          '以四组面子加一对将和牌，或七对、十三幺、组合龙等特殊牌型。',
          '四张相同的牌可算作两对。',
          '花牌总是摊开并补牌；没有王牌。',
        ]),
        RuleSection('calls', '摸牌、打牌与鸣牌', [
          '吃只能取上家的牌。',
          _priority,
          '吃或碰的同一轮不能开杠。',
          _hiddenKongs,
          '最后一张打出的牌只能用来和牌。',
          '多人对同一张牌宣告和牌时，只有放铳者下家起最近的一位和牌。',
        ]),
        RuleSection('winning', '起和8番', [
          '和牌至少需要8番，不计花牌；7番加花牌仍不够。',
          '没有其他番种的牌计无番和（8番）。',
          '没有立直、振听和本场。',
        ]),
        RuleSection('scoring', '81个番种与不计原则', [
          '计分考虑全部81个番种及其组合原则，选出合法的最高总分。',
          '重叠或包含的番种不一定能相加。',
          '花牌只在达到起和番数后每张加1番。',
          '所有番种及其不计的番种列在下方。',
        ]),
        RuleSection('payments', '支付', [
          '自摸：每位对手各付F＋8分（F为含花牌的番数）。',
          '点和：放铳者付F＋8分，其余两位各付8分。',
          '流局不转移分数；分数从0开始，可以为负。',
        ]),
        RuleSection('game', '庄家与对局长度', [
          '无论和牌还是流局，每局都轮庄。',
          '完整对局共16局，每圈四局；练习局为东圈四局。',
        ]),
        RuleSection('source', '关于本简介', [
          '依据世界麻将组织（WMO）的《麻将竞赛规则》。',
          '赛事管理和裁判罚则不在游戏范围内。',
          _openPdf,
        ]),
      ];

  @override
  List<RuleSection> sichuan() => const [
        RuleSection('setup', '牌与目标', [
          '四人使用108张序数牌，没有字牌和花牌。',
          _hold13,
          '以四组面子加一对将或七对胡牌；四张相同的牌可算作两对。',
          '没有赤五和王牌；开杠补牌从牌墙尾部摸。',
        ]),
        RuleSection('void', '定缺', [
          '开局前选定一门要打掉的花色。',
          '打完这门的牌之前，不能打其他花色。',
          '手牌或副露中还有这门牌时不能胡。',
          '所选的花色在第一次打牌时才公开。',
        ]),
        RuleSection('calls', '鸣牌与血战到底', [
          '可以碰和杠，但不能吃；手中的顺子没有问题。',
          '胡牌的玩家退出，其余玩家继续。',
          '多人可以同时胡同一张牌。',
          '三人胡牌或牌墙摸完时本局结束。',
          '最后一张打出的牌只能用来胡牌。',
        ]),
        RuleSection('winning', '胡牌与过胡', [
          '没有起胡番数、立直和本场。',
          '过胡后，到自己的回合之前不能胡别人打出的这张牌，其他牌也要番数更高才能胡。',
        ]),
        RuleSection('scoring', '番数与支付', [
          '牌值：0、1、2、3番及以上分别为1、2、4、8分。',
          '对对胡和每个根（四张相同的牌）各加1番，清一色和七对各加2番，另有情境番。',
          '点炮：放铳者向每位胡牌者支付牌值。',
          '自摸：仍在局中的对手各付牌值＋1分。',
        ]),
        RuleSection('settlement', '杠与流局结算', [
          '暗杠：向每位仍在局中的对手各收2分。',
          '明杠：向放铳者收2分。',
          '加杠：向每位仍在局中的对手各收1分，且只能用刚摸到的牌。',
          '被抢杠或杠后立即点炮时，该杠的收入取消。',
          '留到最后仍未听牌的玩家拿不到杠的收入。',
          '牌墙摸完时，未听牌者向每位听牌者支付其所听牌的最高牌值。',
        ]),
        RuleSection('game', '庄家与对局长度', [
          '分数从0开始；练习局四局，完整对局八局，没有圈风。',
          '第一个胡牌者下局坐庄；若是多人同胡一张牌，则由放铳者坐庄。',
          '无人胡牌时庄家连庄。',
        ]),
        RuleSection('source', '关于本简介', [
          '依据 mahjongpictureguide.com 的四川血战规则速查表；表中未说明之处采用 TileSense 的结算和轮次规则。',
          _openPdf,
        ]),
      ];

  @override
  String hongKongDefaultMinimum(int faan, List<int> choices) =>
      '默认起和：$faan番，开局前可选${choices.join('、')}番。';
  @override
  String hongKongTableMinimum(int faan) => '本桌起和：$faan番。';
  @override
  String taiwaneseDefaultMinimum(int tai, List<int> choices) =>
      '默认起胡：$tai台，开局前可选${choices.join('、')}台。';
  @override
  String taiwaneseTableMinimum(int tai) => '本桌起胡：$tai台。';

  @override
  String groupTitle(String id) => switch (id) {
        'yaku' => '全部役种',
        'yakuman' => '役满',
        'dora' => '宝牌与额外番数',
        'fu' => '符',
        'limits' => '满贯及以上',
        'faan' => '全部番种',
        'tai' => '全部台数',
        'sichuanFan' => '全部番种',
        _ => '${id.substring(3)}番番种',
      };

  @override
  List<String> groupIntro(String id) => switch (id) {
        'yaku' => const [
            '和牌至少需要一个役，宝牌不能单独成立。',
            '两个相关的役都成立时，较高的役取代较低的役。',
          ],
        'yakuman' => const [
            '每个役满计基本点8,000点，可以复合。',
            '未实现天和、地和、人和、四杠子和流局满贯。',
          ],
        'dora' => const ['额外番数只在已有役时计算，且不加到役满上。'],
        'fu' => const ['符表示手牌结构：先相加，再进位。'],
        'limits' => const [
            '基本点 = 符 × 2^(番 + 2)，再提升到以下等级。',
            '荣和支付基本点的4倍，和庄家则为6倍。',
            '自摸时庄家付2倍、闲家付1倍；庄家自摸则每人付2倍。',
            '每笔支付进位到百位。',
          ],
        'faan' => const ['独立的番种相加；超过13番的部分会显示，但支付封顶在13番。'],
        'tai' => const [
            '台数相加；有等级的番种只计最高一级。',
            '未实现原表的立直（10台）和抢花（20台）。',
          ],
        'sichuanFan' => const ['番数相加；0、1、2、3番及以上分别付1、2、4、8分。'],
        'mcr88' => const [
            '规则附录1的全部81个番种；计分选取合法的最高总分。',
            '“不计”后列出的番种已包含在内，不再重复计算。',
          ],
        _ => const [],
      };

  @override
  String get nameHeading => '名称';
  @override
  String get valueHeading => '计分';
  @override
  String get exampleHeading => '牌例';

  @override
  String value(ValueUnit unit, ScoringPattern p) {
    final each = p.each ? '各' : '';
    return switch (unit) {
      ValueUnit.han when p.yakuman > 0 => p.yakuman == 1 ? '役满' : '双倍役满',
      ValueUnit.han when p.closedOnly => '${p.value}番（仅门清）',
      ValueUnit.han when p.open != null => '${p.value}番（副露${p.open}番）',
      ValueUnit.han ||
      ValueUnit.faan ||
      ValueUnit.fan ||
      ValueUnit.mcrFan =>
        '$each${p.value}番',
      ValueUnit.tai => '$each${p.value}台',
      ValueUnit.fu => p.value == 0 ? '' : '${p.value}符',
      ValueUnit.basicPoints => '基本点${groupDigits(p.value)}',
    };
  }

  @override
  Map<String, String> get readerNames => const {
        'yakuhaiDragon': '役牌（三元牌）',
        'hkDragonPung': '三元牌刻子',
        'hkSeatFlower': '本位花或季',
        'fuBase': '底符',
        'fuClosedRon': '门清荣和',
        'fuTsumo': '自摸',
        'fuPinfu': '平和',
        'fuChiitoitsu': '七对子',
        'fuOpenSimpleTriplet': '中张明刻',
        'fuClosedSimpleTriplet': '中张暗刻',
        'fuOpenHonorTriplet': '幺九明刻',
        'fuClosedHonorTriplet': '幺九暗刻',
        'fuKan': '杠子',
        'fuValuePair': '役牌雀头',
        'fuWait': '嵌张、边张、单骑听牌',
        'fuRounding': '进位',
      };

  @override
  String mcrExcludes(List<String> names) => '不计：${names.join('、')}。';

  @override
  Map<String, String> notes(Ruleset ruleset) => switch (ruleset) {
        Ruleset.riichi || Ruleset.sanma => _riichi,
        Ruleset.hongKong => _hongKong,
        Ruleset.taiwanese => _taiwanese,
        Ruleset.mcr => _mcr,
        Ruleset.sichuan => _sichuan,
      };

  static const _riichi = {
    'Riichi': '门清听牌时支付1,000点宣告，之后手牌锁定。',
    'Double Riichi': '在任何鸣牌或开杠之前，于第一次打牌时立直。取代立直。',
    'Ippatsu': '立直后一巡之内和牌，其间没有鸣牌或开杠。',
    'Menzen Tsumo': '门清自摸和牌。',
    'Pinfu': '四组顺子、非役牌的雀头，且为两面听。',
    'Iipeiko': '同花色两组相同的顺子。',
    'Haitei Raoyue': '摸牌墙最后一张自摸和牌。',
    'Houtei Raoyui': '荣和最后一张打出的牌。',
    'Rinshan Kaihou': '用王牌的补牌和牌。',
    'Chankan': '荣和别人加杠的那张牌。',
    'Tanyao': '完全没有幺九牌。副露也成立。',
    'yakuhaiDragon': '任一三元牌的刻子或杠子。',
    'Round Wind': '场风的刻子或杠子。',
    'Seat Wind': '自风的刻子或杠子。同时是场风则计2番。',
    'Sanshoku Doujun': '三种花色相同的顺子。',
    'Ittsu': '同花色的123、456、789。',
    'Chanta': '每组面子和雀头都含幺九牌，且至少有一组顺子。',
    'Chiitoitsu': '七个不同的对子，固定25符。TileSense 只另加宝牌，不计立直、自摸、断幺九和染手。',
    'Toitoi': '四组刻子或杠子。',
    'Sanankou': '三组暗刻。荣和完成的刻子算明刻。',
    'Sanshoku Doukou': '三种花色相同数字的刻子。',
    'Sankantsu': '三组杠子，明杠暗杠皆可。',
    'Honroutou': '只有幺九牌，四组刻子加雀头，因此同时计对对和。',
    'Shousangen': '两组三元牌刻子加三元牌雀头。两组三元牌刻子也各自计役。',
    'Junchan': '每组面子和雀头都含一或九，且没有字牌。取代混全带幺九。',
    'Honitsu': '一种花色加字牌。',
    'Ryanpeikou': '两组一杯口。取代一杯口。',
    'Chinitsu': '只有一种花色。取代混一色。',
    'Kokushi Musou': '十三种幺九牌各一张，再加其中一种的第二张。',
    'Suuankou': '四组暗刻。单骑听牌也不算双倍役满。',
    'Daisangen': '三种三元牌都成刻子。',
    'Shousuushii': '三组风牌刻子加风牌雀头。',
    'Daisuushii': '四种风牌都成刻子。',
    'Tsuuiisou': '只有字牌，七对子型也算。',
    'Chinroutou': '只有一和九的序数牌。',
    'Ryuuiisou': '只有二、三、四、六、八条和发财；可以没有发财。',
    'Chuuren Poutou': '门清同花色1112345678999再加一张同花色的牌。九面听也不算双倍役满。',
    'Dora': '每张宝牌指示牌的下一张牌。',
    'Ura Dora': '里宝牌指示牌同理，只在立直和牌时计算。',
    'Aka Dora': '每张赤五。',
    'Kita': '每张拔出的北。指示牌指向北时另外加番。',
    'fuBase': '除平和与七对子外，所有手牌的基础。',
    'fuClosedRon': '门清荣和。',
    'fuTsumo': '自摸和牌；平和不加。',
    'fuPinfu': '荣和30符，自摸20符。',
    'fuChiitoitsu': '固定，不进位。',
    'fuOpenSimpleTriplet': '鸣牌得来的二至八刻子。',
    'fuClosedSimpleTriplet': '二至八的暗刻。荣和完成的刻子算明刻。',
    'fuOpenHonorTriplet': '鸣牌得来的一、九或字牌刻子。',
    'fuClosedHonorTriplet': '一、九或字牌的暗刻。',
    'fuKan': '相应刻子的四倍：8、16或32符。',
    'fuValuePair': '三元牌、场风或自风的雀头；同时是场风和自风则为4符。',
    'fuWait': '和牌张也能看作两面听时不加。',
    'fuRounding': '进位到十位。副露荣和且只有底符的牌保持20符（标准规则为30符）。',
    'Mangan': '5番，或番数较少但符数使基本点达到2,000点。不采用切上满贯。',
    'Haneman': '6至7番。',
    'Baiman': '8至10番。',
    'Sanbaiman': '11至12番。',
    'Kazoe Yakuman': '普通役和宝牌合计13番以上。',
    'Yakuman': '每个役满；多个可复合。',
  };

  static const _hongKong = {
    'Self-Pick': '摸到自己的牌食糊。',
    'Win by Kong Replacement': '用开杠的补牌自摸。取代自摸。',
    'Double Kong Replacement': '第一张补牌再开杠，并用第二张补牌食糊。取代其他自摸番种。',
    'Concealed Hand': '没有摊开的鸣牌；暗杠不影响门前清。食别人打出的牌也计。',
    'Robbing the Kong': '食别人加在明刻上的牌。',
    'Moon Under the Sea': '用牌墙最后一张或最后一张打出的牌食糊。',
    'All Sequences': '四组顺子。',
    'All Triplets': '四组刻子或杠子。',
    'All Concealed Triplets': '四组暗刻，自摸或食别人的牌完成对子。取代对对糊。',
    'All Quadruplets': '四组杠子。取代刻子类番种。',
    'hkDragonPung': '任一三元牌的刻子或杠子。',
    'Small Three Dragons': '两组三元牌刻子加三元牌对子。取代三元牌刻子的番。',
    'Big Three Dragons': '三种三元牌都成刻子。取代三元牌刻子的番。',
    'Seat Wind': '门风的刻子或杠子。',
    'Round Wind': '圈风的刻子或杠子。同时是门风则计2番。',
    'Small Four Winds': '三组风牌刻子加风牌对子。取代门风和圈风的番。',
    'Big Four Winds': '四种风牌都成刻子。取代门风和圈风的番。',
    'Mixed Flush': '一种花色加字牌。',
    'Full Flush': '只有一种花色。取代混一色。',
    'Mixed Terminals': '只有幺九牌和字牌，已含对对糊。与坎坎胡或十八罗汉重叠时只加升级部分（5或10番）。',
    'All Terminals': '只有一和九。已含对对糊。',
    'All Honours': '只有字牌。已含对对糊。',
    'Seven Pairs': '七个不同的对子（已启用的可选规则）。可与混一色、清一色和字一色复合。',
    'Nine Gates': '门前清同花色1112345678999再加一张同花色的牌。',
    'Thirteen Orphans': '十三种幺九牌各一张，再加其中一种的第二张。',
    'Blessing of Heaven': '庄家以起手牌食糊。',
    'Blessing of Earth': '在任何鸣牌之前，食庄家打出的第一张牌。',
    'Blessing of Man': '在任何鸣牌之前，闲家第一次摸牌就自摸。',
    'No Flowers or Seasons': '没有摊开任何花牌。',
    'hkSeatFlower': '与本位编号相同的花牌：东1、南2、西3、北4。',
    'All Flowers': '四张花牌齐全。另加于本位花。',
    'All Seasons': '四张季牌齐全。另加于本位季。',
    'Seven Flowers': '摊开第七张花牌时可选择的即时食糊，不计其他番种。',
    'Eight Flowers': '八张花牌全部摊开时可选择的即时食糊，不计其他番种。',
    'Chicken Hand': '没有任何番种的完整牌，只在起和0番时可食糊。',
  };

  static const _taiwanese = {
    'Self-Drawn': '摸到自己的牌胡牌。可与门清自摸叠加。',
    'Concealed Hand': '门清胡别人打出的牌。',
    'Fully Concealed Hand': '门清自摸，代替门清计算。',
    'Value Honor': '每组三元牌刻子或杠子，以及自风的刻子或杠子。',
    'Flower Tile': '每张摊开的花牌或季牌，不论编号。',
    'No Flower Tiles': '没有花牌或季牌。',
    'No Honors': '没有字牌。',
    'No Flower or Honor Tiles': '两者皆无。取代上面两项。',
    'Melded Kong': '每组明杠或加杠。',
    'Concealed Kong': '每组暗杠。',
    'Two Concealed Pungs': '两组暗刻或暗杠。胡别人打出的牌完成的刻子不算暗刻。',
    'Three Concealed Pungs': '三组。取代二暗刻。',
    'Four Concealed Pungs': '四组。取代较低等级。',
    'Five Concealed Pungs': '五组。取代较低等级。',
    'Single Wait': '胡的牌完成对子。',
    'Closed Wait': '胡的牌是顺子中间的一张，例如4-5-6的5。',
    'Robbing the Kong': '胡别人加在明刻上的牌。',
    'Last Tile Draw': '摸牌墙最后一张自摸。',
    'Win Within 5 Discards': '胡牌时桌上打出的牌少于五张。',
    'Win Within 5 to 10 Discards': '桌上打出的牌有五至九张。若符合上一项则计上一项。',
    'Pure Straight': '同花色的123、456、789。',
    'All Pungs': '五组刻子或杠子。',
    'All Chows': '五组顺子，没有花牌，眼不是字牌。',
    'All Chows with Flowers or Honors': '五组顺子，有花牌或眼是字牌。取代平胡。',
    'Melded Hand': '五组面子全部鸣牌，并胡别人打出的牌。',
    'Little Three Dragons': '两组三元牌刻子加三元牌眼。',
    'Big Three Dragons': '三种三元牌都成刻子。取代小三元和三元牌的字牌刻。',
    'Little Three Winds': '两组风牌刻子加风牌眼。',
    'Big Three Winds': '三组风牌刻子。取代小三风。',
    'Little Four Winds': '三组风牌刻子加风牌眼。取代大三风。',
    'Big Four Winds': '四种风牌都成刻子。取代较低的风牌等级。',
    'Half Flush': '一种花色加字牌。',
    'Full Flush': '只有一种花色。取代混一色。',
    'Seven Pairs and a Pung': '七个不同的对子加一组刻子，即17张的特殊牌型。',
    'Blessings of Heaven': '庄家以起手的17张胡牌。',
    'Blessings of Earth': '闲家胡庄家打出的第一张牌。',
    'All Flowers': '八张花牌齐全，即时胡牌，不计其他番种。',
  };

  static const _mcr = {
    'Big Four Winds': '四种风牌都成刻子或杠子。',
    'Big Three Dragons': '三种箭牌都成刻子或杠子。',
    'All Green': '只有二、三、四、六、八条和发。',
    'Nine Gates': '门前清同花色1112345678999，和该花色任一张牌。',
    'Four Kongs': '四组杠，明杠暗杠皆可。',
    'Seven Shifted Pairs': '同花色数字相连的七个对子，例如二至八。',
    'Thirteen Orphans': '十三种幺九牌各一张，再加其中一种的第二张。',
    'All Terminals': '只有一和九。',
    'Little Four Winds': '三组风牌刻子或杠子加风牌将。',
    'Little Three Dragons': '两组箭牌刻子或杠子加箭牌将。',
    'All Honors': '只有字牌。',
    'Four Concealed Pungs': '四组暗刻或暗杠。',
    'Pure Terminal Chows': '同花色两组123、两组789，再加同花色的五作将。',
    'Quadruple Chow': '同花色四组相同的顺子。',
    'Four Pure Shifted Pungs': '同花色数字依次递增的四组刻子或杠子。',
    'Four Shifted Chows': '同花色四组顺子，依次递增一位或依次递增两位。',
    'Three Kongs': '三组杠。',
    'All Terminals and Honors': '只有一、九和字牌，组成刻子加将或七对。',
    'Seven Pairs': '七个对子；四张相同的牌可算作两对。',
    'Greater Honors and Knitted Tiles':
        '七种字牌各一张，加上147、258、369组合龙（各一种花色）中的七张，没有对子。',
    'All Even Pungs': '由二、四、六、八组成的刻子或杠子，将也是偶数。',
    'Full Flush': '只有一种花色。',
    'Pure Triple Chow': '同花色三组相同的顺子。',
    'Pure Shifted Pungs': '同花色数字依次递增的三组刻子或杠子。',
    'Upper Tiles': '只有七、八、九。',
    'Middle Tiles': '只有四、五、六。',
    'Lower Tiles': '只有一、二、三。',
    'Pure Straight': '同花色的123、456、789。',
    'Three-Suited Terminal Chows': '两种花色各有123和789，第三种花色的五作将。',
    'Pure Shifted Chows': '同花色三组顺子，依次递增一位或依次递增两位。',
    'All Fives': '每组面子和将都含五。',
    'Triple Pung': '三种花色相同数字的刻子或杠子。',
    'Three Concealed Pungs': '三组暗刻或暗杠。',
    'Lesser Honors and Knitted Tiles': '由字牌和147、258、369组合龙组成的十四张不同单张。',
    'Knitted Straight': '147、258、369分属三种花色，再加一组面子和将。',
    'Upper Four': '只有六、七、八、九。',
    'Lower Four': '只有一、二、三、四。',
    'Big Three Winds': '三种风牌的刻子或杠子。',
    'Mixed Straight': '123、456、789分属三种花色。',
    'Reversible Tiles': '只有上下颠倒形状不变的牌：一二三四五八九筒、二四五六八九条和白板。',
    'Mixed Triple Chow': '三种花色相同的顺子。',
    'Mixed Shifted Pungs': '三种花色各一组、数字依次递增的刻子或杠子。',
    'Chicken Hand': '除花牌外没有其他番种的牌。',
    'Last Tile Draw': '摸牌墙最后一张自摸和牌。',
    'Last Tile Claim': '和最后一张打出的牌。',
    'Out with Replacement Tile': '用开杠的补牌自摸和牌。',
    'Robbing the Kong': '和别人加在明刻上的牌。',
    'Two Concealed Kongs': '两组暗杠。',
    'All Pungs': '四组刻子或杠子加将。',
    'Half Flush': '一种花色加字牌。',
    'Mixed Shifted Chows': '三种花色各一组顺子，依次递增一位。',
    'All Types': '万、条、饼、风牌和箭牌齐全。',
    'Melded Hand': '全部面子都是鸣牌，和别人打出的牌完成将。',
    'Two Dragon Pungs': '两组箭牌刻子或杠子。',
    'Outside Hand': '每组面子和将都含幺九牌。',
    'Fully Concealed': '没有鸣牌，自摸和牌。',
    'Two Melded Kongs': '两组明杠。',
    'Last Tile': '和其余三张已见的牌的最后一张。',
    'Dragon Pung': '箭牌的刻子或杠子。',
    'Prevalent Wind': '圈风的刻子或杠子。',
    'Seat Wind': '门风的刻子或杠子。',
    'Concealed Hand': '没有鸣牌，和别人打出的牌。',
    'All Chows': '四组顺子加序数牌的将。',
    'Tile Hog': '用到同一种牌的全部四张而不开杠。',
    'Double Pung': '两种花色相同数字的刻子或杠子。',
    'Two Concealed Pungs': '两组暗刻或暗杠。',
    'Concealed Kong': '一组暗杠。',
    'All Simples': '没有幺九牌。',
    'Pure Double Chow': '同花色两组相同的顺子。',
    'Mixed Double Chow': '两种花色相同的顺子。',
    'Short Straight': '同花色两组顺子，连成六个相连的数字。',
    'Two Terminal Chows': '同花色的123和789。',
    'Pung of Terminals or Honors': '一、九，或既非门风也非圈风的风牌的刻子或杠子。',
    'Melded Kong': '一组明杠。',
    'One Voided Suit': '缺少三种花色中的一种。',
    'No Honors': '没有字牌。',
    'Edge Wait': '和12的3或89的7，且只听这一张。',
    'Closed Wait': '和顺子中间的牌，且只听这一张。',
    'Single Wait': '和将牌，且只听这一张。',
    'Self-Drawn': '摸到自己的牌和牌。',
    'Flower Tiles': '每张花牌，在达到起和8番后加计。',
    mcrMixedKongs: '一组明杠和一组暗杠。',
  };

  static const _sichuan = {
    'Root': '手中每组四张相同的牌，不论是否开杠，七对也算。',
    'All Pungs': '四组刻子或杠子加将。',
    'Full Flush': '只有一种花色。',
    'Seven Pairs': '七个对子；四张相同的牌可算作两对。',
    'Golden Single Wait': '四组面子都已摊开，胡的牌完成将。已含对对胡。',
    'Win after Kong': '用开杠的补牌自摸。',
    'Robbing the Kong': '胡别人加在明刻上的牌。',
    'Shoot after Kong': '胡别人开杠后紧接着打出的牌。',
    'Under the Sea': '胡牌墙最后一张，或其后打出的牌。',
  };
}
