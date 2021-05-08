# coding: utf-8
# 5chのデータのcsvファイルのパス
FILES = {}
FILES['頭'] =     './5ch/MHR_EQUIP_HEAD - 頭.csv'  
FILES['胴'] =     './5ch/MHR_EQUIP_BODY - 胴.csv'  
FILES['腕'] =     './5ch/MHR_EQUIP_ARM - 腕.csv'   
FILES['腰'] =     './5ch/MHR_EQUIP_WST - 腰.csv'   
FILES['脚'] =     './5ch/MHR_EQUIP_LEG - 脚.csv'   
FILES['スキル'] = './5ch/MHR_SKILL - スキル.csv'   
FILES['装飾品'] = './5ch/MHR_DECO - Sheet 1.csv'

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
# (0..[0 1 2 3]) 加護珠【２】:{装飾品} -> -1 Lv2スロ, 1 精霊の加護
def deco(sklmax)
  lines = IO.readlines(FILES['装飾品']).map {|x| x.encode('UTF-8', 'UTF-8') }
  lines.shift # 見出しは捨てる
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
    rng = (0..rngmax).to_a.join(' ')
    res.push('(0..[%s]) %s:{装飾品} -> %s, %s' % [rng, name, slotstr, str])
  }
  res
end

# parse_skillで得た、スキル系統=>最大値の情報から、以下のようなものを生成し、Arrayを返す
# ([0 1 2 3 4 5 6 7]..7)* ひるみ軽減:{スキル}
def skill(sklmax)
  res = []
  sklmax.each {|name, maxval|
    rng = (0..maxval).to_a.join(' ')
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
  #
  yss = lss.map.with_index {|ls, i|
    ls.map {|line|
      xs = line.split(',')
      name, sl1, sl2, sl3, de, demax = xs.values_at(0, 3,4,5, 7,8)
      taisei = xs[9..13]
      sklval = xs[14..23] # スキル系統が5つ確保してある
      demax = de if demax == '' # !! スパイオＳペット:{胴} で抜けている
      # 防御力、耐性
      str = '(0..C) %s:{%s} -> %s 防御力, %s 最終強化防御力' %
            [name,bs[i],de,demax]
      str += ', %s 火耐性, %s 水耐性, %s 雷耐性, %s 氷耐性, %s 龍耐性' % taisei
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
  #
  res = Hash.new(0)
  lines.each {|line|
    name, val = line.split(',').values_at(0, 2)
    res[name] = [res[name], val.to_i].max
  }
  res
end



#### main
sklmax = parse_skill
# puts sklmax
de = deco(sklmax)
sk = skill(sklmax)
eq = equip
puts DATA.to_a.join % [
       eq.join("\n"),
       de.join("\n"),
       sk.join("\n"),
     ]

__END__
# mhrシミュの雛形パーセントsは3つあり、順に、防具、装飾品、スキル条件
<META>
title mhrシミュ
# glpk show

<UI>
width:150px
subsection 防具
(0..1) 頭防具なし:{頭}
(0..1) 胴防具なし:{胴}
(0..1) 腕防具なし:{腕}
(0..1) 腰防具なし:{腰}
(0..1) 脚防具なし:{脚}

#### 以下の防具はデータベースから作成
%s

#### 以下の装飾品はデータベースから作成
subsection 装飾品
%s

#### 以下の護石はユーザー定義なので、どうする?
subsection 護石
nowidth
(0..1) 護石なし:{護石}
(0..C) 護石１:{護石} -> [0 1 2] [スキルなし {スキル}], [0 1 2] [スキルなし {スキル}], [0 1 2 3] Lv1スロ, [0 1 2 3] Lv2スロ, [0 1 2 3] Lv3スロ

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
width:100px
(-30?..) 火耐性:{耐性}
(-30?..) 水耐性:{耐性}
(-30?..) 雷耐性:{耐性}
(-30?..) 氷耐性:{耐性}
(-30?..) 龍耐性:{耐性}
br
nowidth
(1..1) 武器スロット -> [0 1 2 3] Lv1スロ, [0 1 2 3] Lv2スロ, [0 1 2 3] Lv3スロ

subsection 最大化するもの
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

<QUERY>
検索 検索中止 追加検索 最大化式

<SUMMARY>
width:50px
v 防御力
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

newcolumn 追加スキル