/* helper function to get the max number of children / chars in a node */
function maxOffset(node) {
  var type = node.nodeType;
  switch (type) {
    case Node.ELEMENT_NODE:
    case Node.DOCUMENT_NODE:
    case Node.DOCUMENT_FRAGMENT_NODE:
      return node.childNodes.length;
    case Node.TEXT_NODE:
    case Node.COMMENT_NODE:
      return node.length;
    default:
      return 0;
  }
}

var PRUNE = 0;
var FILTER = 1;
var ACCEPT = 2;

/*
  Filter window.getSelection() to contain only nodes contained in root
  that pass test.
  
  A breadth first search is run starting at root. Any encountered node is
  tested first to see if it intersects the selection. If it does, it is then
  tested with test. 
  
  Test returns:
    filterSelection.PRUNE: Deselect this node and all descendents
    filterSelection.FILTER: Continue to search the subtree rooted at this node further
    filterSelection.ACCEPT: Retain the intersection of this node and all descendents in the selection.
  
  filterSelection returns the text content of the filtered selection as a string
*/
export default function filterSelection(root, test) {
  var sel = window.getSelection();
  var q = Array.from(root.childNodes);
  var n = [];
  
  /* 
    BFS starting at root, pruning subtrees as we go if they're
    either not in sel or they're rejected by the filter.
    
    This search produces an array of elements that intersects
    the selection. However, the list of elements may overlap the
    selection somewhat on either the start or the end, so additional
    work will be needed to tighten that up after the BFS.
  */
  while (q.length) {
    var x = q.shift();
    if (!sel.containsNode(x, true /* allow partial containment */)) {
      // this node is not even in the selection. keep moving.
      continue;
    }
    
    var action = test(x);
    
    if (action == PRUNE) {
      continue;
    } else if (action == FILTER) {
      for (var i = 0; i < x.childNodes.length; i++) q.push(x.childNodes[i]);
    } else /* action == ACCEPT */ {
      n.push(x);
    }
  }
  
  if (n.length == 0) {
    return "";
  }
  
  // Now, build the range list
  var ranges = [];
  var last = n.length - 1;
  n.forEach((x, i) => {
    var range = document.createRange();
    if ((i == 0 || i == last) && !sel.containsNode(x, false)) {
      // x hangs over the selection, either at the start, end, or both.
      var range = document.createRange();
      var startRange = sel.getRangeAt(0);
      var endRange = sel.getRangeAt(sel.rangeCount-1);
      var overhangStart = x.contains(startRange.startContainer);
      var overhangEnd = x.contains(endRange.endContainer);
      if (overhangStart) {
        range.setStart(startRange.startContainer, startRange.startOffset);
      } else {
        range.setStart(x, 0);
      }
      if (overhangEnd) {
        range.setEnd(endRange.endContainer, endRange.endOffset);
      } else {
        range.setEnd(x, maxOffset(x));
      }
    } else {
      range.setStart(x, 0);
      range.setEnd(x, maxOffset(x));
    }
    ranges.push(range);
  });
  
  return ranges.map((r) => r.toString()).join("");
}

filterSelection.PRUNE = PRUNE;
filterSelection.FILTER = FILTER;
filterSelection.ACCEPT = ACCEPT;

