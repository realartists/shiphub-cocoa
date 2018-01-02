import DiffRow from './diff-row.js'

import h from 'util/make-element.js'
import htmlEscape from 'html-escape';

class PlaceholderRow extends DiffRow {
  constructor(colorblind) {
    super();
    
    this.rows = [];
    this.colorblind = colorblind;
  }
  
  makeGutters() {
    var gutterLeft = h('td', { className:'gutter gutter-left' });
    var gutterRight = h('td', { className:'gutter gutter-right' });

    function lineMax(a, b) {
      if (a === undefined) return b;
      if (b === undefined) return a;
      return a > b ? a : b;
    }
    
    var { maxLeft, maxRight } = this.rows.reduce((accum, r) => {
      return { maxLeft: lineMax(accum.maxLeft, r.leftLineNum), 
               maxRight: lineMax(accum.maxRight, r.rightLineNum) };
    }, {});
    
    if (maxLeft !== undefined) {
      this.configureGutterCol(gutterLeft, maxLeft);
    }
    if (maxRight !== undefined) {
      this.configureGutterCol(gutterRight, maxRight);
    }
    
    return { gutterLeft, gutterRight };
  }
  
  addRow(row) {
    row.hasPlaceholder = true;
    this.rows.push(row);
    return true;
  }
  
  freeze() {
    if (this.node) {
      throw new Error("freeze() must be called exactly once");
    }
  
    if (this.rows.length == 0) {
      throw new Error("Need at least 1 row to freeze()");
    }
  }
}

class UnifiedPlaceholderRow extends PlaceholderRow {
  makeCodeHTML() {
    var code = this.rows.map(r => r.text||"\xA0").join("\n");
    return this.codeColContents(htmlEscape(code||""));
  }

  freeze() {
    super.freeze();
     
    var { gutterLeft, gutterRight } = this.makeGutters();
    
    var codeClasses = 'unified unified-codecol';
    var cbClasses = 'cb cb-empty';
    
    var codeCell = this.codeCell = h('td', { className: codeClasses });
    codeCell.innerHTML = this.makeCodeHTML();
    
    var row;
    if (this.colorblind) {
      var cbCol = h('td', {className:cbClasses});
      cbCol.innerHTML = mode || '';
      row = h('tr', {}, gutterLeft, gutterRight, cbCol, codeCell);
    } else {
      row = h('tr', {}, gutterLeft, gutterRight, codeCell);
    }
    this.node = row;
  }
}

class SplitPlaceholderRow extends PlaceholderRow {
  makeCodeHTML() {
    var code = this.rows.map(r => r.leftLine||"\xA0").join("\n");
    return this.codeColContents(htmlEscape(code||""));
  }

  freeze() {
    super.freeze();
    
    var { gutterLeft, gutterRight } = this.makeGutters();
    
    var leftClasses = 'left codecol';
    var rightClasses = 'right codecol';
    
    var codeHTML = this.makeCodeHTML();
    var left = this.left = h('td', {className:leftClasses});
    var right = this.right = h('td', {className:rightClasses});
    left.innerHTML = codeHTML;
    right.innerHTML = codeHTML;
    
    var row;
    
    if (this.colorblind) {
      var cbLeft;
      var cbRight;
      
      cbLeft = h('td', {className:'cb cb-empty'});
      cbRight = h('td', {className:'cb cb-empty'});
      
      row = h('tr', {}, gutterLeft, cbLeft, left, gutterRight, cbRight, right);
    } else {
      row = h('tr', {}, gutterLeft, left, gutterRight, right);
    }
    
    this.node = row;
  }
}

export { PlaceholderRow, UnifiedPlaceholderRow, SplitPlaceholderRow };
