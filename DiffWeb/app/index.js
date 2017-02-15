
import h from 'hyperscript'
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

class App {
  constructor(root) {  
    var minimapWidth = 32;
    
    var style = {
      'width': '100%',
      'max-width': '100%'
    };
    this.table = h('table', {className:"diff", style:style});
    
    this.diffMode = "unified";
    
    this.table.addEventListener('mousedown', (event) => {
      this.updateSelectability(event);
    });
    
    this.table.addEventListener('copy', (event) => {
      this.copyCode(event);
    });
    
    this.table.addEventListener('dragstart', (event) => {
      this.dragCode(event);
    });
    
    window.addEventListener('resize', () => {
      this.sizeTable();
    });
    
    root.appendChild(this.table);
    
    this.miniMap = new MiniMap(root, this.table, minimapWidth);
    this.sizeTable();
  }
  
  sizeTable() {
    this.table.style.minHeight = window.innerHeight + 'px';
  }
  
  setDiffMode(newMode) {
    if (!(newMode == "split" || newMode == "unified")) {
      throw "unknown mode " + newMode;
    }
    if (this.diffMode != newMode) {
      this.diffMode = newMode;
      if (this.filename) {
        this.updateDiff(this.filename, this.leftText, this.rightText, this.uDiff);
      }
    }
  }
  
  build() {
    var leftLines = splitLines(this.leftText);
    var rightLines = splitLines(this.rightText);
    var diffLines = splitLines(this.uDiff);
    
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
        if (this.mode == 'split') {      
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
    
    // create the actual row objects from the rowInfos
    var codeRows = null;
    if (this.mode == 'split') {    
      codeRows = rowInfos.map((ri) => {
        return new SplitRow(
          ri.leftIdx===undefined?undefined:leftLines[ri.leftIdx],
          ri.leftIdx,
          ri.rightIdx==undefined?undefined:rightLines[ri.rightIdx],
          ri.rightIdx,
          ri.diffIdx,
          ri.changed===true
        );
      });
    } else /* unified */ {
      codeRows = rowInfos.map((ri) => {
        var text = "";
        var oldText = undefined;
        var mode = "";
        if (ri.leftIdx!==undefined && ri.rightIdx!==undefined) {
          // context line
          text = leftLines[ri.leftIdx];
        } else if (ri.leftIdx!==undefined) {
          text = leftLines[ri.leftIdx];
          mode = "-";
          if (ri.ctxRightIdx!==undefined) {
            oldText = rightLines[ri.ctxRightIdx];
          }
        } else if (ri.rightIdx!==undefined) {
          text = rightLines[ri.rightIdx];
          mode = "+";
          if (ri.ctxLeftIdx!==undefined) {
            oldText = leftLines[ri.ctxLeftIdx];
          }
        }
      
        return new UnifiedRow(
          mode,
          text,
          oldText,
          ri.leftIdx,
          ri.rightIdx,
          ri.diffIdx
        );
      });
    }
    this.codeRows = codeRows;
    
    // merge in comments
    var commentsLookup = []; // sparse array of diffIdx => [comments]
    this.comments.sort((a, b) => {
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
    this.comments.forEach((c) => {
      var i = c.position + firstHunkIdx;
      var a = commentsLookup[i];
      if (!a) a = commentsLookup[i] = [];
      a.push(c);
    });
    
    var codeAndComments = [];
    var commentCols = this.mode == 'split' ? 4 : 3;
    codeRows.forEach((code) => {
      codeAndComments.push(code);
      if (code.diffLine!==undefined) {
        var comments = commentsLookup[code.diffLine];
        if (comments) {
          codeAndComments.push(...comments.map((c) => new CommentRow(c, this.issueIdentifier, commentCols)));
        }
      }
    });
    
    var rows = Array.from(codeAndComments);
    
    // add a trailing row to take up space for short diffs
    var trailer = new TrailerRow(this.mode);
    rows.push(trailer);
    
    var rowNodes = rows.map((r) => r.node);
    
    // Write out DOM
    this.table.innerHTML = '';
    rowNodes.forEach((rn) => {
      this.table.appendChild(rn);
    });
    
    // Update the minimap
    var miniMapRegions = codeAndComments.reduce((accum, row) => {
      if (row.miniMapRegions) {
        accum = accum.concat(row.miniMapRegions);
      }
      return accum;
    }, []);
    this.miniMap.setRegions(miniMapRegions);
    
    // Highlighting
    var hw = new HighlightWorker;
    if (this.mode == 'split') {
      hw.onmessage = function(result) {
        var leftHighlighted = result.data.leftHighlighted;
        var rightHighlighted = result.data.rightHighlighted;
      
        rowInfos.forEach((ri, i) => {
          var row = codeRows[i];
          var left = ri.leftIdx===undefined?undefined:leftHighlighted[ri.leftIdx];
          var right = ri.rightIdx===undefined?undefined:rightHighlighted[ri.rightIdx];
          row.updateHighlight(left, right);
        });
      };
    } else /* unified */ {
      hw.onmessage = function(result) {
        var leftHighlighted = result.data.leftHighlighted;
        var rightHighlighted = result.data.rightHighlighted;
      
        rowInfos.forEach((ri, i) => {
          var row = codeRows[i];
        
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
        
          row.updateHighlight(code, ctx);
        });
      };
    }
    hw.postMessage({filename:this.filename, leftText:this.leftText, rightText:this.rightText});
  }
  
  updateDiff(filename, leftText, rightText, uDiff, issueIdentifier, comments) {
    // note: the left is considered the 'original' (what's in master)
    // and the right is considered the 'modified' (result of original + patch)
    
    var displayedDiffMode = this.diffMode;
    if (leftText.length == 0 || rightText.length == 0) {
      displayedDiffMode = "unified";
    }
    
    this.displayedDiffMode = displayedDiffMode;
    
    this.filename = filename;
    this.leftText = leftText;
    this.rightText = rightText;
    this.uDiff = uDiff;
    this.issueIdentifier = issueIdentifier;
    this.comments = comments;
  
    this.build();
  }
  
  updateSelectability(e) {
    if (this.displayedDiffMode != 'split')
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
    if (this.displayedDiffMode == 'split') {
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

var app = new App(document.getElementById('app'));

window.updateDiff = function(filename, oldFile, newFile, patch, issueIdentifier, comments) {
  app.updateDiff(filename||"", oldFile||"", newFile||"", patch||"", issueIdentifier, comments||[]);
};

window.setDiffMode = function(newDiffMode) {
  app.setDiffMode(newDiffMode);
};

window.loadComplete.postMessage({});

