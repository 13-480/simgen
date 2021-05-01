# -*- coding: utf-8 -*-
# class Parse で Array の扱いを変えた
# UIセクションとINDUCEセクションを発展・統合
# UIとINDUCEセクションを統合したUI2セクションのパーズまでは書いたので、
# GLPKとhtmlを吐く所をこれから書く

#### 正規表現
avoidchars = '-+=<>()#?:"\'\\[\\]{},\\s'
# グループ名
GROUPre = Regexp.new('^{[^%1$s\d][^%1$s]*}' % avoidchars)
GROUPSUMre = Regexp.new(GROUPre.to_s + '\.sum')
# 変数名 (システムではコロンを使用する)。グループ指定付き
VARre = Regexp.new('^([^%1$s\d][^%1$s]*)(?::(%2$s))?' % [avoidchars, GROUPre.source[1..-1]])
# 空白区切りの文字列、行末まですべて取る文字列
STRre = /^[^\s#<>\\[\\]]+/
STRre0 = /^[^\n#<>]+/

#### エラー表示
def err(*xs)
  xs.each {|x| $stderr.puts x.inspect }
end
def pp(x, delim = "\n")
  case x
  when Array
    if delim == "\n" then
      x.map {|y| pp(y, ',') }.join(delim)
    else
      '[' + x.map {|y| pp(y, ',') }.join(',') + ']'
    end
  when Hash
    x.map {|k,v| pp(k, ',') + ' => ' + pp(v, ',') }.join(delim)
  else
    x.to_s
  end
end  

#### パーズエラークラス
class ParseError < StandardError; end

#### 簡易パーザクラス (簡易だが汎用ではある)
class Parser
  # 空行、コメント行
  EMPTYre = /^\s*(#.*)?$/
  # 入力の登録
  def initialize(lines)
    @linessave = lines.dup
    @lines = lines
  end
  # エラー報告 # !! ここ直したい
  def err(str)
    lineno = @linessave.size - @lines.size
    pos = @linessave[lineno].size - @lines[0].size
    $stderr.puts 'ERROR at line %d: %s' % [lineno +1, str]
    $stderr.puts '| ' + @linessave[lineno][0...pos]
    $stderr.puts '| ' + @lines[0]
  end
  # 空行、コメントをスキップする
  def skip
    while ! @lines.empty? && EMPTYre =~ @lines[0]
      @lines.shift
    end
    true
  end
  # 行末まで何もないことを確認して捨てる
  def discard
    return false if EMPTYre !~ @lines[0].lstrip
    @lines.shift
    true
  end
  # 終了判定
  def empty?
    self.skip
    @lines.empty?
  end
  # 次に指定のものがあるかチェック。StringとRegexpのみ受け付ける
  def check(x)
    @lines[0] = @lines[0].lstrip
    case x
    when String
      @lines[0].index(x) == 0
    when Regexp
      (x =~ @lines[0]) == 0
    else
      raise x.inspect
    end
  end
  # 1行パーズ
  # syn = [要素, 要素, ...]
  # 要素は、
  #   String その文字列に一致したら、結果には含めず読み飛ばす。
  #   Regexp その正規表現にマッチしたら、結果に含める。
  #   Proc    入力行を引数にprocを呼び出す。返り値は [値, 行の残り]。
  #           返り値を結果に含める。proc中の失敗はfalseを返す。
  #   Array   先頭要素が '*' か '?' によって0回以上、0か1回の繰り返し。
  # 各要素間は空白を読み飛ばす。行末は空白とコメントのみなのを確認して捨てる
  # 通常の返り値は結果のArray、エラー時はerrで報告して落ちる。
  def parse(syn)
    linesave = @lines[0]
    res = self.parse1(syn)
    if ! res then
      @lines[0] = linesave
      return false
    end
    if ! self.discard then
      # @lines[0] = linesave
      self.err('Garbage at eol')
        raise ParseError # これはこれでいいか
    end
    res
  end

  # parseと同じだが、行末チェックをしない
  def parse1(syn)
    syn = syn.dup
    res = []
    while ! syn.empty?
      @lines[0] = @lines[0].lstrip
      case syn[0]
      when String
        return false if @lines[0].index(syn[0]) != 0
        @lines[0] = @lines[0][syn[0].size..-1]
        syn.shift
      when Regexp
        m = (syn[0] =~ @lines[0])
        return false if m != 0
        res.push $&
        syn.shift
        @lines[0] = $'
      when Proc, Method
        x, rest = syn[0].call(@lines[0])
        return false if ! x
        res.push(x)
        @lines[0] = rest
        syn.shift
      when Array
        kind = syn[0][0]
        raise "bad syntax (#{syn[0]})" unless %w(* ?).include?(kind)
        linesave = @lines[0]
        res1 = self.parse1(syn[0][1..-1])
        if res1 then
          res += res1
          syn.shift if kind == '?'
        else
          @lines[0] = linesave
          syn.shift
        end
      else
        self.err('Bad syntax in parse: %s' % syn[0].inspect)
      end
    end # of while ! syn.empty?
    res
  end # of parse
end # of class Parser

#### パーザクラス (シミュ特化)
class SimParser
  attr_accessor :meta           # ['title', タイトル]
  attr_accessor :group          # グループ名=>[変数名]
  attr_accessor :ui             # [下限, 上限, '*', 変数名] か ['br'] 等
  attr_accessor :ui2            #
  attr_accessor :query          # [ボタンテキスト, 中止, 追加, 変数名]
  attr_accessor :relation       # [1次式, op, 1次式, ...]
  attr_accessor :induce         # [変数名, 変数名1, 数値1,...]
  attr_accessor :unlock         # [変数名1, 数値a, 変数名2, 数値b, 数値c]
  attr_accessor :summary        # [フラグ, 変数名]か列見出し等
  attr_accessor :details        # [フラグ, 変数名]か列見出し等
  attr_accessor :var            # 変数名=>GLPK変数名
  #
  def initialize(lines)
    # Parserのインスタンス
    @psr = Parser.new(lines)
    # 結果を保存する配列 (@group0は後に@groupに変換)
    @meta, @group0, @ui, @query, @relation = [], [], [], [], []
    @induce, @unlock, @summary, @details = [], [], [], []
    @ui2 = []
    # 変数名=>GLPK変数のHash
    @var = {}
    # グループ名=>[変数名]のHash
    @group = Hash.new {|h, k| h[k] = [] }
    # SimParse#parse で使うためのprocオブジェクト
    @varp = method(:parse_var)
    @formp = method(:parse_form)
    @intp = method(:parse_int)
    @rngp = method(:parse_ui_rng)
    @varuip = method(:parse_varui)
    @intuip = method(:parse_intui)
    # 文法 (SimParse#parse 参照)
    # [セクションタグ, 蓄積する配列, パターン, パターン, ...] (パターンのどれかにマッチ)
    @sec = [
      # UI2 の最後の2つは、範囲有りなら (0開始で) 第2成分が '' か '*' になることで判断
      ['[UI2]', @ui2,
        [/br|space|width:\d+px|nowidth/],
        [/subsection/, STRre0],
        ['(', @rngp, '..', @rngp, ')', /\*?/, @varuip,
          ['?', '->', @intuip, @varuip, ['*', ',', @intuip, @varuip]]],
        [@varuip,
         '->', @intuip, @varuip, ['*', ',', @intuip, @varuip]],
      ],
      ['[META]', @meta,
        [/title/, STRre0],
        [/glpk/, STRre],
      ],
      ['[GROUP]', @group0,
        [GROUPre],
        [@varp, ['*', @varp]],
      ],
      ['[QUERY]', @query,
        [STRre, STRre, STRre, @varp],
      ],
      ['[RELATION]', @relation,
        [@formp, ['*', /<=|>=|=/, @formp]],
      ],
      ['[UNLOCK]', @unlock,
        [@varp, @intp, ',', @varp, @intp, @intp],
      ],
      ['[SUMMARY]', @summary,
        [/width:\d+px|nowidth/],
        [/[nv*]+/, @varp],
        [/[nv*]+/, GROUPre],
      ],
      ['[DETAILS]', @details,
        [/newcolumn/, STRre0],
        [/[nv*]+/, @varp],
        [/[nv*]+/, GROUPre],
        # !! 追加スキルボタンを作る予定
      ],
    ]
  end

  # 変数名を登録する。v0から順に番号を増やす
  def register_var(str)
    @var[str] = ('v%d' % @var.size) if ! @var.has_key?(str)
  end

  # 入力から変数名を読む。GLPK変数に登録して変数名を返す。変数名にはグループも指定可能
  def parse_var(line)
    line = line.lstrip
    return false if VARre !~ line
    v, grp, line = $1, $2, $'.lstrip
    register_var(v)
    @group[grp] |= [v] if grp
    [v, line]
  end

  # 入力から変数名かグループ名か変数名集合を読む。
  # 変数名ならGLPK変数に登録して変数名を返し、
  # 変数名、グループ名、または、変数名集合なら変数名とグループ名からなるArrayを返す。
  def parse_varui(line)
    # 変数名
    vline = parse_var(line)
    return vline if vline
    # グループ名
    return [[$&], $'] if GROUPre =~ line
    # 変数名集合
    if line[0] == '[' then
      ary = []
      return false if line[1..-1] !~ /\]/
      vs, line = $`.split(' '), $'.lstrip
      vs.each {|x|
        # 変数名
        vline = parse_var(x)
        if vline then
          return false unless vline[1].empty?
          ary.push vline[0]
        elsif (GROUPre =~ x && $'.empty?) then # グループ名
          ary.push x
        else
          return false
        end
      }
      return [ary, line]
    end
    # マッチせず
    false
  end

  # 入力から整数を読む
  def parse_int(line)
    line = line.lstrip
    return false if /^-?[0-9]+/ !~ line
    [$&.to_i, $']
  end

  # 入力から整数、または、[整数 整数 ..] を読む。
  # 数値単独ならInteger、集合ならArray
  def parse_intui(line)
    if /^-?\d+/ =~ line then # 数値
      [$&.to_i, $']
    elsif /^\[(.*)\]/ =~ line then # 数値集合
      [$1.split(' ').map {|x| x.to_i }, $']
    else
      false
    end
  end

  # 入力から1次式を読む。結果はHashで返す
  def parse_form(line)
    line = line.lstrip
    res = Hash.new(0)
    loop {
      sgn, coef, v = 1, 1, ''
      # 符号
      case line[0]
      when '+'; sgn, line =  1, line[1..-1].lstrip
      when '-'; sgn, line = -1, line[1..-1].lstrip
      end
      # 係数
      len = line.size # エラー判定用
      if /^\d+/ =~ line then
        coef, line = $&.to_i, $'.lstrip
      end
      # 変数名
      v_line = parse_var(line)
      if v_line then
        v, line = v_line
        res[v] += sgn * coef
      elsif GROUPSUMre =~ line then # グループの和 (未確定なので展開不可)
        v, line = $&, $'.lstrip
        res[v] += sgn*coef
      else # 定数項
        res[v] += sgn*coef
      end
      # エラー判定
      return false if line.size == len
      # 終了判定
      break if /^[+-]/ !~ line
    }
    [res, line]
  end

  # 入力からUIセクションの範囲指定を読む
  # 上限・下限を、ないならnil、数値単独ならInteger、集合ならArray、テキス
  # トボックスならその初期値をString で返す
  def parse_ui_rng(line)
    if /^C/ =~ line then # チェックボックス
      [:checkbox, $']
    elsif /^(-?\d+)\?/ =~ line then # テキストボックス
      [$1, $']
    elsif /^-?\d+/ =~ line then # 数値
      [$&.to_i, $']
    elsif /^\[(.*)\]/ =~ line then # 数値集合
      [$1.split(' ').map {|x| x.to_i }, $']
    else
      [:none, line]
    end
  end

  # 入力全体をパーズして、@group, @relationを整える
  def parse
    parse_lines
    # @group0から@groupを生成 (グループ名と変数名の配列をHashに変換)
    resolve_group
    # @relationを整える ([1次式, op, 1次式, ...]においてグループの和を展開)
    resolve_group_in_relation
    # @ui2を整える (変数名集合でのグループ名の展開)
    resolve_group_in_ui
  end

  # パーズ後に@group0から@groupを生成 (グループ名と変数名の配列をHashに変換)
  def resolve_group
    grp = nil
    @group0.flatten.each {|x|
      if ! grp && GROUPre !~ x then
        @psr.err('group section not started with group name')
        raise ParseError # これはこれでいいか
      end
      if GROUPre =~ x then # グループ名
        grp = x
      elsif (v_line = parse_var(x)) then # 変数名
        @group[grp] |= v_line[0..0]
      else
        raise ParseError # これはこれでいいか
      end
    }
  end # of resolve_group

  # パーズ後に@relationを整える ([1次式, op, 1次式, ...]においてグループの和を展開)
  def resolve_group_in_relation
    @relation.each {|line|
      0.step(line.size-1, 2) {|i|
        h = line[i]
        h.keys.each {|k|
          if k =~ GROUPSUMre then
            kk = k[0..-5]
            @group[kk].each {|k1| h[k1] += h[k] }
            h.delete(k)
          end
        }
      }
    }
  end # of resolve_group_in_relation

  # @ui2を整える (変数名集合でのグループ名の展開)
  # @ui2の要素は、UI指定なら要素数3以上で、
  # (0開始で) 第2成分が '' か '*' なら範囲有り、違えば範囲なし (以下参照)
  # |  ['(', @rngp, '..', @rngp, ')', /\*?/, @varuip,
  # |   ['?', '->', @intuip, @varuip, ['*', ',', @intuip, @varuip]]],
  # |  [@varuip,
  # |   '->', @intuip, @varuip, ['*', ',', @intuip, @varuip]],
  # つまり、範囲有りなら0開始で、第3, 5,...成分、範囲なしなら、第0, 2,...成分が@varuip
  # @varuipは、
  # 変数名、グループ名、または、変数名集合なら変数名とグループ名からなるArray

  def resolve_group_in_ui
    @ui2.each {|line|
      next if line.size < 3
      i = (line[2] == '' || line[2] == '*') ? 3 : 0 # @varuipの最初の位置
      while i < line.size
        if line[i].kind_of?(String) && GROUPre =~ line[i] then # グループ名
          line[i] = @group[line[i]]
        elsif line[i].kind_of?(Array) then # 変数名集合
          line[i].size.times {|j|
            if GROUPre =~ line[i][j] then # 変数名集合の中のグループ名
              line[i][j] = @group[line[i][j]] # とりあえずArrayを埋める
            end
          }
          line[i] = line[i].flatten
        end
        i += 2
      end
    }
  end # of resolve_group_in_ui

  # 入力全体をパーズ
  def parse_lines
    while ! @psr.empty?
      # セクションタグを照合
      secno = 0
      secno += 1 while secno < @sec.size && ! @psr.parse([@sec[secno][0]])
      if secno >= @sec.size then
        @psr.err('bad section tag')
        raise ParseError # これはこれでいいか
      end
      # そのセクションでの構文解析
      ary, syns = @sec[secno][1], @sec[secno][2..-1]
      i = 0
      while ! @psr.empty? && i < syns.size
        res = @psr.parse(syns[i])
        if res then
          ary.push res
          i = 0
        else
          i += 1
        end
      end # of while ! @psr.empty? && i < syns.size
    end # of while ! @psr.empty?
  end
end # of class SimParser

#### GLPKソース生成
# SimParserので収集したのは以下
# @meta     ['title', タイトル]
# @group    グループ名=>[変数名]
# @ui2      [最小値, 最大値, *, 寄与元変数, 寄与先数値a, 寄与先変数a, ..]か幅指定等
# @query    [ボタンテキスト, 中止, 追加, 変数名]
# @relation [1次式, op, 1次式, ...]
# @unlock   [変数名1, 数値a, 変数名2, 数値b, 数値c]
# @summary  [フラグ, 変数名]か列見出し等
# @details  [フラグ, 変数名]か列見出し等
# @var      変数名=>GLPK変数名
#
# これらを元に以下をGenGLPKで設定する。
# @maximize	Array。@queryから確定
# @subj		Array。@relationと@unlockから確定。@ui2からは何も登録されない。
# @bounds	GLPK変数名=>[最小, 最大]。@varと@unlockからすべてのkeyは作っておいて、
#		@ui2で確定するものは更新する。確定しないものは実行時に更新。
# @generals	Array。@varと@unlockから確定
# @induce	寄与先GLPK変数名=>1次式のGLPK文字列。@ui2で確定するもののみ文字列化。
#		確定しないものは実行時に追加される。キーが実行時に追加される可能性有。
#		実行時に更新された後、「Subject to」へ送られる。

class GenGLPK
  attr_accessor :maximize, :subj, :bounds, :generals, :induce
  def initialize(psr)
    @psr = psr # SimParser (not Parser)
    @maximize = ['Maximize']
    @subj = []
    @bounds = Hash.new {|h, k| h[k] = [-Float::INFINITY, Float::INFINITY] }
    @generals = ['Generals']
    @induce = Hash.new {|h, k| h[k] = '' }
    # !! ソース末尾にENDも必要?
  end
  # GLPKソースやその元を生成し、@maximize, @subj, @bounds, @generals, @induceに設定
  # 「Subject To」と「Bounds」は実行時まで確定しない。
  def gen_glpk
    # query -> maximize
    v = @psr.var[@psr.query[0][3]]
    @maximize.push v
    #
    self.do_ui		# ui2 -> bounds, induce # !! 中身まだ
    self.do_relation	# relation -> subj
    self.do_unlock    	# unlock -> var, subj (varの処理より先にやること)
    self.do_var    	# var -> generals, bounds (unlockの処理より後にやること)
  end # of gen_glpk

  # UIセクションの範囲指定の確定分だけ@boundsに登録。残りは実行時。
  # 寄与指定のうち確定分は@indeceに登録。残りは実行時。
  # UIの要素は [下限, 上限, '*', 変数名, 値1, 変数名1,...]  か幅指定等
  # (始めの3つと値1以降は、一方だけなら省略可能)
  # 上限・下限や値は、定数はInteger、プルダウンはArray、チェックボックスはSymbol、
  # テキストボックスはString、ないならnil。
  # 変数名は、変数名・グループ名はString、プルダウンはArray。
  def do_ui
    # 範囲を調べて@boundsへ登録
    @psr.ui2.each {|x|
      next if x.size < 3 # UI部品以外は無視
      next if x[2] != '' && x[2] != '*' # 範囲省略も無視
      next if !x[3].kind_of?(String) || VARre !~ x[3] # 変数が確定でなければ無視
      @bounds[x[3]][0] = [@bounds[x[3]][0], x[0]].max if x[0].kind_of?(Integer)
      @bounds[x[3]][1] = [@bounds[x[3]][1], x[1]].min if x[1].kind_of?(Integer)
    }
    # 寄与を調べて@induceへ登録
    @psr.ui2.each {|x|
      next if x.size < 3 # UI部品以外は無視
      x = x[3..-1] if x[2] == '' || x[2] == '*' # 範囲部分は捨てる
      next if x.size  <= 1 # 寄与のないものは無視
      next unless x[0].kind_of?(String) && VARre =~ x[0] # 寄与元未確定は無視
      x[1..-1].each_slice(2) {|c, v|
        next unless v.kind_of?(String) && VARre =~ v # 寄与先未確定は無視
        @induce[@psr.var[v]] += '%+d %s' % [c, @psr.var[x[0]]]
      }
    }
  end # of do_ui

  # RELATIONセクションを@subjに登録
  # RELATIONの要素は [1次式, op, 1次式, ...]
  def do_relation
    @psr.relation.each {|f|
      f = f.dup
      while f.size >= 3 # 等式・不等式以外は無視
        @subj.push(self.simplify(*f[0..2]))
        f = f[2..-1]
      end
    }
  end # of do_relation

  # 1次式2つを、定数項は右辺へ他は左辺へ移項して、等式・不等式を作る
  def simplify(f1, op, f2)
    lhs, rhs = Hash.new(0), 0
    f1.each {|k, v| (k == '') ? (rhs -= v) : (lhs[k] += v) }
    f2.each {|k, v| (k == '') ? (rhs += v) : (lhs[k] -= v) }
    lhs.reject! {|k,v| v == 0 }
    raise '0 %s %s' % [op, rhs] if lhs.empty? # エラーの可能性大だが
    #
    [lhs.map {|k, v| '%+d %s' % [v, @psr.var[k]] }, op, rhs].flatten.join(' ')
  end # of simplify

  # UNLOCKセクションを@subjに登録、補助変数は@psr.varに新規に登録
  # 変数名1、2は@boundsに登録しなくて良いだろうし、補助変数もよくわからないからしない
  # UNLOCKの要素は [変数名1, 数値a, 変数名2, 数値b, 数値c]
  def do_unlock
    @psr.unlock.each {|x|
      next if x.size != 5 # 上限解放指定以外は無視 (今はないけど)
      vv = x[0] + ':' + x[2]
      @psr.register_var(vv) # 補助変数
      w = @psr.var[vv]
      v1, a, v2, b, c = @psr.var[x[0]], x[1], @psr.var[x[2]], x[3], x[4]
      @subj.push [v2, '+%d'%(b-c), w, '<=', b].join(' ')
      @subj.push [v1, '%+d'%(-a), w, '>= 0'].join(' ')
    }
  end # of do_unlock

  # @psr.varから @generalsと@boundsを設定
  def do_var
    # 変数の登録
    @generals.push(@psr.var.values.each_slice(17).map {|x| x.join(' ') })
    # 変数の範囲をとりあえず実数全体にしておく
    @psr.var.each_value {|x| 
      @bounds[x] = [-Float::INFINITY, Float::INFINITY] if ! @bounds.has_key?(x)
    }
  end # of do_var
end # of class GenGLPK

#### html生成
module GenHTML
  @@ui_width = nil # UI部品の幅
  module_function

  # htmlを生成して配列で返す
  def gen_html(psr) # このpsrはSimParserのインスタンス (not Parser)
    @@ui_width = nil # UI部品の幅
    res = []
    # ヘッダ
    res.push(gen_html_head(psr))
    # UI
    res.push(gen_html_ui(psr))
    # 検索ボタン
    res.push(gen_html_btn(psr))
    # GLPKログ
    res.push(gen_html_glpklog(psr))
    # 結果ペイン
    res.push('<!-- 検索結果 -->', '<div id=resultpane>', '</div>')
    # GLPKソースの確定している部分
    res.push(gen_html_glpk(psr))
    # SUMMARYセクションのデータ
    res.push(gen_html_summary(psr))
    # DETAILSセクションのデータ
    res.push(gen_html_details(psr))
    # GLPK変数の範囲最大の条件
    res.push(gen_html_fullrange(psr))
    # GLPK変数=>変数名の辞書
    res.push(gen_html_var(psr))
    # フッタ
    res.push('</body>', '</html>')
    res
  end

  # ヘッダ
  def gen_html_head(psr)
    title = psr.meta.assoc('title')
    title = title ? title[1] : 'タイトル'
    str = <<EOS % [title, title]
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>%s</title>

<!-- スクリプト読み込み -->
<script type="text/javascript" src="./simgenlib.js"></script>
<!-- スタイルシート読み込み -->

</head>
<body style="font-family:sans-serif;font-size:small">
<h2>%s</h2>
EOS
    str
  end

  # UI
  def gen_html_ui(psr)
    res = []
    inDetails = false
    psr.ui.each {|x| # [下限, 上限, '*', 変数名] か ['br'] 等
      if x.kind_of?(Array) && x.size < 4 then
        case x[0]
        when 'br' # 改行
          res.push('<br>')
        when 'space' # スペース (幅指定時のみ有効)
          if @@ui_width then
            res.push('<span style="display:inline-block;%s">' % @@ui_width,
                '</span>')
          end
        when 'nowidth' # UI部品の幅指定解除
          @@ui_width = nil
        when /^width:\d+px/  # UI部品の幅
          @@ui_width = x[0]
        when 'subsection' # details要素に入れる
          res.push('</details>') if inDetails # 前回のを閉じる
          res.push('<details open=true>', '<summary>%s</h3></summary>' % x[1])
          inDetails = true
        else # そのまま垂れ流し !! エスケープ必要
          res.push(x[0])
        end
      else # プルダウン他
        a, b, s, v = x
        aa = (a!=:none) && rng_html(psr, a, v+':min')
        bb = (b!=:none)  && rng_html(psr, b, v+':max')
        if (aa || bb) then
          st = ' style="display:inline-block;%s"' % @@ui_width
          res.push('<span %s>' % st) if @@ui_width
          res.push aa if aa
          res.push bb if bb
          res.push v
          res.push('</span>')  if @@ui_width
        end
      end
    }
    res.push('</details>') if inDetails
    res
  end

  # UIの下請け。プルダウン等を生成
  RNG_TEXTBOX = '<input type=text class=ui v="%s" value=%s style="width:25px">'
  RNG_CHECKBOX = '<input type=checkbox class=ui v="%s">'
  RNG_PULLDOWN1 = '<select class=ui v="%s">'
  RNG_PULLDOWN2 = '<option value="%s">%s</option>'
  RNG_PULLDOWN3 = '</select>'

  def rng_html(psr, a, v)
    case a
    when Integer # 数値ならUIなし
      nil
    when String # テキストボックス
      psr.register_var(v)
      RNG_TEXTBOX % [psr.var[v], a]
    when :checkbox # チェックボックス
      psr.register_var(v)
      RNG_CHECKBOX % psr.var[v]
    when Array # プルダウン
      psr.register_var(v)
      [ RNG_PULLDOWN1 % psr.var[v],
        a.map {|x| RNG_PULLDOWN2 % [x, x] },
        RNG_PULLDOWN3 ]
    else
      raise 'bad range'
    end
  end

  # 検索ボタン
  BTN1 = '<button id=querybtn onclick="doQueryBtn()" data-run="%s" data-stop="%s" data-add="%s">%s</button>'
  BTN2 = '<button onclick="clearResult()">検索結果の全消去</button>'
  def gen_html_btn(psr)
    run, stop, add, v = psr.query[0] # 1個と信じる
    [ '<hr>',
      BTN1 % [run, stop, add, run],
      BTN2,
      '<hr>' ]
  end

  # GLPKログの表示域
  def gen_html_glpklog(psr)
    showhide = psr.meta.assoc('glpk')
    showhide = (showhide && showhide[1]=='show') ? 'block' : 'none'
    ['<!-- GLPKログ -->',
      '<textarea id=glpklog cols=150 rows=5 style="display:%s">' % showhide,
      '</textarea>']
  end

  # GLPKソースの確定している部分
  def gen_html_glpk(psr)
    glpk = GenGLPK.new(psr)
    glpk.gen_glpk
    #
    res = []
    res.push('<script>')
    res.push('var glpkmaximize = `', glpk.maximize, '`;')
    res.push('var glpksubj = `', glpk.subj, '`;')
    res.push('var glpkbounds = `', glpk.bounds, '`;')
    res.push('var glpkgenerals = `', glpk.generals, '`;')
    res.push('</script>')
  end

  # SUMMRAYセクションのデータ
  # psr.summaryの要素は、[フラグ, 変数名] か nowidth等
  # 出力のsummaryは、Stringならnowidth等、配列なら[フラグ, GLPK変数名]
  def gen_html_summary(psr)
    res = ['<script>', 'var summary = [']
    psr.summary.each {|x|
      if x.size <= 1 then # nowidth等
        res.push("'#{x[0]}',")
      elsif GROUPre =~ x[1] then # グループ
        psr.group[x[1]].each {|v| res.push("['#{x[0]}', '#{psr.var[v]}']," ) }
      else # 変数
        res.push("['#{x[0]}', '#{psr.var[x[1]]}']," )
      end
    }
    res.push('];', '</script>')
  end

  # DETAILSセクションのデータ
  # psr.detailsの要素は、[フラグ, 変数名] か 列見出し等
  # 出力のdetailsは、Stringなら見出しやnowidth等、配列なら[フラグ, GLPK変数名]
  def gen_html_details(psr)
    res = ['<script>', 'var details = [']
    psr.details.each {|x|
      if x.size <= 1 then # nowidth等
        res.push("'#{x[0].trip}',")
      elsif x[0] == 'newcolumn' then # newcolumn
        res.push("'newcolumn',", "'#{x[1].strip}',")
        elsif GROUPre =~ x[1] then # グループ
        psr.group[x[1]].each {|v| res.push("['#{x[0]}', '#{psr.var[v]}']," ) }
      else # 変数
        res.push("['#{x[0]}', '#{psr.var[x[1]]}']," )
      end
    }
    res.push('];', '</script>')
  end

  # *指定有の変数がUIセクションで範囲指定される時、範囲最大になる条件を
  # 収集しておく。GLPK変数=>[GLPK変数a, 値a, ...] (変数a=値aが条件))
  def gen_html_fullrange(psr)
    res = ['<script>', 'var fullrange = {']
    # psr.ui は[下限, 上限, '*', 変数名] か ['br'] 等上限・下限は、
    # Integer (定数)、Array (プルダウン)、String (テキストボックス)、
    # nil (なし)
    psr.ui.each {|x|
      next unless x.kind_of?(Array) && x[2] == '*'
      res1 = [] # 上限・下限はプルダウンだけ対象
      res1.push(psr.var[x[3]+':min'], x[0].min) if x[0].kind_of?(Array)
      res1.push(psr.var[x[3]+':max'], x[1].max) if x[1].kind_of?(Array)
      res.push(psr.var[x[3]] + ':' + res1.inspect + ',') if ! res1.empty?
    }
    res.push('};', '</script>')
  end

  # GLPK変数=>変数名の辞書
  def gen_html_var(psr)
    res = ['<script>', 'var vname = {']
    psr.var.each_slice(5) {|x|
      res.push x.map {|k,v| "#{v}:'#{k}'," }.join(' ') }
    res[-1][-2..-1] == ''
    res.push('};', '</script>')
  end
end # of module GenHTML

# 直に呼ばれたらARGFからソースを読み、htmlを出力する
if $0 == __FILE__ then
  lines = ARGF.to_a.map {|line| line.encode('UTF-8', 'UTF-8') }
  psr = SimParser.new(lines)
  psr.parse
#   p psr.meta
#   $stderr.puts psr.ui.inspect
   $stderr.puts 'UI2', pp(psr.ui2)
#   $stderr.puts psr.query.inspect
#   $stderr.puts 'RELATION', pp(psr.relation)
#    $stderr.puts psr.induce.inspect
#   p psr.unlock
#   $stderr.puts psr.summary.inspect
#   $stderr.puts psr.details.inspect
# $stderr.puts 'GROUP', pp(psr.group)
   # $stderr.puts psr.var

   glpk = GenGLPK.new(psr)
   glpk.gen_glpk
   $stderr.puts 'maximize', pp(glpk.maximize)
   $stderr.puts 'subj', pp(glpk.subj)
   $stderr.puts 'bounds', pp(glpk.bounds)
   $stderr.puts 'generals', pp(glpk.generals)
   $stderr.puts 'induce', pp(glpk.induce)

#  puts GenHTML.gen_html(psr)
end
