// -*- mode:js; mode:outline-minor -*-
var job;
var glpkmaximize, glpksubj, glpkgenerals; // simgen.rbで生成したデータ
var vname; // GLPK変数=>変数名の辞書
var summary; // SUMMARYセクションそのままの配列
var details; // SUMMARYセクションそのままの配列
var localstoragekey = 'simgen';

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
    var induce = {};
    var uis = document.querySelectorAll('.ui');
    for (var elt of uis) {
	var v = get_value(elt.children[3]); // 寄与元GLPK変数名
	for (var i = 4; i < elt.children.length-1; i+=2) {
	    var c = get_value(elt.children[i]);
	    var u = get_value(elt.children[i+1]);
	    if (! (u in induce)) { induce[u] = ''; }
	    if (c[0] != '-') { c = '+' + c; }
	    induce[u] = induce[u] + c + v;	    
	}
    }
    // 式構成
    var res = []; // glpksubjには既に'Subject to'あるので、ここは空
    for (var u in induce) {
	var eq = induce[u];
	res.push(eq + '-' + u + ' = 0');
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
    var cond = condInAddText(res);
    if (cond) {
	lines.push('<details>', `<summary condInAdd="${cond}">`);
    } else {
	lines.push('<details>', '<summary>');
    }
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
// 追加検索用の不等式にして返す。なければnull
function condInAddText(res) {
    var cond = [];
    var condVal = 0;
    for (var x of summary) { // [フラグ, GLPK変数]か幅指定
	if (x instanceof Array && (x[0]=='n*'||x[0]=='*n') && res[x[1]] > 0) {
	    condVal += res[x[1]];
	    cond.push(x[1]);
	}
    }
    if (cond.length == 0) { return null; }
    return cond.join(' + ') + " <= " + String(condVal-1);
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

		// !! 追加スキルボタンの処理が入る予定
		
	    } else if (x[0] == '!') { // 先頭!は強制で先頭
		(row || lines).unshift(x.slice(1));
	    } else {
		(row || lines).push(x);
	    }
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

//// localstrageの記録と回復
// UIのパラメータをlocal storage
// !! ここはぜんぜんだめ。目処もたたない
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
// !! ここはぜんぜんだめ。目処もたたない
function loadUIparam() {
    var str = localStorage[localstoragekey];
    var dic = str ? JSON.parse(str) : {};
    var uis = document.querySelectorAll('.ui');
    for (var elt of uis) {
	var uicnt = elt.getAttribute('uicnt');
	if (! uicnt) { continue; } // すべて定数のUI部品は無視
	var v = elt.getAttribute('v');
	if (vname[v] in dic) {
	    var val = dic[vname[v]];
	    if (elt.tagName == 'INPUT' && elt.type == 'text') {
		elt.value = val;
	    } else if (elt.tagName == 'INPUT' && elt.type == 'checkbox') {
		elt.checked = ((val==0) ? false : true);
	    } else if (elt.tagName == 'SELECT') {
		for (var i = 0; i < elt.length; i++) {
		    if (elt.options[i].value == val) {
			elt.selectedIndex = i;
		    }
		}
	    }
	}
    }
}

//// onload
onload = function () {
    // UIパラメータの回復
    // loadUIparam(); !! ちょっとやめておく
}
