import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'
import AttributedString from './attributed-string.js'

import React, { createElement as h } from 'react'
import diff_match_patch from 'diff-match-patch'
import htmlEscape from 'html-escape';

class SplitRow extends DiffRow {
  constructor(props) {
    super(props);
    this.state = computeHTML(props);
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
    
    if (this.props.changed !== nextProps.changed) {
      return true;
    }
  
    var wasLeftHighlighted = this.props.leftLine instanceof AttributedString;
    var isLeftHighlighted = nextProps.leftLine instanceof AttributedString;
    
    if (wasLeftHighlighted != isLeftHighlighted) {
      return true;
    }
    
    var wasRightHighlighted = this.props.rightLine instanceof AttributedString;
    var isRightHighlighted = nextProps.rightLine instanceof AttributedString;
    
    if (wasRightHighlighted != isRightHighlighted) {
      return true;
    }
    
    if (this.props.leftLine !== nextProps.leftLine) {
      return true;
    }
    
    if (this.props.rightLine !== nextProps.rightLine) {
      return true;
    }
    
    return false;
  }
  
  componentWillReceiveProps(nextProps) {
    this.setState(Object.assign({}, this.state, this.computeHTML(nextProps)));
  }
  
  computeHTML(nextProps) {
    var leftHTML;
    var rightHTML;
    
    if (nextProps.changed) {
      var leftAstr;
      var rightAstr;
      
      if (nextProps.leftLine instanceof AttributedString) {
        leftAstr = new AttributedString(nextProps.leftLine);
      } else {
        leftAstr = new AttributedString(htmlEscape(nextProps.leftLine||""));
      }
      
      if (nextProps.rightLine instanceof AttributedString) {
        rightAstr = new AttributedString(nextProps.rightLine);
      } else {
        rightAstr = new AttributedString(htmlEscape(nextProps.rightLine||""));
      }
      
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
      
      leftHTML = leftAstr.toHTML();
      rightHTML = rightAstr.toHTML();
    }
    
    return {leftHTML, rightHTML};
  }
  
  componentDidUpdate() {
    if (this.leftLine === undefined) {
      this.miniMapRegions = [new MiniMap.Region(this.rightCell, 'green')];
    } else if (this.rightLine == undefined) {
      this.miniMapRegions = [new MiniMap.Region(this.leftCell, 'red')];
    } else if (changed) {
      this.miniMapRegions = [
        new MiniMap.Region(this.row, "blue")
      ];
    } else {
      this.miniMapRegions = [];
    }
  }
  
  render() {
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
    
    var left = this.left = h('td', {
      ref:(td)=>{this.leftCell=td}, 
      className:leftClasses, 
      dangerouslySetInnerHTML:{__html:this.codeColContents(this.state.leftHTML)}
    });
    
    var right = this.right = h('td', {
      ref:(td)=>{this.rightCell=td}, 
      className:rightClasses, 
      dangerouslySetInnerHTML:{__html:this.codeColContents(this.state.rightHTML)}
    });
    
    var row = h('tr', {ref:(tr)=>{this.row=tr}}, gutterLeft, left, gutterRight, right);
    return row;
  }
}

export default SplitRow;

