/* Collection of utilities for working on Codemirror instances */

export function shiftTab(cm) {
  var from = cm.getCursor("from");
  var to = cm.getCursor("to");
  
  if (from.line == 0 && from.ch == 0 && to.line == 0 && to.ch == 0) {
    // find the previous input and select it
    var inputs = document.getElementsByTagName('input');
    
    var x = null;
    for (var i = inputs.length-1; i >= 0; i--) {
      if (inputs.item(i).type == 'text') {
        x = inputs.item(i);
        break;
      }
    }
    
    if (x) x.focus();
    
  } else {
    cm.execCommand('indentLess');
  }
};

export function searchForward(cm, startPos, needle) {
  var line = startPos.line;
  var ch = startPos.ch;
  
  var lc = cm.lineCount();
  while (line < lc) {
    var lt = cm.getLine(line);
    var ls = lt.slice(ch);
    var p = ls.indexOf(needle);
    if (p != -1) {
      p += ch;
      return {from:{line:line, ch:p}, to:{line:line, ch:p+needle.length}};
    }
    line++;
    ch = 0;
  }
}
      
export function searchBackward(cm, startPos, needle) {
  var line = startPos.line;
  var ch = startPos.ch;
  
  while (line >= 0) {
    var lt = cm.getLine(line);
    var ls = ch == -1 ? lt : lt.slice(0, ch);
    var p = ls.lastIndexOf(needle);
    if (p != -1) {
      return {from:{line:line, ch:p}, to:{line:line, ch:p+needle.length}};
    }
    line--;
    ch = -1;
  }
}
 
//  Returns a function suitable to be passed to a codemirror key-handler:
//  cm.setOption('extraKeys', {
//    'Cmd-B': toggleFormat('**', 'strong'),
//    'Cmd-I': toggleFormat('_', 'em'),
//  });
export function toggleFormat(operator, tokenType) {
  return function(cm) {
    var from = cm.getCursor("from");
    var to = cm.getCursor("to");
    
    var fromMode = cm.getModeAt(from).name;
    var toMode = cm.getModeAt(to).name;
    
    if (fromMode != 'markdown' || toMode != 'markdown') {
      return;
    }
    
    // special case: if the current word is just the 2**operator, then
    // delete the current word
    var wordRange = cm.findWordAt(from);
    var word = cm.getRange(wordRange.anchor, wordRange.head);
    var doubleOp = operator+operator;
    if (word == doubleOp) {
      cm.replaceRange("", wordRange.anchor, wordRange.head);
      return;
    }
    
    // Use the editor's syntax parsing to determine the format on the selection
    var fromType = cm.getTokenTypeAt(from);
    var toType = cm.getTokenTypeAt(to);
    
    if (fromType && toType && fromType.indexOf(tokenType) != -1 && toType.indexOf(tokenType) != -1) {
      // it would seem that we're already apply the formatting, and so should undo it

      // walk forward from to and see if we can find operator and delete it.
      if (to.ch >= operator.length) to.ch-=operator.length; // step in a bit in case we have the operator selected
      var end = searchForward(cm, to, operator);
      if (end) {
        cm.replaceRange("", end.from, end.to, "+input");
      }
      
      from.ch+=operator.length; // step out a bit in case we have the operator selected
      var start = searchBackward(cm, from, operator);
      if (start) {
        cm.replaceRange("", start.from, start.to, "+input");
      }
      
      if (start && end) {
        if (end.from.line == start.from.line) {
          end.from.ch -= operator.length;
        }
      
        cm.setSelection(start.from, end.from, "+input");
      }
      
    } else {
      // need to add formatting to the selection
      
      var selection = cm.getSelection();
      // use Object.assign as "from" and "to" can return identical objects and we don't want that.
      var from = Object.assign({}, cm.getCursor("from"));
      var to = Object.assign({}, cm.getCursor("to"));
      cm.replaceSelection(operator + selection + operator, "+input");
      from.ch += operator.length;
      if (to.line == from.line) to.ch += operator.length;
      cm.setSelection(from, to, "+input");
    }
  };
}
