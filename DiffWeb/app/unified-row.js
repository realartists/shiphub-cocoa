import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'
import AttributedString from './attributed-string.js'

import React, { createElement as h } from 'react'
import diff_match_patch from 'diff-match-patch'
import htmlEscape from 'html-escape';

class UnifiedRow extends DiffRow {
  constructor(props) {
    super(props);
    this.state = this.computeHTML(props);
  }

  shouldComponentUpdate(nextProps, nextState) {
    // compare props in order of the cost of the comparison
  
    if (this.props.leftLineNum !== nextProps.leftLineNum) {
      return true;
    }
    
    if (this.props.rightLineNum !== nextProps.rightLineNum) {
      return true;
    }
    
    if (this.props.diffLineNum !== nextProps.diffLineNum) {
      return true;
    }
    
    var wasHighlighted = this.props.text instanceof AttributedString;
    var isHighlighted = nextProps.text instanceof AttributedString;
    
    if (wasHighlighted != isHighlighted) {
      return true;
    }
    
    if (this.props.text != nextProps.text) {
      return true;
    }
    
    if (this.props.oldText != nextProps.oldText) {
      return true;
    }
    
    return true;
  }
  
  componentWillReceiveProps(nextProps) {
    this.setState(Object.assign({}, this.state, this.computeHTML(nextProps)));
  }
  
  computeHTML(nextProps) {
    var html;
    var text = nextProps.text;
    var oldText = htmlEscape(nextProps.oldText||"");
    if (!(text instanceof AttributedString)) {
      text = html = htmlEscape(nextProps.text||"");
    }
    var myAstr = new AttributedString(text);
    
    if (nextProps.oldText) {
      var dmp = new diff_match_patch();
      var diff = dmp.diff_main(myAstr.string, oldText);
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
      
      html = myAstr.toHTML();
    }
    
    if (!html) {
      html = text?text.toHTML():"";
    }
    
    return {html};
  }

  render() {
    var gutterLeft = h('td', { className:'gutter gutter-left' }, 
      this.props.leftLineNum===undefined?"":(1+this.props.leftLineNum)
    );
    var gutterRight = h('td', { className:'gutter gutter-right' },
      this.props.rightLineNum===undefined?"":(1+this.props.rightLineNum)
    );
    
    var codeClasses = 'unified unified-codecol';
    if (this.props.mode === '-') {
      codeClasses += ' deleted-original';
    } else if (this.props.mode === '+') {
      codeClasses += ' inserted-new';
    }
    var codeCell = this.codeCell = h('td', { 
      ref: (td) => { this.codeCell = td },
      className: codeClasses,
      dangerouslySetInnerHTML:{__html:this.codeColContents(this.state.html)} 
    });
    
    var row = h('tr', {}, gutterLeft, gutterRight, codeCell);
    return row;
  }
  
  componentDidUpdate() {
    if (this.props.mode === '-') {
      this.miniMapRegions = [new MiniMap.Region(this.codeCell, 'red')];
    } else if (this.props.mode === '+') {
      this.miniMapRegions = [new MiniMap.Region(this.codeCell, 'green')];
    } else {
      this.miniMapRegions = [];
    }
  }
}

export default UnifiedRow;

