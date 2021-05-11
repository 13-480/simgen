# -*- coding: utf-8 -*-
#### 正規表現
avoidchars = '-+=<>()%#?:"\'\\[\\]{},\\s'
# グループ名
GROUPre = Regexp.new('^{[^%1$s\d][^%1$s]*}' % avoidchars)
GROUPSUMre = Regexp.new(GROUPre.to_s + '\.sum')
# 変数名 (システムではコロンを使用する)。グループ指定付き
VARre = Regexp.new('^([^%1$s\d][^%1$s]*)(?::(%2$s))?' % [avoidchars, GROUPre.source[1..-1]])
# 空白区切りの文字列、行末まですべて取る文字列
STRre = /^[^\s#<>\\[\\]]+/
STRre0 = /^[^\n#<>]+/

#### 読み易い表示
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
  attr_accessor :lines
  # 空行、コメント行
  EMPTYre = /^\s*(#.*)?$/

  # 入力の登録
  def initialize(lines)
    @linessave = lines.dup
    @lines = lines
  end

  # エラー報告
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
        raise ParseError # 強制終了
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
  attr_accessor :query          # [ボタンテキスト, 中止, 追加, 変数名]
  attr_accessor :relation       # [1次式, op, 1次式, ...]
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
    @unlock, @summary, @details = [], [], []
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
      # UI の最後の2つは、範囲有りなら (0開始で) 第2成分が '' か '*' になることで判断
      ['<UI>', @ui,
       [/br|space|width:\d+px|nowidth/],
       [/subsection/, STRre0],
       ['(', @rngp, '..', @rngp, ')', /\*?/, @varuip,
        ['?', '->', @intuip, @varuip, ['*', ',', @intuip, @varuip]]],
       [@varuip,
        '->', @intuip, @varuip, ['*', ',', @intuip, @varuip]],
      ],
      ['<META>', @meta,
       [/title/, STRre0],
       [/glpk/, STRre],
       [/localstrage/, STRre],
      ],
      ['<GROUP>', @group0,
       [GROUPre],
       [@varp, ['*', @varp]],
      ],
      ['<QUERY>', @query,
       [/query/, STRre, STRre, STRre, @varp],
      ],
      ['<RELATION>', @relation,
       [@formp, ['*', /<=|>=|=/, @formp]],
      ],
      ['<UNLOCK>', @unlock,
       [@varp, @intp, ',', @varp, @intp, @intp],
      ],
      ['<SUMMARY>', @summary,
       [/width:\d+px|nowidth/],
       [/[nv*]+/, @varp],
       [/[nv*]+/, GROUPre],
      ],
      ['<DETAILS>', @details,
       [/newcolumn/, STRre0],
       [/time/],
       [/more/, STRre, GROUPre],
       [/[nv*]+/, @varp],
       [/[nv*]+/, GROUPre],
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

  # グループ名
  def parse_group(line)
    line = line.lstrip
    return false if GROUPre !~ line
    [$&, $']
  end

  # 変数名集合
  def parse_varset(line)
    line = line.lstrip
    return false if line[0] != '['
    ary = []
    return false if line[1..-1] !~ /\]/
    vs, line = $`.split(' '), $'.lstrip
    vs.each {|x|
      vline = parse_var(x)
      if vline then # 変数名
        return false unless vline[1].empty?
        ary.push vline[0]
      elsif (GROUPre =~ x && $'.empty?) then # グループ名
        ary.push x
      else
        return false
      end
    }
    # 新規グループとして登録
    grp = "{#{@group.size}}"
    @group[grp] = ary
    [grp, line]
  end

  # 入力から変数名かグループ名か変数名集合を読む。
  # 変数名ならGLPK変数に登録して変数名 (String) を返し、
  # グループ名ならグループ名 (String) を返し、
  # 変数名集合なら、新規グループとして登録して、そのグループ名 (String) を返す。
  def parse_varui(line)
    # 変数名、グループ名、変数名集合
    parse_var(line) || parse_group(line) || parse_varset(line)
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
    elsif /^\[(.*?)\]/ =~ line then # 数値集合 (?は*の最短を指定)
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
    # @group0から@groupを生成 (グループ名と変数名の配列をHashに変換) し、
    # グループの入れ子を展開
    resolve_group
  end
  
  # パーズ後に@group0から@groupを生成 (グループ名と変数名の配列をHashに変換)
  # その後、グループの入れ子を処理 (変数名集合で発生)
  def resolve_group
    # GORUPセクションの処理
    grp = nil
    @group0.flatten.each {|x|
      if ! grp && GROUPre !~ x then
        @psr.err('group section not started with group name')
        raise ParseError # 強制終了
      end
      if GROUPre =~ x then # グループ名
        grp = x
      elsif (v_line = parse_var(x)) then # 変数名
        @group[grp] |= v_line[0..0]
      else
        raise ParseError # 強制終了
      end
    }
    # 入れ子の処理
    h = Hash.new {|h, k| h[k] = [] }
    while ! @group.empty?
      cnt = @group.size
      @group.each {|grp, ary|
        if ary.all? {|x| x[0] != '{' } then
          @group.delete(grp)
          h[grp] = ary.uniq
          @group.keys.each {|grp2|
            ary2 = @group[grp2].uniq
            i = ary2.index(grp)
            @group[grp2] = ary2[0...i] + ary + ary2[i+1..-1] if i
          }
          break
        end
      }
      raise 'recursive group:' if cnt == @group.size
    end
    @group = h
  end # of resolve_group

  # 入力全体をパーズ
  def parse_lines
    while ! @psr.empty?
      # セクションタグを照合
      secno = 0
      secno += 1 while secno < @sec.size && ! @psr.parse([@sec[secno][0]])
      if secno >= @sec.size then
        @psr.err('bad section tag')
        raise ParseError # 強制終了
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

#### html生成
# SimParserで収集したのは以下
# @meta     ['title', タイトル], ['localstrage', キー]
# @group    グループ名=>[変数名]
# @ui       [下限, 上限, *, 寄与元変数, 寄与先数値a, 寄与先変数a, ..]か幅指定等
# @query    [ボタンテキスト, 中止, 追加, 変数名]
# @relation [1次式, op, 1次式, ...]
# @unlock   [変数名1, 数値a, 変数名2, 数値b, 数値c]
# @summary  [フラグ, 変数名]か列見出し等
# @details  [フラグ, 変数名]か列見出し等
# @var      変数名=>GLPK変数名
#
# これらを元に以下をGenHTMLで設定する。
# @maximize	Array。@queryから確定
# @subj		Array。@relationと@unlockから確定。
#		@ui2からは何も登録されず、実行時に追加される。
# @generals	Array。@varと@unlockから確定
# 以上はhtmlファイルに記録される。
# @uiの情報は、すべてhtmlに書き込まれ、実行時にSubject toに追記される。
# 他に、@varや@groupの情報もhtmlに書き込まれる。
# Boundsはすべて実行時に生成。Binaryは使わない。

class GenHTML
  attr_accessor :psr, :maximize, :subj, :maximize, :generals
  def initialize(psr)
    @psr = psr # SimParser (not Parser)
    @maximize = ['Maximize']
    @subj = ['Subject to']
    @generals = ['Generals']
    @ui_cnt = 0 # ui部品に連番を振るため
  end # of initialize

  # htmlを生成して配列で返す
  def gen_html
    @ui_width = nil # UI部品の幅
    res = []
    # @maximize, @subj, @generalsを確定させる
    setup_glpk
    # ヘッダ
    res.push(gen_html_head)
    # UI
    res.push(gen_html_ui)
    # 検索ボタン
    res.push(gen_html_btn)
    # GLPKログ
    res.push(gen_html_glpklog)
    # 結果ペイン
    res.push('<!-- 検索結果 -->', '<div id=resultpane>', '</div>')
    # GenGLPKで生成するデータ
    res.push(gen_html_glpk_data)
    # Local strage key
    res.push(gen_html_localstragekey)
    # SUMMARYセクションのデータ
    res.push(gen_html_summary)
    # DETAILSセクションのデータ
    res.push(gen_html_details)
    # GLPK変数=>変数名の辞書
    res.push(gen_html_var)
    # グループ名=>[GLPK変数]の辞書
    res.push(gen_html_group)
    # フッタ
    res.push('</body>', '</html>')
    res
  end # of gen_html

  # glpkのデータを整える
  def setup_glpk
    # query -> @maximize
    v = @psr.var[@psr.query[0][4]]
    @maximize.push v
    
    # unlock -> @subj。補助変数は@psr.varに新規に登録
    @psr.unlock.each {|x| # x は [変数名1, 数値a, 変数名2, 数値b, 数値c]
      next if x.size != 5 # 上限解放指定以外は無視 (今はないけど)
      vv = x[0] + ':' + x[2]
      @psr.register_var(vv) # 補助変数
      w = @psr.var[vv]
      v1, a, v2, b, c = @psr.var[x[0]], x[1], @psr.var[x[2]], x[3], x[4]
      @subj.push [v2, '%+d'%(b-c), w, '<=', b].join(' ')
      @subj.push [v1, '%+d'%(-a), w, '>= 0'].join(' ')
    }

    # relation -> @subj
    @psr.relation.each {|f| # f は [1次式, op, 1次式, ...]
      f = f.dup
      # sumを展開
      0.step(f.size-1, 2) {|i|
        h = f[i]
        h.keys.each {|k|
          if GROUPSUMre =~ k then
            kk = k[0..-5]
            @psr.group[kk].each {|k1| h[k1] += h[k] }
            h.delete(k)
          end
        }
      }
      while f.size >= 3 # 等式・不等式以外は無視
        @subj.push(self.simplify(*f[0..2]))
        f = f[2..-1]
      end
    }

    # var -> @generals
    @generals.push(@psr.var.values.each_slice(17).map {|x| x.join(' ') })
  end

  # 1次式2つを、定数項は右辺へ他は左辺へ移項して、等式・不等式を作る
  def simplify(f1, op, f2)
    lhs, rhs = Hash.new(0), 0
    f1.each {|k, v| (k == '') ? (rhs -= v) : (lhs[k] += v) }
    f2.each {|k, v| (k == '') ? (rhs += v) : (lhs[k] -= v) }
    lhs.reject! {|k,v| v == 0 }
    if lhs.empty? then # エラーの疑い濃厚か?
      $stderr.puts 'Warning in simplify: 0 %s %s' % [op, rhs]
    end
    #
    [lhs.map {|k, v| '%+d %s' % [v, @psr.var[k]] }, op, rhs].flatten.join(' ')
  end # of simplify

  # ヘッダ
  def gen_html_head
    title = @psr.meta.assoc('title')
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
<style type="text/css">
summary.uismry {background: #ddddff;font-weight:bold}
summary.ressmry {background: #ddffdd;font-weight:normal}
select.hiliteMax {background: #ffdddd}
select.hiliteMin {background: #f8f8f8}
</style>

</head>
<body style="font-family:sans-serif;font-size:small">
<h2>%s</h2>
EOS
    str
  end

  # glpk.uiは、[下限, 上限, *, 寄与元変数, 寄与先数値a, 寄与先変数a, ..]か幅指定等
  # 最初の3つは省略可能。
  # 上限・下限や値は、定数はInteger、プルダウンはArray、チェックボックスは:checkbox、
  # テキストボックスはString、ないなら:none。
  # 変数名は、変数名・グループ名はString、プルダウンはArray。
  def gen_html_ui
    res = ['<!-- UI -->']
    inDetails = false
    @psr.ui.each {|x| # [下限, 上限, *, 寄与元変数, 寄与先数値a, 寄与先変数a, ..]
      if x.kind_of?(Array) && x.size >= 3 then
        res.push gen_html_ui_elt(x) # UI部品
      else # 幅指定等
        case x[0]
        when 'br' # 改行
          res.push('<br>')
        when 'space' # スペース (幅指定時のみ有効)
          if @ui_width then
            res.push('<span style="display:inline-block;%s">' % @ui_width,
                '</span>')
          end
        when 'nowidth' # UI部品の幅指定解除
          @ui_width = nil
        when /^width:\d+px/  # UI部品の幅
          @ui_width = x[0]
        when 'subsection' # details要素に入れる
          res.push('</details>') if inDetails # 前回のを閉じる
          res.push('<details open=true>')
          res.push('<summary class=uismry>%s</h3></summary>' % x[1])
          inDetails = true
        else # そのまま垂れ流し !! エスケープ必要 !! これ現状はありえないことになってる
          res.push(x[0])
        end
      end
    }
    res.push('</details>') if inDetails # 前回のを閉じる
    res
  end

  # gen_html_uiの下請けで、UI部品をArrayで返す
  # x は [下限, 上限, *, 寄与元変数, 寄与先数値a, 寄与先変数a, ..]
  def gen_html_ui_elt(x)
    line = []
    x = [:none, :none, '', *x] if x[2] != '' && x[2] != '*' # 範囲なしは補う
    # UI部品の有無を調べる
    ui_elt = false
    ui_elt |= (x[0] != :none && ! x[0].kind_of?(Integer))
    ui_elt |= (x[1] != :none && ! x[1].kind_of?(Integer))
    3.step(x.size-1, 2) {|i| ui_elt |= (x[i][0] == '{') }
    4.step(x.size-1, 2) {|i|
      ui_elt |= x[i] != :none && ! x[i].kind_of?(Integer) }
    # spanでくるむ
    if ! ui_elt then
      line.push '<span class=ui style="display:none">'
    elsif @ui_width then
      line.push '<span class=ui uicnt=%s style="display:inline-block;%s">' %
                [@ui_cnt, @ui_width]
    else
      line.push '<span class=ui uicnt=%s>' % @ui_cnt
    end
    @ui_cnt += 1
    # 下限、上限
    line.push gen_html_ui_num(x[0], :min)
    line.push gen_html_ui_num(x[1], :max)
    # フラグ
    line.push '<span v="%s"></span>' % x[2]
    # 寄与元変数
    line.push gen_html_ui_varui(x[3], ui_elt)
    # 寄与先
    x[4...x.size].each_slice(2) {|val, var|
      line.push gen_html_ui_num(val)
      line.push gen_html_ui_varui(var, !val.kind_of?(Integer))
    }
    line.push '</span>'      
    line
  end

  # 数値の定数やプルダウン等をArrayで返す
  # v属性はget_valueで拾える。f属性はfullrangeになる値
  def gen_html_ui_num(a, f=nil)
    case a
    when :none # 無指定でもプレースホルダ
      '<span v="" f=""></span>'
    when Integer # 数値
      "<span v=#{a} f=#{a}></span>"
    when String # テキストボックス
      '<input type=text value="%s" f="" style="width:25px">' % a
    when :checkbox # チェックボックス
      fstr = (f==:max) ? 1 : 0
      "<input type=checkbox f=#{fstr}>"
    when Array # プルダウン
      fstr = (f==:max) ? a.max : a.min
      [ "<select f=#{fstr}>",
        a.map {|x| '<option value="%s">%s</option>' % [x, x] },
        '</select>' ]
    else
      raise 'bad num'
    end
  end

  # 変数名かグループ名・変数名集合のUI
  def gen_html_ui_varui(v, visible = false)
    line = []
    if v[0] != '{' then # 変数名
      text = visible ? v : ''
      line.push '<span v=%s>%s</span>' % [@psr.var[v], text]
    else # グループ名・変数名集合 (後者もグループにされている)
      line.push '<select>'
      @psr.group[v].map {|x|
        line.push '<option value="%s">%s</option>' % [@psr.var[x], x] }
      line.push '</select>'
    end
    line
  end

  # 検索ボタン
  BTN1 = '<button id=querybtn onclick="doQueryBtn()" run="%s" stop="%s" add="%s">%s</button>'
  BTN2 = '<button onclick="clearResult()">検索結果の全消去</button>'
  def gen_html_btn
    q, run, stop, add, v = @psr.query.assoc('query')
    raise 'no query button'  if ! q
    [ '<hr>',
      '<!-- 検索ボタン -->',
      BTN1 % [run, stop, add, run],
      BTN2,
      '<hr>' ]
  end

  # GLPKログの表示域
  def gen_html_glpklog
    showhide = @psr.meta.assoc('glpk')
    showhide = (showhide && showhide[1]=='show') ? 'block' : 'none'
    ['<!-- GLPKログ -->',
      '<textarea id=glpklog cols=150 rows=5 style="display:%s">' % showhide,
      '</textarea>']
  end

  # GenGLPKで生成したデータ
  def gen_html_glpk_data
    res = []
    res.push('<script>')
    # maximize, subj, generalsはArrayなので単に保存
    res.push('var glpkmaximize = `', @maximize, '`;')
    res.push('var glpksubj = `', @subj, '`;')
    res.push('var glpkgenerals = `', @generals, '`;')
    res.push('</script>')
  end

  # Local strage keyのデータ
  def gen_html_localstragekey
    loc = @psr.meta.assoc('localstrage')
    key = loc ? loc[1] : 'simgen'
    res = []
    res.push('<script>')
    res.push("var glpklocalstoragekey = '#{key}';")
    res.push('</script>')
  end

  # SUMMARYセクションのデータ
  # @psr.summaryの要素は、[フラグ, 変数名] か nowidth等
  # 出力のsummaryは、Stringならnowidth等、配列なら[フラグ, GLPK変数名]
  def gen_html_summary
    res = ['<script>', 'var summary = [']
    @psr.summary.each {|x|
      if x.size <= 1 then # nowidth等
        res.push("'#{x[0]}',")
      elsif GROUPre =~ x[1] then # グループ
        @psr.group[x[1]].each {|v| res.push("['#{x[0]}', '#{@psr.var[v]}'],") }
      else # 変数
        res.push("['#{x[0]}', '#{@psr.var[x[1]]}']," )
      end
    }
    res.push('];', '</script>')
  end

  # DETAILSセクションのデータ
  # @psr.detailsの要素は、[フラグ, 変数名] か 列見出し等
  # 出力のdetailsは、Stringなら見出しやnowidth等、配列なら[フラグ, GLPK変数名]
  def gen_html_details
    res = ['<script>', 'var details = [']
    @psr.details.each {|x|
      if x.size <= 1 then # nowidth等
        res.push("'#{x[0].strip}',")
      elsif x[0] == 'newcolumn' then # newcolumn
        res.push("'newcolumn',", "'#{x[1].strip}',")
      elsif x[0] == 'more' then # more
        res.push("['more', '#{x[1]}', '#{x[2]}'],") 
      elsif GROUPre =~ x[1] then # [フラグ, グループ]
        @psr.group[x[1]].each {|v| res.push("['#{x[0]}', '#{@psr.var[v]}'],") }
      else # [フラグ, 変数]
        res.push("['#{x[0]}', '#{@psr.var[x[1]]}']," )
      end
    }
    res.push('];', '</script>')
  end

  # GLPK変数=>変数名の辞書
  def gen_html_var
    res = ['<script>', 'var vname = {']
    @psr.var.each_slice(4) {|x|
      res.push x.map {|k,v| "#{v}:'#{k}'," }.join(' ') }
    res[-1][-2..-1] == ''
    res.push('};', '</script>')
  end

  # グループ名=>[GLPK変数]の辞書
  def gen_html_group
    res = ['<script>', 'var group = {']
    @psr.group.each {|k,vs|
      res.push("'%s':[%s]," % [k, vs.map {|v| "'#{@psr.var[v]}'" }.join(',') ])}
    res[-1][-2..-1] == ''
    res.push('};', '</script>')      
  end
end # of class GenHTML

#### 直に呼ばれたらARGFからソースを読み、htmlを出力する
if $0 == __FILE__ then
  lines = ARGF.to_a.map {|line| line.encode('UTF-8', 'UTF-8') }
  psr = SimParser.new(lines)
  psr.parse
  # $stderr.puts 'UI', pp(psr.ui)
  # $stderr.puts '@group', pp(psr.group)
  # $stderr.puts 'RELATION', pp(psr.relation)
  # $stderr.puts 'GROUP', pp(psr.group)
  gh = GenHTML.new(psr)
  puts gh.gen_html
end
