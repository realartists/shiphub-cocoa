/* Defines a spellcheck module for CodeMirror that relies on the system spellchecker */

import BBPromise from 'util/bbpromise.js'
import CodeMirror from 'codemirror'

var checkHandle = 0;
var checkResults = [];
var focusedCM = null;

/* 
  Spell check text. Returns a promise where on success is an array of
  text ranges that are misspelled.
  
  [{ start: ..., end: ... }]
*/
function checkText(text) {
  return new BBPromise((resolve, reject) => {
    if (window.spellcheck) {
      var handle = ++checkHandle;
      checkResults[handle] = resolve;
      window.spellcheck.postMessage({text, handle});
    } else {
      reject(new Error("System spellcheck unavailable"));
    }
  });
}

window.spellcheckResults = function(data) {
  var handle = data.handle;
  var resolve = checkResults[handle];
  delete checkResults[handle];
  resolve(data.results);
};

window.spellcheckFixer = function(token, replacement) {
  var myCM = focusedCM;
  if (!myCM) {
    return;
  }
  
  myCM.replaceRange(replacement, token.start, token.end, "+input");
};

function CheckState(cm, options) {
  this.marked = [];
  this.options = options;
  this.timeout = null;
  this.waitingFor = 0
}

function parseOptions(_cm, options) {
  if (options instanceof Function) return options();
  if (!options || options === true) options = {};
  return options;
}

function clearMarks(cm) {
  var state = cm.state.systemSpellcheck;
  for (var i = 0; i < state.marked.length; ++i)
    state.marked[i].clear();
  if (state.pendingMark) {
    state.pendingMark.clear();
    delete state.pendingMark;
  }
  state.marked.length = 0;
}

function textInViewport(cm, viewport) {
  var start = { line: viewport.from, ch: 0 };
  var endl = viewport.to;
  if (endl > cm.lastLine()) endl = cm.lastLine();
  var ll = cm.getLine(endl);
  var end = { line: endl, ch: ll.length };
  
  if (start.line == end.line && start.ch == end.ch) return "";
  
  return cm.getRange(start, end);
}

function startChecking(cm) {
  var state = cm.state.systemSpellcheck, options = state.options;
  
  var text = cm.getValue();
  checkText(text).then((results) => {    
    var newText = cm.getValue();
    
    if (text != newText) {
      return;
    }
    
    clearMarks(cm);
    results.forEach((range) => {
      var mode = cm.getModeAt(range.start);
      var tt = cm.getTokenTypeAt(range.start);
      var cursor = cm.getCursor();
      var inCursor = cursor.line == range.start.line && range.start.ch <= cursor.ch && range.end.ch >= cursor.ch;
      
      // Only show misspellings in markdown mode, and ignore `backticks` ```triple-ticks``` and links.
      if (mode.name === 'markdown' && (!tt || (tt.indexOf('comment') == -1 && tt.indexOf('link') == -1))) {
        if (inCursor) {
          state.pendingMark = cm.markText(range.start, range.end, {});
        } else {
          state.marked.push(cm.markText(range.start, range.end, {className:'misspelling'}));
        }
      }
    });
    
  }).catch((error) => {
    console.log("Unable to spellcheck", error);
    clearMarks(cm);
  });
}

function scheduleCheck(cm) {
  var state = cm.state.systemSpellcheck;
  if (!state) return;
  clearTimeout(state.timeout);
  state.timeout = setTimeout(function(){startChecking(cm);}, state.options.delay || 50);
}

function onChange(cm) {
  scheduleCheck(cm);
}

function onCursor(cm) {
  var state = cm.state.systemSpellcheck;
  if (!state) return;
  if (state.pendingMark) {
    var markRange = state.pendingMark.find();
    if (!markRange || !markRange.from) return;
    
    var wordRange = cm.findWordAt(markRange.from);
    wordRange = {from: wordRange.anchor, to:wordRange.head};
    
    var cursor = cm.getCursor();
    
    function inCursor(range) {
      return cursor.line == range.from.line && range.from.ch <= cursor.ch && range.to.ch >= cursor.ch;
    }
    
    if (!inCursor(wordRange)) {
      state.pendingMark.clear();
      delete state.pendingMark;
      
      var markIsWord = markRange.from.ch == wordRange.from.ch && markRange.to.ch == wordRange.to.ch;
      if (markIsWord) {
        state.marked.push(cm.markText(markRange.from, markRange.to, {className:'misspelling'}));
      }
    }
  }
}

function onContextMenu(cm, event) {
  if (!window.spellcheck) {
    return false;
  }
  
  var el = event.target;
  var targetIsMisspelling = (' ' + el.className + ' ').indexOf(' misspelling ') > -1;
  
  if (targetIsMisspelling) {
    // find the range of the targeted element
    var bb = el.getBoundingClientRect();
    
    var leftPt = { left: bb.left, top: bb.top + (bb.height / 2) };
    var rightPt = { left: bb.right, top: bb.top + (bb.height / 2) };
    
    var left = cm.coordsChar(leftPt, "window");
    var right = cm.coordsChar(rightPt, "window");
    var text = cm.getRange(left, right);
        
    var token = { start: left, end: right, text: text };
    focusedCM = cm;
    window.spellcheck.postMessage({contextMenu: true, target: token});
  }
  
  return false;
}

function onFocus(cm) {
  focusedCM = cm;
}

function onBlur(cm) {
  focusedCM = null;
}

CodeMirror.defineOption("systemSpellcheck", false, function(cm, val, old) {
  if (old && old != CodeMirror.Init) {
    clearMarks(cm);
    cm.off("change", onChange);
    cm.off("cursorActivity", onCursor);
    cm.off("contextmenu", onContextMenu);
    cm.off("focus", onFocus);
    cm.off("blur", onBlur);
    clearTimeout(cm.state.systemSpellcheck.timeout);
    delete cm.state.systemSpellcheck;
  }

  if (val) {
    var state = cm.state.systemSpellcheck = new CheckState(cm, parseOptions(cm, val));
    cm.on("change", onChange);
    cm.on("cursorActivity", onCursor);
    cm.on("contextmenu", onContextMenu);
    cm.on("focus", onFocus);
    cm.on("blur", onBlur);
    startChecking(cm);
  }
});
