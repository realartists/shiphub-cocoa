import './xcode7.css'
import './index.css'

import h from 'hyperscript'
import diff_match_patch from 'diff-match-patch'
import htmlEscape from 'html-escape';

import filterSelection from './filter-selection.js'
import MiniMap from './minimap.js'
import AttributedString from './attributed-string.js'
var HighlightWorker = require('worker!./highlight-worker.js');

function splitLines(text) {
  return text.split(/\r\n|\r|\n/);
}

function codeColContents(code) {
  if (!code || code.length == 0) return "<pre>\xA0\n</pre>";
  return "<pre>"+code+"\n</pre>";
} 

class Row {
  constructor(leftLine, leftLineNum, rightLine, rightLineNum, diffLine, changed) {
    this.leftLineNum = leftLineNum;
    this.rightLineNum = rightLineNum;
    this.diffLine = diffLine;  
    this.changed = changed;
    
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
    
    var left = this.left = h('td', {className:leftClasses});
    left.innerHTML = codeColContents(htmlEscape(leftLine||""));
    
    var right = this.right = h('td', {className:rightClasses});
    right.innerHTML = codeColContents(htmlEscape(rightLine||""));
    
    var row = h('tr', {}, gutterLeft, left, gutterRight, right);
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
    
    this.left.innerHTML = codeColContents(leftLineHighlighted);
    this.right.innerHTML = codeColContents(rightLineHighlighted);
  }
}

class TrailerRow {
  constructor() {
    var gutterLeft = h('td', { className:'gutter gutter-left' });
    var gutterRight = h('td', { className:'gutter gutter-right' });
    var left = this.left = h('td', {style:{height:'100%'}});
    var right = this.right = h('td', {style:{height:'100%'}});
    
    var row = h('tr', {style:{height:'100%'}}, gutterLeft, left, gutterRight, right);
    this.node = row;
  }
  updateHighlight() { }
}

class App {
  constructor(root) {  
    var minimapWidth = 32;
    
    var style = {
      'width': '100%',
      'max-width': '100%'
    };
    this.table = h('table', {className:"diff", style:style});
    
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
  
  updateDiff(filename, leftText, rightText, uDiff) {
    // note: the left is considered the 'original' (what's in master)
    // and the right is considered the 'modified' (result of original + patch)
  
    var leftLines = splitLines(leftText);
    var rightLines = splitLines(rightText);
    var diffLines = splitLines(uDiff);
    
    // contain information needed to build Row objects (indexes into left, right, and diff)
    var rowInfos = [];
    
    var leftIdx = 0;    // into leftLines
    var rightIdx = 0;   // into rightLines
    var diffIdx = 0;    // into diffLines
    var hunkQueue = 0;  // offset from end of rowInfos. implements a queue for lining up corresponding deletions and insertions

    // walk to the first hunk of the diff
    while (diffIdx < diffLines.length && !diffLines[diffIdx].startsWith("@@")) diffIdx++;
    
    // process the diff line at a time, building up rowInfos as we go.
    while (diffIdx < diffLines.length) {
      var diffLine = diffLines[diffIdx];
      if (diffLine.startsWith("@@")) {
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
        if (hunkQueue) {
          // if we have an active hunk queue, hook this line in right up with the corresponding deleted line in left.
          var hunkIdx = rowInfos.length - hunkQueue;
          rowInfos[hunkIdx].rightIdx = rightIdx;
          rowInfos[hunkIdx].changed = true;
          hunkQueue--;
        } else {
          rowInfos.push({rightIdx, diffIdx});
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
    var rows = rowInfos.map((ri) => {
      return new Row(
        ri.leftIdx===undefined?undefined:leftLines[ri.leftIdx],
        ri.leftIdx,
        ri.rightIdx==undefined?undefined:rightLines[ri.rightIdx],
        ri.rightIdx,
        ri.diffIdx,
        ri.changed===true
      );
    });
    
    // add a trailing row to take up space for short diffs
    var trailer = new TrailerRow();
    rows.push(trailer);
    
    var rowNodes = rows.map((r) => r.node);
    
    this.table.innerHTML = '';
    rowNodes.forEach((rn) => {
      this.table.appendChild(rn);
    });
    
    var miniMapRegions = rows.reduce((accum, row) => {
      if (row.miniMapRegions) {
        accum = accum.concat(row.miniMapRegions);
      }
      return accum;
    }, []);
    this.miniMap.setRegions(miniMapRegions);
    
    var hw = new HighlightWorker;
    hw.onmessage = function(result) {
      var leftHighlighted = result.data.leftHighlighted;
      var rightHighlighted = result.data.rightHighlighted;
      
      rowInfos.forEach((ri, i) => {
        var row = rows[i];
        var left = ri.leftIdx===undefined?undefined:leftHighlighted[ri.leftIdx];
        var right = ri.rightIdx===undefined?undefined:rightHighlighted[ri.rightIdx];
        row.updateHighlight(left, right);
      });
    };
    hw.postMessage({filename, leftText, rightText});
  }
  
  updateSelectability(e) {
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
    var col = this.selectedColumn || 'left';
    var text = filterSelection(this.table, (node) => {
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

window.updateDiff = function(filename, oldFile, newFile, patch) {
  app.updateDiff(filename||"", oldFile||"", newFile||"", patch||"");
};

window.loadComplete.postMessage({});

