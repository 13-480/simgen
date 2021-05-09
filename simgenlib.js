// -*- mode:js; mode:outline-minor -*-
// 検索ボタン (not 追加検索) で起動されるworkerが代入される
var job;
//// simgen.rbで生成されhtmlで定義される定数
var glpkmaximize, glpksubj, glpkgenerals; // GLPKソースのうち確定部分
var vname; 	// GLPK変数=>変数名の辞書
var group; 	// グループ名=>[GLPK変数]の辞書
var summary; 	// SUMMARYセクションそのままの配列
var details; 	// SUMMARYセクションそのままの配列

var localstoragekey = 'simgen'; // !! 未対応

//// 検索ボタン押下時の処理
// 検索ボタンのイベントハンドラ
function doQueryBtn() {
    saveUIparam();
    var btn = document.getElementById('querybtn');
    if        (btn.textContent == btn.getAttribute('run')) {
	updateQueryBtn('stop');
	doQueryBtnRun();
    } else if (btn.textContent == btn.getAttribute('stop')) { 
	updateQueryBtn('run/add');
	doQueryBtnStop();
    } else if (btn.textContent == btn.getAttribute('add')) { 
	updateQueryBtn('stop');
	doQueryBtnAdd(); 
    }
}

// 検索ボタンの表示を変更 (val = 'stop' なら強制で「中止」に変更)
function updateQueryBtn(val) {
    var btn = document.getElementById('querybtn');
    if (job || val == 'stop') {
	btn.textContent = btn.getAttribute('stop');
	return;
    }	
    var d = document.querySelector('#resultpane details');
    if (d) {
	btn.textContent = btn.getAttribute('add');
    }	else {
	btn.textContent = btn.getAttribute('run');
    }
}

// 検索ボタンで「検索」
// maximize, generalsは確定済。subjは途中までわかっているがUIから来る分が未確定。
// boundsは何も確定していない。
function doQueryBtnRun() {
    // UIから変数の値を取得して (Subject to への追加分と、Bounds全体) GLPKソースを構築
    var glpktxt = glpkmaximize + glpksubj + get_glpk_ui() +
	get_glpk_bounds() + glpkgenerals;
    // GLPKを表示する設定なら変数の対応やソースを表示
    if (glpkshow()) {
	console.log(glpktxt);
	str = [];
	for (var v of Object.keys(vname)) {
	    str.push(String(v) + ' ' + vname[v]);
	}
	console.log(str.join(' / '));
    }
    // 検索実行
    doGLPK(glpktxt);
}

// 検索ボタンで「検索中止」
function doQueryBtnStop() {
    job.terminate();
    job = null;
    updateQueryBtn('run/add');
}

// 検索ボタンで「追加検索」
function doQueryBtnAdd() {
    var glpktxt = glpkmaximize + glpksubj + get_glpk_ui() + get_glpk_add() +
	get_glpk_bounds() + glpkgenerals;
    doGLPK(glpktxt);
}

// GLPKログを表示する設定かどうか
function glpkshow() {
    var logNode = document.getElementById("glpklog");
    return logNode.style.display != 'none';
}

// プルダウン、テキストボックス、チェックボックス等から値を取得
// これ以外はv属性を返す
function get_value(elt) {
    if (elt.tagName == 'SELECT') {
	return elt.options[elt.selectedIndex].value;
    } else if (elt.tagName == 'INPUT' && elt.type == 'text') {
	return elt.value;
    } else if (elt.tagName == 'INPUT' && elt.type == 'checkbox') {
	return elt.checked ? 1 : 0;
    }
    return elt.getAttribute('v');
}

// プルダウン、テキストボックス、チェックボックス等へ値を設定
// これ以外はv属性を設定
function set_value(elt, val) {
    if (elt.tagName == 'SELECT') {
	for (var i = 0; i < elt.length; i++) {
	    if (elt.options[i].value == val) {
		elt.selectedIndex = i;
		break;
	    }
	}
    } else if (elt.tagName == 'INPUT' && elt.type == 'text') {
	elt.value = val;
    } else if (elt.tagName == 'INPUT' && elt.type == 'checkbox') {
	elt.checked = (val!=0);
    } else {
	elt.setAattribute('v', val);
    }
}

// UIの寄与指定から関係式を作り、文字列で返す
function get_glpk_ui() {
    // まず情報収集
    var induce = {}; // 寄与先GLPK変数 => 1次式 (1次式は、GLPK変数=>係数)
    var uis = document.querySelectorAll('.ui');
    for (var elt of uis) {
	var v = get_value(elt.children[3]); // 寄与元GLPK変数名
	for (var i = 4; i < elt.children.length-1; i+=2) {
	    var c = get_value(elt.children[i]);   // 寄与先GLPK変数の係数
	    var u = get_value(elt.children[i+1]); // 寄与先GLPK変数名
	    if (! (u in induce)) { induce[u] = {}; }
	    if (! (v in induce[u])) { induce[u][v] = 0; }
	    induce[u][v] += Number(c);
	}
    }
    // 式構成
    var res = []; // glpksubjには既に'Subject to'あるので、ここは空
    for (var u in induce) { // u は寄与先GLPK変数
	// 左辺のうち、1次式部分の構築
	var eq = '';
	for (var v in induce[u]) { // v は寄与元GLPK変数
	    if (induce[u][v] >= 0) { eq += '+'; }
	    eq += String(induce[u][v]) + v;
	}
	if (eq == '') { eq = '0'; }
	// 左辺の寄与先変数部分と、右辺の構築
	eq += '-' + u + ' = 0';
	res.push(eq);
    }
    res.push("\n");
    return res.join("\n");
}

// 追加検索用に、検索結果から制約条件の関係式を作り、文字列で返す。
// summaryで n* と指定されているもので、結果で0でないものが対象。
// insertResultするときに、summary要素に保存してある。
function get_glpk_add() {
    var res = [];
    var smrys = document.querySelectorAll('#resultpane details summary');
    for (var smry of smrys) {
	res.push(smry.getAttribute('condInAdd'));
    }
    res.push("\n");
    return res.join("\n");
}

// 追加スキル検索時に、装備固定の関係式を文字列で返す。
// btnを起点に要素を親へ辿ったてsummary要素で n* と指定されているもので、
// 結果で0でないものが対象。
// insertResultするときに、summary要素に保存してある。
function get_glpk_more(btn) {
    var elt = btn;
    while (elt.tagName != 'DETAILS') { elt = elt.parentNode; }
    // 多分[0]がsummary要素
    return elt.children[0].getAttribute('condInMore') + "\n";
}

// UIの範囲指定からBonudsの式を作り、配列で返す
function get_glpk_bounds() {
    var res = ['Bounds'];
    // すべてのGLPK変数のSet
    var vs = new Set();
    for (v of Object.keys(vname)) { vs.add(v); }
    // UIにあるものは範囲を取得
    var elts = document.querySelectorAll('.ui');
    for (var elt of elts) {
	var min = String(get_value(elt.children[0]));
	var max = String(get_value(elt.children[1]));
	var v = get_value(elt.children[3]);
	vs.delete(v);
	if (min != '') { v = min + ' <= ' + v; }
	if (max != '') { v = v + ' <= ' + max; }
	if (min == '' && max == '') { v = '-inf <= ' + v + ' <= +inf'; }
	res.push(v);
    }
    // UIになかったもの
    for (var v of vs) {
	res.push('-inf <= ' + v + '<= +inf');
    }
    res.push("\n");
    return res.join("\n");
}

// GLPKに検索を送る
function doGLPK(glpktxt) {
    // 検索実行
    job = new Worker("simgenworker.js");
    var tm;
    job.onmessage = function(e) {
	if (e.data.action == 'tentative') { // 検索途中経過
	    var tm1 = performance.now() - tm;
	    insertResult(e.data.result, tm1);
	    tm = performance.now();
	} else if (e.data.action == 'done') { // 検索完了
	    insertNoResult(e.data.result, tm1); // 結果なしの場合の処理
	    job.terminate();
	    job = null;
	    updateQueryBtn('run/add');
	} else if (e.data.action == 'log') {
	    log_if_glpkshow(e.data.message);
	}
    };
    tm = performance.now();
    job.postMessage({action: 'load', data: glpktxt, mip: true});
}

// GLPK実行中にログを書き足し
function log_if_glpkshow(value){
    if (! glpkshow()) {return; }
    var logNode = document.getElementById("glpklog");
    logNode.appendChild(document.createTextNode(value + "\n"));
    logNode.scrollTop = logNode.scrollHeight;
}

//// 結果表示
// 結果を挿入
function insertResult(res, tm) {
    var lines = [];
    // summary部分
    var cond = condInAddMoreText(res);
    var condstr = cond[0] ? ` condInAdd="${cond[0]}"` : '';
    var cond2str = cond[1] ? ` condInMore="${cond[1]}"` : '';
    lines.push('<details>');
    lines.push(`<summary class="ressmry"${condstr}${cond2str}>`);
    lines.push(summaryText(res, tm));
    lines.push('</summary>');
    // details部分
    lines.push(detailsText(res, tm));
    lines.push('</details>');
    lines.push('<hr>');
    // 挿入
    var respane = document.getElementById('resultpane');
    var text = lines.join('');
    respane.insertAdjacentHTML('afterbegin', text);
}

// 結果なしを挿入
function insertNoResult(res, tm) {
    for (var v in res) {
	if (res[v] != 0) { return; }
    }
    var respane = document.getElementById('resultpane');
    respane.insertAdjacentHTML('afterbegin', '検索結果なし<hr>');
}

// summaryのテキスト生成
// また 追加検索用の不等式をcondInAdd 属性に保存
function summaryText(res, tm) {
    var lines = [];
    var width = null;
    for (var x of summary) { // [フラグ, GLPK変数]か幅指定
	if (! (x instanceof Array)) { // 幅指定
	    width = x.match(/width:\d+px/) ? x : null;
	} else if (x[0].includes('*') && res[x[1]] == 0) { // 0で表示抑制
		continue;
	} else {
	    var line = [];
	    if (x[0].includes('n')) { // 変数名
		line.push(vname[x[1]]);
	    }
	    if (x[0].includes('v')) { // 値
		line.push(res[x[1]]);
	    }
	    if (line.length > 0) { // 表示するものがあれば出力
		lines.push(spanWithStyle(line.join(' '), width));
	    }
	}
    }
    return lines.join("\n");
}

// summaryで n* と指定されているもので結果で0でないものを、
// 追加検索用の不等式と、追加スキル用の等式にして返す。なければnull
function condInAddMoreText(res) {
    var cond = [];
    var condVal = 0;
    for (var x of summary) { // [フラグ, GLPK変数]か幅指定
	if (x instanceof Array && (x[0]=='n*'||x[0]=='*n') && res[x[1]] > 0) {
	    condVal += res[x[1]];
	    cond.push(x[1]);
	}
    }
    if (cond.length == 0) { return [null, null]; }
    var condstr = cond.join(' + ') + " <= " + String(condVal-1);
    var cond2str = cond.join(" = 1\n") + " = 1\n";
    return [condstr, cond2str]
}

// detailsのテキスト生成
function detailsText(res, tm) {
    var lines = [];
    var row = null;
    var carryover = []; // 次の列に持ち越すもの
    var fullrng = fullrange(); // UIセクションで「*」かつ範囲一杯のGLPK変数のSet
    // 
    for (var x of details) {
	if (! (x instanceof Array)) { // 見出し等
	    if (x == 'newcolumn') { // 列生成
		if (row) { // 前の列を確定
		    lines.push(vbox(row));
		}
		row = carryover;
		carryover = [];
	    } else if (x == 'time') { // 時刻
		(row || lines).push(String((tm/1000).toFixed(3)) + 'sec');
	    } else { // 見出し
		var st = 'text-decoration:underline';
		if (x[0] == '!') { // 先頭!は強制で先頭
		    (row || lines).unshift(spanWithStyle(x.slice(1), st));
		} else {
		    (row || lines).push(spanWithStyle(x, st));
		}
	    }
	} else if (x[0] == 'more') { // 追加スキルボタン
	    // 追加スキルで検索するGLPK変数=>当該結果の値の辞書を作成
	    var h = {};
	    for (var v of group[x[2]]) {
		h[v] = res[v];
	    }
	    var hstr = JSON.stringify(h);
	    var str = '<button onclick="doMoreSkillBtn(event)" ' +
		`vs='${hstr}'>` + x[1] + '</button>';
	    (row || lines).push(str);
	} else { // [フラグ, GLPK変数]
	    line = [];
	    // 0で表示抑制
	    if (x[0].includes('*') && res[x[1]] == 0) {
		continue;
	    }
	    // 変数名
	    if (x[0].includes('n')) {
		line.push(vname[x[1]]);
	    }
	    // 値
	    if (x[0].includes('v')) {
		line.push(res[x[1]]);
	    }
	    // 範囲一杯かどうかで判断して現在列か次の列に追加する
	    if (line.length > 0) {
		if (res[x[1]] > 0 && fullrng.has(x[1])) {
		    carryover.push(line.join(' '));
		} else {
		    (row || lines).push(line.join(' '));
		}
	    }
	}
    }
    // 列が残っていたら確定
    if (row && row.length > 0) { lines.push(vbox(row)); }
    // 持ち越しが残っていたら確定
    if (carryover.length > 0) { lines.push(vbox(carryover)); }
    return lines.join("\n");
}

// UIセクションで「*」付きで、かつ、範囲一杯の指定を受けているGLPK変数のSetを返す
function fullrange() {
    var res = new Set();
    var elts = document.querySelectorAll('.ui');
    for (var elt of elts) {
	var minelt = elt.children[0];
	var maxelt = elt.children[1];
	var star = get_value(elt.children[2]);
	var v = get_value(elt.children[3]);
	if (star == '*' &&
	    get_value(minelt) == minelt.getAttribute('f') &&
	    get_value(maxelt) == maxelt.getAttribute('f')) {
	    res.add(v);
	}
    }
    return res;
}
   
// スタイル指定付きspanを配列で返す
function spanWithStyle(x, st) {
    if (! st) {
	return '<span>' + x + '</span>';
    } else {
	return `<span style="display:inline-block;${st}">` + x + '</span>';
    }
}

// 配列要素を縦に並べる
function vbox(strs) {
    res = [];
    res.push(`<table  style="vertical-align:top;display:inline-block">`);
    res.push('<tr><td>');
    for (var s of strs) { res.push(s, '<br>'); }
    res.push('</table>');
    return res.join("\n");
}

// 検索結果をすべて消去
function clearResult() {
    var respane = document.getElementById('resultpane');
    respane.innerHTML = '';
    updateQueryBtn('run/add');
    saveUIparam();
}

//// 追加スキル検索
// ハンドラ
function doMoreSkillBtn(ev) {
    var btn = ev.target;
    btn.disabled = 'true';
    // 確定しているGLPKソースを作成
    var glpktxt1 = glpksubj + get_glpk_ui();
    var glpktxt2 = get_glpk_bounds() + glpkgenerals;
    // 検索対象の変数グループ取得
    var vs = JSON.parse(btn.getAttribute('vs'));
    // 非同期にglpk実行 (非同期にするため、グループごと渡す)
    doMoreSkill2(vs, btn, glpktxt1, glpktxt2);
}

// 非同期にglpkで追加スキルを検索し、結果を挿入
function doMoreSkill2(vs, btn, glpktxt1, glpktxt2) {
    var ks = Object.keys(vs);
    if (ks.length == 0) { return; }
    // スキル名を表示
    var elt = document.createElement('span');
    elt.innerHTML = vname[ks[0]];
    btn.parentNode.appendChild(elt);
    // 検索時のglpkテキストを取得
    var glpktxt =
	`Maximize\n${ks[0]}\n` + glpktxt1 + get_glpk_more(btn) + glpktxt2;
    // glpk実行
    var job = new Worker("simgenworker.js");
    job.onmessage = function(e) {
	if (e.data.action == 'done') {
	    job.terminate();
	    job = null;
	    var lv = e.data.result[ks[0]];
	    if (lv > vs[ks[0]]) {
		btn.parentNode.appendChild(document.createTextNode(`Lv${lv}`));
		btn.parentNode.appendChild(document.createElement('br'));
	    } else {
		btn.parentNode.lastElementChild.remove();
	    }
	    delete vs[ks[0]];
	    doMoreSkill2(vs, btn, glpktxt1, glpktxt2);
	} else if (e.data.action == 'log') {
	    // log_if_glpkshow(e.data.message);
	}
    };
    job.postMessage({action: 'load', data: glpktxt, mip: true});
}

//// localstrageの記録と回復
// UIのパラメータをlocal storageへ保存
function saveUIparam() {
    // (GLPKでない) 変数名をキーにして辞書を作る
    var res = {};
    var uis = document.querySelectorAll('.ui');
    for (var elt of uis) {
	var uicnt = elt.getAttribute('uicnt');
	if (! uicnt) { continue; } // すべて定数のUI部品は無視
	var xs = elt.children;
	var h = {};
	// 定数でない値を収集
	for (var i = 0; i < xs.length; i++) {
	    if (xs[i].tagName == 'SELECT' || xs[i].tagName == 'INPUT') {
		h[String(i)] = get_value(xs[i]);
	    }
	}
	// 寄与元が定数なら単にresに登録、違うなら順にためる
	if (xs[3].tagName != 'SELECT' && xs[3].tagName != 'INPUT') {
	    res[vname[get_value(xs[3])]] = h;
	} else {
	    res[uicnt] = h;
	}
    }
    // 記録
    localStorage[localstoragekey] = JSON.stringify(res);
}

// UIのパラメータをlocal storageから回復
function loadUIparam() {
    var str = localStorage[localstoragekey];
    var dic = str ? JSON.parse(str) : {};
    var uis = document.querySelectorAll('.ui');
    for (var elt of uis) {
	var uicnt = elt.getAttribute('uicnt');
	if (! uicnt) { continue; } // すべて定数のUI部品は無視
	var xs = elt.children;
	// 寄与元が定数かどうかで、dicのキーを決める
	var k = (xs[3].tagName == 'SELECT' || xs[3].tagName == 'INPUT') ?
	    String(uicnt) : vname[get_value(xs[3])];
	if (! (k in dic)) { continue; }
	// 安全のため定数でない要素にのみ値を設定
	for (var ii in dic[k]) {
	    var i = Number(ii);
	    if (xs[i].tagName == 'SELECT' || xs[i].tagName == 'INPUT') {
		set_value(xs[i], dic[k][ii]);
	    }
	}
    }
}

//// プルダウンを選択したときの色設定
// 数値のプルダウンのイベントハンドラを設定
function setPulldownHandlers() {
    var drps = document.querySelectorAll('select');
    for (var elt of drps) {
	if (elt.hasAttribute('f')) {
	    updateHilite(elt);
	    elt.addEventListener('change', h_Pulldown);
	}
    }
}

// プルダウンに変更があったときのイベントハンドラ
function h_Pulldown(ev) {
    updateHilite(ev.target);
}

// プルダウンの背景色を設定する
function updateHilite(elt) {
    var max = -999999;
    var min = 999999;
    for (var i = 0; i < elt.length;  i++) {
	var a = Number(elt.options[i].value);
	max = Math.max(max, a);
	min = Math.min(min, a);
    }
    elt.classList.remove('hiliteMax');
    elt.classList.remove('hiliteMin');
    var a = Number(elt.options[elt.selectedIndex].value);
    if (a == max) {
	elt.classList.add('hiliteMax');
    } else if (a == min) {
	elt.classList.add('hiliteMin');
    }
}

//// onload
onload = function () {
    // UIパラメータの回復
    loadUIparam();
    // プルダウンのイベントハンドラ設定
    setPulldownHandlers();
}
