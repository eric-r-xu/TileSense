/// Traditional Chinese rules text, following [EnRulesText] section for
/// section, with each ruleset's own words as on the score screen (榮和,
/// 食糊, 胡; 番 and 台).
library;

import 'package:mahjong_core/ruleset.dart';

import 'rules_content.dart';
import 'rules_text.dart';

class ZhHantRulesText extends RulesText {
  const ZhHantRulesText();

  @override
  List<RuleSection> riichi({required bool sanma}) => [
        RuleSection(
            'setup',
            '牌與目標',
            sanma
                ? '三人使用108張牌，去掉二至八萬，對家空位。摸牌之間手中保持13張。和牌通常為四組面子加一對雀頭。七對子（七個不同的對子）和國士無雙是特殊和牌型。起始點數為35,000點。'
                : '四人使用136張牌，含赤五。摸牌之間手中保持13張。和牌通常為四組面子加一對雀頭。面子是同花色三張相連的順子，或三張相同的刻子；槓子是四張相同的牌。七對子（七個不同的對子）和國士無雙是特殊和牌型。起始點數為25,000點。'),
        RuleSection(
            'calls',
            '摸牌、打牌與鳴牌',
            sanma
                ? '摸一張，再打一張。可以碰別人打出的牌組成刻子，或槓成槓子，但不能吃。開槓後從王牌摸嶺上牌。碰或明槓後手牌變為副露，可計的役也隨之改變。'
                : '摸一張，再打一張。吃只能取上家（前一位）打出的牌組成順子；碰組成刻子，槓組成槓子。和牌優先。開槓後從王牌摸嶺上牌。吃、碰、明槓都會使手牌副露，可計的役也隨之改變。'),
        const RuleSection('winning', '和牌：役與振聽',
            '摸到自己的牌和牌為自摸，和別人打出的牌為榮和。至少需要一個役，只有寶牌不能和牌。若聽的牌中有任何一張在自己的牌河裡，就是振聽：不能榮和，但仍可自摸。放過可以榮和的牌也會暫時不能榮和；立直後這一限制持續到本局結束。'),
        const RuleSection('riichi', '立直與寶牌',
            '門清聽牌且點數足夠時，可以宣告立直並支付1,000點立直棒。之後手牌鎖定：一般摸什麼打什麼，只能開允許的槓。役和寶牌增加番數，符表示手牌結構。寶牌指示牌決定寶牌，赤五也加番，立直和牌時還會翻開裡寶牌。'),
        if (sanma)
          const RuleSection('kita', '拔北',
              '輪到自己時，可以把北拔出放在一旁，算一番寶牌，再摸一張補牌。寶牌或裡寶牌指示牌指向北時，拔北同樣加番。立直後只能拔剛摸到的北。拔北會使一發和第一巡的役失效。別人可以榮和拔出的北，但這不算搶槓。拔北和開槓共用八次補牌。一萬為指示牌時寶牌是九萬，反之亦然。'),
        RuleSection(
            'payments',
            '點數與支付',
            sanma
                ? '番和符決定點數，普通點數表之上還有滿貫等封頂和役滿。榮和由放銃者支付。自摸時兩位對手按四人麻將的份額支付，空位的那份無人支付（自摸損）。荒牌流局時，若聽牌者和未聽牌者都有，轉移2,000點。中途流局只有九種九牌。'
                : '番和符決定點數，普通點數表之上還有滿貫等封頂和役滿。榮和由放銃者支付；自摸由所有對手支付，金額視莊閒而定。本場增加連莊的額外支付，和牌者收取桌上的立直棒。荒牌流局時，若聽牌者和未聽牌者都有，轉移3,000點。少見的符和部分雙倍役滿規則為近似處理。'),
        RuleSection(
            'game',
            '莊家與對局長度',
            sanma
                ? '半莊包括東場和南場，每場預定三局；東風戰為三局。莊家連莊會延長對局。對家空位從不行動。'
                : '半莊包括東場和南場，每場預定四局；東風戰為四局。莊家和牌，或荒牌流局時莊家聽牌，即可連莊並延長對局。'),
        const RuleSection('source', '關於本簡介',
            '這是 TileSense 已實作規則的速查；上面的列表涵蓋計分時計算的所有役、符和滿貫等級。三麻參考 Japanese Mahjong Wiki 的三麻說明。詳情請查看外部參考資料。'),
      ];

  @override
  List<RuleSection> hongKong(String minimum) => [
        const RuleSection('setup', '牌與目標',
            '四人使用144張牌，含八張花牌和季牌。摸牌之間手中保持13張普通牌；一般食糊為四組面子加一對眼。也支援七對和十三幺。花牌攤開後從牌牆尾部補牌，開槓補牌也一樣。沒有保留的王牌。'),
        const RuleSection('calls', '摸牌、打牌與鳴牌',
            '摸一張，再打一張。上（吃）只能取上家的牌組成順子；碰組成刻子，槓組成槓子。食糊優先於槓和碰，槓和碰優先於上。加槓可以被搶槓，暗槓不能。多人可以同時食同一張牌。最後一張打出的牌只能用來食糊。'),
        RuleSection('winning', '食糊與起糊番數',
            '$minimum 不夠起糊番數的牌不能食糊。起糊為0番時，沒有任何番種的完整牌（雞糊）也可以食糊。自摸本身加番，所以有些牌食別人的牌不夠番，自摸卻可以食糊。沒有立直和振聽。'),
        const RuleSection('scoring', '番與花牌',
            '獨立的番種相加；較高的番種取代較低的番種。花牌和季牌也可加番。攤開第七或第八張花牌時，可在摸補牌前選擇3番或8番的花糊。所有番種列在下方。'),
        const RuleSection('payments', '支付',
            '0至13番的番值依次為1、2、4、8、16、24、32、48、64、96、128、192、256、384分，更高的番數也封頂在384分。食別人打出的牌時，只由放銃者向每位食糊者支付兩倍番值。自摸時每位對手各付番值。流局不轉移分數；沒有莊家加倍，也沒有連莊加分。'),
        const RuleSection('game', '莊家與對局長度',
            '莊家食糊或流局都連莊，否則輪莊。TileSense 打東南兩圈（預定八局）或只打東圈（四局），連莊會延長對局。籌碼為負也不會結束對局。'),
        const RuleSection('source', '關於本簡介',
            '依據 TileSense 對 danma《香港麻雀正統牌型》1.0 版的實作，採用新式「放銃者全包」的支付方式。原表請查看 PDF。'),
      ];

  @override
  List<RuleSection> taiwanese(String minimum) => [
        const RuleSection('setup', '牌與目標',
            '四人使用144張牌，含花牌和季牌。摸牌之間手中保持16張普通牌。一般胡牌為17張：五組面子加一對眼。七個不同的對子加一副刻子也是胡牌型。槓仍算一組面子。花牌自動攤開並補牌。'),
        const RuleSection('calls', '摸牌、打牌與鳴牌',
            '摸一張，再打一張。吃只能取上家的牌組成順子；碰和槓取相同的牌。胡牌優先。暗槓在本局結束前四張都背面朝上。沒有立直、寶牌或赤五加分。最後一張打出的牌只能用來胡牌。'),
        RuleSection('winning', '胡牌與起胡台數',
            '$minimum 這個起胡台數是 TileSense 的自訂規則。不夠台數的完整牌不能胡。放過可以胡的牌後，到自己下次摸牌前不能胡這些聽牌；自己以前打出的牌不會造成立直式的振聽。'),
        const RuleSection('scoring', '累加的台數與花牌',
            '各番種直接加上固定台數，而不是用港式的倍數表。原表的分數在應用程式中作為台數使用。花牌加的台也計入起胡台數。集齊八張花牌可特殊胡牌。所有番種列在下方。'),
        const RuleSection('payments', '支付與連莊加台',
            '自摸時每位對手各付全部台數；胡別人打出的牌時，只由放銃者支付。莊家連莊加台：此前連續胡牌0、1、2、3次或以上，分別加0、2、4、6台。莊家胡牌或莊家放銃時適用。流局會使連莊紀錄歸零。'),
        const RuleSection(
            'game', '莊家與對局長度', '莊家胡牌或流局都連莊，否則輪莊。可以打東南兩圈，或較短的東風圈。連莊會延長預定的局數。'),
        const RuleSection('source', '關於本簡介',
            '依據聖地牙哥麻將俱樂部的台灣麻將小冊子（Nathanael J. Reynolds 設計），並加上 TileSense 可調的起胡台數。'),
      ];

  @override
  List<RuleSection> mcr() => const [
        RuleSection('setup', '牌與目標',
            '四人使用144張牌，含八張花牌。摸牌之間手中保持13張。一般和牌為四組面子加一對將；特殊牌型有七對、十三幺和組合龍等。四張相同的牌可算作兩對。TileSense 中花牌總是攤開並補牌。沒有王牌。'),
        RuleSection('calls', '摸牌、打牌與鳴牌',
            '吃只能取上家的牌。和牌優先於槓和碰，槓和碰優先於吃。吃或碰的同一輪不能開槓。暗槓在本局結束前保持背面朝上。最後一張打出的牌只能用來和牌。多人對同一張牌宣告和牌時，只有放銃者下家起最近的一位和牌。'),
        RuleSection('winning', '起和8番',
            '和牌至少需要8番，不計花牌。7番加花牌仍不夠起和。沒有其他番種的牌可計無番和（8番）。沒有立直、振聽和本場。'),
        RuleSection('scoring', '81個番種與不計原則',
            '計分時考慮全部81個番種及其組合原則，選出合法的最高總分。重疊或包含的番種不一定能相加。花牌只在達到起和番數後每張加1番。所有番種及其不計的番種列在下方。'),
        RuleSection('payments', '支付',
            '對含花牌共F番的牌，自摸時每位對手各付F＋8分。點和時放銃者付F＋8分，其餘兩位各付8分。流局不轉移分數。分數從0開始，可以為負。'),
        RuleSection('game', '莊家與對局長度',
            '無論和牌還是流局，每局都輪莊。完整對局共16局：東、南、西、北圈各四局。較短的練習局為東圈四局。'),
        RuleSection('source', '關於本簡介',
            '依據世界麻將組織（WMO）的《麻將競賽規則》。TileSense 實作了對局和計分；賽事管理和裁判罰則不在遊戲範圍內。詳細規則請查看 PDF。'),
      ];

  @override
  List<RuleSection> sichuan() => const [
        RuleSection('setup', '牌與目標',
            '四人使用108張序數牌，沒有字牌和花牌。摸牌之間手中保持13張。以四組面子加一對將或七對胡牌；四張相同的牌可算作兩對。沒有赤五和王牌。開槓補牌從牌牆尾部摸。'),
        RuleSection('void', '定缺',
            '開局前選定一門要打掉的花色。打完這門的所有牌之前，不能打其他花色。手牌或副露中還有這門牌時不能胡。所選的花色在第一次打牌前對其他玩家保密。'),
        RuleSection('calls', '鳴牌與血戰到底',
            '可以碰和槓，但不能吃；手中的順子沒有問題。胡牌的玩家退出，其餘玩家繼續。多人可以同時胡同一張牌。三人胡牌或牌牆摸完時本局結束。最後一張打出的牌只能用來胡牌。'),
        RuleSection('winning', '胡牌與過胡',
            '沒有起胡番數、立直和本場。放過可以胡的牌後，到自己的回合之前不能再胡別人打出的這張牌，其他牌也要番數更高才能胡。'),
        RuleSection('scoring', '番數與支付',
            '0、1、2、3番及以上的牌值分別為1、2、4、8分。對對胡和每個根（四張相同的牌）各加1番；清一色和七對各加2番。另有情境番。點炮時放銃者向每位胡牌者支付牌值。自摸時仍在局中的對手各付牌值＋1分。'),
        RuleSection('settlement', '槓與流局結算',
            '暗槓向每位仍在局中的對手各收2分；明槓向放銃者收2分；加槓向每位仍在局中的對手各收1分。加槓只能用剛摸到的牌。被搶槓或槓後立即點炮時，該槓的收入取消。留到最後仍未聽牌的玩家拿不到槓的收入。牌牆摸完時，未聽牌者向每位聽牌者支付其所聽牌的最高牌值。'),
        RuleSection('game', '莊家與對局長度',
            '分數從0開始。練習局四局，完整對局八局，沒有圈風。第一個胡牌者下局坐莊；若第一次胡牌是多人同胡一張牌，則由放銃者坐莊。無人胡牌時莊家連莊。'),
        RuleSection('source', '關於本簡介',
            '依據 mahjongpictureguide.com 的四川血戰規則速查表；表中未說明之處採用 TileSense 的結算和輪次規則。詳情請查看 PDF。'),
      ];

  @override
  String hongKongDefaultMinimum(int faan, List<int> choices) =>
      '預設起糊：$faan番。開局前可選${choices.join('、')}番。';
  @override
  String hongKongTableMinimum(int faan) => '本桌起糊：$faan番。';
  @override
  String taiwaneseDefaultMinimum(int tai, List<int> choices) =>
      '預設起胡：$tai台。開局前可選${choices.join('、')}台。';
  @override
  String taiwaneseTableMinimum(int tai) => '本桌起胡：$tai台。';

  @override
  String groupTitle(String id) => switch (id) {
        'yaku' => '全部役種',
        'yakuman' => '役滿',
        'dora' => '寶牌與額外番數',
        'fu' => '符',
        'limits' => '滿貫及以上',
        'faan' => '全部番種',
        'tai' => '全部台數',
        'sichuanFan' => '全部番種',
        _ => '${id.substring(3)}番番種',
      };

  @override
  String groupIntro(String id) => switch (id) {
        'yaku' => '和牌至少需要一個役，寶牌不能單獨成立。兩個相關的役都成立時，較高的役取代較低的役。',
        'yakuman' => '每個役滿計基本點8,000點，可以複合。未實作天和、地和、人和、四槓子和流局滿貫。',
        'dora' => '額外番數只在已有役時計算，且不加到役滿上。',
        'fu' => '符表示手牌結構。先相加，再進位。',
        'limits' =>
          '基本點 = 符 × 2^(番 + 2)，再提升到以下等級。榮和支付基本點的4倍，和莊家則為6倍。自摸時莊家付2倍、閒家付1倍；莊家自摸則每人付2倍，各自進位到百位。',
        'faan' => '獨立的番種相加。超過13番的部分會顯示，但支付封頂在13番。',
        'tai' => '台數相加。有等級的番種只計最高一級。未實作原表的立直（10台）和搶花（20台）。',
        'sichuanFan' => '番數相加；0、1、2、3番及以上分別付1、2、4、8分。',
        'mcr88' => '規則附錄1的全部81個番種。計分選取合法的最高總分；「不計」後列出的番種已包含在內，不再重複計算。',
        _ => '',
      };

  @override
  String value(ValueUnit unit, ScoringPattern p) {
    final each = p.each ? '各' : '';
    return switch (unit) {
      ValueUnit.han when p.yakuman > 0 => p.yakuman == 1 ? '役滿' : '雙倍役滿',
      ValueUnit.han when p.closedOnly => '${p.value}番（僅門清）',
      ValueUnit.han when p.open != null => '${p.value}番（副露${p.open}番）',
      ValueUnit.han ||
      ValueUnit.faan ||
      ValueUnit.fan ||
      ValueUnit.mcrFan =>
        '$each${p.value}番',
      ValueUnit.tai => '$each${p.value}台',
      ValueUnit.fu => p.value == 0 ? '' : '${p.value}符',
      ValueUnit.basicPoints => '基本點${groupDigits(p.value)}',
    };
  }

  @override
  Map<String, String> get readerNames => const {
        'yakuhaiDragon': '役牌（三元牌）',
        'hkDragonPung': '三元牌刻子',
        'hkSeatFlower': '正花或正季',
        'fuBase': '底符',
        'fuClosedRon': '門清榮和',
        'fuTsumo': '自摸',
        'fuPinfu': '平和',
        'fuChiitoitsu': '七對子',
        'fuOpenSimpleTriplet': '中張明刻',
        'fuClosedSimpleTriplet': '中張暗刻',
        'fuOpenHonorTriplet': '幺九明刻',
        'fuClosedHonorTriplet': '幺九暗刻',
        'fuKan': '槓子',
        'fuValuePair': '役牌雀頭',
        'fuWait': '嵌張、邊張、單騎聽牌',
        'fuRounding': '進位',
      };

  @override
  String mcrExcludes(List<String> names) => '不計：${names.join('、')}。';

  @override
  Map<String, String> notes(Ruleset ruleset) => switch (ruleset) {
        Ruleset.riichi || Ruleset.sanma => _riichi,
        Ruleset.hongKong => _hongKong,
        Ruleset.taiwanese => _taiwanese,
        Ruleset.mcr => _mcr,
        Ruleset.sichuan => _sichuan,
      };

  static const _riichi = {
    'Riichi': '門清聽牌時支付1,000點宣告，之後手牌鎖定。',
    'Double Riichi': '在任何鳴牌或開槓之前，於第一次打牌時立直。取代立直。',
    'Ippatsu': '立直後一巡之內和牌，其間沒有鳴牌或開槓。',
    'Menzen Tsumo': '門清自摸和牌。',
    'Pinfu': '四組順子、非役牌的雀頭，且為兩面聽。',
    'Iipeiko': '同花色兩組相同的順子。',
    'Haitei Raoyue': '摸牌牆最後一張自摸和牌。',
    'Houtei Raoyui': '榮和最後一張打出的牌。',
    'Rinshan Kaihou': '用王牌的補牌和牌。',
    'Chankan': '榮和別人加槓的那張牌。',
    'Tanyao': '完全沒有幺九牌。副露也成立。',
    'yakuhaiDragon': '任一三元牌的刻子或槓子。',
    'Round Wind': '場風的刻子或槓子。',
    'Seat Wind': '自風的刻子或槓子。同時是場風則計2番。',
    'Sanshoku Doujun': '三種花色相同的順子。',
    'Ittsu': '同花色的123、456、789。',
    'Chanta': '每組面子和雀頭都含幺九牌，且至少有一組順子。',
    'Chiitoitsu': '七個不同的對子，固定25符。TileSense 只另加寶牌，不計立直、自摸、斷幺九和染手。',
    'Toitoi': '四組刻子或槓子。',
    'Sanankou': '三組暗刻。榮和完成的刻子算明刻。',
    'Sanshoku Doukou': '三種花色相同數字的刻子。',
    'Sankantsu': '三組槓子，明槓暗槓皆可。',
    'Honroutou': '只有幺九牌，四組刻子加雀頭，因此同時計對對和。',
    'Shousangen': '兩組三元牌刻子加三元牌雀頭。兩組三元牌刻子也各自計役。',
    'Junchan': '每組面子和雀頭都含一或九，且沒有字牌。取代混全帶幺九。',
    'Honitsu': '一種花色加字牌。',
    'Ryanpeikou': '兩組一盃口。取代一盃口。',
    'Chinitsu': '只有一種花色。取代混一色。',
    'Kokushi Musou': '十三種幺九牌各一張，再加其中一種的第二張。',
    'Suuankou': '四組暗刻。單騎聽牌也不算雙倍役滿。',
    'Daisangen': '三種三元牌都成刻子。',
    'Shousuushii': '三組風牌刻子加風牌雀頭。',
    'Daisuushii': '四種風牌都成刻子。',
    'Tsuuiisou': '只有字牌，七對子型也算。',
    'Chinroutou': '只有一和九的序數牌。',
    'Ryuuiisou': '只有二、三、四、六、八條和發財；可以沒有發財。',
    'Chuuren Poutou': '門清同花色1112345678999再加一張同花色的牌。九面聽也不算雙倍役滿。',
    'Dora': '每張寶牌指示牌的下一張牌。',
    'Ura Dora': '裡寶牌指示牌同理，只在立直和牌時計算。',
    'Aka Dora': '每張赤五。',
    'Kita': '每張拔出的北。指示牌指向北時另外加番。',
    'fuBase': '除平和與七對子外，所有手牌的基礎。',
    'fuClosedRon': '門清榮和。',
    'fuTsumo': '自摸和牌；平和不加。',
    'fuPinfu': '榮和30符，自摸20符。',
    'fuChiitoitsu': '固定，不進位。',
    'fuOpenSimpleTriplet': '鳴牌得來的二至八刻子。',
    'fuClosedSimpleTriplet': '二至八的暗刻。榮和完成的刻子算明刻。',
    'fuOpenHonorTriplet': '鳴牌得來的一、九或字牌刻子。',
    'fuClosedHonorTriplet': '一、九或字牌的暗刻。',
    'fuKan': '相應刻子的四倍：8、16或32符。',
    'fuValuePair': '三元牌、場風或自風的雀頭；同時是場風和自風則為4符。',
    'fuWait': '和牌張也能看作兩面聽時不加。',
    'fuRounding': '進位到十位。副露榮和且只有底符的牌保持20符（標準規則為30符）。',
    'Mangan': '5番，或番數較少但符數使基本點達到2,000點。不採用切上滿貫。',
    'Haneman': '6至7番。',
    'Baiman': '8至10番。',
    'Sanbaiman': '11至12番。',
    'Kazoe Yakuman': '普通役和寶牌合計13番以上。',
    'Yakuman': '每個役滿；多個可複合。',
  };

  static const _hongKong = {
    'Self-Pick': '摸到自己的牌食糊。',
    'Win by Kong Replacement': '用開槓的補牌自摸。取代自摸。',
    'Double Kong Replacement': '第一張補牌再開槓，並用第二張補牌食糊。取代其他自摸番種。',
    'Concealed Hand': '沒有攤開的鳴牌；暗槓不影響門前清。食別人打出的牌也計。',
    'Robbing the Kong': '食別人加在明刻上的牌。',
    'Moon Under the Sea': '用牌牆最後一張或最後一張打出的牌食糊。',
    'All Sequences': '四組順子。',
    'All Triplets': '四組刻子或槓子。',
    'All Concealed Triplets': '四組暗刻，自摸或食別人的牌完成對子。取代對對糊。',
    'All Quadruplets': '四組槓子。取代刻子類番種。',
    'hkDragonPung': '任一三元牌的刻子或槓子。',
    'Small Three Dragons': '兩組三元牌刻子加三元牌對子。取代三元牌刻子的番。',
    'Big Three Dragons': '三種三元牌都成刻子。取代三元牌刻子的番。',
    'Seat Wind': '門風的刻子或槓子。',
    'Round Wind': '圈風的刻子或槓子。同時是門風則計2番。',
    'Small Four Winds': '三組風牌刻子加風牌對子。取代門風和圈風的番。',
    'Big Four Winds': '四種風牌都成刻子。取代門風和圈風的番。',
    'Mixed Flush': '一種花色加字牌。',
    'Full Flush': '只有一種花色。取代混一色。',
    'Mixed Terminals': '只有幺九牌和字牌，已含對對糊。與坎坎胡或十八羅漢重疊時只加升級部分（5或10番）。',
    'All Terminals': '只有一和九。已含對對糊。',
    'All Honours': '只有字牌。已含對對糊。',
    'Seven Pairs': '七個不同的對子（已啟用的可選規則）。可與混一色、清一色和字一色複合。',
    'Nine Gates': '門前清同花色1112345678999再加一張同花色的牌。',
    'Thirteen Orphans': '十三種幺九牌各一張，再加其中一種的第二張。',
    'Blessing of Heaven': '莊家以起手牌食糊。',
    'Blessing of Earth': '在任何鳴牌之前，食莊家打出的第一張牌。',
    'Blessing of Man': '在任何鳴牌之前，閒家第一次摸牌就自摸。',
    'No Flowers or Seasons': '沒有攤開任何花牌。',
    'hkSeatFlower': '與本位編號相同的花牌：東1、南2、西3、北4。',
    'All Flowers': '四張花牌齊全。另加於正花。',
    'All Seasons': '四張季牌齊全。另加於正季。',
    'Seven Flowers': '攤開第七張花牌時可選擇的即時食糊，不計其他番種。',
    'Eight Flowers': '八張花牌全部攤開時可選擇的即時食糊，不計其他番種。',
    'Chicken Hand': '沒有任何番種的完整牌，只在起糊0番時可食糊。',
  };

  static const _taiwanese = {
    'Self-Drawn': '摸到自己的牌胡牌。可與門清自摸疊加。',
    'Concealed Hand': '門清胡別人打出的牌。',
    'Fully Concealed Hand': '門清自摸，代替門清計算。',
    'Value Honor': '每組三元牌刻子或槓子，以及自風的刻子或槓子。',
    'Flower Tile': '每張攤開的花牌或季牌，不論編號。',
    'No Flower Tiles': '沒有花牌或季牌。',
    'No Honors': '沒有字牌。',
    'No Flower or Honor Tiles': '兩者皆無。取代上面兩項。',
    'Melded Kong': '每組明槓或加槓。',
    'Concealed Kong': '每組暗槓。',
    'Two Concealed Pungs': '兩組暗刻或暗槓。胡別人打出的牌完成的刻子不算暗刻。',
    'Three Concealed Pungs': '三組。取代二暗刻。',
    'Four Concealed Pungs': '四組。取代較低等級。',
    'Five Concealed Pungs': '五組。取代較低等級。',
    'Single Wait': '胡的牌完成對子。',
    'Closed Wait': '胡的牌是順子中間的一張，例如4-5-6的5。',
    'Robbing the Kong': '胡別人加在明刻上的牌。',
    'Last Tile Draw': '摸牌牆最後一張自摸。',
    'Win Within 5 Discards': '胡牌時桌上打出的牌少於五張。',
    'Win Within 5 to 10 Discards': '桌上打出的牌有五至九張。若符合上一項則計上一項。',
    'Pure Straight': '同花色的123、456、789。',
    'All Pungs': '五組刻子或槓子。',
    'All Chows': '五組順子，沒有花牌，眼不是字牌。',
    'All Chows with Flowers or Honors': '五組順子，有花牌或眼是字牌。取代平胡。',
    'Melded Hand': '五組面子全部鳴牌，並胡別人打出的牌。',
    'Little Three Dragons': '兩組三元牌刻子加三元牌眼。',
    'Big Three Dragons': '三種三元牌都成刻子。取代小三元和三元牌的字牌刻。',
    'Little Three Winds': '兩組風牌刻子加風牌眼。',
    'Big Three Winds': '三組風牌刻子。取代小三風。',
    'Little Four Winds': '三組風牌刻子加風牌眼。取代大三風。',
    'Big Four Winds': '四種風牌都成刻子。取代較低的風牌等級。',
    'Half Flush': '一種花色加字牌。',
    'Full Flush': '只有一種花色。取代混一色。',
    'Seven Pairs and a Pung': '七個不同的對子加一組刻子，即17張的特殊牌型。',
    'Blessings of Heaven': '莊家以起手的17張胡牌。',
    'Blessings of Earth': '閒家胡莊家打出的第一張牌。',
    'All Flowers': '八張花牌齊全，即時胡牌，不計其他番種。',
  };

  static const _mcr = {
    'Big Four Winds': '四種風牌都成刻子或槓子。',
    'Big Three Dragons': '三種箭牌都成刻子或槓子。',
    'All Green': '只有二、三、四、六、八條和發。',
    'Nine Gates': '門前清同花色1112345678999，和該花色任一張牌。',
    'Four Kongs': '四組槓，明槓暗槓皆可。',
    'Seven Shifted Pairs': '同花色數字相連的七個對子，例如二至八。',
    'Thirteen Orphans': '十三種幺九牌各一張，再加其中一種的第二張。',
    'All Terminals': '只有一和九。',
    'Little Four Winds': '三組風牌刻子或槓子加風牌將。',
    'Little Three Dragons': '兩組箭牌刻子或槓子加箭牌將。',
    'All Honors': '只有字牌。',
    'Four Concealed Pungs': '四組暗刻或暗槓。',
    'Pure Terminal Chows': '同花色兩組123、兩組789，再加同花色的五作將。',
    'Quadruple Chow': '同花色四組相同的順子。',
    'Four Pure Shifted Pungs': '同花色數字依次遞增的四組刻子或槓子。',
    'Four Shifted Chows': '同花色四組順子，依次遞增一位或依次遞增兩位。',
    'Three Kongs': '三組槓。',
    'All Terminals and Honors': '只有一、九和字牌，組成刻子加將或七對。',
    'Seven Pairs': '七個對子；四張相同的牌可算作兩對。',
    'Greater Honors and Knitted Tiles':
        '七種字牌各一張，加上147、258、369組合龍（各一種花色）中的七張，沒有對子。',
    'All Even Pungs': '由二、四、六、八組成的刻子或槓子，將也是偶數。',
    'Full Flush': '只有一種花色。',
    'Pure Triple Chow': '同花色三組相同的順子。',
    'Pure Shifted Pungs': '同花色數字依次遞增的三組刻子或槓子。',
    'Upper Tiles': '只有七、八、九。',
    'Middle Tiles': '只有四、五、六。',
    'Lower Tiles': '只有一、二、三。',
    'Pure Straight': '同花色的123、456、789。',
    'Three-Suited Terminal Chows': '兩種花色各有123和789，第三種花色的五作將。',
    'Pure Shifted Chows': '同花色三組順子，依次遞增一位或依次遞增兩位。',
    'All Fives': '每組面子和將都含五。',
    'Triple Pung': '三種花色相同數字的刻子或槓子。',
    'Three Concealed Pungs': '三組暗刻或暗槓。',
    'Lesser Honors and Knitted Tiles': '由字牌和147、258、369組合龍組成的十四張不同單張。',
    'Knitted Straight': '147、258、369分屬三種花色，再加一組面子和將。',
    'Upper Four': '只有六、七、八、九。',
    'Lower Four': '只有一、二、三、四。',
    'Big Three Winds': '三種風牌的刻子或槓子。',
    'Mixed Straight': '123、456、789分屬三種花色。',
    'Reversible Tiles': '只有上下顛倒形狀不變的牌：一二三四五八九筒、二四五六八九條和白板。',
    'Mixed Triple Chow': '三種花色相同的順子。',
    'Mixed Shifted Pungs': '三種花色各一組、數字依次遞增的刻子或槓子。',
    'Chicken Hand': '除花牌外沒有其他番種的牌。',
    'Last Tile Draw': '摸牌牆最後一張自摸和牌。',
    'Last Tile Claim': '和最後一張打出的牌。',
    'Out with Replacement Tile': '用開槓的補牌自摸和牌。',
    'Robbing the Kong': '和別人加在明刻上的牌。',
    'Two Concealed Kongs': '兩組暗槓。',
    'All Pungs': '四組刻子或槓子加將。',
    'Half Flush': '一種花色加字牌。',
    'Mixed Shifted Chows': '三種花色各一組順子，依次遞增一位。',
    'All Types': '萬、條、餅、風牌和箭牌齊全。',
    'Melded Hand': '全部面子都是鳴牌，和別人打出的牌完成將。',
    'Two Dragon Pungs': '兩組箭牌刻子或槓子。',
    'Outside Hand': '每組面子和將都含幺九牌。',
    'Fully Concealed': '沒有鳴牌，自摸和牌。',
    'Two Melded Kongs': '兩組明槓。',
    'Last Tile': '和其餘三張已見的牌的最後一張。',
    'Dragon Pung': '箭牌的刻子或槓子。',
    'Prevalent Wind': '圈風的刻子或槓子。',
    'Seat Wind': '門風的刻子或槓子。',
    'Concealed Hand': '沒有鳴牌，和別人打出的牌。',
    'All Chows': '四組順子加序數牌的將。',
    'Tile Hog': '用到同一種牌的全部四張而不開槓。',
    'Double Pung': '兩種花色相同數字的刻子或槓子。',
    'Two Concealed Pungs': '兩組暗刻或暗槓。',
    'Concealed Kong': '一組暗槓。',
    'All Simples': '沒有幺九牌。',
    'Pure Double Chow': '同花色兩組相同的順子。',
    'Mixed Double Chow': '兩種花色相同的順子。',
    'Short Straight': '同花色兩組順子，連成六個相連的數字。',
    'Two Terminal Chows': '同花色的123和789。',
    'Pung of Terminals or Honors': '一、九，或既非門風也非圈風的風牌的刻子或槓子。',
    'Melded Kong': '一組明槓。',
    'One Voided Suit': '缺少三種花色中的一種。',
    'No Honors': '沒有字牌。',
    'Edge Wait': '和12的3或89的7，且只聽這一張。',
    'Closed Wait': '和順子中間的牌，且只聽這一張。',
    'Single Wait': '和將牌，且只聽這一張。',
    'Self-Drawn': '摸到自己的牌和牌。',
    'Flower Tiles': '每張花牌，在達到起和8番後加計。',
    mcrMixedKongs: '一組明槓和一組暗槓。',
  };

  static const _sichuan = {
    'Root': '手中每組四張相同的牌，不論是否開槓，七對也算。',
    'All Pungs': '四組刻子或槓子加將。',
    'Full Flush': '只有一種花色。',
    'Seven Pairs': '七個對子；四張相同的牌可算作兩對。',
    'Golden Single Wait': '四組面子都已攤開，胡的牌完成將。已含對對胡。',
    'Win after Kong': '用開槓的補牌自摸。',
    'Robbing the Kong': '胡別人加在明刻上的牌。',
    'Shoot after Kong': '胡別人開槓後緊接著打出的牌。',
    'Under the Sea': '胡牌牆最後一張，或其後打出的牌。',
  };
}
