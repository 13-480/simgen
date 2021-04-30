var job; // sim08glpk.js で定義されている
var glpkmaximize, glpksubj, glpkbounds, glpkgenerals; // glpkソースの確定部分
var vname; // GLPK変数=>変数名の辞書
var summary; // GLPK変数=>SUMMARYに表示するフラグ
var details; // GLPK変数=>DETAILSに表示するフラグ
var fullrange; // GLPK変数の範囲最大の条件
var localstoragekey = 'simgen';


//// 検索ボタン押下時の処理
// 検索ボタンのイベントハンドラ
function doQueryBtn() {
    saveUIparam();
    var btn = document.getElementById('querybtn');
    if        (btn.textContent == btn.dataset.run) {
	updateQueryBtn('stop');
	doQueryBtnRun();
    } else if (btn.textContent == btn.dataset.stop) { 
	updateQueryBtn('run/add');
	doQueryBtnStop();
    } else if (btn.textContent == btn.dataset.add) { 
	updateQueryBtn('stop');
	doQueryBtnAdd(); 
    }
}

// 検索ボタンの表示を変更 (val = 'stop' なら強制で「中止」)
function updateQueryBtn(val) {
    var btn = document.getElementById('querybtn');
    if (job || val == 'stop') {
	btn.textContent = btn.dataset.stop;
	return;
    }	
    var d = document.querySelector('#resultpane details');
    if (d) {
	btn.textContent = btn.dataset.add;
    }	else {
	btn.textContent = btn.dataset.run;
    }
}

// 検索ボタンで「検索」
function doQueryBtnRun() {
    // UIから変数の値を取得して (Subject to 末尾に追加される) GLPKソースを構築
    var glpktxt = glpkmaximize + glpksubj +
	get_glpk_ui() + glpkbounds + glpkgenerals;
    dump_if_glpkshow(glpktxt);
    str = []
    for (var v of Object.keys(vname)) {
	str.push(String(v) + ' ' + vname[v]);
    }
    dump_if_glpkshow(str.join(' / '));
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
    var glpktxt = glpkmaximize + glpksubj + 
	get_glpk_ui() + get_glpk_add() + glpkbounds + glpkgenerals;
    doGLPK(glpktxt);
}

// GLPKログを表示する設定ならjavascriptコンソールへ出力
function dump_if_glpkshow(x) {
    var logNode = document.getElementById("glpklog");
    if (logNode.style.display == 'none') { return; }
    console.log(x);
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

// UIから関係式を作り、文字列で返す
function get_glpk_ui() {
    var res = [];
    var uis = document.querySelectorAll('.ui');
    for (var elt of uis) {
	var v = elt.getAttribute('v');
	res.push(`${v}=${get_value(elt)}\n`);
    }
    return res.join('');
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
	    log(e.data.message);
	}
    };
    tm = performance.now();
    job.postMessage({action: 'load', data: glpktxt, mip: true});
}

// GLPK実行中にログを書き足し
function log(value){
    var logNode = document.getElementById("glpklog");
    if (logNode.style.display == 'none') { return; }
    logNode.appendChild(document.createTextNode(value + "\n"));
    logNode.scrollTop = logNode.scrollHeight;
}


//// 結果表示
// 結果を挿入 // !! 暫定版 ここは非常に複雑になるはず
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
	    if (x == 'nowidth') { // 幅指定解除
		width = null;
	    } else if (x.match(/width:\d+px/)) { // 幅指定
		width = x;
	    }
	} else if (x[0].indexOf('*') >= 0 && res[x[1]] == 0) { // 0で表示抑制
		continue;
	} else {
	    var line = [];
	    if (x[0].indexOf('n') >= 0) { // 変数名
		line.push(vname[x[1]]);
	    }
	    if (x[0].indexOf('v') >= 0) { // 値
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
    for (var x of details) {
	if (! (x instanceof Array)) { // 見出し等
	    if (x == 'newcolumn') { // 列生成
		if (row) { // 前の列を確定
		    lines.push(vbox(row));
		}
		row = carryover;
		carryover = [];
	    } else if (x[0] == '!') { // 先頭!は強制で先頭
		(row || lines).unshift(x.slice(1));
	    } else {
		(row || lines).push(x);
	    }
	} else { // [フラグ, GLPK変数]
	    line = [];
	    // 0で表示抑制
	    if (x[0].indexOf('*') >= 0 && res[x[1]] == 0) {
		continue;
	    }
	    // 変数名
	    if (x[0].indexOf('n') >= 0) {
		line.push(vname[x[1]]);
	    }
	    // 値
	    if (x[0].indexOf('v') >= 0) {
		line.push(res[x[1]]);
	    } // 追加
	    if (line.length > 0) {
		if (isFullrange(res, x[1])) {
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

// 与えられたGLPK変数がUIセクションで範囲一杯の指定を受けているか
function isFullrange(res, v) {
    var x = fullrange[v];
    if (! x) { return false; }
    if (x.length >= 2 && res[x[0]] != x[1]) { return false; }
    if (x.length >= 4 && res[x[2]] != x[3]) { return false; }
    return true;
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
// UIのパラメータをlocal storageに記録
function saveUIparam() {
    // 変数名をキーにして辞書を作る
    var res = {};
    var uis = document.querySelectorAll('.ui');
    for (var elt of uis) {
	var v = elt.getAttribute('v');
	res[vname[v]] = get_value(elt);
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
    loadUIparam();
}
