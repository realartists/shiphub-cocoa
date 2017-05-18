import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import { splitLines, parseDiffLine } from 'util/diff-util.js'
import codeHighlighter from 'util/code-highlighter.js'
import AttributedString from 'util/attributed-string.js'
import diff_match_patch from 'diff-match-patch'

import './diff-hunk.css'

class DiffHunkHeader extends React.Component {
  render() {  
    var comps = [];
    
    comps.push(h('span', {key:'filename', className:'DiffHunkFilename'}, this.props.comment.path));
    
    if (this.props.canCollapse) {
      if (this.props.collapsed) {
        comps.push(h('a', {key: 'collapse', className:'DiffHunkCollapse',onClick:this.props.onCollapse}, 
          "show outdated ",
          h('i', {className:'fa fa-expand'})
        ));
      } else {
        comps.push(h('a', {key: 'expand', className:'DiffHunkCollapse',onClick:this.props.onCollapse}, 
          "hide outdated ",
          h('i', {className:'fa fa-compress'})
        ));
      }
    }
  
    return h('tr', {},
      h('th', {colSpan:3}, comps)
    );
  }
}

class DiffHunkLine extends React.Component {
  render() {
    var contents = this.props.lineHighlighted;
    var line = this.props.line;
    if (!contents.endsWith('\n')) { 
      contents = contents + '\n';
    }
    var className = 'unified-codecol';
    if (line.startsWith('+')) {
      contents = "+" + contents;
      className += ' inserted-new';
    } else if (line.startsWith('-')) {
      contents = "-" + contents;
      className += ' deleted-original';
    } else {
      contents = " " + contents;
    }
        
    var leftLineProps = {className:'gutter'};
    var rightLineProps = {className:'gutter'};
    
    if (Number.isInteger(this.props.leftLineNum) &&
        this.props.onLineClick) {
      leftLineProps.className += ' gutter-navigable';
      leftLineProps.onClick = (evt) => {
        this.props.onLineClick(this.props.leftLineNum, true /*left*/);
        evt.preventDefault();
      };
    }
    if (Number.isInteger(this.props.rightLineNum) &&
        this.props.onLineClick) {
      rightLineProps.className += ' gutter-navigable';
      rightLineProps.onClick = (evt) => {
        this.props.onLineClick(this.props.rightLineNum, false /*!left*/);
        evt.preventDefault();
      };
    }
    
    return h('tr', {className:'DiffHunkLine'},
      h('td', leftLineProps, this.props.leftLineNum || ""),
      h('td', rightLineProps, this.props.rightLineNum || ""),
      h('td', {className},
        h('pre', {dangerouslySetInnerHTML: { __html: contents } })
      )
    );
  }
}

class DiffHunkContextLine extends React.Component {
  render() {
    return h('tr', {className:'DiffHunkLine DiffHunkContextLine'},
      h('td', {className:'gutter'}, '...'),
      h('td', {className:'gutter'}, '...'),
      h('td', {className:'DiffHunkContextCodeLine'}, 
        h('pre', {}, " " + this.props.ctxLine)
      )
    );
  }
}

class DiffHunk extends React.Component {
  shouldComponentUpdate(nextProps, nextState) {
    return nextProps.comment.diff_hunk != this.props.comment.diff_hunk
        || nextProps.comment.path != this.props.comment.path
        || nextProps.collapsed != this.props.collapsed
        || nextProps.canCollapse != this.props.canCollapse
  }
  
  render() {
    var onLineClick = this.props.onLineClick;
    var canCollapse = this.props.canCollapse;
    var collapsed = this.props.collapsed;
    var onCollapse = this.props.onCollapse;
  
    var diffLines = splitLines(this.props.comment.diff_hunk);
    
    var diffIdx = 0;    // into lines
    while (diffIdx < diffLines.length && !diffLines[diffIdx].startsWith("@@")) diffIdx++;
    
    if (diffIdx >= diffLines.length) {
      return h('div', {className:'diffHunkEmpty'});
    }
    
    var ctxLine = diffLines[diffIdx];
    var {leftStartLine, leftRun, rightStartLine, rightRun} = parseDiffLine(diffLines[diffIdx]);
    
    var lineInfo = [];
    var leftLineNum = leftStartLine;
    var rightLineNum = rightStartLine;
    var hunkQueue = 0; // offset from end of lineInfo. implements a queue for lining up corresponding deletions and insertions
    
    var leftCode = [];
    var rightCode = [];
    
    var leftIdx = 0;
    var rightIdx = 0;
    
    while (diffIdx < diffLines.length) {
      var line = diffLines[diffIdx];
      if (line.startsWith(" ")) {
        hunkQueue = 0; // reset +/- queue
        
        lineInfo.push({line, leftLineNum, rightLineNum, leftIdx, rightIdx});
        leftCode.push(line.substr(1));
        rightCode.push(line.substr(1));
        leftLineNum++;
        rightLineNum++;
        leftIdx++;
        rightIdx++;
      } else if (line.startsWith("-")) {
        lineInfo.push({line, leftLineNum, leftIdx});
        leftCode.push(line.substr(1));
        leftLineNum++;
        leftIdx++;
        hunkQueue++;
      } else if (line.startsWith("+")) {
        var next = {line, rightLineNum, rightIdx};
        if (hunkQueue) {
          var hunkIdx = lineInfo.length - hunkQueue;
          lineInfo[hunkIdx].ctxRightIdx = rightIdx;
          next.ctxLeftIdx = lineInfo[hunkIdx].leftIdx;
        }
        lineInfo.push(next);
        rightCode.push(line.substr(1));
        rightLineNum++;
        rightIdx++;
      }
      diffIdx++;
    }
    
    // syntax highlight the code we have
    leftCode = leftCode.join("\n");
    rightCode = rightCode.join("\n");
        
    var { leftHighlighted, rightHighlighted } = codeHighlighter({leftText: leftCode, rightText: rightCode, filename: this.props.comment.path});
        
    for (var i = 0; i < lineInfo.length; i++) {
      var ri = lineInfo[i];
      var code = "";
      var ctx = undefined;
      if (ri.leftIdx!==undefined) {
        code = leftHighlighted[ri.leftIdx];
        if (ri.ctxRightIdx) {
          ctx = rightHighlighted[ri.ctxRightIdx];
        }
      } else if (ri.rightIdx!==undefined) {
        code = rightHighlighted[ri.rightIdx];
        if (ri.ctxLeftIdx) {
          ctx = leftHighlighted[ri.ctxLeftIdx];
        }
      }
      
      if (ctx) {
        var myAstr = AttributedString.fromHTML(code);
        var ctxAstr = AttributedString.fromHTML(ctx);
      
        var dmp = new diff_match_patch();
        var diff = dmp.diff_main(myAstr.string, ctxAstr.string);
        dmp.diff_cleanupSemantic(diff);
      
        if (diff.length > 1) {
          var leftIdx = 0, rightIdx = 0;
          for (var j = 0; j < diff.length; j++) {
            var change = diff[j];
            var length = change[1].length;
            if (change[0] == -1) {
              myAstr.addAttributes(new AttributedString.Range(leftIdx, length), ["char-changed"]);
            }
            leftIdx += length;
          }
        }
      
        ri.lineHighlighted = myAstr.toHTML();
      } else {
        ri.lineHighlighted = code;
      }
    }
    
    // just keep the last 4 lines of lineInfo
    var truncated = false;
    if (lineInfo.length > 4) {
      lineInfo.splice(0, lineInfo.length - 4);
      truncated = true;
    }    
    var body = lineInfo.map((li, i) => h(DiffHunkLine, Object.assign({}, {key:""+i, onLineClick}, li)));

    if (!truncated) {
      body.splice(0, 0, h(DiffHunkContextLine, {key:'ctx', ctxLine}))
    }
    
    return h('table', {className:'diffHunk'},
      h('thead', {}, 
        h(DiffHunkHeader, {
          comment:this.props.comment,
          canCollapse,
          collapsed,
          onCollapse
        })
      ),
      h('tbody', {}, collapsed ? [] : body)
    ); 
  }
}

export default DiffHunk;
