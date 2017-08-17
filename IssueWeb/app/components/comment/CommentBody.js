import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import Sortable from 'sortablejs'
import CodeSnippet from './CodeSnippet.js'
import { markdownRender } from 'util/markdown-render.js'
import { rewriteTaskList } from 'util/rewrite-task-list.js'
import matchAll from 'util/match-all.js'

function preOrderTraverseDOM(root, handler) {
  var stack = [root];
  var i = 0;
  while (stack.length != 0) {
    var x = stack.shift();
    
    handler(x, i);
    i++;
    
    if (x.childNodes != null) {
      stack.unshift(...x.childNodes);
    }
  }
}

var CommentBody = React.createClass({
  propTypes: {
    body: React.PropTypes.string,
    onEdit: React.PropTypes.func, /* function(newBody) */
    repoOwner: React.PropTypes.string,
    repoName: React.PropTypes.string
  },
  
  updateLastRendered: function(lastRendered) {
    this.lastRendered = lastRendered;
  },
  
  shouldComponentUpdate: function(newProps) {
    return newProps.body !== this.lastRendered;
  },
  
  render: function() {
    var body = this.props.body;
    this.updateLastRendered(body);
    if (!body || body.trim().length == 0) {
      return h('div', { 
        className:'commentBody', 
        style: {padding: "14px"},
        ref: 'commentBody',
        dangerouslySetInnerHTML: {__html:'<i style="color: #777;">No Description Given.</i>'}
      });
    } else {
      return h('div', { 
        className:'commentBody', 
        ref: 'commentBody',
        dangerouslySetInnerHTML: {
          __html:markdownRender(
            body,
            this.props.repoOwner,
            this.props.repoName
          )
        }
      });
    }
  },
  
  expandCodeSnippets: function(nodes) {
    var expandMe = nodes.filter(n => n.nodeName == 'DIV' && n.className == 'codeSnippet' && n.childNodes.length == 0);
    console.log("snippets to expand", expandMe);
    
    expandMe.forEach(n => {
      ReactDOM.render(h(CodeSnippet, {
        repo: n.getAttributeNode("data-repo").value,
        sha: n.getAttributeNode("data-sha").value,
        path: n.getAttributeNode("data-path").value,
        startLine: n.getAttributeNode("data-start-line").value,
        endLine: n.getAttributeNode("data-end-line").value
      }), n);
    });
  },
  
  updateCheckbox: function(i, checked) {
    // find the i-th checkbox in the markdown
    var body = this.props.body;
    var pattern = /((?:(?:\d+\.)|(?:\-)|(?:\*))\s+)\[[x ]\]/g;
    var matches = matchAll(pattern, body);
            
    if (i < matches.length) {
      var match = matches[i];
      
      var start = match.index;
      start += match[1].length;
      
      var checkText;
      if (checked) {
        checkText = "[x]";
      } else {
        checkText = "[ ]";
      }
      body = body.slice(0, start) + checkText + body.slice(start + 3);
      
      this.updateLastRendered(body);
      this.props.onEdit(body);
    }
  },
  
  /* srcIdx and dstIdx are comment global checkbox indices */
  moveTaskItem: function(srcIdx, dstIdx) {
    var body = this.props.body;
    
    var newBody = rewriteTaskList(body, srcIdx, dstIdx);
    
    if (body != newBody) {
      this.rebindChecks();
    
      this.updateLastRendered(newBody);
      this.props.onEdit(newBody);
    }
  },
  
  rebindChecks(nodes) {
    if (!nodes) {
      var el = ReactDOM.findDOMNode(this.refs.commentBody);
      if (!el) return;
      var nodes = [];
      preOrderTraverseDOM(el, (x) => nodes.push(x));
    }
  
    var checks = nodes.filter((x) => x.nodeName == 'INPUT' && x.type == 'checkbox');
    
    checks.forEach((x, i) => {
      x.onchange = (evt) => {
        var checked = evt.target.checked;
        this.updateCheckbox(i, checked);
      };
    });
  },
  
  postProcessRenderedMarkdown: function() {
    var el = ReactDOM.findDOMNode(this.refs.commentBody);
    
    // traverse dom, pre-order, rooted at el
    
    var nodes = [];
    preOrderTraverseDOM(el, (x) => nodes.push(x));
    
    this.expandCodeSnippets(nodes);

    this.rebindChecks(nodes);

    // Find and bind sortables to task lists
    var rootTaskList = (x) => {
      var k = x.parentElement;
      while (k && k != el) {
        if (k.nodeName == 'UL' || k.nodeName == 'OL') {
          return false;
        }
        k = k.parentElement;
      }
      return true;
    };    
    var taskLists = nodes.filter((x) => x.nodeName == 'UL' && x.className == 'taskList' && rootTaskList(x));
    
    var counter = { i: 0 };
    taskLists.forEach((x) => {
      if (!x._sortableInstalled) {
        var handles = [];
        x._sortableInstalled = true;
        var offset = counter.i;
        // install drag handle on each 
        Array.from(x.childNodes).filter((cn) => cn.nodeName == 'LI' && cn.className == 'taskItem').forEach((li) => {
          var handle = document.createElement('i');
          handle.className = "fa fa-bars taskHandle";
          li.insertBefore(handle, li.firstChild);
          handles.push(handle);
          counter.i++;
        });
        var s = Sortable.create(x, {
          animation: 150,
          draggable: '.taskItem',
          handle: '.taskHandle',
          ghostClass: 'taskGhost',
          onStart: () => {
            handles.forEach((h) => {
              h.style.opacity = "0.0";
            });
          },
          onEnd: (evt) => {
            handles.forEach((h) => {
              h.style.opacity = "";
            });
            if (evt.oldIndex != evt.newIndex) {
              var srcIdx = evt.oldIndex;
              var dstIdx = evt.newIndex;
              
              var nonTasksLTSrc = 0;
              var nonTasksLTDst = 0;
              for (var i = 0; i < srcIdx || i < dstIdx; i++) {
                var cn = x.childNodes[i];
                if (cn.nodeName == 'LI' && cn.className != 'taskItem') {
                  if (i < srcIdx) nonTasksLTSrc++;
                  if (i < dstIdx) nonTasksLTDst++;
                }
              }
              
              srcIdx += offset - nonTasksLTSrc;
              dstIdx += offset - nonTasksLTDst;
              
              this.moveTaskItem(srcIdx, dstIdx);
            }
          }
        });
      }
    });
  },
  
  componentDidMount: function() {
    this.postProcessRenderedMarkdown();
  },
  
  componentDidUpdate: function() {
    this.postProcessRenderedMarkdown();
  }
});

export default CommentBody;
