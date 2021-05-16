# coding: utf-8
# 所持している護石から、simgen.rbのUIセクションで読める形式の護石のス
# キルやスロットのデータを出力する。mhr2simgen.rb でコマンドライン引数
# として指定すると、適切な位置に読み込まれる。

lines = <<EOS
# レア7
水耐性            1  ひるみ軽減      1  Lv1スロ  1  Lv2スロ  2
精霊の加護        1  爆破やられ耐性  2  Lv1スロ  1  Lv3スロ  1
火耐性            2  氷耐性          2  Lv1スロ  1  Lv2スロ  1
アイテム使用強化  2  回避距離ＵＰ    2  Lv1スロ  1  Lv2スロ  1
アイテム使用強化  1  装填速度        1  Lv1スロ  1  Lv2スロ  1
回避距離ＵＰ      1  腹減り耐性      1  Lv1スロ  1  Lv2スロ  1
アイテム使用強化  2  飛び込み        1  Lv1スロ  1  Lv2スロ  1
高速変形          2  広域化          1  Lv1スロ  1  Lv2スロ  1
風圧耐性          3  爆破やられ耐性  2  Lv1スロ  1  Lv2スロ  1
気絶耐性          2  ひるみ軽減      2  Lv1スロ  1  Lv2スロ  1
龍耐性            1  満足感          2  Lv1スロ  2  Lv2スロ  1
不屈              1  翔蟲使い        2  Lv1スロ  1  Lv2スロ  1
納刀術            2  精霊の加護      2  Lv1スロ  1  Lv2スロ  1
氷耐性            2  麻痺耐性        2  Lv1スロ  1  Lv2スロ  1
アイテム使用強化  2  回復速度        2  Lv1スロ  1  Lv2スロ  1
見切り            2  龍属性攻撃強化  1  Lv1スロ  1  Lv3スロ  1
雷耐性            1  乗り名人        1  Lv1スロ  1  Lv3スロ  1
耳栓              1  装填速度        1  Lv1スロ  1  Lv3スロ  1

アイテム使用強化  2  高速変形          1  Lv2スロ  2
ブレ抑制          2  アイテム使用強化  2  Lv3スロ  1
破壊王            2  逆襲              2  Lv1スロ  2
腹減り耐性        2  睡眠耐性          2  Lv3スロ  1
龍属性攻撃強化    2  砲弾装填          1  Lv1スロ  1
飛び込み          1  フルチャージ      1  Lv1スロ  1
毒属性強化        3  逆恨み            1  Lv1スロ  2
笛吹き名人        1  防御              2  Lv3スロ  1
ＫＯ術            2  死中に活          1  Lv3スロ  1
精霊の加護        2  鈍器使い          2  Lv1スロ  2

死中に活        2  高速変形        2  Lv1スロ  1
反動軽減        1  龍耐性          2  Lv2スロ  2
陽動            1  毒属性強化      1  Lv1スロ  3
回避距離ＵＰ    1  弱点特効        1  Lv1スロ  1
氷属性攻撃強化  1  弱点特効        1  Lv1スロ  2
麻痺耐性        1  装填速度        2  Lv3スロ  1
毒属性強化      2  ＫＯ術          2  Lv2スロ  1
回避性能        2  高速変形        2  Lv2スロ  2
ガード性能      1  龍属性攻撃強化  2  Lv1スロ  1

弱点特効 1 麻痺属性強化 1

弾導強化  1  Lv1スロ  2
達人芸    1  Lv1スロ  1
剛刃研磨  1  Lv1スロ  3

# レア6
翔蟲使い 2 破壊王 2 Lv1スロ 2
風圧耐性 2 ＫＯ術 1 Lv2スロ 1
回避距離ＵＰ 1 龍耐性 2 Lv1スロ 2

# レア4
回復速度 1 火耐性 3 Lv1スロ 1
EOS

lines.each_line {|line|
  next if line.strip == ''
  if line[0] == '#' then
    puts line
    next
  end
  xs = line.split(' ')
  name = xs[0][0..1] + xs[1] + '/'
  name += "#{xs[2][0..1]}#{xs[3]}/" if xs[2] && xs[2][0] != 'L'
  sl = []
  xs.each_slice(2) {|b, a|
    a.to_i.times { sl.push b[2] } if b[0] == 'L'
  }
  name += sl.sort.reverse.join
  print '(0..1) ', name, ':{護石} -> '
  puts xs.each_slice(2).map {|b, a| a + ' ' + b }.join(', ')
}    
