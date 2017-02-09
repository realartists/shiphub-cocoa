import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'
import AttributedString from './attributed-string.js'

import h from 'hyperscript'
import diff_match_patch from 'diff-match-patch'
import htmlEscape from 'html-escape';

class UnifiedRow extends DiffRow {
  constructor(mode, text, oldText, leftLineNum, rightLineNum, diffLine) {
    super();
    
    this.mode = mode;
    this.text = text;
    this.oldText = oldText;
    this.leftLineNum = leftLineNum;
    this.rightLineNum = rightLineNum;
    this.diffLine = diffLine;
            
    var gutterLeft = h('td', { className:'gutter gutter-left' });
    var gutterRight = h('td', { className:'gutter gutter-right' });
    
    if (leftLineNum !== undefined) {
      gutterLeft.innerHTML = "" + (1+leftLineNum);
    }
    if (rightLineNum !== undefined) {
      gutterRight.innerHTML = "" + (1+rightLineNum);
    }
    
    var codeClasses = 'unified unified-codecol';
    if (mode === '-') {
      codeClasses += ' deleted-original';
    } else if (mode === '+') {
      codeClasses += ' inserted-new';
    }
    var codeCell = this.codeCell = h('td', { className: codeClasses });
    
    codeCell.innerHTML = this.codeColContents(htmlEscape(text||""));
    
    var row = h('tr', {}, gutterLeft, gutterRight, codeCell);
    this.node = row;
    
    if (mode === '-') {
      this.miniMapRegions = [new MiniMap.Region(codeCell, 'red')];
    } else if (mode === '+') {
      this.miniMapRegions = [new MiniMap.Region(codeCell, 'green')];
    }
  }
  
  updateHighlight(highlighted, ctxHighlighted) {
    if (ctxHighlighted) {
      var myAstr = AttributedString.fromHTML(highlighted);
      var ctxAstr = AttributedString.fromHTML(ctxHighlighted);
      
      var dmp = new diff_match_patch();
      var diff = dmp.diff_main(myAstr.string, ctxAstr.string);
      dmp.diff_cleanupSemantic(diff);
      
      if (diff.length > 1) {
        var leftIdx = 0, rightIdx = 0;
        for (var i = 0; i < diff.length; i++) {
          var change = diff[i];
          var length = change[1].length;
          if (change[0] == -1) {
            myAstr.addAttributes(new AttributedString.Range(leftIdx, length), ["char-changed"]);
          }
          leftIdx += length;
        }
      }
      
      highlighted = myAstr.toHTML();
    }
    
    this.codeCell.innerHTML = this.codeColContents(highlighted);
  }
}

export default UnifiedRow;

