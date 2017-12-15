import 'diff.css'
import 'font-awesome/css/font-awesome.css'
import '../markdown-mark/style.css'
import 'codemirror/lib/codemirror.css'
import 'components/comment/comment.css'
import 'components/diff/comment.css'
import 'ctheme.js'

import 'util/crash-reporter.js'

import h from 'util/make-element.js'
import filterSelection from 'util/filter-selection.js'
import MiniMap from 'components/diff/minimap.js'
import AttributedString from 'util/attributed-string.js'
import DiffRow from 'components/diff/diff-row.js'
import SplitRow from 'components/diff/split-row.js'
import UnifiedRow from 'components/diff/unified-row.js'
import CommentRow from 'components/diff/comment-row.js'
import TrailerRow from 'components/diff/trailer-row.js'
import { UnifiedPlaceholderRow, SplitPlaceholderRow } from 'components/diff/placeholder-row.js'
import ghost from 'util/ghost.js'
import escapeStringForRegex from 'util/escape-regex.js'
import 'util/media-reloader.js'
import { splitLines, parseDiffLine } from 'util/diff-util.js'

var HighlightWorker = require('worker!./highlight-worker.js');

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
    this.diffIdxMapping = null; // null or array, mapping lines in diff to ultimate span diff where comments are defined
    this.comments = []; // Array of PRComments
    this.inReview = false; // Whether or not comments are being buffered to submit in one go
    this.leftHighlight = null; // syntax highlighting
    this.rightHighlight = null;
    this.rowInfos = []; // Array of pointers into left, right, and diff, plus context info
    this.headSha = ""; // commit id of head of PR branch
    this.baseSha = ""; // commit id of base of PR branch
    this.mentionable = []; // Array of Account objects for users who can be @mentioned
    this.me = ghost; // user object (used for adding new comments)
    this.repo = null; // repo owning the viewed pull request
    this.colorblind = false; // whether or not we need to use more than just color to differentiate changes lines
    this.receivedFirstUpdate = false; // whether updateDiff has been called yet
    this.placeholders = []; // Array of PlaceholderRows
    this.simplified = {}; // tracks simplified DOM state
    
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
  
  updateMiniMap() {
    this.miniMap.setNeedsDisplay();
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
    this.unsimplify({quick:true});
  
    var displayedDiffMode = this.diffMode;
    if (this.leftText.length == 0 || this.rightText.length == 0) {
      displayedDiffMode = "unified";
    }
    
    var diffIdxMapping = this.diffIdxMapping;
    var mapDiffIdx = (idx) => {
      if (diffIdxMapping) {
        var x = diffIdxMapping[idx];
        if (x >= 0) return x;
        else return undefined;
      } else {
        return idx;
      }
    };

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
    var hunkNum = -1;  // which hunk we're on

    // walk to the first hunk of the diff
    while (diffIdx < diffLines.length && !diffLines[diffIdx].startsWith("@@")) diffIdx++;
    var firstHunkIdx = diffIdx;
    
    // process the diff line at a time, building up rowInfos as we go.
    while (diffIdx < diffLines.length) {
      var diffLine = diffLines[diffIdx];
      if (diffLine.startsWith("@@")) {
        var {leftStartLine, leftRun, rightStartLine, rightRun} = parseDiffLine(diffLine);
        
        hunkNum++;
        
        hunkQueue = 0; // reset +/- queue
        
        // include all lines up to the hunk as non-edited lines
        while (leftIdx+1 < leftStartLine && rightIdx+1 < rightStartLine) {
          rowInfos.push({leftIdx, rightIdx});
          leftIdx++; rightIdx++;
        }
      } else if (diffLine.startsWith(" ")) {
        hunkQueue = 0; // reset +/- queue
        
        // it's a context line
        rowInfos.push({leftIdx, rightIdx, diffIdx:mapDiffIdx(diffIdx), hunkNum});
        leftIdx++;
        rightIdx++;
      } else if (diffLine.startsWith("-")) {
        // the line exists in left, but no longer in right
        rowInfos.push({leftIdx, diffIdx:mapDiffIdx(diffIdx), hunkNum});
        leftIdx++;
        hunkQueue++;
      } else if (diffLine.startsWith("+")) {
        if (this.displayedDiffMode == 'split') {      
          if (hunkQueue) {
            // if we have an active hunk queue, hook this line in right up with the corresponding deleted line in left.
            var hunkIdx = rowInfos.length - hunkQueue;
            rowInfos[hunkIdx].rightIdx = rightIdx;
            rowInfos[hunkIdx].rightDiffIdx = mapDiffIdx(diffIdx);
            rowInfos[hunkIdx].changed = true;
            hunkQueue--;
          } else {
            rowInfos.push({rightIdx, diffIdx:mapDiffIdx(diffIdx), hunkNum});
          }
        } else /* unified */ {
          var nextRow = {rightIdx, diffIdx:mapDiffIdx(diffIdx), hunkNum};
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
          ri.hunkNum,
          ri.rightDiffIdx,
          ri.changed===true,
          this.colorblind,
          this.insertComment.bind(this)
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
          ri.diffIdx,
          ri.hunkNum,
          this.colorblind,
          this.insertComment.bind(this)
        );
      });
    }
    this.codeRows = codeRows;
    
    // mix in highlighting if we already have it computed
    if (this.leftHighlighted || this.rightHighlighted) {
      this.applyHighlightingToCodeRows();
    }
    
    var rows = this.buildPlaceholders(codeRows);
    
    // add a trailing row to take up space for short diffs
    var trailer = new TrailerRow(this.displayedDiffMode, this.colorblind);    
    rows.push(trailer);
    
    // Write out DOM
    this.table.innerHTML = '';
    rows.forEach(r => this.table.appendChild(r.node));
    
    this.positionComments();
    
    this.updateMiniMapRegions();
  }
  
  buildPlaceholders(rows) {
    if (rows.length < 1000) {
      return Array.from(rows);
    }
    
    var margin = 10 + Math.trunc(window.screen.height / parseFloat(document.documentElement.style.getPropertyValue("--ctheme-line-height") || "13"));
    
    var placeholderType = this.diffMode == 'unified' ? UnifiedPlaceholderRow : SplitPlaceholderRow;
    var placeholders = [];
    var newRows = [];
    var ph = null;
    var i = 0;
    while (i < rows.length) {
      if (rows[i].diffIdx === undefined && rows[i].rightDiffIdx === undefined) {
        // see if we can find a run of at least 3x margin
        var j;
        for (j = i; j < rows.length && rows[j].diffIdx === undefined && rows[j].rightDiffIdx === undefined; j++);
        
        if ((j - i) > (3 * margin)) {
          // we can make a placeholder!
          ph = new placeholderType(this.colorblind);
          placeholders.push(ph);
          for (var k = i; k < i+margin; k++) {
            newRows.push(rows[k]);
          }
          newRows.push(ph);
          for (var k = i+margin; k < j-margin; k++) {
            ph.addRow(rows[k]);
            newRows.push(rows[k]);
          }
          for (var k = j-margin; k < j; k++) {
            newRows.push(rows[k]);
          }
        } else {
          for (var k = i; k < j; k++) {
            newRows.push(rows[k]);
          }
        }
        i = j;
      } else {
        newRows.push(rows[i]);
        i++;
      }
    }
    
    for (var i = 0; i < placeholders.length; i++) {
      var ph = placeholders[i];
      ph.freeze();
      ph.node.style.display = 'none';
    }
    
    this.placeholders = placeholders;
    return newRows;
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
    this.receivedFirstUpdate = true;
  
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
    
    this.unsimplify({now:true});
  
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
    var colspan;
    if (this.displayedDiffMode == 'split') {
      if (this.colorblind) {
        colspan = 6;
      } else {
        colspan = 4;
      }
    } else {
      if (this.colorblind) {
        colspan = 4;
      } else {
        colspan = 3;
      }
    }
    this.commentRows.forEach((cr) => {
      var node = cr.node;
      var currentPrev = node.previousSibling;
      var desiredPrev = diffIdxToRow[cr.diffIdx];
      if (!desiredPrev) {
        return; // can't place the comment anywhere
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
  
  firstHunkDiffIdx() {
    var diffIdx = 0;
    var diffLines = this.diffLines;
    while (diffIdx < diffLines.length && !diffLines[diffIdx].startsWith("@@")) diffIdx++;
    
    return diffIdx;
  }
  
  updateComments(comments, inReview) {
    if (!this.receivedFirstUpdate) {
      console.log("updateComments called early");
      return;
    }
  
    this.inReview = inReview;
    this.comments = comments;
    var existingRows = this.commentRows;
    
    // augment each comment with its diffIdx (position offset by first hunk in diffLines)
    
    // find the first hunk in our diff
    var diffIdx = this.firstHunkDiffIdx();
    
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
        commentRow = new CommentRow(this.issueIdentifier, this.me, this.repo, this.mentionable, this);
        diffIdxToCommentRow[diffIdx] = commentRow;
      }
      commentRow.comments = cg;
      nextRows.add(commentRow);
    });
    
    // add any CommentRows in that have pending comments
    existingRows.forEach((cr) => {
      if (cr.hasNewComment && !nextRows.has(cr)) {
        cr.comments = [];
        nextRows.add(cr);
      }
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
    var sel = window.getSelection();
    if (sel.rangeCount == 0) {
      return "";
    }
    // find out if the selection is fully within a comment
    // if so, return just it
    var startRange = sel.getRangeAt(0);
    var endRange = sel.getRangeAt(sel.rangeCount-1);
    var containsComment = this.commentRows.find((r) => {
      var hasStart = r.node.contains(startRange.startContainer);
      var hasEnd = r.node.contains(endRange.endContainer);
      return hasStart && hasEnd;
    });
    if (containsComment) {
      return sel.toString();
    }
    
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
      
      var selectedRows = this.codeRows.filter((r) => sel.containsNode(r.node, true /* allow partial containment */));
      if (selectedRows.length <= 1) {
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
    // contains comment
    var containsComment = this.commentRows.find((r) => {
      return e.srcElement && r.node.contains(e.srcElement);
    });
    if (!containsComment) {
      var text = this.getSelectedText();
      e.dataTransfer.setData('text', text);
    }
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
  */
  addNewComment(comment) { 
    if (comment.in_reply_to) {
      var parent = this.comments.find((c) => c.id == comment.in_reply_to);
      comment.diffIdx = parent.diffIdx;
      comment.position = parent.position;
    } else {
      comment.position = comment.diffIdx - this.firstHunkDiffIdx();
    }
    
    // compute diff_hunk:
    
    var hunkLines = [];
    var diffIdx = comment.diffIdx;
    
    while (diffIdx >= 0) {
      var line = this.diffLines[diffIdx];
      hunkLines.push(line);
      if (line.startsWith("@@")) {
        break;
      }      
      diffIdx--;
    }
    hunkLines.reverse();
    comment.diff_hunk = hunkLines.join("\n");
    
    comment.path = this.path;
    comment.commit_id = this.headSha;
    
    this.updateComments(this.comments.concat([comment]), this.inReview);
        
    if (this.inReview) {
      window.queueReviewComment.postMessage(comment);
    } else {
      comment.pending_id = "single." + comment.pending_id;
      window.addSingleComment.postMessage(comment);
    }
  }
  
  editComment(comment) {
    window.editComment.postMessage(comment);
  }
  
  deleteComment(comment) {
    window.deleteComment.postMessage(comment);
  }
  
  insertComment(diffIdx) {
    // if we already have a comment row at diffIdx, then just ask it to do a reply
    var cr = this.commentRows.find((cr) => cr.diffIdx == diffIdx);
    if (cr) {
      cr.showReply();
    } else {
      cr = new CommentRow(this.issueIdentifier, this.me, this.repo, this.mentionable, this);
      cr.setHasNewComment(true, diffIdx);
      this.commentRows.push(cr);
      this.positionComments();
      this.updateMiniMapRegions();
    }
  }
  
  cancelInsertComment(diffIdx) {
    var crIdx = this.commentRows.findIndex((cr) => cr.diffIdx == diffIdx);
    if (crIdx != -1) {
      var cr = this.commentRows[crIdx];
      cr.node.remove();
      this.commentRows.splice(crIdx, 1);
      this.updateMiniMapRegions();
    }
  }
    
  scrollToCommentId(commentId) {
    var comment = this.comments.find((c) => c.id == commentId || c.pending_id == commentId);
    if (comment) {
      var cr = this.commentRows.find((cr) => cr.diffIdx == comment.diffIdx);
      cr.scrollToComment(comment);
    }
  }
  
  scrollToLine(options) {
    var line = options.line;
    var left = options.left;
    var cr = this.codeRows.find(cr => {
      if (left) {
        return cr.leftLineNum === line;
      } else {
        return cr.rightLineNum === line;
      }
    });
    this.codeRows.forEach(r => {
      if (r != cr) {
        r.search(null); // clear existing search
      }
    });
    if (cr) {
      cr.node.scrollIntoViewIfNeeded();
      if (options.highlight) {
        var regex = new RegExp(options.highlight.regex, options.highlight.insensitive ? "ig" : "g");
        cr.search(regex, true);
      }
    }
  }
  
  /*
  options - {
    type: string, (comment|hunk|line)
    direction: int, 1 (down) or -1 (up)
    first: boolean, go to item at top of file
    last: boolean, go to the item at the bottom of the file
    
    line specific options:
    left: line is in left or right
  }
  */
  scrollTo(options) { 
    if (options.type === "line") {
      this.scrollToLine(options);
      return;
    }
    
    var commentBlocks = () => {
      return this.commentRows.map((cr) => {
        return { diffIdx: cr.diffIdx, startNode: cr.node, endNode: cr.node, type:'comment' };
      });
    };
    
    var codeBlocks = (cuts) => {
      cuts = cuts?new Set(cuts):new Set();
      var l = [];
      var cur = null;
      for (var i = 0; i < this.codeRows.length; i++) {
        var cr = this.codeRows[i];
        if (cr.hunkNum !== undefined) {
          if (cur == null || cr.hunkNum != cur.hunkNum) {
            cur = { diffIdx: cr.diffIdx, startNode: cr.node, hunkNum: cr.hunkNum, type:'code' };
            l.push(cur);
          }
          cur.endNode = cr.node;
          if ((cr.rightDiffIdx !== undefined && cuts.has(cr.rightDiffIdx)) || cuts.has(cr.diffIdx)) {
            cur = null;
          }
        }
      }
      return l;
    };
    
    var computeBlockBounds = (b) => {
        var offsetTop = 0;
        var n = b.startNode;
        while (n && n != this.table) {
          offsetTop += n.offsetTop;
          n = n.offsetParent;
        }
        n = b.endNode;
        var offsetBottom = n.offsetHeight;
        while (n && n != this.table) {
          offsetBottom += n.offsetTop;
          n = n.offsetParent;
        }
        b.offsetTop = offsetTop;
        b.offsetBottom = offsetBottom;
        if (b.type == 'comment') {
          // hack to deal with bottom shadow
          b.offsetBottom -= 2;
        }
        return { offsetTop, offsetBottom };
    };
  
    var blocks;
    if (options.type === 'comment') {
      blocks = commentBlocks();
    } else if (options.type == 'hunk') {
      blocks = codeBlocks();
    } else {
      var comments = commentBlocks();
      var code = codeBlocks(comments.map(c => c.diffIdx));
      blocks = comments.concat(code);
      blocks.sort((a, b) => {
        if (a.diffIdx < b.diffIdx) return -1;
        else if (a.diffIdx > b.diffIdx) return 1;
        else {
          // code row comes before comment row
          if (a.type == 'code' && b.type != 'code') {
            return -1;
          } else if (a.type != 'code' && b.type == 'code') {
            return 1;
          } else {
            return 0;
          }
        }
      });
    }
    
    var scrollableHeight = this.table.scrollHeight;
    var visibleHeight = this.miniMap.canvas.clientHeight;
    var lineTop = window.scrollY;
    var lineBottom = lineTop + visibleHeight;
    var atBottom = Math.abs(lineTop - (scrollableHeight - visibleHeight)) < 1.0;
    var atTop = lineTop < 1.0;
    
    if (options.direction) {      
      var onscreen = [];
      var above = [];
      var below = [];
      
      for (var i = 0; i < blocks.length; i++) {
        var b = blocks[i];
        computeBlockBounds(b);
        
        if (b.offsetBottom <= lineTop) {
          above.push(i);
        } else if (b.offsetTop < lineBottom) {
          onscreen.push(i);
        } else {
          below.push(i);
        }
      }
      
      var next = undefined;
      if (options.direction > 0) {
        // scroll down
        if (atBottom) { }
        else if (onscreen.length > 1) next = onscreen[1];
        else if (onscreen.length > 0 && blocks[onscreen[0]].offsetBottom > lineBottom) next = "pgdn";
        else if (below.length > 0) next = below[0];
      } else {
        // scroll up
        if (atTop) { }
        else if (onscreen.length > 0 && blocks[onscreen[0]].offsetTop < lineTop) next = "pgup";
        else if (above.length > 0) next = above[above.length-1];
      }
      
      if (next === "pgup") {
        window.scrollBy(0, -visibleHeight);
      } else if (next === "pgdn") {
        window.scrollBy(0, visibleHeight);
      } else if (next !== undefined) {
        blocks[next].startNode.scrollIntoView({behavior: "smooth"});
      } else {
        window.scrollContinuation.postMessage(options);
      }
    } else if (options.first) {
      if (blocks.length) {
        blocks[0].startNode.scrollIntoView();
      } else {
        window.scroll(0, 0);
      }
    } else if (options.last) {
      if (blocks.length) {
        var block = blocks[blocks.length-1];
        computeBlockBounds(block);
        window.scroll(0, Math.max(0, (block.offsetBottom + 20.0) - visibleHeight));
      } else {
        window.scroll(0, scrollableHeight - visibleHeight);
      }
    }
  }
  
  activeComment() {
    for (var i = 0; i < this.commentRows.length; i++) {
      var cr = this.commentRows[i];
      var active = cr.activeComment();
      if (active) return active;
    }
    return null;
  }
  
  applyMarkdownFormat(format) {
    var c = this.activeComment();
    if (c) { 
      c.applyMarkdownFormat(format);
    }
  }
  
  toggleCommentPreview() {
    var c = this.activeComment();
    if (c) {
      c.togglePreview();
    }
  }
  
  /*
    search runs in different modes depending on opts:
    { str: "..." } -- start a new search for str
    { action: "next" } -- scroll to the next match of the current search
    { action: "previous" } -- scroll to the previous match of the current search
    { action: "scroll" } -- scroll to the current match of the current search
    null -- return the currently selected text
  */
  search(opts) {
    if (!opts) {
      return this.getSelectedText();
    }
    
    if ("str" in opts) {
      if (opts.str.length < 2) opts.str = null;
      this.searchState = { str: opts.str, i: null };
    } else if (opts.action && this.searchState) {
      if (opts.action == "next") {
        this.searchState.i += 1;
      } else if (opts.action == "previous") {
        this.searchState.i -= 1;
      }
    }
    
    var maxMatches = 500;
    
    if (this.searchState) {
      var totalMatches = 0;
      var matchIdxToCodeRow = [];
      var baseMatchIdxForCodeRow = [];
      var regexp = this.searchState.str ? new RegExp(escapeStringForRegex(this.searchState.str), 'ig') : null;
      var nextIdx = null;
      var scrollableHeight = this.table.scrollHeight;
      var visibleHeight = this.miniMap.canvas.clientHeight;
      var lineTop = window.scrollY;
      var lineBottom = lineTop + visibleHeight;
      var needsViewportCalc = this.searchState.i === null;
      for (var i = 0; i < this.codeRows.length; i++) {
        var r = this.codeRows[i];
        var offsetY = 0;
        
        if (needsViewportCalc) {
          var n = r.node;
          while (n && n != this.table) {
            offsetY += n.offsetTop;
            n = n.offsetParent;
          }
        }
        
        baseMatchIdxForCodeRow[i] = totalMatches;
        var numMatches = r.search(regexp);
        if (offsetY >= lineTop && numMatches > 0 && nextIdx === null) {
          nextIdx = totalMatches;
        }
        for (var j = 0; j < numMatches; j++) {
          matchIdxToCodeRow[totalMatches+j] = i;
        }
        totalMatches += numMatches;        
      }
      
      if (this.searchState.i === null) {
        this.searchState.i = nextIdx;
      }
    
      if (totalMatches > 0) {
        while (this.searchState.i < 0) {
          this.searchState.i += totalMatches;
        }
        this.searchState.i = this.searchState.i % totalMatches;
      
        var codeRow = matchIdxToCodeRow[this.searchState.i];
        var baseIdx = baseMatchIdxForCodeRow[codeRow];
        var rowLocalMatchIdx = this.searchState.i - baseIdx;
        this.codeRows[codeRow].highlightSearchMatch(rowLocalMatchIdx);
      }
    }
  }
  
  simplifyTimerFired() {
    delete this.simplified.timer;
    
    if (this.simplified.nextState == this.simplified.state) {
      return;
    }
    
    if (this.simplified.nextState) {
      console.log("simplify");
      this.simplified.state = this.simplified.nextState;
      delete this.simplified.nextState;
      
      var initialScrollPosition = window.scrollY;

      this.placeholders.forEach(ph => {
        ph.rows.forEach(cr => cr.node.style.display = 'none');
        ph.node.style.display = 'table-row';
      });
      
      this.simplified.scrollListener = (evt) => {
        var newScrollPosition = window.scrollY;
        if (Math.abs(newScrollPosition - initialScrollPosition) > window.screen.height) {
          this.unsimplify();
        }
      };
      window.addEventListener('scroll', this.simplified.scrollListener);
    } else {
      this.unsimplify({now:true});
    }
  }
  
  scheduleSimplifyTimer(nextState) {
    if (this.simplified.state != nextState) {
      this.simplified.nextState = nextState;
      if (!this.simplified.timer) {
        this.simplified.timer = window.setTimeout(this.simplifyTimerFired.bind(this), 10);
      }
    }
  }
  
  /* 
  Simplify DOM underneath this.table. In a nutshell, offscreen portions of the DOM
  are compressed into a structure that sizes and behaves just like the uncompressed
  structure it is replacing, and even largely visually resembles the structure it is
  replacing, but the compressed structure has a fraction of the node count.
  */
  simplify() {
    this.scheduleSimplifyTimer(true);
  }
  
  /* 
  Undo simplify.
  
  Arguments:
    quick - just reset tracking state / event listeners, but don't edit the DOM
  */
  unsimplify(opts) {
    if (opts && (opts.quick || opts.now)) {
      if (this.simplified.state) {
        console.log("unsimplify: quick: " + opts.quick);
        window.removeEventListener('scroll', this.simplified.scrollListener);
        delete this.simplified.scrollListener;
        this.simplified.state = false;
        delete this.simplified.nextState;
        if (this.simplified.timer) {
          window.clearTimeout(this.simplified.timer);
        }
        if (!opts.quick) {
          this.placeholders.forEach(ph => {
            ph.node.style.display = 'none';
            ph.rows.forEach(cr => cr.node.style.display = 'table-row');        
          });
        }
      }
    } else {
      this.scheduleSimplifyTimer(false);
    }
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
  headSha: string, commit id of head of PR branch
  baseSha: string, commit id of base of PR branch
  me: object, user
  repo: object
}
*/
window.updateDiff = function(diffState) {
  app.saveDraftComments();
  app.clearComments();
  app.updateDiff(diffState)
  app.updateComments(diffState.comments, diffState.inReview);
};

window.setDiffMode = function(newDiffMode) {
  window.getSelection().removeAllRanges();
  app.setDiffMode(newDiffMode);
};

window.updateComments = function(comments, inReview) {
  app.updateComments(comments, inReview);
};

window.scrollToCommentId = function(commentId) {
  app.scrollToCommentId(commentId);
};

window.diff_scrollTo = function(options) {
  app.scrollTo(options);
}

window.applyMarkdownFormat = function(format) {
  app.applyMarkdownFormat(format);
}

window.toggleCommentPreview = function(format) {
  app.toggleCommentPreview();
}

window.search = function(options) {
  return app.search(options);
}

window.onload = () => {
  app = new App(document.getElementById('app'));
  
  window.addEventListener('contextmenu', function(e) {
    var tgt = e.target;
    var url = tgt.href || tgt.src;
    window.contextContext.postMessage({downloadurl: url});
  });
  
  window.loadComplete.postMessage({});
}
