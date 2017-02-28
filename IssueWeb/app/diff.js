
import h from 'hyperscript'
import filterSelection from 'util/filter-selection.js'
import MiniMap from 'components/diff/minimap.js'
import AttributedString from 'util/attributed-string.js'
import DiffRow from 'components/diff/diff-row.js'
import SplitRow from 'components/diff/split-row.js'
import UnifiedRow from 'components/diff/unified-row.js'
import CommentRow from 'components/diff/comment-row.js'
import TrailerRow from 'components/diff/trailer-row.js'

import './xcode7.css'
import './diff.css'

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
    // Model state
    this.filename = ""; // used primarily for syntax highlighting
    this.path = ""; // full path name of the new file
    this.leftText = ""; // the full left file as a string
    this.rightText = ""; // the full right file as a string
    this.diff = ""; // the text of the patch as a unified diff
    this.leftLines = []; // lines in leftText
    this.rightLines = []; // lines in rightText
    this.diffLines = []; // lines in diff
    this.comments = []; // Array of PRComments
    this.inReview = false; // Whether or not comments are being buffered to submit in one go
    this.leftHighlight = null; // syntax highlighting
    this.rightHighlight = null;
    this.rowInfos = []; // Array of pointers into left, right, and diff, plus context info
    
    // View state
    this.codeRows = []; // Array of SplitRow|UnifiedRow
    this.commentRows = []; // Array of CommentRow
    
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
    
    var minimapWidth = 32;
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
      this.recreateCodeRows();
    }
  }
  
  recreateCodeRows() {
    var displayedDiffMode = this.diffMode;
    if (this.leftText.length == 0 || this.rightText.length == 0) {
      displayedDiffMode = "unified";
    }
    
    this.displayedDiffMode = displayedDiffMode;
    
    var leftLines = this.leftLines;
    var rightLines = this.rightLines;    
    var diffLines = this.diffLines;
  
    // contain indexes into left, right, and diff, as well as some additional context
    var rowInfos = this.rowInfos = [];

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
        if (this.displayedDiffMode == 'split') {      
          if (hunkQueue) {
            // if we have an active hunk queue, hook this line in right up with the corresponding deleted line in left.
            var hunkIdx = rowInfos.length - hunkQueue;
            rowInfos[hunkIdx].rightIdx = rightIdx;
            rowInfos[hunkIdx].rightDiffIdx = diffIdx;
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
    if (this.displayedDiffMode == 'split') {    
      codeRows = rowInfos.map((ri) => {
        return new SplitRow(
          ri.leftIdx===undefined?undefined:leftLines[ri.leftIdx],
          ri.leftIdx,
          ri.rightIdx==undefined?undefined:rightLines[ri.rightIdx],
          ri.rightIdx,
          ri.diffIdx,
          ri.rightDiffIdx,
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
    
    // mix in highlighting if we already have it computed
    if (this.leftHighlighted || this.rightHighlighted) {
      this.applyHighlightingToCodeRows();
    }
    
    var rows = Array.from(codeRows);
    
    // add a trailing row to take up space for short diffs
    var trailer = new TrailerRow(this.displayedDiffMode);    
    rows.push(trailer);
    
    var rowNodes = rows.map((r) => r.node);
    
    // Write out DOM
    this.table.innerHTML = '';
    rowNodes.forEach((rn) => {
      this.table.appendChild(rn);
    });
    
    this.positionComments();
    
    this.updateMiniMapRegions();
  }
  
  updateMiniMapRegions() {
    // Update the minimap
    var allRows = this.codeRows.concat(this.commentRows);
    var miniMapRegions = allRows.reduce((accum, row) => {
      if (row.miniMapRegions) {
        accum = accum.concat(row.miniMapRegions);
      }
      return accum;
    }, []);
    this.miniMap.setRegions(miniMapRegions);
  }
    
  highlightDidFinish(leftHighlighted, rightHighlighted) {
    this.leftHighlighted = leftHighlighted;
    this.rightHighlighted = rightHighlighted;
    
    this.applyHighlightingToCodeRows();
  }
  
  applyHighlightingToCodeRows() {
    var codeRows = this.codeRows;
    var leftHighlighted = this.leftHighlighted;
    var rightHighlighted = this.rightHighlighted;
    
    if (this.displayedDiffMode == 'split') {
      this.rowInfos.forEach((ri, i) => {
        var row = codeRows[i];
        var left = ri.leftIdx===undefined?undefined:leftHighlighted[ri.leftIdx];
        var right = ri.rightIdx===undefined?undefined:rightHighlighted[ri.rightIdx];
        row.updateHighlight(left, right);
      });
    } else /* unified */ {
      this.rowInfos.forEach((ri, i) => {
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
    }
  }
  
  doHighlight() {
    // Highlighting
    if (this.highlightWorker) {
      // cancel existing highlightWorker
      this.highlightWorker.onmessage = null;
      delete this.highlightWorker;
    }
    var hw = this.highlightWorker = new HighlightWorker;
    hw.onmessage = (result) => {
      this.leftHighlighted = result.data.leftHighlighted;
      this.rightHighlighted = result.data.rightHighlighted;
      
      this.applyHighlightingToCodeRows();
    };
    hw.postMessage({
      filename:this.filename, 
      leftText:this.leftText, 
      rightText:this.rightText
    });
  }
  
  updateDiff(diffState) {
    Object.assign(this, diffState);
    
    this.leftLines = splitLines(this.leftText);
    this.rightLines = splitLines(this.rightText);
    this.diffLines = splitLines(this.diff);
    
    this.leftHighlighted = null;
    this.rightHighlighted = null;
    this.recreateCodeRows();
    this.doHighlight();
  }
  
  positionComments() {
    if (this.commentRows.length == 0) return;
  
    // for every row in commentRows, calculate the item in codeRows that should precede it
    var diffIdxToRow = this.codeRows.reduce((accum, row) => {
      if (row.diffIdx !== undefined) {
        accum[row.diffIdx] = row;
      }
      if (row.rightDiffIdx !== undefined) {
        accum[row.rightDiffIdx] = row;
      }
      return accum;
    }, {});
    
    // manipulate the DOM to reflect the ordering computed above
    var colspan = this.displayedDiffMode == 'split' ? 4 : 3;
    this.commentRows.forEach((cr) => {
      var node = cr.node;
      var currentPrev = node.previousSibling;
      var desiredPrev = diffIdxToRow[cr.diffIdx];
      if (!desiredPrev) {
        throw "Could not find code row for diff index " + cr.diffIdx;
      }
      desiredPrev = desiredPrev.node;
      if (currentPrev != desiredPrev) {
        this.table.insertBefore(node, desiredPrev.nextSibling);
      }
      
      cr.colspan = colspan;
    });
  }
  
  saveDraftComments() {
    // TODO: Implement
  }
  
  clearComments() {
    this.commentRows.forEach((c) => {
      c.node.remove();
    });
    this.commentRows = [];
  }
  
  updateComments(comments) {
    this.comments = comments;
    
    // augment each comment with its diffIdx (position offset by first hunk in diffLines)
    
    // find the first hunk in our diff
    var diffIdx = 0;
    var diffLines = this.diffLines;
    while (diffIdx < diffLines.length && !diffLines[diffIdx].startsWith("@@")) diffIdx++;
    
    comments.forEach((c) => {
      c.diffIdx = diffIdx + c.position; // position is relative to the first hunk in diffLines
    });
    
    // take stock of existing commentRows
    var diffIdxToCommentRow = this.commentRows.reduce((accum, row) => {
      accum[row.diffIdx] = row;
      return accum;
    }, {});
    
    // group new comments by diffIdx
    var cmpDiffIdx = (a, b) => {
      if (a.diffIdx < b.diffIdx) return -1;
      else if (a.diffIdx == b.diffIdx) return 0;
      else return 1;
    };
    
    comments.sort(cmpDiffIdx);
    
    var commentGroups = [];
    comments.forEach((c, i) => {
      if (commentGroups.length == 0 || commentGroups[commentGroups.length-1][0].diffIdx != c.diffIdx) {
        commentGroups.push([c]);
      } else {
        commentGroups[commentGroups.length-1].push(c);
      }
    });
    
    // update existing CommentRows and create new CommentRows as needed
    var nextRows = new Set();
    commentGroups.forEach((cg) => {
      var diffIdx = cg[0].diffIdx;
      var commentRow = diffIdxToCommentRow[diffIdx];
      if (!commentRow) {
        commentRow = new CommentRow(this.issueIdentifier);
        diffIdxToCommentRow[diffIdx] = commentRow;
      }
      commentRow.comments = cg;
      nextRows.add(commentRow);
    });
    
    // remove any CommentRows from the DOM that aren't in nextRows
    this.commentRows.forEach((cr) => {
      if (!nextRows.has(cr)) {
        cr.node.remove();
      }
    });
    
    var commentRows = Array.from(nextRows);
    commentRows.sort(cmpDiffIdx);
    
    this.commentRows = commentRows;

    this.positionComments();
    this.updateMiniMapRegions();
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
  
  // --- Comment handling ---
  
  /*
    comment - { 
      body: markdown content
      diffIdx: index in this file's diff - callee will convert this to position
    }
    OR
    comment - {
      body: markdown content
      in_reply_to: id of comment to reply to
    } 
    options - {
      start_review: boolean
    }
  */
  addComment(comment, options) {
    
  }
  
}

var app = null;

/*
diffState - {
  filename: string, used mainly for syntax highlighting
  path: string, used for creating comments
  leftText: string, original contents of file
  rightText: string, new contents of file
  diff: string, text of the patch as a unified diff
  comments: array of PRComments
  issueIdentifier: string, repo_owner/repo_name#number
  inReview: boolean, whether or not comments are being buffered to submit in one go with a review
}
*/
window.updateDiff = function(diffState) {
  app.saveDraftComments();
  app.clearComments();
  app.updateDiff(diffState)
  app.updateComments(diffState.comments);
};

window.setDiffMode = function(newDiffMode) {
  app.setDiffMode(newDiffMode);
};

window.onload = () => {
  app = new App(document.getElementById('app'));
  window.loadComplete.postMessage({});
}


