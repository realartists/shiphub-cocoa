import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'
import AttributedString from 'util/attributed-string.js'

import h from 'util/make-element.js'
import diff_match_patch from 'diff-match-patch'
import htmlEscape from 'html-escape';

class SplitRow extends DiffRow {
  constructor(leftLine, leftLineNum, rightLine, rightLineNum, diffIdx, hunkNum, rightDiffIdx, changed, colorblind, addNewCommentHandler) {
    super();
    
    this.leftLineNum = leftLineNum;
    this.rightLineNum = rightLineNum;
    this.diffIdx = diffIdx;
    this.hunkNum = hunkNum;
    this.rightDiffIdx = rightDiffIdx;
    this.changed = changed;
    this.colorblind = colorblind;
    this.addNewCommentHandler = addNewCommentHandler;
    
    var leftClasses = 'left codecol';
    var rightClasses = 'right codecol';
    
    var gutterLeft = h('td', { className:'gutter gutter-left' });
    var gutterRight = h('td', { className:'gutter gutter-right' });

    this.configureGutterCol(gutterLeft, leftLineNum, diffIdx===undefined?rightDiffIdx:diffIdx, this.addCommentLeft.bind(this));
    this.configureGutterCol(gutterRight, rightLineNum, rightDiffIdx===undefined?diffIdx:rightDiffIdx, this.addCommentRight.bind(this));
    
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
    
    var row;
    
    if (colorblind) {
      var cbLeft;
      var cbRight;
      
      if (leftLine === undefined) {
        cbLeft = h('td', {className:'cb cb-empty'});
        cbRight = h('td', {className:'cb cb-plus'});
        cbRight.innerHTML = '+';
      } else if (rightLine === undefined) {
        cbLeft = h('td', {className:'cb cb-minus'});
        cbLeft.innerHTML = '-';
        cbRight = h('td', {className:'cb cb-empty'});
      } else if (changed) {
        cbLeft = h('td', {className:'cb cb-changed'});
        cbLeft.innerHTML = '-';
        cbRight = h('td', {className:'cb cb-changed'});
        cbRight.innerHTML = '+';
      } else {
        cbLeft = h('td', {className:'cb cb-empty'});
        cbRight = h('td', {className:'cb cb-empty'});
      }
      
      row = h('tr', {}, gutterLeft, cbLeft, left, gutterRight, cbRight, right);
      
    } else {
      row = h('tr', {}, gutterLeft, left, gutterRight, right);
    }
    
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
    
    if (this.lastSearch) {
      this.search(this.lastSearch);
    }
  }
  
  addCommentLeft() {
    var idx = this.diffIdx !== undefined ? this.diffIdx : this.rightDiffIdx;
    this.addNewCommentHandler(idx);
  }
  
  addCommentRight() {
    var idx = this.rightDiffIdx !== undefined ? this.rightDiffIdx : this.diffIdx;
    this.addNewCommentHandler(idx);
  }
  
  currentLeftAstr() {
    return AttributedString.fromHTML(this.left.innerHTML.substr(5, this.left.innerHTML.length-7));
  }
  
  currentRightAstr() {
    return AttributedString.fromHTML(this.right.innerHTML.substr(5, this.right.innerHTML.length-7));
  }
  
  search(regexp) {
    this.lastSearch = regexp;
    
    var leftText = this.left.textContent;
    var rightText = this.right.textContent;
    
    if (this.hadSearchMatch || (regexp && leftText.match(regexp)) || (regexp && rightText.match(regexp))) {
      var leftAstr = this.currentLeftAstr();
      var rightAstr = this.currentRightAstr();
      
      leftAstr.off(["search-match", "search-match-highlight"]);
      rightAstr.off(["search-match", "search-match-highlight"]);
      
      var matchCount = {c:0};
      if (regexp) {
        this.leftSearchMatchRanges = [];
        this.rightSearchMatchRanges = [];
      
        var matchem = function(astr, ranges) {
          regexp.lastIndex = 0;
          var match;
          while ((match = regexp.exec(astr.string)) !== null) {
            var offset = match.index;
            var length = match[0].length;
            var range = new AttributedString.Range(offset, length);
            astr.addAttributes(range, ["search-match"]);
            ranges.push(range);
            matchCount.c = matchCount.c + 1;
          }
        }
        matchem(leftAstr, this.leftSearchMatchRanges);
        matchem(rightAstr, this.rightSearchMatchRanges);
      } else {
        delete this.leftSearchMatchRanges;
        delete this.rightSearchMatchRanges;
      }
        
      this.left.innerHTML = this.codeColContents(leftAstr.toHTML());
      this.right.innerHTML = this.codeColContents(rightAstr.toHTML());
        
      this.hadSearchMatch = matchCount.c > 0;
      return matchCount.c;
    }
    return 0;
  }
  
  highlightSearchMatch(idx) {
    var leftAstr = this.currentLeftAstr();
    var rightAstr = this.currentRightAstr();
            
    var j = 0;
    
    if (idx < this.leftSearchMatchRanges.length) {
      leftAstr.addAttributes(this.leftSearchMatchRanges[idx], ["search-match-highlight"]);
      this.left.innerHTML = this.codeColContents(leftAstr.toHTML());
    } else {
      idx -= this.leftSearchMatchRanges.length;
      if (idx < this.rightSearchMatchRanges.length) {
        rightAstr.addAttributes(this.rightSearchMatchRanges[idx], ["search-match-highlight"]);
        this.right.innerHTML = this.codeColContents(rightAstr.toHTML());
      }
    }
    
    this.node.scrollIntoViewIfNeeded();
  }
}

export default SplitRow;

