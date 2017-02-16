
import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'

import filterSelection from './filter-selection.js'
import MiniMap from './minimap.js'
import AttributedString from './attributed-string.js'
import DiffRow from './diff-row.js'
import SplitRow from './split-row.js'
import UnifiedRow from './unified-row.js'
import CommentRow from './comment-row.js'
import TrailerRow from './trailer-row.js'

import './xcode7.css'
import './index.css'

var HighlightWorker = require('worker!./highlight-worker.js');

function splitLines(text) {
  return text.split(/\r\n|\r|\n/);
}

function parseDiffLine(diffLine) {
  var m = diffLine.match(/@@ \-(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/);
  if (!m) {
    throw "Invalid diff line " + diffLine;
  }
  var leftStartLine, leftRun, rightStartLine, rightRun;
  if (m.length == 3) {
    leftStartLine = parseInt(m[1]);
    leftRun = 1;
    rightStartLine = parseInt(m[2]);
    rightRun = 1;
  } else {
    leftStartLine = parseInt(m[1]);
    leftRun = parseInt(m[2]);
    rightStartLine = parseInt(m[3]);
    rightRun = parseInt(m[4]);
  }
  return {leftStartLine, leftRun, rightStartLine, rightRun};
}

class App extends React.Component {
  constructor() {
    super();
    
    this.state = {
      diffMode: "unified",
      displayedDiffMode: "unified",
      leftHighlighted: null,
      rightHighlighted: null
    };
  }
  
  componentDidMount() {
    var table = this.table;
    
    table.addEventListener('mousedown', (event) => {
      this.updateSelectability(event);
    });
    
    table.addEventListener('copy', (event) => {
      this.copyCode(event);
    });
    
    table.addEventListener('dragstart', (event) => {
      this.dragCode(event);
    });
    
    window.addEventListener('resize', () => {
      this.sizeTable();
    });
    
    this.sizeTable();
  }
  
  componentDidUpdate() {
    // Update the minimap
    var codeAndComments = this.codeRows.concat(this.commentRows);
    var miniMapRegions = codeAndComments.reduce((accum, row) => {
      var regions = row.miniMapRegions;
      if (regions) {
        accum = accum.concat(regions);
      }
      return accum;
    }, []);
    this.props.miniMap.setRegions(miniMapRegions);
  }
      
  sizeTable() {
    this.table.style.minHeight = window.innerHeight + 'px';
  }
  
  calculateRowInfo(data, displayedDiffMode) {
    var leftLines = data.leftLines;
    var rightLines = data.rightLines;
    var diffLines = data.diffLines;
    
    // contain information needed to build SplitRow objects (indexes into left, right, and diff)
    var rowInfos = [];
    
    var leftIdx = 0;    // into leftLines
    var rightIdx = 0;   // into rightLines
    var diffIdx = 0;    // into diffLines
    var hunkQueue = 0;  // offset from end of rowInfos. implements a queue for lining up corresponding deletions and insertions

    // walk to the first hunk of the diff
    while (diffIdx < diffLines.length && !diffLines[diffIdx].startsWith("@@")) diffIdx++;
    var firstHunkIdx = diffIdx;
    
    // process the diff line at a time, building up rowInfos as we go.
    while (diffIdx < diffLines.length) {
      var diffLine = diffLines[diffIdx];
      if (diffLine.startsWith("@@")) {
        var {leftStartLine, leftRun, rightStartLine, rightRun} = parseDiffLine(diffLine);
        
        hunkQueue = 0; // reset +/- queue
        
        // include all lines up to the hunk as non-edited lines
        while (leftIdx+1 < leftStartLine && rightIdx+1 < rightStartLine) {
          rowInfos.push({leftIdx, rightIdx});
          leftIdx++; rightIdx++;
        }
      } else if (diffLine.startsWith(" ")) {
        hunkQueue = 0; // reset +/- queue
        
        // it's a context line
        rowInfos.push({leftIdx, rightIdx, diffIdx});
        leftIdx++;
        rightIdx++;
      } else if (diffLine.startsWith("-")) {
        // the line exists in left, but no longer in right
        rowInfos.push({leftIdx, diffIdx});
        leftIdx++;
        hunkQueue++;
      } else if (diffLine.startsWith("+")) {
        if (displayedDiffMode == 'split') {      
          if (hunkQueue) {
            // if we have an active hunk queue, hook this line in right up with the corresponding deleted line in left.
            var hunkIdx = rowInfos.length - hunkQueue;
            rowInfos[hunkIdx].rightIdx = rightIdx;
            rowInfos[hunkIdx].changed = true;
            hunkQueue--;
          } else {
            rowInfos.push({rightIdx, diffIdx});
          }
        } else /* unified */ {
          var nextRow = {rightIdx, diffIdx};
          if (hunkQueue) {
            // if we have an active hunk queue, note the context for intraline changes
            var hunkIdx = rowInfos.length - hunkQueue;
            rowInfos[hunkIdx].ctxRightIdx = rightIdx;
            nextRow.ctxLeftIdx = rowInfos[hunkIdx].leftIdx;
          }
          rowInfos.push(nextRow);
        }
        rightIdx++;
      } 
      
      diffIdx++;
    }
    
    // add the remaining rows from left and right
    while (leftIdx < leftLines.length && rightIdx < rightLines.length) {
      rowInfos.push({leftIdx, rightIdx});
      leftIdx++;
      rightIdx++;
    }
    while (leftIdx < leftLines.length) {
      rowInfos.push({leftIdx});
      leftIdx++;
    }
    while (rightIdx < rightLines.length) {
      rowInfos.push({rightIdx});
      rightIdx++;
    }
    
    return {rowInfos, firstHunkIdx};
  }
  
  updateDiff(filename, oldFile, newFile, diff, issueIdentifier, comments) {
    var stateUpdate = {};
    stateUpdate.filename = filename;
    stateUpdate.oldFile = oldFile;
    stateUpdate.newFile = newFile;
    stateUpdate.diff = diff;
    stateUpdate.comments = comments;
    stateUpdate.leftLines = splitLines(oldFile);
    stateUpdate.rightLines = splitLines(newFile);
    stateUpdate.diffLines = splitLines(diff);
  
    var displayedDiffMode = this.state.diffMode;
    if (oldFile.length == 0 || newFile.length == 0) {
      displayedDiffMode = "unified";
    }
    
    stateUpdate.displayedDiffMode = displayedDiffMode;
  
    // recalculate row text pointers
    stateUpdate = Object.assign({}, stateUpdate, this.calculateRowInfo(stateUpdate, displayedDiffMode));
    
    // recalculate syntax highlighting
    stateUpdate.leftHighlighted = null;
    stateUpdate.rightHighlighted = null;
    
    if (this.highlighter) {
      // clear old callback. we don't care anymore.
      delete this.highlighter.onmessage;
    }
    var hw = this.highlighter = new HighlightWorker;
    hw.onmessage = () => {
      var leftHighlighted = result.data.leftHighlighted;
      var rightHighlighted = result.data.rightHighlighted;
      
      delete this.highlighter;
      
      highlightFinished(leftHighlighted, rightHighlighted);
    };
    
    this.setState(Object.assign({}, this.state, stateUpdate));
  }
  
  highlightFinished(leftHighlighted, rightHighlighted) {
    this.setState(Object.assign({}, this.state, {
      leftHighlighted: leftHighlighted.map((l) => AttributedString.fromHTML(leftHighlighted)), 
      rightHighlighted: rightHighlighted.map((l) => AttributedString.fromHTML(rightHighlighted))
    }));
  }
  
  setDiffMode(newDiffMode) {
    if (!(newDiffMode == "split" || newDiffMode == "unified")) {
      throw "unknown mode " + newDiffMode;
    }
    if (newDiffMode != this.state.diffMode) {
      var stateUpdate = {};
      
      var displayedDiffMode = this.state.diffMode;
      if ((this.state.leftText||"").length == 0 || (this.state.rightText||"").length == 0) {
        displayedDiffMode = "unified";
      }    
      stateUpdate.displayedDiffMode = displayedDiffMode;
      
      if (displayedDiffMode != this.state.displayedDiffMode) {
        stateUpdate = Object.assign({}, stateUpdate, this.calculateRowInfo(this.state, displayedDiffMode));
      }
      
      this.setState(Object.assign({}, this.state, stateUpdate));
    }
  }
  
  render() {
    var leftLines = this.state.leftLines;
    var rightLines = this.state.rightLines;
    var diffLines = this.state.diffLines;
    var rowInfos = this.state.rowInfos || [];
    var leftHighlighted = this.state.leftHighlighted || [];
    var rightHighlighted = this.state.rightHighlighted || [];
    
    // create the actual row objects from the rowInfos
    this.codeRows = [];
    var codeRows = null;
    if (this.state.displayedDiffMode == 'split') {    
      codeRows = rowInfos.map((ri) => {
        return h(SplitRow, {
          ref: (e) => { if (e) { this.codeRows[i] = e; } },
          key: `SplitRow.${ri.leftIdx||-1}.${ri.rightIdx||-1}.${ri.diffIdx||-1}`,
          leftLine: ri.leftIdx===undefined?undefined:(leftHighlighted[ri.leftIdx]||leftLines[ri.leftIdx]),
          leftLineNum: ri.leftIdx,
          rightLine: ri.rightIdx==undefined?undefined:(rightHighlighted[ri.rightIdx]||rightLines[ri.rightIdx]),
          rightLineNum: ri.rightIdx,
          diffLineNum: ri.diffIdx,
          changed: ri.changed===true,
        });
      });
    } else /* unified */ {
      codeRows = rowInfos.map((ri, i) => {
        var text = "";
        var oldText = undefined;
        var mode = "";
        if (ri.leftIdx!==undefined && ri.rightIdx!==undefined) {
          // context line
          text = leftHighlighted[ri.leftIdx] || leftLines[ri.leftIdx];
        } else if (ri.leftIdx!==undefined) {
          text = leftHighlighted[ri.leftIdx] || leftLines[ri.leftIdx];
          mode = "-";
          if (ri.ctxRightIdx!==undefined) {
            oldText = rightLines[ri.ctxRightIdx];
          }
        } else if (ri.rightIdx!==undefined) {
          text = rightHighlighted[ri.rightIdx] || rightLines[ri.rightIdx];
          mode = "+";
          if (ri.ctxLeftIdx!==undefined) {
            oldText = leftLines[ri.ctxLeftIdx];
          }
        }
        
        return h(UnifiedRow, {
          ref: (e) => { if (e) { this.codeRows[i] = e; } },
          key: `UnifiedRow.${ri.leftIdx||-1}.${ri.rightIdx||-1}.${ri.diffIdx||-1}`,
          mode,
          text,
          oldText,
          leftLineNum:ri.leftIdx,
          rightLineNum:ri.rightIdx,
          diffLine:ri.diffIdx
        });
      });
    }
    
    // merge in comments
    var commentsLookup = []; // sparse array of diffIdx => [comments]
    var sortedComments = Array.from(this.state.comments||[]);
    sortedComments.sort((a, b) => {
      var d1 = new Date(a.created_at);
      var d2 = new Date(b.created_at);
      if (d1 < d2) {
        return -1;
      } else if (d1 == d2) {
        return 0;
      } else {
        return 1;
      }
    });
    var firstHunkIdx = this.state.firstHunkIdx;
    sortedComments.forEach((c) => {
      var i = c.position + firstHunkIdx;
      var a = commentsLookup[i];
      if (!a) a = commentsLookup[i] = [];
      a.push(c);
    });
    
    this.commentRows = [];
    var codeAndComments = [];
    var commentCols = this.state.displayedDiffMode == 'split' ? 4 : 3;
    var counter = { i: 0 };
    codeRows.forEach((code) => {
      codeAndComments.push(code);
      if (code.diffLine!==undefined) {
        var comments = commentsLookup[code.diffLine];
        if (comments) {
          var j = counter.i;
          codeAndComments.push(
            h(CommentRow, {
              ref: (e) => { if (e) { this.commentRows[j] = e; } },
              key:`CommentRow.${code.diffLine}`,
              comments, 
              issueIdentifier:this.state.issueIdentifier, 
              commentCols
            })
          );
          counter.i++;
        }
      }
    });
    
    var rows = Array.from(codeAndComments);
    
    // add a trailing row to take up space for short diffs
    var trailer = h(TrailerRow, {key:'trailer', mode:this.displayedDiffMode});
    rows.push(trailer);
  
    var tableStyle = {
      'width': '100%',
      'maxWidth': '100%'
    };
    var table = h('table', {ref:(t)=>{this.table=t}, className:'diff', style:tableStyle}, 
      h('tbody', {}, rows)
    );
    
    return table;
  }
  
  updateSelectability(e) {
    if (this.state.displayedDiffMode != 'split')
      return;
  
    var t = this.table;
    
    var x = e.target;
    var col = null;
    while (x) {
      if (x.classList && (x.classList.contains('right') || x.classList.contains('gutter-right'))) {
        col = 'right';
        break;
      } else if (x.classList && (x.classList.contains('left') || x.classList.contains('gutter-left'))) {
        col = 'left';
        break;
      }
      x = x.parentNode;
    }
    
    this.selectedColumn = col;
    if (col == 'left') {
      t.classList.remove('selecting-right');
      t.classList.add('selecting-left');
      this.selectedColumn = 'left';
    } else if (col == 'right') {
      t.classList.remove('selecting-left');
      t.classList.add('selecting-right');
      this.selectedColumn = 'right';
    }
  }
    
  getSelectedText() {
    var text = "";
    if (this.state.displayedDiffMode == 'split') {
      var col = this.selectedColumn || 'left';
      text = filterSelection(this.table, (node) => {
        if (node.tagName == 'TR' || node.tagName == 'TABLE') {
          return filterSelection.FILTER;
        } else if (node.tagName == 'TD') {
          if (node.classList.contains(col) && !node.classList.contains('spacer')) {
            return filterSelection.ACCEPT;
          } else {
            return filterSelection.PRUNE;
          }
        } else {
          return filterSelection.ACCEPT;
        }
      });
    } else /*unified mode*/ {
      var col = 'unified-codecol';
      
      // two cases:
      
      // 1. if it's just a single line snippet, just return that bare.
      
      // 2. if it's a multiline selection, return the whole line contents for each line 
      // that intersects the selection, including prefix " ", "+", "-"
      
      var sel = window.getSelection();
      
      var selectedRows = this.codeRows.filter((r) => sel.containsNode(r.node, true /* allow partial containment */));
      if (selectedRows <= 1) {
        var col = 'unified-codecol';
        text = filterSelection(this.table, (node) => {
          if (node.tagName == 'TR' || node.tagName == 'TABLE') {
            return filterSelection.FILTER;
          } else if (node.tagName == 'TD') {
            if (node.classList.contains(col) && !node.classList.contains('spacer')) {
              return filterSelection.ACCEPT;
            } else {
              return filterSelection.PRUNE;
            }
          } else {
            return filterSelection.ACCEPT;
          }
        });
      } else {
        text = selectedRows.reduce((t, row) => {
          var line = row.text;
          if (row.mode.length == 0) {
            return t + "  " + line + "\n";
          } else {
            return t + row.mode + " " + line + "\n";
          }
        }, "");
      }
    }
    
    // strip non-breaking spaces out of text
    text = text.replace(/\xA0/, '');
    return text;
  }
  
  copyCode(e) {
    var clipboardData = e.clipboardData;
    var text = this.getSelectedText();
    clipboardData.setData('text', text);
    e.preventDefault();
  }
  
  dragCode(e) {
    var text = this.getSelectedText();
    e.dataTransfer.setData('text', text);
  }
}

var miniMapWidth = 32;
var miniMap = new MiniMap(document.getElementById("body"), document.getElementById('app'), miniMapWidth);

var app = null;

window.updateDiff = function(filename, oldFile, newFile, patch, issueIdentifier, comments) {
  console.log("updateDiff", app);
  app.updateDiff(filename||"", oldFile||"", newFile||"", patch||"", issueIdentifier, comments||[]);
};

window.setDiffMode = function(newDiffMode) {
  app.setDiffMode(newDiffMode);
};

app = ReactDOM.render(
  h(App, {miniMap: miniMap}),
  document.getElementById('app'),
  function() { 
    window.loadComplete.postMessage({});
  }
);