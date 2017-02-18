import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'
import AttributedString from './attributed-string.js'

import h from 'hyperscript'
import diff_match_patch from 'diff-match-patch'
import htmlEscape from 'html-escape';

class SplitRow extends DiffRow {
  constructor(leftLine, leftLineNum, rightLine, rightLineNum, diffIdx, rightDiffIdx, changed) {
    super();
    
    this.leftLineNum = leftLineNum;
    this.rightLineNum = rightLineNum;
    this.diffIdx = diffIdx;
    this.rightDiffIdx = rightDiffIdx;
    this.changed = changed;
    
    var leftClasses = 'left codecol';
    var rightClasses = 'right codecol';
    
    var gutterLeft = h('td', { className:'gutter gutter-left' });
    var gutterRight = h('td', { className:'gutter gutter-right' });

    if (leftLineNum !== undefined) {
      gutterLeft.innerHTML = "" + (1+leftLineNum);
    }
    if (rightLineNum !== undefined) {
      gutterRight.innerHTML = "" + (1+rightLineNum);
    }
    
    if (leftLine === undefined) {
      leftClasses += ' spacer';
      rightClasses += ' inserted-new';
    } else if (rightLine === undefined) {
      leftClasses += ' deleted-original';
      rightClasses += ' spacer';
    } else if (changed) {
      leftClasses += ' changed-original';
      rightClasses += ' changed-new';
    }
    
    var left = this.left = h('td', {className:leftClasses});
    left.innerHTML = this.codeColContents(htmlEscape(leftLine||""));
    
    var right = this.right = h('td', {className:rightClasses});
    right.innerHTML = this.codeColContents(htmlEscape(rightLine||""));
    
    var row = h('tr', {}, gutterLeft, left, gutterRight, right);
    this.node = row;
    
    if (leftLine === undefined) {
      this.miniMapRegions = [new MiniMap.Region(right, 'green')];
    } else if (rightLine == undefined) {
      this.miniMapRegions = [new MiniMap.Region(left, 'red')];
    } else if (changed) {
      this.miniMapRegions = [
        new MiniMap.Region(row, "blue")
      ];
    }
  }
  
  updateHighlight(leftLineHighlighted, rightLineHighlighted) {
    if (this.changed) {
      var leftAstr = AttributedString.fromHTML(leftLineHighlighted);
      var rightAstr = AttributedString.fromHTML(rightLineHighlighted);
      
      var dmp = new diff_match_patch();
      var diff = dmp.diff_main(leftAstr.string, rightAstr.string);
      dmp.diff_cleanupSemantic(diff);
      
      if (diff.length > 1) {      
        var leftIdx = 0, rightIdx = 0;
        for (var i = 0; i < diff.length; i++) {
          var change = diff[i];
          var length = change[1].length;
          if (change[0] == -1) {
            leftAstr.addAttributes(new AttributedString.Range(leftIdx, length), ["char-changed"]);
            leftIdx += length;
          } else if (change[0] == 1) {
            rightAstr.addAttributes(new AttributedString.Range(rightIdx, length), ["char-changed"]);
            rightIdx += length;
          } else {
            leftIdx += length;
            rightIdx += length;
          }
        }
      }
      
      leftLineHighlighted = leftAstr.toHTML();
      rightLineHighlighted = rightAstr.toHTML();
    }
    
    this.left.innerHTML = this.codeColContents(leftLineHighlighted);
    this.right.innerHTML = this.codeColContents(rightLineHighlighted);
  }
}

export default SplitRow;

