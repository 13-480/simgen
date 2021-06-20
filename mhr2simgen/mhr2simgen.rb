# coding: utf-8
# 5chの表計算データを読み、simgen.rbの入力ファイルを出力する。

# 5chのデータのcsvファイルのパス
FILES = {}
FILES['頭'] =     './5ch/MHR_EQUIP_HEAD - 頭.csv'  
FILES['胴'] =     './5ch/MHR_EQUIP_BODY - 胴.csv'  
FILES['腕'] =     './5ch/MHR_EQUIP_ARM - 腕.csv'   
FILES['腰'] =     './5ch/MHR_EQUIP_WST - 腰.csv'   
FILES['脚'] =     './5ch/MHR_EQUIP_LEG - 脚.csv'   
FILES['スキル'] = './5ch/MHR_SKILL - スキル.csv'   
FILES['装飾品'] = './5ch/MHR_DECO - Sheet 1.csv'
DECOord = %w(
達芸珠【２】 匠珠【３】 運気珠【３】 鬼火珠【３】 強跳珠【３】 速射珠【３】 節弾珠【２】
斬鉄珠【２】 散弾珠【３】 貫通珠【３】 強弾珠【３】 剛刃珠【２】 爆破珠【２】 睡眠珠【２】
麻痺珠【２】 全開珠【２】 窮地珠【２】 逆上珠【２】 無傷珠【２】 挑戦珠【２】 痛撃珠【２】
超心珠【２】 装填珠【３】
守勢珠【３】 茸好珠【３】 抜刀珠【３】 射法珠【２】 属会珠【２】 砲術珠【２】 強走珠【２】
短縮珠【２】 心眼珠【２】 底力珠【２】 特射珠【２】 増弾珠【２】 強壁珠【２】 鉄壁珠【２】
早気珠【２】 昂揚珠【２】 渾身珠【２】 攻撃珠【２】 達人珠【２】 速変珠【２】 抑反珠【１】
鈍器珠【２】 早填珠【１】 耐絶珠【１】 耐震珠【２】 防音珠【３】 逆襲珠【２】 泡沫珠【２】
点射珠【１】 抜打珠【２】 跳躍珠【２】 回避珠【２】 耐衝珠【１】 速納珠【２】 防風珠【１】
ＫＯ珠【２】 友愛珠【２】 重撃珠【２】 耐属珠【２】 早食珠【２】 加護珠【２】 壁走珠【２】
翔蟲珠【２】 研磨珠【１】 持続珠【２】 早復珠【１】 治癒珠【２】 鼓笛珠【１】 奪気珠【１】
体術珠【２】 毒珠【１】 滑走珠【１】 爆師珠【１】 火炎珠【１】 流水珠【１】 雷光珠【１】
氷結珠【１】 破龍珠【１】 防御珠【１】 皮剥珠【１】 乗慣珠【２】 無食珠【１】 節食珠【１】
泥雪珠【１】 陽動珠【１】 飛込珠【１】 逆境珠【２】 地学珠【１】 植学珠【１】 耐爆珠【１】
耐眠珠【１】 耐麻珠【１】 耐毒珠【１】 耐火珠【１】 耐水珠【１】 耐雷珠【１】 耐氷珠【１】
耐龍珠【１】
)
SKILLord = %w(
スタミナ急速回復    ジャンプ鉄人      ランナー            翔蟲使い        壁面移動
体術                地質学            植生学              滑走強化
腹減り耐性          剥ぎ取り鉄人      剥ぎ取り名人        幸運            捕獲名人
早食い              体力回復量ＵＰ    アイテム使用強化    キノコ大好き
満足感              広域化            ボマー              泡沫の舞        回避性能
回避距離ＵＰ        飛び込み          ガード性能          ガード強化
精霊の加護          納刀術            ひるみ軽減          回復速度        耳栓
風圧耐性            耐震              気絶耐性            麻痺耐性        毒耐性
睡眠耐性            泥雪耐性          爆破やられ耐性      属性やられ耐性  鬼火纏
攻撃                防御              火耐性              水耐性          氷耐性
雷耐性              龍耐性            火属性攻撃強化      水属性攻撃強化
氷属性攻撃強化      雷属性攻撃強化    龍属性攻撃強化      毒属性強化
爆破属性強化        睡眠属性強化      麻痺属性強化        ＫＯ術          破壊王
スタミナ奪取        乗り名人          陽動                見切り          弱点特効
渾身                抜刀術【技】      抜刀術【力】	超会心  	会心撃【属性】
攻めの守勢          火事場力	龍気活性
逆恨み              逆襲            死中に活
不屈                フルチャージ      力の解放            挑戦者          鈍器使い
集中                強化持続          砲術                匠
業物                達人芸            心眼                砥石使用高速化
剛刃研磨            高速変形          砲弾装填            笛吹き名人
通常弾・連射矢強化  散弾・拡散矢強化  貫通弾・貫通矢強化  弾丸節約
弾導強化            特殊射撃強化      反動軽減            装填速度
装填拡張            ブレ抑制          速射強化            弓溜め段階解放
雷紋の一致          風紋の一致        霞皮の恩恵          鋼殻の恩恵      炎鱗の恩恵
風雷合一
)
# 装飾品
# 00 名前
# 01 レア度
# 02 スロットサイズ
# 03 入手時期
# 04 スキル系統1
# 05 スキル値1
# 06 スキル系統2
# 07 スキル値2
# 後略
#
# これから、以下のようなものを生成し、Arrayを返す
# (0..[0-3]) 加護珠【２】:{装飾品} -> -1 Lv2スロ, 1 精霊の加護
def deco(sklmax)
  lines = IO.readlines(FILES['装飾品']).map {|x| x.encode('UTF-8', 'UTF-8') }
  lines.shift # 見出しは捨てる
  # DECOord順に並べかえる
  lines = lines.sort_by {|line|
    name = line.split(',')[0]
    DECOord.index(name) || 99999 }
  #
  res = []
  lines.each {|line|
    name, slot, skl1, val1, skl2, val2 = line.split(',').values_at(0,2,4,5,6,7)
    rngmax = sklmax[skl1]
    str = val1 + ' ' + skl1
    slotstr = "-1 Lv#{slot}スロ"
    if skl2 && val2 && skl2 != '' then
      rngmax = [rngmax, sklmax[skl2]].max
      str += ', ' + val2 + ' ' + skl2
    end
    rng = "0-#{rngmax}"
    res.push('(0..[%s]) %s:{装飾品} -> %s, %s' % [rng, name, slotstr, str])
  }
  res
end

# parse_skillで得た、スキル系統=>最大値の情報から、以下のようなものを生成し、Arrayを返す
# ([0-7]..7)* ひるみ軽減:{スキル}
def skill(sklmax)
  res = []
  sklmax.each {|name, maxval|
    rng = "0-#{maxval}"
    res.push('([%s]..%s)* %s:{スキル}' % [rng, maxval, name])
  }
  res
end

# 防具
# 00 名前
# 01 "性別(0=両,1=男,2=女)"
# 02 レア度
# 03 スロット1 (1つ目のスロットのLvがいくつか。なければ0)
# 04 スロット2
# 05 スロット3
# 06 入手時期
# 07 初期防御力
# 08 最終防御力
# 09 火耐性
# 10 水耐性
# 11 雷耐性
# 12 氷耐性
# 13 龍耐性
# 14 スキル系統1
# 15 スキル値1
# 16 スキル系統2
# 17 スキル値2
# 18 スキル系統3
# 19 スキル値3
# 20 スキル系統4
# 21 スキル値4
# 22 スキル系統5
# 23 スキル値5
# 後略
#
# 例えば、
# 金色ノ添髪,0,7,2,1,0,7,70,76,2,1,3,-5,2,火事場力,2,渾身,1,,,,,,,,,,,,,,,,,,,,,670
# から、以下のようなものを生成し、Arrayを返す
# (0..C) 金色ノ添髪:{頭} -> 90 最終強化防御力, 70 防御力, 2 火耐性, 1 水耐性, 3 雷耐性, -5 氷耐性, 2 龍耐性, 1 渾身, 2 火事場力, 1 Lv2スロ, 1 Lv1スロ
def equip
  bs = %w(頭 胴 腕 腰 脚)
  lss = bs.map {|b|
    ls = IO.readlines(FILES[b]).map {|x| x.encode('UTF-8', 'UTF-8') }
    ls.shift # 見出しは捨てる
    ls
  }
  lss = sort_equip(lss) # レア度順に安定ソートし、全部位ないときはnilで埋める
  #
  yss = lss.map.with_index {|ls, i|
    ls.map {|line|
      if line.nil? then # その部位はない
        next 'space' # 引数付きnext はその回の値を指定しつつ、次の繰り返しへジャンプ
      end
      xs = line.split(',')
      name, sl1, sl2, sl3, de, demax = xs.values_at(0, 3,4,5, 7,8)
      taisei = xs[9..13]
      sklval = xs[14..23] # スキル系統が5つ確保してある
      demax = de if demax == '' # !! スパイオＳペット:{胴} で抜けている
      # 防御力、耐性
      str = '(0..C) %s:{%s} -> %s 防御力, %s 最終強化防御力' %
            [name,bs[i],de,demax]
      str += ', %s 防具火耐性, %s 防具水耐性, %s 防具雷耐性, %s 防具氷耐性, %s 防具龍耐性' % taisei
      # スロット
      slot = Hash.new(0)
      [sl1, sl2, sl3].each {|sl|
        slot["Lv#{sl}スロ"] += 1 if sl && sl != '' && sl != '0'
      }
      slot.each {|sl, val| str += ", #{val} #{sl}" }
      # スキル
      sklval.each_slice(2) {|skl, val|
        val = '1' if val == '１'
        str += ", #{val} #{skl}" if skl != '' && val != ''
      }
      str
    }
  }
  #
  res = []
  imax = yss.map {|ys| ys.size }.max
  (0...imax).each {|i|
    5.times {|j| res.push(yss[j][i]) if (i < yss[j].size) }
    res.push('br')
  }
  res
end

# 風雷合一対応版
# 例えば、
# 金色ノ添髪,0,7,2,1,0,7,70,76,2,1,3,-5,2,火事場力,2,渾身,1,,,,,,,,,,,,,,,,,,,,,670
# から、以下を生成する (UIセクションへ)。
# (0..C) 金色ノ添髪:{頭} -> 90 最終強化防御力, 70 防御力, 2 火耐性, 1 水耐性, 3 雷耐性, -5 氷耐性, 2 龍耐性, 1 Lv2スロ, 1 Lv1スロ, 1 渾身＊, 2 火事場力＊
#
# 防具に付いている「風雷合一」以外のスキルを収集して、以下を生成する。
# UIセクション:
# (0..) 渾身＊ -> 1 渾身
# (0..1) 渾身追加4 -> 1 渾身, 1 最大化式
# (0..1) 渾身追加5 -> 1 渾身, 1 最大化式
# RELATIONセクション:
# 渾身追加4 <= 風雷4
# 渾身追加5 <= 風雷5
# 渾身追加5 <= 渾身追加4 <= 渾身＊

def equip
  bs = %w(頭 胴 腕 腰 脚)
  lss = bs.map {|b|
    ls = IO.readlines(FILES[b]).map {|x| x.encode('UTF-8', 'UTF-8') }
    ls.shift # 見出しは捨てる
    ls
  }
  lss = sort_equip(lss).transpose # レア度順に安定ソートし、ない部位はnilで埋める
  #
  skls = [] # 防具に付いているスキルのうち風雷合一以外を収集
  res_ui = [] # UIセクションに置くべきもの (UI付き)
  res_induce = [] # UIセクションに置くべきもの (UIなし)
  res_relation = [] # RELATIONセクションに置くべきもの
  # UIセクション (UI付き) の生成と、防具に付いているスキルの収集
  lss.each {|lines|
    lines.each_with_index {|line, i|
      if line.nil? then # その部位はない
        res_ui.push('space')
        next
      end
      xs = line.split(',')
      name, sl1, sl2, sl3, de, demax = xs.values_at(0, 3,4,5, 7,8)
      taisei = xs[9..13]
      sklval = xs[14..23] # スキル系統が5つ確保してある
      demax = de if demax == '' # !! 抜けているものがある
      # 防御力、耐性
      str = '(0..C) %s:{%s} -> %s 防御力, %s 最終強化防御力' %
            [name, bs[i], de, demax]
      str += ', %s 防具火耐性, %s 防具水耐性, %s 防具雷耐性, %s 防具氷耐性, %s 防具龍耐性' % taisei
      # スロット
      slot = Hash.new(0)
      [sl1, sl2, sl3].each {|sl|
        slot["Lv#{sl}スロ"] += 1 if sl && sl != '' && sl != '0'
      }
      slot.each {|sl, val| str += ", #{val} #{sl}" }
      # スキル
      sklval.each_slice(2) {|skl, val|
        next if skl == '' || val == ''
        if skl == '風雷合一' then
          str += ", #{val} #{skl}"
        else
          skls |= [skl]
          str += ", #{val} #{skl}＊"
        end
      }
      res_ui.push str
    }
    res_ui.push 'br'
  }
  # UIセクション (UIなし) と、RELATIONセクションの生成
  skls.each {|skl|
    res_induce.push('(0..) %s＊ -> 1 %s' % [skl, skl])
    res_induce.push('(0..1) %s追加4 -> 1 %s, 1 最大化式' % [skl, skl])
    res_induce.push('(0..1) %s追加5 -> 1 %s, 1 最大化式' % [skl, skl])
    res_relation.push('%s追加4 <= 風雷4' % skl)
    res_relation.push('%s追加5 <= 風雷5' % skl)
    res_relation.push('%s追加5 <= %s追加4 <= %s＊' % [skl, skl, skl])
  }
  #
  [res_ui + res_induce, res_relation]
end

# 装備をレア度で安定ソートし、5部位揃っていないものはnilで補う
# 防具
# 00 名前
# 01 "性別(0=両,1=男,2=女)"
# 02 レア度
# 後略
def sort_equip(lss)
  # 各防具をレア度で安定ソート
  lss = lss.map {|ls|
    ls.stable_sort_by {|line| line.split(',')[2].to_i } }
  # 次をカットすればシリーズ共通の文字列になる
  cutre = Regexp.new(<<EOS.split(/\s+/).join('|'))
【元結】 【白衣】 【花袖】 【腰巻】 【緋袴】
【兜】 【胸当て】 【篭手】 【腰当て】 【具足】
【頭巾】 【上衣】 【手甲】 【脚絆】
【御面】 【覆面】 
【烏帽子】 【大袖】 【丸帯】
クラウン
こうべ むなさき かいな こしもと おみあし
アンク ディール ハトゥー アンダ ペイル
ヘルム メイル アーム コイル グリーヴ
ヘッド ボディ グラブ ベルト フット
テスタ ペット マーノ アンカ ガンバ
ハット スーツ グローブ ブーツ
フロール トロンコ ラーマ オッハ ライース
フード マント ペプラム スリーブ パンツ
ベスト パレオ サンダル
ゲヒル ムスケル ファオスト ナーベル フェルゼ
パオ・ カイ・
フェイク
ロボス
革籠手 革臑当
添髪 羽織 篭手 帯 袴 
EOS
  # ガブラスの頭だけ「ーツ」がないので注意
  align_by(lss) {|line|
    line.split(',')[0].sub('ガブラスーツ', 'ガブラス').gsub(cutre, '')
  }
end

# スキルのファイルを見て、最大値を取得し、スキル系統=>最大値のHashを返す
# 00 スキル系統
# 01 発動スキル
# 02 必要ポイント
# 03 カテゴリ
# 04 効果
# 05 系統番号
# 06 仮番号
def parse_skill
  lines = IO.readlines(FILES['スキル']).map {|x| x.encode('UTF-8', 'UTF-8') }
  lines.shift # 見出しは捨てる
  # SKILLord順に並べかえる
  lines = lines.sort_by {|line|
    name = line.split(',')[0]
$stderr.puts name if ! SKILLord.index(name)


    SKILLord.index(name) || 99999 }

  #
  res = Hash.new(0)
  lines.each {|line|
    name, val = line.split(',').values_at(0, 2)
    res[name] = [res[name], val.to_i].max
  }
  res
end

# 配列の配列を与えると、カテゴリごとに何番目かが揃うようにnilを挿入
# 例: [[1,1,2,2,3], [1,2,2,3,3]] => [[1,1,2,2,3,nil], [1,nil,2,2,3,3]]
# ブロックを与えると、それでカテゴリに変換する
def align_by(xss, &f)
  xss = xss.map {|xs| xs.dup }
  g = f ? (proc {|x| x ? f[x] : x }) : (proc {|x| x} )
  n = xss.size
  yss = n.times.map {[]}
  #
  while xss.any? {|xs| ! xs.empty? }
    ass = n.times.map {|i|
      n.times.map {|j| xss[j].index {|x| g[x] == g[xss[i][0]] }}}
    n.times {|ii|
      if ! ass[ii].empty? && ass[ii].compact.max == 0 then
        n.times {|jj|
          yss[jj].push(ass[ii][jj]==0 ? xss[jj].shift : nil ) }
        break
      end
    }
  end
  yss
end

# 安定なsort_by (Arrayに定義するのは怒られそうだが)
class Array
  def stable_sort_by(&f)
    self.sort_by.with_index {|x, i| [f[x], i] }
  end
end

#### main
sklmax = parse_skill
# puts sklmax
de = deco(sklmax)
sk = skill(sklmax)
eq_ui, eq_rel = equip
if ARGV.size > 0 then
  lines = ARGF.to_a.map {|line| line.encode('UTF-8', 'UTF-8') }.join
else
  lines = ''
end

puts DATA.to_a.join % [
       eq_ui.join("\n") + "\n" + lines,
       de.join("\n"),
       sk.join("\n"),
       eq_rel.join("\n"),
     ]

# DATAはmhrシミュの雛形。%sは4つあり、順に、防具、装飾品、スキル条件、関係式
__END__
<META>
title mhrシミュ
# glpk show
localstrage simgenMHR

<UI>
width:150px
subsection 防具
(0..1) 頭防具なし:{頭}
(0..1) 胴防具なし:{胴}
(0..1) 腕防具なし:{腕}
(0..1) 腰防具なし:{腰}
(0..1) 脚防具なし:{脚}

(0..1) 風雷4 -> 1 最大化式
(0..1) 風雷5 -> 1 最大化式

#### 以下の防具はデータベースから作成
%s

#### 以下の装飾品はデータベースから作成
subsection 装飾品
%s

#### 以下の護石はユーザー定義なので、どうする?
subsection 護石
nowidth
(0..1) 護石なし:{護石}
(0..C) 護石00:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石01:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石02:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石03:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石04:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石05:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石06:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石07:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石08:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石09:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石10:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石11:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石12:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石13:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石14:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石15:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石16:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石17:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石18:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石19:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br
(0..C) 護石20:{護石} -> [0-3] [スキルなし {スキル}], [0-3] [スキルなし {スキル}], [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ
br

#### 以下のスキル条件はデータベースから作成
subsection スキル条件
width:180px
%s

subsection 最低防御力、最低耐性値指定、武器スロット数
width:100px
(1?..) 防御力
nowidth
(1?..) 最終強化防御力
br
width:150px
(-30?..) 防具火耐性:{耐性}
(-30?..) 防具水耐性:{耐性}
(-30?..) 防具雷耐性:{耐性}
(-30?..) 防具氷耐性:{耐性}
(-30?..) 防具龍耐性:{耐性}
br
nowidth
(1..1) 武器スロット -> [0-3] Lv1スロ, [0-3] Lv2スロ, [0-3] Lv3スロ

subsection 何が最大のものを検索するか
[最終強化防御力 防御力 {スキル}] -> 1000 最大化式
Lv1以上空きスロ -> 1 最大化式

<UNLOCK>
# 解放 3, 攻撃 3 5

<RELATION>
{頭}.sum = {胴}.sum = {腕}.sum = {腰}.sum = {脚}.sum = {護石}.sum = 1

Lv3スロ >= 0
Lv3スロ + Lv2スロ >= 0
Lv3スロ + Lv2スロ + Lv1スロ >= 0

Lv1以上空きスロ = Lv3スロ + Lv2スロ + Lv1スロ
Lv2以上空きスロ <= Lv1以上空きスロ
Lv2以上空きスロ <= Lv3スロ + Lv2スロ
Lv3以上空きスロ <= Lv2以上空きスロ
Lv3以上空きスロ <= Lv3スロ

Lv1空きスロ = Lv1以上空きスロ - Lv2以上空きスロ
Lv2空きスロ = Lv2以上空きスロ - Lv3以上空きスロ
Lv3空きスロ = Lv3以上空きスロ

4 風雷4 <= 風雷合一
5 風雷5 <= 風雷合一

#### 以下の関係式は条件はデータベースから作成
%s

<QUERY>
query 検索 検索中止 追加検索 最大化式

<SUMMARY>
width:50px
v 最終強化防御力
width:150px
n* {頭}
n* {胴}
n* {腕}
n* {腰}
n* {脚}

<DETAILS>
newcolumn 検索対象スキル
nv* {スキル}
newcolumn !その他スキル

newcolumn 護石・装飾品
n* {護石}
nv* {装飾品}

newcolumn 防御力・耐性
nv 防御力
nv 最終強化防御力
nv {耐性}

newcolumn 空きスロット
nv Lv1空きスロ
nv Lv2空きスロ
nv Lv3空きスロ

newcolumn 所要時間
time

newcolumn 追加スキル
more 追加スキル {スキル}
