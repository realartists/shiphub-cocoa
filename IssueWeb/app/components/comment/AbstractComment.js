/* This is the shared Comment component between IssueWeb and DiffWeb */

import 'font-awesome/css/font-awesome.css'
import 'codemirror/lib/codemirror.css'
import '../../../markdown-mark/style.css'
import './comment.css'
import 'xcode7.css'

import Sortable from 'sortablejs'
import CodeMirror from 'codemirror'
import Codemirror from 'react-codemirror'
import 'codemirror/mode/gfm/gfm'
import 'codemirror/mode/clike/clike'
import 'codemirror/mode/swift/swift'
import 'codemirror/mode/javascript/javascript'
import 'codemirror/mode/css/css'
import 'codemirror/mode/htmlmixed/htmlmixed'
import 'codemirror/mode/python/python'
import 'codemirror/mode/ruby/ruby'
import 'codemirror/mode/go/go'
import 'codemirror/addon/display/placeholder.js'
import 'codemirror/addon/hint/show-hint.css'
import 'codemirror/addon/hint/show-hint.js'
import 'codemirror/addon/search/searchcursor.js'
import 'util/spellcheck.js'

import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import ghost from 'util/ghost.js';
import { keypath } from 'util/keypath.js'
import { promiseQueue } from 'util/promise-queue.js'
import { pasteHelper } from 'util/paste-helper.js'
import { shiftTab, searchForward, searchBackward, toggleFormat, increasePrefix, decreasePrefix, insertTemplate } from 'util/cm-util.js'
import { emojify, emojifyReaction } from 'util/emojify.js'

import AddCommentHeader from './AddCommentHeader.js'
import AddCommentFooter from './AddCommentFooter.js'
import AddCommentUploadProgress from './AddCommentUploadProgress.js'
import CommentControls from './CommentControls.js'
import CommentReactions from './CommentReactions.js'
import CommentHeader from './CommentHeader.js'
import CommentPRBar from './CommentPRBar.js'
import CommentBody from './CommentBody.js'
import CommentButtonBar from './CommentButtonBar.js'

class AbstractComment extends React.Component {
  constructor(props) {
    super(props);
    
    this.state = {
      editing: !(this.props.comment),
      code: "",
      previewing: false,
      uploadCount: 0,
      pendingTaskBody: null
    };
  }

  /* Subclassers must override */
  
  me() { throw "not implemented" }
  
  editComment() { throw "not implemented"; }
  
  issue() { throw "not implemented"; }  

  isNewIssue() { throw "not implemented"; }
  
  canClose() { throw "not implemented"; }
  
  repoOwner() { throw "not implemented"; }
  
  repoName() { throw "not implemented"; }
  
  shouldShowCommentPRBar() { throw "not implemented"; }
  
  saveDraftState() { throw "not implemented"; }
  
  restoreDraftState() { throw "not implemented"; }
  
  deleteComment() { throw "not implemented"; }
    
  editCommentURL() { throw "not implemented"; }
  
  editCommentQueue() { throw "not implemented"; }
  
  addReaction(reaction) { throw "not implemented"; }
  
  toggleReaction(reaction) { throw "not implemented"; }

  _save() { throw "not implemented"; }
  
  saveAndClose() { throw "not implemented"; }
  
  loginCompletions() { throw "not implemented"; }
  
  /* End methods that subclassers must override 
    
     The following methods may be overridden by subclassers or left as is.
  */
  
  componentWillReceiveProps(nextProps) {
    if (this.state.editing && nextProps.comment && this.props.comment && nextProps.comment.id != this.props.comment.id) {
      this.setState(Object.assign({}, this.state, {editing: false, pendingTaskBody: null}));
    }
  }
  
  commentIdentifier() {
    return keypath(this.props, "comment.id");
  }
  
  setInitialContents(contents) {
    this.setState(Object.assign({}, this.state, {code: contents}));
  }
  
  updateCode(newCode) {
    this.setState(Object.assign({}, this.state, {code: newCode}));
    if (window.documentEditedHelper) {
      window.documentEditedHelper.postMessage({});
    }
  }
  
  replaceInCode(original, replacement) {
    var cmr = this.refs.codemirror, cm = cmr ? cmr.getCodeMirror() : null;
    if (cm) {
      var cursor = cm.getSearchCursor(original);
      while (cursor.findNext()) {
        cursor.replace(replacement);
      }
    } else {
      var c = this.state.code;
      c = c.replace(original, replacement);
      this.updateCode(c);
    }
  }
  
  beginEditing() {
    if (!this.state.editing) {
      this.setState(Object.assign({}, this.state, {
        previewing: false,
        editing: true,
        code: this.props.comment.body || ""
      }));
    }
  }
  
  cancelEditing() {
    if (this.state.editing) {
      this.setState(Object.assign({}, this.state, {
        previewing: false,
        editing: false,
        code: ""
      }));
      if (window.documentEditedHelper) {
        window.documentEditedHelper.postMessage({});
      }
    }
  }
  
  /* Called for task list edits that occur 
     e.g. checked a task button or reordered a task list 
  */
  onTaskListEdit(newBody) {
    if (!this.props.comment || this.state.editing) {
      this.updateCode(newBody);
    } else {
      this.setState(Object.assign({}, this.state, {pendingTaskBody: newBody}));
      
      var owner = IssueState.current.repoOwner;
      var repo = IssueState.current.repoName;
      var num = IssueState.current.issue.number;
      var patch = { body: newBody };
      var q = this.editCommentQueue();
      var url = this.editCommentURL();
      var initialId = this.props.comment.id;
            
      promiseQueue(q, () => {
        var currentId = keypath(this.props, "comment.id") || "";
        if (currentId == initialId && newBody != this.state.pendingTaskBody) {
          // let's just jump ahead to the next thing, we're already stale.
          return Promise.resolve();
        }
        var request = api(url, { 
          headers: { 
            Authorization: "token " + IssueState.current.token,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }, 
          method: "PATCH",
          body: JSON.stringify(patch)
        });
        var end = () => {
          if (this.state.pendingTaskBody == newBody) {
            this.setState(Object.assign({}, this.state, {pendingTaskBody: null}));
          }
        };
        return new Promise((resolve, reject) => {
          // NB: The 1500ms delay is because GitHub only has 1s precision on updated_at
          request.then(() => {
            setTimeout(() => {
              end();
              resolve();            
            }, 1500);
          }).catch((err) => {
            setTimeout(() => {
              end();
              reject(err);
            }, 1500);
          });
        });
      });
    }
  }
  
  findReaction(reaction) {
    var me = this.me();
    var existing = this.props.comment.reactions.filter((r) => r.content === reaction && r.user.login === me.login);
    return existing.length > 0 ? existing[0] : null;
  }
  
  scrollIntoView() {
    var el = ReactDOM.findDOMNode(this);
    if (el) {
      el.scrollIntoView();
    }
  }
  
  togglePreview() {
    var previewing = !this.state.previewing;
    this.doFocus = !previewing;
    this.setState(Object.assign({}, this.state, {previewing:previewing}));
    setTimeout(() => { 
      this.scrollIntoView();
      if (!previewing) {
        this.focusCodemirror();
      }
    }, 0);
  }
  
  hasFocus() {
    if (this.refs.codemirror) {
      var cm = this.refs.codemirror.getCodeMirror();
      return cm && cm.hasFocus(); 
    }
    return false;
  }
  
  isActive() {
    return this.state.previewing || this.hasFocus();
  }
  
  focusCodemirror() {
    this.refs.codemirror.focus()
  }
  
  onBlur() {
    if (window.inAppCommentFocus) {
      window.inAppCommentFocus.postMessage({key:this.key, state:false});
    }
    var isNewIssue = this.isNewIssue();
    if (isNewIssue) {
      this.editComment();
    }
  }
  
  onFocus() {
    if (window.inAppCommentFocus) {
      window.inAppCommentFocus.postMessage({key:this.key, state:true});
    }
  }
  
  waitForUploads() {
    if (this.state.uploadCount == 0) {
      return Promise.resolve();
    } else {
      var uploadQueue = this.uploadQueue;
      if (!uploadQueue) {
        this.uploadQueue = uploadQueue = [];
      }
      var p = new Promise((resolve, reject) => {
        uploadQueue.push({resolve, reject});
      });
      return p;
    }
  }
  
  save() { 
    return this.waitForUploads().then(() => {
      return this._save()
    });
  }
  
  // Subclassers might consider overriding this
  needsSave() {
    if (this.props.comment && !this.state.editing) {
      return false;
    }
    var body = this.state.code;
    if (body.trim().length > 0) {
      if (this.props.comment) {
        if (this.props.comment.body != body) {
          return true;
        }
      } else {
        return true;
      }
    }
    return false;
  }
  
  renderCodemirror() {
    var isNewIssue = this.isNewIssue();
  
    return h('div', {className: 'CodeMirrorContainer', onClick:this.focusCodemirror.bind(this)},
      h(Codemirror, {
        ref: 'codemirror',
        value: this.state.code,
        onChange: this.updateCode.bind(this),
        options: {
          readOnly: false,
          mode: 'gfm',
          placeholder: (isNewIssue ? "Describe the issue" : "Leave a comment"),
          cursorHeight: 0.85,
          lineWrapping: true,
          viewportMargin: Infinity
        }
      })
    )
  }
  
  renderCommentBody(body) {
    return h(CommentBody, { 
      body: body, 
      onEdit:this.onTaskListEdit.bind(this),
      repoOwner: this.repoOwner(),
      repoName: this.repoName()
    });
  }
  
  renderHeader() {
    if (this.props.comment) {
      return h(CommentHeader, {
        ref:'header',
        comment:this.props.comment, 
        first:this.props.first,
        editing:this.state.editing,
        hasContents:this.state.code.trim().length>0,
        previewing:this.state.previewing,
        togglePreview:this.togglePreview.bind(this),
        attachFiles:this.selectFiles.bind(this),
        beginEditing:this.beginEditing.bind(this),
        cancelEditing:this.cancelEditing.bind(this),
        deleteComment:this.deleteComment.bind(this),
        addReaction:this.addReaction.bind(this)
      });
    } else {
      return h(AddCommentHeader, {
        ref:'header', 
        hasContents:this.state.code.trim().length>0,
        previewing:this.state.previewing,
        togglePreview:this.togglePreview.bind(this),
        attachFiles:this.selectFiles.bind(this),
        me:this.me()
      });
    }
  }
  
  renderFooter() {
    if (this.state.editing) {
      if (this.state.uploadCount > 0) {
        return h(AddCommentUploadProgress, {ref:'uploadProgress'});
      } else {
        return h(AddCommentFooter, {
          ref:'footer', 
          canClose: this.canClose(),
          previewing: this.state.previewing,
          onClose: this.saveAndClose.bind(this), 
          onSave: this.save.bind(this),
          onCancel: this.props.onCancel||this.cancelEditing.bind(this),
          hasContents: this.state.code.trim().length > 0,
          editingExisting: !!(this.props.comment),
          canSave: this.needsSave(),
          isNewIssue: this.isNewIssue(),
          canCancel: !!(this.props.onCancel)
        })
      }
    } else if (this.props.first && this.shouldShowCommentPRBar()) {
      return h(CommentPRBar, {
        key:"pr", 
        comment:this.props.comment,
        issue:this.issue(), 
        me: this.me(),
        onToggleReaction:this.toggleReaction.bind(this)
      });
    } else if ((this.props.buttons||[]).length > 0) {
      return h(CommentButtonBar, {
        key:"buttons", 
        comment:this.props.comment,
        issue:this.issue(), 
        me: this.me(),
        buttons:this.props.buttons,
        onToggleReaction:this.toggleReaction.bind(this)
      });
    } else if ((keypath(this.props, "comment.reactions")||[]).length > 0) {
      return h(CommentReactions, {
        me:this.me(), 
        reactions:this.props.comment.reactions, 
        onToggle:this.toggleReaction.bind(this)
      });
    } else {
      return h('div', {className:'commentEmptyFooter'});
    }
  }
  
  render() {
    if (!this.state.editing && !this.props.comment) {
      console.log("Invalid state detected! Must always be editing if no comment");
    }
  
    var showEditor = this.state.editing && !this.state.previewing;
    var body = this.state.editing ? this.state.code : (this.state.pendingTaskBody || this.props.comment.body);
    
    var outerClass = 'comment';
    
    if (!this.props.comment) {
      outerClass += ' addComment';
    }

    return h('div', {className:outerClass},
      this.renderHeader(),
      (showEditor ? this.renderCodemirror() : this.renderCommentBody(body)),
      this.renderFooter()
    );
  }
  
  selectFiles() {
    var cm = this.refs.codemirror;
    if (!cm) return;
    cm = cm.getCodeMirror();
    if (!cm) return;

    var pasteText = (text) => {
      cm.replaceSelection(text);
    };
      
    var uploadsStarted = (count, placeholders) => {
      this.updateUploadCount(count);
    };

    var uploadFinished = (placeholder, link) => {
      this.replaceInCode(placeholder, link);
      this.updateUploadCount(-1);
    };

    var uploadFailed = (placeholder, err) => {
      this.replaceInCode(placeholder, "");
      this.updateUploadCount(-1, err);
      alert(err);
    };

    pasteHelper("NSOpenPanel", pasteText, uploadsStarted, uploadFinished, uploadFailed);
  }
  
  updateUploadCount(delta, error) {
    var newCount = this.state.uploadCount + delta;
    this.setState(Object.assign({}, this.state, {uploadCount:newCount}));
    if ((newCount == 0 || error) && this.uploadQueue) {
      var q = this.uploadQueue;
      delete this.uploadQueue;
      q.forEach((cb) => {
        if (error) {
          cb.reject(error);
        } else {
          cb.resolve();
        }
      });
    }
  }
  
  configureCM() {
    if (!(this.refs.codemirror)) {
      return;
    }
    
    var cm = this.refs.codemirror.getCodeMirror();
    if (cm && cm.issueWebConfigured === undefined) {
      cm.issueWebConfigured = true;
      
      var sentinelHint = function(cm, options) {
        var cur = cm.getCursor();
        var wordRange = cm.findWordAt(cur);

        var sentinel = options.sentinel || " ";        
        var term = cm.getRange(wordRange.anchor, wordRange.head);
        
        if (term != sentinel) {          
          wordRange.anchor.ch -= 1;
          term = cm.getRange(wordRange.anchor, wordRange.head);
          
          if (term.indexOf(sentinel) != 0) {
            // return if we didn't begin with sentinel
            return;
          }
        }
        
        if (wordRange.anchor.ch != 0) {
          var prev = {line:wordRange.anchor.line, ch:wordRange.anchor.ch-1};
          var thingBefore = cm.getRange(prev, wordRange.anchor);
          if (!(/\s/.test(thingBefore))) {
            // return if the thing before sentinel isn't either the beginning of the line or a space
            return;
          }
        }
        
        // use the hint function to append a space after the completion
        var hint = function(cm, data, completion) {
          return cm.replaceRange(completion.text + " ", completion.from || data.from, completion.to || data.to, "complete");
        }
        
        var found = options.words.
        filter((w) => w.slice(0, term.length) == term).
        map(function(w) { return { text: w, hint: hint } })
        
        if (found.length) {
          var ret = {list: found, from: wordRange.anchor, to: wordRange.head};
          if (options.render) {
            ret.list = ret.list.map((c) => {
              return Object.assign({}, c, {render: options.render});
            });
          }
          return ret;
        }
      };
      
      // Show assignees and emoji completions on @ or : press
      cm.on('change', function(cm, change) {
        if (!cm.hasFocus()) return;
        var cursor = cm.getCursor();
        var mode = cm.getModeAt(cursor);
        if (mode.name != 'markdown') return; // don't do completions outside of markdown mode
        
        if (change.text.length == 1 && change.text[0] === '@') {
          CodeMirror.showHint(cm, sentinelHint, {
            words: this.loginCompletions().map((a) => '@' + a),
            sentinel: '@',
            completeSingle: false
          });
        } else if (change.text.length == 1 && change.text[0] === ':' && !cm.state.completionActive) {
          CodeMirror.showHint(cm, sentinelHint, {
            words: Object.keys(emojify.dictionary).map((w) => ':' + w + ":"),
            sentinel: ':',
            completeSingle: false,
            render: (element, self, data) => {
              var base = document.createTextNode(data.text);
              element.appendChild(base);
              var emoji = emojify(data.text, {size:14});
              if (emoji.indexOf('<img') != -1) {
                var span = document.createElement('span');
                span.innerHTML = emoji;
                element.appendChild(span);
              } else {
                var enode = document.createTextNode(emoji);
                element.appendChild(enode);
              }
            }
          });
        }
      });
      
      // Utility to actually handle the work of doing pastes/drops when running
      // in app. This uses the native code side to handle reading the pasteboard
      // and doing file uploads since it is so much more flexible than web based APIs
      // for this stuff.
      var doAppPaste = (pasteboardName, cm, e) => {
        var pasteText = (text) => {
          cm.replaceSelection(text);
        };
                  
        var uploadsStarted = (count, placeholders) => {
          this.updateUploadCount(count);
        };
        
        var uploadFinished = (placeholder, link) => {
          this.replaceInCode(placeholder, link);
          this.updateUploadCount(-1);
        };
        
        var uploadFailed = (placeholder, err) => {
          this.replaceInCode(placeholder, "");
          this.updateUploadCount(-1);
          alert(err);
        };
        
        pasteHelper(pasteboardName, pasteText, uploadsStarted, uploadFinished, uploadFailed);
        
        e.stopPropagation();
        e.preventDefault();
        
        return true;
      };
      
      // Configure drag n drop handling
      cm.on('drop', (cm, e) => {
        if (window.inAppPasteHelper) {
          return doAppPaste('dragging', cm, e);
        }
      });
      
      // Configure general pasteboard handling
      cm.on('paste', (cm, e) => {
        if (window.inAppPasteHelper) {
          return doAppPaste('general', cm, e);
        } else {
          return false; // use default 
        }
      });
      
      // Configure spellchecking
      cm.setOption("systemSpellcheck", true);
      
      cm.extraCommands = {
        bold: toggleFormat('**', 'strong'),
        italic: toggleFormat('_', 'em'),
        strike: toggleFormat('~~', 'strikethrough'),
        headingMore: increasePrefix('#'),
        headingLess: decreasePrefix('#'),
        insertUL: insertTemplate('* Item'),
        insertOL: insertTemplate('1. First'),
        insertTaskList: insertTemplate('- [x] Complete\n- [ ] Incomplete'),
        hyperlink: insertTemplate('[title](url)'),
        attach: (cm) => { this.selectFiles(); },
        quoteMore: increasePrefix('>'),
        quoteLess: decreasePrefix('>'),
        code: toggleFormat('`', 'comment'),
        codefence: insertTemplate(
          '```swift\n' +
          'func sayHello(name: String) {\n' +
          '  print("Hello, \(name)!")\n' +
          '}\n' +
          '```'
        ),
        insertTable: insertTemplate(
          'Heading 1 | Heading 2\n' +
          '----------|----------\n' +
          'Cell 1    | Cell 2   \n'
        ),
        insertHorizontalRule: insertTemplate('\n\n---\n\n')
      };
      
      // Configure some formatting controls
      cm.setOption('extraKeys', {
        'Cmd-B': cm.extraCommands.bold,
        'Cmd-I': cm.extraCommands.italic,
        'Cmd-S': () => { this.save(); },
        'Cmd-Enter': () => { this.save(); },
        'Shift-Cmd-Enter': () => { this.saveAndClose(); },
        'Shift-Tab': shiftTab,
        'Tab': 'indentMore',
        // unbind cmd-u/shift-cmd-u to let app handle them
        // codemirror treats them as undo/redo selection, but this is nonstandard
        // and we need these bindings elsewhere
        'Cmd-U': false,
        'Shift-Cmd-U' : false,
      });
      
      cm.on('blur', () => { this.onBlur(); });
      cm.on('focus', () => { this.onFocus(); });
    }
  }
  
  cmGoToEnd() {
    if (!this.refs.codemirror) return;
    var cm = this.refs.codemirror.getCodeMirror();
    cm.execCommand('goDocEnd');
  }
  
  applyMarkdownFormat(format) {
    if (this.state.previewing) {
      this.setState(Object.assign({}, this.state, {previewing: false}), () => {
        this.focusCodemirror();
        var cm = this.refs.codemirror.getCodeMirror();
        cm.execCommand('goDocEnd');
        insertTemplate('\n')(cm);
        this.applyMarkdownFormat(format);
      });
      return;
    }
  
    if (!(this.refs.codemirror)) {
      return;
    }
    
    var cm = this.refs.codemirror.getCodeMirror();
    if (format in cm.extraCommands) {
      cm.extraCommands[format](cm);
    } else {
      cm.execCommand(format);
    }
  }
  
  componentDidUpdate() {
    this.configureCM();
  }
  
  componentDidMount() {
    this.configureCM();
  }
}

AbstractComment.PropTypes = {
  comment: React.PropTypes.object,
  commentIdx: React.PropTypes.number,
  first: React.PropTypes.bool
}

export default AbstractComment;