/// Japanese rules text, following [EnRulesText] section for section. Riichi
/// and Hong Kong count 翻, Taiwanese 台, MCR and Sichuan 番, as on the score
/// screen.
library;

import 'package:mahjong_core/ruleset.dart';

import 'rules_content.dart';
import 'rules_text.dart';

class JaRulesText extends RulesText {
  const JaRulesText();

  @override
  List<RuleSection> riichi({required bool sanma}) => [
        RuleSection(
            'setup',
            '牌と目標',
            sanma
                ? '3人で108枚を使います。二〜八萬は抜かれ、対面は空席です。ツモの合間は13枚を持ちます。和了形は通常4面子1雀頭です。七対子（異なる7つの対子）と国士無双は特殊な和了形です。持ち点は35,000点です。'
                : '4人で、赤五を含む136枚を使います。ツモの合間は13枚を持ちます。和了形は通常4面子1雀頭です。面子は同じ色の数牌3枚の順子か、同じ牌3枚の刻子で、槓子は同じ牌4枚です。七対子（異なる7つの対子）と国士無双は特殊な和了形です。持ち点は25,000点です。'),
        RuleSection(
            'calls',
            'ツモ・打牌・鳴き',
            sanma
                ? '1枚ツモって1枚捨てます。捨て牌をポンして刻子、カンして槓子にできますが、チーはできません。カンすると王牌から嶺上牌をツモります。ポンや明槓をすると副露となり、つけられる役が変わります。'
                : '1枚ツモって1枚捨てます。チーは上家（直前の人）の捨て牌で順子を作り、ポンは刻子、カンは槓子を作ります。和了の宣言が最優先です。カンすると王牌から嶺上牌をツモります。チー・ポン・明槓で副露となり、つけられる役が変わります。'),
        const RuleSection('winning', '和了：役とフリテン',
            '自分のツモで和了ればツモ、捨て牌で和了ればロンです。役が最低1つ必要で、ドラだけでは和了れません。待ち牌のどれかが自分の捨て牌にあるとフリテンで、ロンはできませんがツモは可能です。和了れるロンを見逃しても一時的にロンできなくなり、リーチ後はその局の終わりまで続きます。'),
        const RuleSection('riichi', 'リーチとドラ',
            '門前で聴牌し、持ち点が足りていればリーチを宣言して1,000点の供託を払います。以後は手牌が固定され、原則としてツモ牌をそのまま捨て、認められたカンだけができます。役とドラが翻を加え、符は手の形を表します。ドラ表示牌がボーナス牌を示し、赤五もボーナスの翻になり、リーチで和了ると裏ドラがめくられます。'),
        if (sanma)
          const RuleSection('kita', '北抜き',
              '自分の番に北を抜いて1翻のボーナスとし、補充牌をツモります。ドラ表示牌や裏ドラ表示牌が北を指せば、その分も加算されます。リーチ後は、ツモったばかりの北だけを抜けます。北抜きは一発と第一巡の役を消します。抜いた北はロンできますが、槍槓ではありません。北抜きとカンの補充は合わせて8回までです。一萬の表示牌なら九萬がドラになり、その逆も同じです。'),
        RuleSection(
            'payments',
            '点数と支払い',
            sanma
                ? '翻と符で点数が決まり、通常の点数表の上に満貫以上と役満があります。ロンは放銃者が払います。ツモは2人の相手が4人打ちと同じ額を払い、空席の分は誰も払いません（ツモ損）。流局時、聴牌者と不聴者がいれば2,000点が移動します。途中流局は九種九牌のみです。'
                : '翻と符で点数が決まり、通常の点数表の上に満貫以上と役満があります。ロンは放銃者が払い、ツモは全員が親・子に応じた額を払います。本場は積み棒の加算点となり、和了者が供託のリーチ棒を受け取ります。流局時、聴牌者と不聴者がいれば3,000点が移動します。まれな符の扱いと一部のダブル役満は簡略化しています。'),
        RuleSection(
            'game',
            '親と対局の長さ',
            sanma
                ? '半荘は東場と南場で、各場3局が予定されています。東風戦は3局です。親の連荘で延長されることがあります。対面の席には手番がありません。'
                : '半荘は東場と南場で、各場4局が予定されています。東風戦は4局です。親が和了るか、流局時に親が聴牌していれば連荘となり、対局が延びます。'),
        const RuleSection('source', 'この概要について',
            'TileSenseが実装しているルールの早見表です。上の一覧は、採点で数えるすべての役・符・満貫以上を網羅しています。三麻はJapanese Mahjong Wikiの三麻の解説に基づいています。詳しくは外部資料をご覧ください。'),
      ];

  @override
  List<RuleSection> hongKong(String minimum) => [
        const RuleSection('setup', '牌と目標',
            '4人で、花牌・季節牌8枚を含む144枚を使います。ツモの合間は通常の牌を13枚持ち、普通の和了形は4面子1雀頭です。七対子と十三幺にも対応しています。花牌は晒して山の後ろから補充し、カンの補充も同じです。王牌はありません。'),
        const RuleSection('calls', 'ツモ・打牌・鳴き',
            '1枚ツモって1枚捨てます。チーは上家からだけ順子を取り、ポンは刻子、カンは槓子を作ります。和了がカン・ポンより、カン・ポンがチーより優先されます。加槓は搶槓できますが、暗槓はできません。同じ捨て牌で複数人が和了れます。最後の捨て牌は和了る場合だけ取れます。'),
        RuleSection('winning', '和了と最低翻数',
            '$minimum 最低翻数に届かない手は和了れません。0翻なら、何の役もない完成形（鶏糊）でも和了れます。自摸には翻が付くので、ロンでは足りない手もツモなら和了れることがあります。リーチやフリテンはありません。'),
        const RuleSection('scoring', '翻と花牌',
            '独立した役は翻を足し合わせ、上位の役は下位の役に置き換わります。花牌・季節牌でもボーナスが付きます。7枚目か8枚目の花牌を晒すと、補充牌を引く前に3翻か8翻の花和了を選べます。すべての役を下に掲載しています。'),
        const RuleSection('payments', '支払い',
            '0〜13翻の点数は1、2、4、8、16、24、32、48、64、96、128、192、256、384点です。それ以上も384点が上限です。ロン和了では放銃者だけが各和了者に点数の2倍を払います。自摸では相手全員が点数を払います。流局では点数は動かず、親の倍付けや積み棒もありません。'),
        const RuleSection('game', '親と対局の長さ',
            '和了でも流局でも親は連荘し、それ以外は親が移ります。TileSenseでは東場と南場（予定8局）または東風戦（4局）で、連荘の分だけ延びます。チップがマイナスになっても対局は終わりません。'),
        const RuleSection('source', 'この概要について',
            'danmaの香港麻雀ルールシート第1.0版をTileSenseが実装したもので、放銃者全額払いの新式の支払いを採用しています。原本はPDFをご覧ください。'),
      ];

  @override
  List<RuleSection> taiwanese(String minimum) => [
        const RuleSection('setup', '牌と目標',
            '4人で、花牌・季節牌を含む144枚を使います。ツモの合間は通常の牌を16枚持ちます。普通の和了形は17枚で、5面子1雀頭です。異なる7つの対子と刻子1つも和了形です。カンも1面子と数えます。花牌は自動で晒して補充します。'),
        const RuleSection('calls', 'ツモ・打牌・鳴き',
            '1枚ツモって1枚捨てます。チーは上家から順子を取り、ポンとカンは同じ牌を取ります。和了の宣言が最優先です。暗槓は局の終わりまで4枚とも伏せて置きます。リーチ・ドラ・赤五のボーナスはありません。最後の捨て牌は和了る場合だけ取れます。'),
        RuleSection('winning', '和了と最低台数',
            '$minimum この最低台数はTileSense独自のハウスルールです。届かない完成形は和了れません。和了れる捨て牌を見逃すと、次の自分のツモまでその待ちでは和了れません。自分の過去の捨て牌によるリーチ式のフリテンはありません。'),
        const RuleSection('scoring', '加算式の台と花牌',
            '役は香港式の倍々の点数表ではなく、固定の点を足し合わせます。元のシートの点数をアプリでは台として使います。花牌のボーナスも最低台数に数えます。花牌8枚で特別な花和了になります。すべての役を下に掲載しています。'),
        const RuleSection('payments', '支払いと連荘ボーナス',
            '自摸では相手全員が手の点数を全額払い、ロンでは放銃者だけが払います。親の連荘ボーナスは、直前までの連続和了が0、1、2、3回以上でそれぞれ0、2、4、6点です。親が和了ったとき、または親が放銃したときに適用されます。流局で連続記録はリセットされます。'),
        const RuleSection('game', '親と対局の長さ',
            '和了でも流局でも親は続投し、それ以外は親が移ります。東場と南場、または短い東風戦で遊べます。連荘の分だけ予定の局数より延びます。'),
        const RuleSection('source', 'この概要について',
            'サンディエゴ麻雀クラブの台湾麻雀パンフレット（Nathanael J. Reynolds作）に基づき、TileSenseの設定可能な最低台数を加えています。'),
      ];

  @override
  List<RuleSection> mcr() => const [
        RuleSection('setup', '牌と目標',
            '4人で、花牌8枚を含む144枚を使います。ツモの合間は13枚を持ちます。通常は4面子1雀頭で和了り、七対・十三幺・組合龍などの特殊形もあります。同じ牌4枚を対子2つと数えることもできます。TileSenseでは花牌は常に晒して補充します。王牌はありません。'),
        RuleSection('calls', 'ツモ・打牌・鳴き',
            'チーは上家からだけできます。和了がカン・ポンより、カン・ポンがチーより優先されます。チーやポンをした手番にはカンできません。暗槓は局の終わりまで伏せたままです。最後の捨て牌は和了る場合だけ取れます。同じ捨て牌に複数人が和了を宣言したら、放銃者の下家から数えて最も近い人だけが和了ります。'),
        RuleSection('winning', '最低8番',
            '和了には花牌を除いて8番以上が必要です。7番に花牌を足しても届きません。ほかに番種がない手は無番和（8番）になります。リーチ・フリテン・本場はありません。'),
        RuleSection('scoring', '81の番種と不計',
            '採点では81の番種すべてと組み合わせの原則を考慮し、合法な最高点を選びます。重なる番種や含まれる番種は足せないことがあります。花牌は最低点を満たした後にだけ1枚1番加わります。すべての番種と、同時に数えない番種を下に掲載しています。'),
        RuleSection('payments', '支払い',
            '花牌を含めてF番の手なら、自摸では相手全員がF＋8点を払います。ロンでは放銃者がF＋8点、ほかの2人が8点ずつ払います。流局では点数は動きません。持ち点は0から始まり、マイナスにもなります。'),
        RuleSection('game', '親と対局の長さ',
            '和了でも流局でも、毎局親が移ります。フルゲームは東・南・西・北の各4局、計16局です。短い練習ゲームは東場の4局です。'),
        RuleSection('source', 'この概要について',
            '世界麻将組織（WMO）の「麻将競技規則」に基づいています。TileSenseは対局と採点を実装しており、大会運営や審判の罰則は対象外です。詳しくはPDFをご覧ください。'),
      ];

  @override
  List<RuleSection> sichuan() => const [
        RuleSection('setup', '牌と目標',
            '4人で数牌108枚を使い、字牌と花牌はありません。ツモの合間は13枚を持ちます。4面子1雀頭か七対子で和了ります。同じ牌4枚を対子2つと数えることもできます。赤五や王牌はありません。カンの補充は山の後ろから引きます。'),
        RuleSection('void', '定缺（捨てる色を決める）',
            '対局前に、捨てる色を1つ選びます。その色の牌をすべて捨てるまで、ほかの色は捨てられません。その色が手牌や副露に残っている間は和了れません。選んだ色は最初の捨て牌まで相手に伏せられます。'),
        RuleSection('calls', '鳴きと続行',
            'ポンとカンはできますが、チーはできません。手牌の中の順子は構いません。和了った人は抜け、残りの人が続けます。同じ捨て牌で複数人が和了れます。3人が和了るか山が尽きると局が終わります。最後の捨て牌は和了る場合だけ取れます。'),
        RuleSection('winning', '和了と見逃し',
            '最低番数・リーチ・本場はありません。和了れる牌を見逃すと、自分の手番が来るまでその牌を他家から和了れず、ほかの捨て牌もより高くならない限り和了れません。'),
        RuleSection('scoring', '番と支払い',
            '手の点数は0、1、2、3番以上でそれぞれ1、2、4、8点です。対々和と根（同じ牌4枚）1つごとに1番、清一色と七対子は2番です。状況役もあります。ロンでは放銃者が各和了者に手の点数を払います。自摸では、まだ対局中の相手が手の点数＋1点ずつ払います。'),
        RuleSection('settlement', 'カンと流局時の精算',
            '暗槓は対局中の相手から2点ずつ、明槓は放銃者から2点、加槓は対局中の相手から1点ずつ得ます。加槓はツモったばかりの牌でしかできません。搶槓されたり、直後の捨て牌で和了られたりするとカンの支払いは取り消されます。最後まで残って聴牌していない人は、カンの支払いを受け取れません。山が尽きたら、不聴の人が聴牌の人それぞれに、その待ちの最高点を払います。'),
        RuleSection('game', '親と対局の長さ',
            '持ち点は0から始まります。練習は4局、フルゲームは8局で、場風はありません。最初に和了った人が次の親になり、最初の和了が同じ捨て牌での複数人なら放銃者が親です。誰も和了らなければ親は続投します。'),
        RuleSection('source', 'この概要について',
            'mahjongpictureguide.comの四川血戦ルール早見表に基づき、シートにない点はTileSenseの精算と手番の決め方で補っています。詳しくはPDFをご覧ください。'),
      ];

  @override
  String hongKongDefaultMinimum(int faan, List<int> choices) =>
      '標準の最低翻数：$faan翻。対局前に${choices.join('・')}翻から選べます。';
  @override
  String hongKongTableMinimum(int faan) => 'この卓の最低翻数：$faan翻。';
  @override
  String taiwaneseDefaultMinimum(int tai, List<int> choices) =>
      '標準の最低台数：$tai台。対局前に${choices.join('・')}台から選べます。';
  @override
  String taiwaneseTableMinimum(int tai) => 'この卓の最低台数：$tai台。';

  @override
  String groupTitle(String id) => switch (id) {
        'yaku' => '役一覧',
        'yakuman' => '役満',
        'dora' => 'ドラとボーナスの翻',
        'fu' => '符',
        'limits' => '満貫以上',
        'faan' => '役一覧',
        'tai' => '台数一覧',
        'sichuanFan' => '番種一覧',
        _ => '${id.substring(3)}番の番種',
      };

  @override
  String groupIntro(String id) => switch (id) {
        'yaku' =>
          '和了には役が1つ以上必要で、ドラだけでは数えません。関連する役が両方成り立つときは、上位の役が下位の役に置き換わります。',
        'yakuman' => '役満は1つにつき基本点8,000点で、複合します。天和・地和・人和・四槓子・流し満貫は実装していません。',
        'dora' => 'ボーナスの翻は役がある手にだけ付き、役満には加算しません。',
        'fu' => '符は手の形を表します。合計してから切り上げます。',
        'limits' =>
          '基本点は 符×2^(翻＋2) で、以下の満貫以上に引き上げます。ロンは基本点の4倍、親へは6倍です。ツモでは親が2倍・子が1倍、親の和了なら全員が2倍を払い、それぞれ100点単位に切り上げます。',
        'faan' => '独立した役は足し合わせます。13翻を超える分も表示しますが、支払いは13翻が上限です。',
        'tai' =>
          '台は足し合わせます。段階のある役は最も高いものだけを数えます。シートにあるリーチ（10台）と搶花（20台）は実装していません。',
        'sichuanFan' => '番は足し合わせ、0、1、2、3番以上でそれぞれ1、2、4、8点を払います。',
        'mcr88' =>
          '規則の付録1にある81の番種すべてです。採点は合法な最高点を選びます。「不計」の後の番種は含まれているため重ねて数えません。',
        _ => '',
      };

  @override
  String value(ValueUnit unit, ScoringPattern p) {
    final each = p.each ? '各' : '';
    return switch (unit) {
      ValueUnit.han when p.yakuman > 0 => p.yakuman == 1 ? '役満' : 'ダブル役満',
      ValueUnit.han when p.closedOnly => '${p.value}翻（門前のみ）',
      ValueUnit.han when p.open != null => '${p.value}翻（鳴き${p.open}翻）',
      ValueUnit.han || ValueUnit.faan => '$each${p.value}翻',
      ValueUnit.tai => '$each${p.value}台',
      ValueUnit.fan || ValueUnit.mcrFan => '$each${p.value}番',
      ValueUnit.fu => p.value == 0 ? '' : '${p.value}符',
      ValueUnit.basicPoints => '基本点${groupDigits(p.value)}点',
    };
  }

  @override
  Map<String, String> get readerNames => const {
        'yakuhaiDragon': '役牌（三元牌）',
        'hkDragonPung': '三元牌の刻子',
        'hkSeatFlower': '自分の花牌・季節牌',
        'fuBase': '副底',
        'fuClosedRon': '門前ロン',
        'fuTsumo': 'ツモ',
        'fuPinfu': '平和',
        'fuChiitoitsu': '七対子',
        'fuOpenSimpleTriplet': '中張牌の明刻',
        'fuClosedSimpleTriplet': '中張牌の暗刻',
        'fuOpenHonorTriplet': '幺九牌の明刻',
        'fuClosedHonorTriplet': '幺九牌の暗刻',
        'fuKan': '槓子',
        'fuValuePair': '役牌の雀頭',
        'fuWait': '嵌張・辺張・単騎待ち',
        'fuRounding': '切り上げ',
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
    'Riichi': '門前で聴牌したら1,000点を払って宣言し、以後は手牌が固定されます。',
    'Double Riichi': '鳴きやカンが入る前の、最初の捨て牌でのリーチ。リーチと置き換わります。',
    'Ippatsu': 'リーチ後、鳴きやカンが入らずに一巡以内に和了ること。',
    'Menzen Tsumo': '門前でのツモ和了。',
    'Pinfu': '4つの順子、役牌でない雀頭、両面待ち。',
    'Iipeiko': '同じ色の同じ順子が2つ。',
    'Haitei Raoyue': '山の最後の牌でツモ和了。',
    'Houtei Raoyui': '最後の捨て牌でロン和了。',
    'Rinshan Kaihou': '王牌からの補充牌で和了。',
    'Chankan': '他家の加槓の牌でロン和了。',
    'Tanyao': '幺九牌を一切含まない。鳴いても成立します。',
    'yakuhaiDragon': '三元牌の刻子か槓子。',
    'Round Wind': '場風の刻子か槓子。',
    'Seat Wind': '自風の刻子か槓子。場風と同じなら2翻。',
    'Sanshoku Doujun': '3色で同じ順子。',
    'Ittsu': '同じ色の123・456・789。',
    'Chanta': 'すべての面子と雀頭に幺九牌を含み、順子が1つ以上ある。',
    'Chiitoitsu': '異なる7つの対子で、常に25符。TileSenseではドラだけを加え、リーチ・ツモ・断幺九・染め手は数えません。',
    'Toitoi': '4つの刻子か槓子。',
    'Sanankou': '暗刻3つ。ロンで完成した刻子は明刻扱いです。',
    'Sanshoku Doukou': '3色で同じ数字の刻子。',
    'Sankantsu': '槓子3つ（明槓・暗槓を問わず）。',
    'Honroutou': '幺九牌だけで4つの刻子と雀頭。対々和も付きます。',
    'Shousangen': '三元牌の刻子2つと三元牌の雀頭。三元牌の刻子それぞれの役も付きます。',
    'Junchan': 'すべての面子と雀頭に一か九を含み、字牌なし。混全帯幺九と置き換わります。',
    'Honitsu': '1色と字牌だけ。',
    'Ryanpeikou': '同じ順子の組が2つ。一盃口と置き換わります。',
    'Chinitsu': '1色だけ。混一色と置き換わります。',
    'Kokushi Musou': '幺九牌13種を1枚ずつと、そのうち1種をもう1枚。',
    'Suuankou': '暗刻4つ。単騎待ちでもダブル役満にはなりません。',
    'Daisangen': '三元牌3種すべての刻子。',
    'Shousuushii': '風牌の刻子3つと風牌の雀頭。',
    'Daisuushii': '風牌4種すべての刻子。',
    'Tsuuiisou': '字牌だけ。七対子形も含みます。',
    'Chinroutou': '一と九の数牌だけ。',
    'Ryuuiisou': '二・三・四・六・八索と發だけ。發はなくても構いません。',
    'Chuuren Poutou': '門前で同じ色の1112345678999にその色の1枚。九面待ちでもダブル役満にはなりません。',
    'Dora': 'ドラ表示牌の次の牌1枚ごと。',
    'Ura Dora': '裏ドラ表示牌について同様。リーチで和了ったときだけ数えます。',
    'Aka Dora': '赤五1枚ごと。',
    'Kita': '抜いた北1枚ごと。表示牌が北を指せばさらに加算。',
    'fuBase': '平和と七対子を除くすべての手の基本。',
    'fuClosedRon': '門前で捨て牌から和了。',
    'fuTsumo': 'ツモ和了。平和には付きません。',
    'fuPinfu': 'ロンで30符、ツモで20符。',
    'fuChiitoitsu': '固定で、切り上げません。',
    'fuOpenSimpleTriplet': '鳴いた二〜八の刻子。',
    'fuClosedSimpleTriplet': '二〜八の暗刻。ロンで完成した刻子は明刻扱いです。',
    'fuOpenHonorTriplet': '鳴いた一・九・字牌の刻子。',
    'fuClosedHonorTriplet': '一・九・字牌の暗刻。',
    'fuKan': '同じ刻子の4倍で、8・16・32符。',
    'fuValuePair': '三元牌・場風・自風の雀頭。場風と自風を兼ねれば4符。',
    'fuWait': '和了牌が両面待ちとしても取れる場合は付きません。',
    'fuRounding': '10符単位に切り上げます。鳴いてロンし副底だけの手は20符のままです（標準ルールでは30符）。',
    'Mangan': '5翻、または符が多く基本点が2,000点に達する手。切り上げ満貫はありません。',
    'Haneman': '6〜7翻。',
    'Baiman': '8〜10翻。',
    'Sanbaiman': '11〜12翻。',
    'Kazoe Yakuman': '通常の役とドラで13翻以上。',
    'Yakuman': '役満1つあたり。複数は複合します。',
  };

  static const _hongKong = {
    'Self-Pick': '自分のツモで和了。',
    'Win by Kong Replacement': 'カンの補充牌で自摸和了。自摸と置き換わります。',
    'Double Kong Replacement': '最初の補充牌で再びカンし、その補充牌で和了。ほかの自摸の役と置き換わります。',
    'Concealed Hand': '晒した副露なし。暗槓は門前を崩しません。ロン和了でも数えます。',
    'Robbing the Kong': '明刻に加えられた牌で和了。',
    'Moon Under the Sea': '山の最後の牌か最後の捨て牌で和了。',
    'All Sequences': '4つの順子。',
    'All Triplets': '4つの刻子か槓子。',
    'All Concealed Triplets': '暗刻4つ。自摸か、雀頭を完成させるロン。対々糊と置き換わります。',
    'All Quadruplets': '槓子4つ。刻子系の役と置き換わります。',
    'hkDragonPung': '三元牌の刻子か槓子。',
    'Small Three Dragons': '三元牌の刻子2つと三元牌の雀頭。三元牌の刻子の役と置き換わります。',
    'Big Three Dragons': '三元牌3種すべての刻子。三元牌の刻子の役と置き換わります。',
    'Seat Wind': '自風（門風）の刻子か槓子。',
    'Round Wind': '場風（圏風）の刻子か槓子。両方を兼ねれば2翻。',
    'Small Four Winds': '風牌の刻子3つと風牌の雀頭。門風・圏風の役と置き換わります。',
    'Big Four Winds': '風牌4種すべての刻子。門風・圏風の役と置き換わります。',
    'Mixed Flush': '1色と字牌だけ。',
    'Full Flush': '1色だけ。混一色と置き換わります。',
    'Mixed Terminals': '幺九牌だけ。対々糊を含みます。暗刻4つや槓子4つと重なるときは、上乗せ分（5か10）だけを加えます。',
    'All Terminals': '一と九だけ。対々糊を含みます。',
    'All Honours': '字牌だけ。対々糊を含みます。',
    'Seven Pairs': '異なる7つの対子（有効にしている選択ルール）。染め手や字一色と複合します。',
    'Nine Gates': '門前で同じ色の1112345678999にその色の1枚。',
    'Thirteen Orphans': '幺九牌13種を1枚ずつと、そのうち1種をもう1枚。',
    'Blessing of Heaven': '親が配牌で和了。',
    'Blessing of Earth': '鳴きが入る前に、親の最初の捨て牌で和了。',
    'Blessing of Man': '鳴きが入る前の、子の最初の自摸和了。',
    'No Flowers or Seasons': '花牌を1枚も晒していない。',
    'hkSeatFlower': '自分の席の番号の花牌：東1、南2、西3、北4。',
    'All Flowers': '花牌4枚すべて。自分の花牌の役に加算。',
    'All Seasons': '季節牌4枚すべて。自分の季節牌の役に加算。',
    'Seven Flowers': '7枚目の花牌を晒したときに選べる即時和了。ほかの役は数えません。',
    'Eight Flowers': '花牌8枚すべてを晒したときに選べる即時和了。ほかの役は数えません。',
    'Chicken Hand': '役のない完成形。最低0翻のときだけ和了れます。',
  };

  static const _taiwanese = {
    'Self-Drawn': '自分のツモで和了。門前清自摸と重ねて数えます。',
    'Concealed Hand': '門前でロン和了。',
    'Fully Concealed Hand': '門前で自摸和了。門前清の代わりに数えます。',
    'Value Honor': '三元牌の刻子・槓子1つごと、および自風の刻子・槓子。',
    'Flower Tile': '晒した花牌・季節牌1枚ごと（番号を問わず）。',
    'No Flower Tiles': '花牌・季節牌なし。',
    'No Honors': '字牌なし。',
    'No Flower or Honor Tiles': 'どちらもなし。上の2つと置き換わります。',
    'Melded Kong': '明槓・加槓1つごと。',
    'Concealed Kong': '暗槓1つごと。',
    'Two Concealed Pungs': '暗刻か暗槓が2つ。捨て牌で完成した刻子は暗刻ではありません。',
    'Three Concealed Pungs': '3つ。二暗刻と置き換わります。',
    'Four Concealed Pungs': '4つ。下位の段階と置き換わります。',
    'Five Concealed Pungs': '5つ。下位の段階と置き換わります。',
    'Single Wait': '和了牌で雀頭が完成。',
    'Closed Wait': '和了牌が順子の真ん中（4-5-6の5など）。',
    'Robbing the Kong': '明刻に加えられた牌で和了。',
    'Last Tile Draw': '山の最後の牌で自摸和了。',
    'Win Within 5 Discards': '和了時に場の捨て牌が5枚未満。',
    'Win Within 5 to 10 Discards': '場の捨て牌が5〜9枚。上の役があればそちらを数えます。',
    'Pure Straight': '同じ色の123・456・789。',
    'All Pungs': '刻子か槓子が5つ。',
    'All Chows': '順子5つで、花牌なし、雀頭が字牌でない。',
    'All Chows with Flowers or Honors': '順子5つで、花牌があるか雀頭が字牌。平胡と置き換わります。',
    'Melded Hand': '5つの面子すべてを鳴いて、ロンで和了。',
    'Little Three Dragons': '三元牌の刻子2つと三元牌の雀頭。',
    'Big Three Dragons': '三元牌3種すべての刻子。小三元と三元牌の役牌と置き換わります。',
    'Little Three Winds': '風牌の刻子2つと風牌の雀頭。',
    'Big Three Winds': '風牌の刻子3つ。小三風と置き換わります。',
    'Little Four Winds': '風牌の刻子3つと風牌の雀頭。大三風と置き換わります。',
    'Big Four Winds': '風牌4種すべての刻子。下位の風牌の段階と置き換わります。',
    'Half Flush': '1色と字牌だけ。',
    'Full Flush': '1色だけ。混一色と置き換わります。',
    'Seven Pairs and a Pung': '異なる7つの対子と刻子1つ。17枚の特殊形です。',
    'Blessings of Heaven': '親が最初の17枚で和了。',
    'Blessings of Earth': '子が親の最初の捨て牌で和了。',
    'All Flowers': '花牌8枚すべて。即時和了で、ほかの役は数えません。',
  };

  static const _mcr = {
    'Big Four Winds': '風牌4種すべての刻子か槓子。',
    'Big Three Dragons': '三元牌3種すべての刻子か槓子。',
    'All Green': '二・三・四・六・八索と發だけ。',
    'Nine Gates': '門前で同じ色の1112345678999を持ち、その色のどの牌でも和了。',
    'Four Kongs': '槓子4つ（明槓・暗槓を問わず）。',
    'Seven Shifted Pairs': '同じ色で数字が連続する7つの対子（2〜8など）。',
    'Thirteen Orphans': '幺九牌13種を1枚ずつと、そのうち1種をもう1枚。',
    'All Terminals': '一と九だけ。',
    'Little Four Winds': '風牌の刻子か槓子3つと風牌の雀頭。',
    'Little Three Dragons': '三元牌の刻子か槓子2つと三元牌の雀頭。',
    'All Honors': '字牌だけ。',
    'Four Concealed Pungs': '暗刻か暗槓4つ。',
    'Pure Terminal Chows': '同じ色の123を2組と789を2組、同じ色の5の雀頭。',
    'Quadruple Chow': '同じ色の同じ順子4つ。',
    'Four Pure Shifted Pungs': '同じ色で数字が連続する刻子か槓子4つ。',
    'Four Shifted Chows': '同じ色で、1つずつか2つずつずれた順子4つ。',
    'Three Kongs': '槓子3つ。',
    'All Terminals and Honors': '一・九・字牌だけで、刻子と雀頭、または七対の形。',
    'Seven Pairs': '7つの対子。同じ牌4枚を2組と数えられます。',
    'Greater Honors and Knitted Tiles':
        '字牌7種すべてと、147・258・369の組合龍（色はそれぞれ別）から7枚。対子なし。',
    'All Even Pungs': '二・四・六・八の刻子か槓子と、同じく偶数の雀頭。',
    'Full Flush': '1色だけ。',
    'Pure Triple Chow': '同じ色の同じ順子3つ。',
    'Pure Shifted Pungs': '同じ色で数字が連続する刻子か槓子3つ。',
    'Upper Tiles': '七・八・九だけ。',
    'Middle Tiles': '四・五・六だけ。',
    'Lower Tiles': '一・二・三だけ。',
    'Pure Straight': '同じ色の123・456・789。',
    'Three-Suited Terminal Chows': '2色でそれぞれ123と789、残りの1色で5の雀頭。',
    'Pure Shifted Chows': '同じ色で、1つずつか2つずつずれた順子3つ。',
    'All Fives': 'すべての面子と雀頭に5を含む。',
    'Triple Pung': '3色で同じ数字の刻子か槓子。',
    'Three Concealed Pungs': '暗刻か暗槓3つ。',
    'Lesser Honors and Knitted Tiles': '字牌と、147・258・369の組合龍から、異なる単独の牌14枚。',
    'Knitted Straight': '147・258・369をそれぞれ別の色で揃え、残りは1面子と雀頭。',
    'Upper Four': '六・七・八・九だけ。',
    'Lower Four': '一・二・三・四だけ。',
    'Big Three Winds': '風牌3種の刻子か槓子。',
    'Mixed Straight': '123・456・789を3色に1つずつ。',
    'Reversible Tiles': '上下逆さでも同じ形の牌だけ：一二三四五八九筒、二四五六八九索、白。',
    'Mixed Triple Chow': '3色で同じ順子。',
    'Mixed Shifted Pungs': '3色に1つずつ、数字が連続する刻子か槓子。',
    'Chicken Hand': '花牌を除いて、ほかに番種がない手。',
    'Last Tile Draw': '山の最後の牌で自摸和了。',
    'Last Tile Claim': '最後の捨て牌で和了。',
    'Out with Replacement Tile': 'カンの補充牌で自摸和了。',
    'Robbing the Kong': '他家が明刻に加えた牌で和了。',
    'Two Concealed Kongs': '暗槓2つ。',
    'All Pungs': '刻子か槓子4つと雀頭。',
    'Half Flush': '1色と字牌だけ。',
    'Mixed Shifted Chows': '3色に1つずつ、1つずつずれた順子。',
    'All Types': '萬子・索子・筒子・風牌・三元牌がすべてある。',
    'Melded Hand': 'すべての面子を鳴き、雀頭を完成させる捨て牌で和了。',
    'Two Dragon Pungs': '三元牌の刻子か槓子2つ。',
    'Outside Hand': 'すべての面子と雀頭に幺九牌を含む。',
    'Fully Concealed': '鳴きなしで自摸和了。',
    'Two Melded Kongs': '明槓2つ。',
    'Last Tile': 'ほかの3枚が見えている牌の、最後の1枚で和了。',
    'Dragon Pung': '三元牌の刻子か槓子。',
    'Prevalent Wind': '圏風（場風）の刻子か槓子。',
    'Seat Wind': '門風（自風）の刻子か槓子。',
    'Concealed Hand': '鳴きなしでロン和了。',
    'All Chows': '順子4つと数牌の雀頭。',
    'Tile Hog': '同じ牌4枚をカンせずに使う。',
    'Double Pung': '2色で同じ数字の刻子か槓子。',
    'Two Concealed Pungs': '暗刻か暗槓2つ。',
    'Concealed Kong': '暗槓1つ。',
    'All Simples': '幺九牌なし。',
    'Pure Double Chow': '同じ色の同じ順子2つ。',
    'Mixed Double Chow': '2色で同じ順子。',
    'Short Straight': '同じ色で、6つ連続する数字になる順子2つ。',
    'Two Terminal Chows': '同じ色の123と789。',
    'Pung of Terminals or Honors': '一・九、または門風でも圏風でもない風牌の刻子か槓子。',
    'Melded Kong': '明槓1つ。',
    'One Voided Suit': '3色のうち1色がない。',
    'No Honors': '字牌なし。',
    'Edge Wait': '12の3、または89の7で和了（唯一の待ち）。',
    'Closed Wait': '順子の真ん中の牌で和了（唯一の待ち）。',
    'Single Wait': '雀頭の牌で和了（唯一の待ち）。',
    'Self-Drawn': '自分のツモで和了。',
    'Flower Tiles': '花牌1枚ごと。最低8番の判定後に加えます。',
    mcrMixedKongs: '明槓1つと暗槓1つ。',
  };

  static const _sichuan = {
    'Root': '手の中の同じ牌4枚1組ごと（カンかどうかを問わず、七対子も含む）。',
    'All Pungs': '刻子か槓子4つと雀頭。',
    'Full Flush': '1色だけ。',
    'Seven Pairs': '7つの対子。同じ牌4枚を2組と数えられます。',
    'Golden Single Wait': '4つの面子を晒し、和了牌で雀頭が完成。対々和を含みます。',
    'Win after Kong': 'カンの補充牌で自摸和了。',
    'Robbing the Kong': '明刻に加えられた牌で和了。',
    'Shoot after Kong': 'カンした人が直後に捨てた牌で和了。',
    'Under the Sea': '山の最後の牌、またはその後の捨て牌で和了。',
  };
}
