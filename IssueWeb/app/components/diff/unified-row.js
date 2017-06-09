import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'
import AttributedString from 'util/attributed-string.js'

import h from 'util/make-element.js'
import diff_match_patch from 'diff-match-patch'
import htmlEscape from 'html-escape';

class UnifiedRow extends DiffRow {
  constructor(mode, text, oldText, leftLineNum, rightLineNum, diffIdx, hunkNum, colorblind, addNewCommentHandler) {
    super();
    
    this.mode = mode;
    this.text = text;
    this.oldText = oldText;
    this.leftLineNum = leftLineNum;
    this.rightLineNum = rightLineNum;
    this.diffIdx = diffIdx;
    this.hunkNum = hunkNum;
    this.colorblind = colorblind;
    this.addNewCommentHandler = addNewCommentHandler;
            
    var gutterLeft = h('td', { className:'gutter gutter-left' });
    var gutterRight = h('td', { className:'gutter gutter-right' });
    
    if (leftLineNum !== undefined) {
      this.configureGutterCol(gutterLeft, leftLineNum, diffIdx, this.addComment.bind(this));
    }
    if (rightLineNum !== undefined) {
      this.configureGutterCol(gutterRight, rightLineNum, diffIdx, this.addComment.bind(this));
    }
    
    var codeClasses = 'unified unified-codecol';
    var cbClasses = 'cb';
    if (mode === '-') {
      codeClasses += ' deleted-original';
      cbClasses += ' cb-minus';
    } else if (mode === '+') {
      codeClasses += ' inserted-new';
      cbClasses += ' cb-plus';
    } else {
      cbClasses += ' cb-empty';
    }
    
    var codeCell = this.codeCell = h('td', { className: codeClasses });
    
    codeCell.innerHTML = this.codeColContents(htmlEscape(text||""));
    
    var row;
    if (colorblind) {
      var cbCol = h('td', {className:cbClasses});
      cbCol.innerHTML = mode || '';
      row = h('tr', {}, gutterLeft, gutterRight, cbCol, codeCell);
    } else {
      row = h('tr', {}, gutterLeft, gutterRight, codeCell);
    }
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
    
    if (this.lastSearch) {
      this.search(this.lastSearch.regexp, this.lastSearch.findInFilesMode);
    }
  }
  
  addComment() {
    this.addNewCommentHandler(this.diffIdx);
  }
  
  currentAstr() {
    return AttributedString.fromHTML(this.codeCell.innerHTML.substr(5, this.codeCell.innerHTML.length-7));
  }
  
  search(regexp, findInFilesMode) {
    this.lastSearch = {regexp, findInFilesMode};
    
    var text = this.codeCell.textContent;
    if (this.hadSearchMatch || (regexp && text.match(regexp))) {
      var astr = this.currentAstr();
      
      astr.off(["search-match", "search-match-highlight"]);
      
      var addedAttrs = ["search-match"];
      if (findInFilesMode) {
        addedAttrs.push("search-match-highlight");
      }
      
      var ranges = this.searchMatchRanges =  [];
      if (regexp) {
        regexp.lastIndex = 0;
        var match;
        while ((match = regexp.exec(astr.string)) !== null) {
          var offset = match.index;
          var length = match[0].length;
          var range = new AttributedString.Range(offset, length);
          astr.addAttributes(range, addedAttrs);
          ranges.push(range);
        }
      }
      
      this.codeCell.innerHTML = this.codeColContents(astr.toHTML());
      this.hadSearchMatch = ranges.length > 0;
      return ranges.length;
    }
    return 0;
  }
  
  highlightSearchMatch(idx) {
    var astr = this.currentAstr();
    if (idx < this.searchMatchRanges.length) {
      astr.addAttributes(this.searchMatchRanges[idx], ["search-match-highlight"]);
      this.codeCell.innerHTML = this.codeColContents(astr.toHTML());
    }
    
    this.node.scrollIntoViewIfNeeded();
  }
  
  selectFindAllMatches(regexp) {
    
  }
}

export default UnifiedRow;

