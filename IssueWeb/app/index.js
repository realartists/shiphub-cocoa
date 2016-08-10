import 'font-awesome/css/font-awesome.css'
import '../markdown-mark/style.css'
import 'codemirror/lib/codemirror.css'
import 'highlight.js/styles/xcode.css'
import './index.css'

import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import escape from 'html-escape'
import hljs from 'highlight.js'
import pnglib from 'pnglib'
window.PNGlib = pnglib;
import identicon from 'identicon.js'
import linkify from 'html-linkify'
import md5 from 'md5'
import 'whatwg-fetch'
import Sortable from 'sortablejs'
import Textarea from 'react-textarea-autosize'
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
import './spellcheck.js'

import $ from 'jquery'
window.$ = $;
window.jQuery = $;
window.jquery = $;

import Completer from './completer.js'
import SmartInput from './smart-input.js'
import { emojify, emojifyReaction } from './emojify.js'
import marked from './marked.min.js'
import { githubLinkify } from './github_linkify.js'
import LabelPicker from './label-picker.js'
import AssigneesPicker from './assignees-picker.js'
import uploadAttachment from './file-uploader.js'
import FilePicker from './file-picker.js'
import { TimeAgo, TimeAgoString } from './time-ago'
import { shiftTab, searchForward, searchBackward, toggleFormat, increasePrefix, decreasePrefix, insertTemplate } from './cm-util.js'
import { promiseQueue } from './promise-queue.js'

var debugToken = "";

/*
Issue State Storage
*/
var ivars = {
  issue: {},
  repos: [],
  assignees: [],
  milestones: [],
  labels: [],
  me: null,
  token: debugToken
};
window.ivars = ivars;

function getIvars() {
  return window.ivars;
}

function setIvars(iv) {
  window.ivars = iv;
}

window.setAPIToken = function(token) {
  window.ivars.token = token;
}

var pendingPasteHandlers = [];
var pasteHandle = 0;

function pasteHelper(pasteboard, pasteText, uploadsStarted, uploadFinished, uploadFailed) {
  var handle = ++pasteHandle;
  pendingPasteHandlers[handle] = { pasteText, uploadsStarted, uploadFinished, uploadFailed };
  window.inAppPasteHelper.postMessage({handle, pasteboard});
}

function pasteCallback(handle, type, data) {
  var handlers = pendingPasteHandlers[handle];
  switch (type) {
    case 'pasteText':
      handlers.pasteText(data);
      break;
    case 'uploadsStarted':
      handlers.uploadsStarted(data);
      break;
    case 'uploadFinished':
      handlers.uploadFinished(data.placeholder, data.link);
      break;
    case 'uploadFailed':
      handlers.uploadFailed(data.placeholder, data.err);
      break;
    case 'completed':
      delete handlers[handle];
      break;
    default:
      console.log("Unknown pasteCallback type", type);
      break;
  }
}

var pendingAPIHandlers = [];
var apiHandle = 0;

// either performs the request directly or proxies it through the app
function api(url, opts) {
  if (window.inApp) {
    var handle = ++apiHandle;
    console.log("Making api call", handle, url, opts);
    return new Promise((resolve, reject) => {
      try {
        pendingAPIHandlers[handle] = {resolve, reject};
        window.postAppMessage({handle, url, opts});
      } catch (exc) {
        console.log(exc);
        reject(exc);
      }
    });
  } else {
    return fetch(url, opts).then(function(resp) {
      if (resp.status == 204) {
        return Promise.resolve(null); // no content
      } else {
        return resp.json();
      }
    });
  }
}

// used by the app to return an api call result
function apiCallback(handle, result, err) {
  console.log("Received apiCallback", handle, result, err);
  if (!(handle in pendingAPIHandlers)) {
    console.log("Received unknown apiCallback", handle, result, err);
    return;
  }
  
  var callbacks = pendingAPIHandlers[handle];
  delete pendingAPIHandlers[handle];
  
  if (err) {
    callbacks.reject(err);
  } else {
    callbacks.resolve(result);
  }
};

function applyPatch(patch) {
  var ghPatch = Object.assign({}, patch);

  if (patch.milestone != null) {
    ghPatch.milestone = patch.milestone.number;
  }

  if (patch.assignees != null) {
    ghPatch.assignees = patch.assignees.map((u) => u.login);
  }

  console.log("patching", patch, ghPatch);
  
  // PATCH /repos/:owner/:repo/issues/:number
  var owner = getIvars().issue._bare_owner;
  var repo = getIvars().issue._bare_repo;
  var num = getIvars().issue.number;
  
  if (num != null) {
    return promiseQueue("applyPatch", () => {
      var url = `https://api.github.com/repos/${owner}/${repo}/issues/${num}`
      var request = api(url, { 
        headers: { 
          Authorization: "token " + getIvars().token,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }, 
        method: "PATCH",
        body: JSON.stringify(ghPatch)
      });
      return new Promise((resolve, reject) => {
        request.then(function(body) {
          console.log(body);
          resolve();
          if (window.documentEditedHelper) {
            window.documentEditedHelper.postMessage({});
          }
        }).catch(function(err) {
          console.log(err);
          reject(err);
        });
      });
    });
  } else {
    return Promise.resolve();
  }
}

function applyCommentEdit(commentIdentifier, newBody) {
  // PATCH /repos/:owner/:repo/issues/comments/:id
  var owner = getIvars().issue._bare_owner;
  var repo = getIvars().issue._bare_repo;
  var num = getIvars().issue.number;
  
  if (num != null) {
    return promiseQueue("applyCommentEdit", () => {
      var url = `https://api.github.com/repos/${owner}/${repo}/issues/comments/${commentIdentifier}`
      var request = api(url, { 
        headers: { 
          Authorization: "token " + getIvars().token,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }, 
        method: "PATCH",
        body: JSON.stringify({body: newBody})
      });
      return new Promise((resolve, reject) => {
        request.then(function(body) {
          console.log(body);
          resolve();
        }).catch(function(err) {
          console.log(err);
          reject(err);
        });
      });
    });
  } else {
    return Promise.reject("Issue does not exist.");
  }
}

function applyCommentDelete(commentIdentifier) {
  // DELETE /repos/:owner/:repo/issues/comments/:id
  
  var owner = getIvars().issue._bare_owner;
  var repo = getIvars().issue._bare_repo;
  var num = getIvars().issue.number;
  
  if (num != null) {
    var url = `https://api.github.com/repos/${owner}/${repo}/issues/comments/${commentIdentifier}`
    var request = api(url, { 
      headers: { 
        Authorization: "token " + getIvars().token,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }, 
      method: "DELETE"
    });
    return request;
  } else {
    return Promise.reject("Issue does not exist.");
  }
}

function applyComment(commentBody) {
  // POST /repos/:owner/:repo/issues/:number/comments
  
  var owner = getIvars().issue._bare_owner;
  var repo = getIvars().issue._bare_repo;
  var num = getIvars().issue.number;
  
  if (num != null) {
    return promiseQueue("applyComment", () => {
      var url = `https://api.github.com/repos/${owner}/${repo}/issues/${num}/comments`
      var request = api(url, { 
        headers: { 
          Authorization: "token " + getIvars().token,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }, 
        method: "POST",
        body: JSON.stringify({body: commentBody})
      });
      return new Promise((resolve, reject) => {
        request.then(function(body) {
          var id = body.id;
          window.ivars.issue.allComments.forEach((m) => {
            if (m.id === 'new') {
              m.id = id;
            }
          });
          applyIssueState(window.ivars);
          resolve();
        }).catch(function(err) {
          console.log(err);
          reject(err);
        });
      });
    });
  } else {
    return Promise.reject("Issue does not exist.");
  }
}

function saveNewIssue() {
  // POST /repos/:owner/:repo/issues
  
  console.log("saveNewIssue");
  
  var issue = getIvars().issue;
  
  if (issue.number) {
    console.log("already have a number");
    return;
  }
  
  if (!issue.title || issue.title.trim().length == 0) {
    return;
  }
  
  var owner = issue._bare_owner;
  var repo = issue._bare_repo;
  
  if (!owner || !repo) {
    return;
  }
  
  if (window.ivars.issue.savePending) {
    console.log("Queueing save ...");
    if (!window.ivars.issue.savePendingQueue) {
      window.ivars.issue.savePendingQueue = [];
    }
    var q = window.ivars.issue.savePendingQueue;
    var p = new Promise((resolve, reject) => {
      q.append({resolve, reject});
    });
    return p;
  }
  
  window.ivars.issue.savePending = true;
  applyIssueState(window.ivars);
  
  var assignees = issue.assignees.map((u) => u.login);
  
  var url = `https://api.github.com/repos/${owner}/${repo}/issues`;
  var request = api(url, {
    headers: { 
      Authorization: "token " + getIvars().token,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }, 
    method: "POST",
    body: JSON.stringify({
      title: issue.title,
      body: issue.body,
      assignees: assignees,
      milestone: keypath(issue, "milestone.number"),
      labels: issue.labels.map((l) => l.name)
    })
  });
  
  return new Promise((resolve, reject) => {
    request.then(function(body) {
      window.ivars.issue = body;
      var q = window.ivars.issue.savePendingQueue;
      window.ivars.issue.savePending = false;
      if (q) {
        delete window.ivars.issue.savePendingQueue;
      }
      applyIssueState(window.ivars);
      resolve();
      if (q) {
        q.forEach((p) => {
          p.resolve();
        });
      }
    }).catch(function(err) {
      var q = window.ivars.issue.savePendingQueue;
      window.ivars.issue.savePending = false;
      if (q) {
        delete window.ivars.issue.savePendingQueue;
      }
      console.log(err);
      reject(err);
      if (q) {
        q.forEach((p) => {
          p.reject(err);
        });
      }
    });
  });
  
}

function patchIssue(patch) {
  window.ivars.issue = Object.assign({}, window.ivars.issue, patch);
  applyIssueState(window.ivars);
  return applyPatch(patch);
}

function editComment(commentIdx, newBody) {
  if (commentIdx == 0) {
    return patchIssue({body: newBody});
  } else {
    commentIdx--;
    window.ivars.issue.allComments[commentIdx].body = newBody;
    applyIssueState(window.ivars);
    return applyCommentEdit(window.ivars.issue.allComments[commentIdx].id, newBody);
  }
}

function deleteComment(commentIdx) {
  if (commentIdx == 0) return; // cannot delete first comment
  commentIdx--;
  var c = window.ivars.issue.allComments[commentIdx];
  window.ivars.issue.allComments = window.ivars.issue.allComments.splice(commentIdx+1, 1);
  applyIssueState(window.ivars);
  return applyCommentDelete(c.id);
}

function addComment(body) {
  var now = new Date().toISOString();
  window.ivars.issue.allComments.push({
    body: body,
    user: getIvars().me,
    id: "new",
    updated_at: now,
    created_at: now
  });
  applyIssueState(window.ivars);
  return applyComment(body);
}

function addReaction(commentIdx, reactionContent) {
  var reaction = {
    id: "new",
    user: getIvars().me,
    content: reactionContent,
    created_at: new Date().toISOString()
  };
  var owner = getIvars().issue._bare_owner;
  var repo = getIvars().issue._bare_repo;
  var num = getIvars().issue.number;
  
  var url;
  if (commentIdx == 0) {
    window.ivars.issue.reactions.push(reaction);
    url = `https://api.github.com/repos/${owner}/${repo}/issues/${num}/reactions`
  } else {
    commentIdx--;
    var c = window.ivars.issue.allComments[commentIdx];
    c.reactions.push(reaction);
    url = `https://api.github.com/repos/${owner}/${repo}/issues/comments/${c.id}/reactions`
  }
  
  applyIssueState(window.ivars);  
  var request = api(url, {
    headers: {
      Authorization: "token " + getIvars().token,
      'Content-Type': 'application/json',
      'Accept': 'application/vnd.github.squirrel-girl-preview'
    },
    method: 'POST',
    body: JSON.stringify({content: reactionContent})
  });
  return new Promise((resolve, reject) => {
    request.then(function(body) {
      reaction.id = body.id;
      applyIssueState(window.ivars);
      resolve();
    }).catch(function(err) {
      console.error("Add reaction failed", err);
      reject(err);
    });
  });
}

function deleteReaction(commentIdx, reactionID) {
  if (reactionID === "new") {
    console.log("Cannot delete pending reaction");
    return;
  }

  if (commentIdx == 0) {
    window.ivars.issue.reactions = window.ivars.issue.reactions.filter((r) => r.id !== reactionID);
  } else {
    commentIdx--;
    var c = window.ivars.issue.allComments[commentIdx];
    c.reactions = c.reactions.filter((r) => r.id !== reactionID);
  }
  
  var url = `https://api.github.com/reactions/${reactionID}`
  applyIssueState(window.ivars);  
  var request = api(url, {
    headers: {
      Authorization: "token " + getIvars().token,
      'Content-Type': 'application/json',
      'Accept': 'application/vnd.github.squirrel-girl-preview'
    },
    method: 'DELETE'
  });
  return new Promise((resolve, reject) => {
    request.then(function(body) {
      resolve();
    }).catch(function(err) {
      console.error("Add reaction failed", err);
      reject(err);
    });
  });
}

var keypath = function(obj, path) {
  if (!obj) return null;
  if (!path) return obj;
  var pattern = /(\w[\w\d]+)\[(\d+)\]/;
  path = path.split('.')
  for (var i = 0; i < path.length; i++) {
    var prop = path[i];
    var match = prop.match(pattern);
    var idx = null;
    if (match) {
      prop = match[1];
      idx = parseInt(match[2]);
    }
    if (obj != null && typeof(obj) === 'object' && prop in obj) {
      obj = obj[prop];
      if (idx !== null) {
        if (Array.isArray(obj)) {
          obj = obj[idx];
        } else {
          return null;
        }
      }
    } else {
      return null;
    }
  }
  return obj;
}

var setKeypath = function(obj, path, value) {
  if (!obj) return;
  if (!path) return;
  path = path.split('.')
  for (var i = 0; i < path.length - 1; i++) {
    var prop = path[i];
    if (obj != null && prop in obj) {
      obj = obj[prop];
    } else {
      return;
    }
  }
  
  var prop = path[path.length-1];
  obj[prop] = value;
}

var markedRenderer = new marked.Renderer();

markedRenderer.defaultListItem = markedRenderer.listitem;
markedRenderer.listitem = function(text) {
  var result = this.defaultListItem(text);
  result = result.replace(/\[ \]/, '<input type="checkbox">');
  result = result.replace(/\[x\]/, '<input type="checkbox" checked>');
  return result;
}

markedRenderer.list = function(body, ordered) {
  if (body.indexOf('<input type="checkbox"') != -1) {
    return "<ul class='taskList'>" + body + "</ol>";
  } else {
    if (ordered) {
      return "<ol>" + body + "</ol>";
    } else {
      return "<ul>" + body + "</ul>";
    }
  }
}

markedRenderer.defaultLink = markedRenderer.link;
markedRenderer.link = function(href, title, text) {
  var lowerHref = href.toLowerCase();
  if (lowerHref.indexOf("?") != -1) {
    lowerHref = lowerHref.substring(0, lowerHref.indexOf("?"));
  }
  if (lowerHref.endsWith('.mov') || lowerHref.endsWith('.mp4')) {
    if (href.indexOf("://www.dropbox.com") != -1 && href.endsWith("?dl=0")) {
      href = href.replace("?dl=0", "?dl=1");
    }
    return `<video src="${href}" title="${title}" controls></video>`;
  } else {
    return markedRenderer.defaultLink(href, title, text);
  }
};

markedRenderer.text = function(text) {
  return emojify(githubLinkify(getIvars().issue._bare_owner, getIvars().issue._bare_repo, text));
}

var ghost = {
  login: "ghost",
  id: 10137,
  avatar_url: "https://avatars1.githubusercontent.com/u/10137?v=3"
};

var langMapping = {
  'objective-c': 'objc',
  'c#' : 'cs'
}

var markdownOpts = {
  renderer: markedRenderer,
  gfm: true,
  tables: true,
  breaks: true,
  pedantic: false,
  sanitize: false,
  smartLists: true,
  smartypants: false,
  highlight: function (code, lang) {
    if (lang) {
      lang = langMapping[lang] || lang;
      return hljs.highlightAuto(code, [lang]).value;
    } else {
      return code;
    }
  }
};

var AvatarIMG = React.createClass({
  propTypes: {
    user: React.PropTypes.object,
    size: React.PropTypes.number
  },
  
  getDefaultProps: function() {
    return {
      user: ghost,
      size: 32
    };
  },
  
  getInitialState: function() {
    return {
      loading: true,
      failed: false,
      identicon: null,
    }
  },
  
  pointSize: function() {
    var s = 32;
    if (this.props.size) {
      s = this.props.size;
    }
    return s;
  },
  
  pixelSize: function() {
    return this.pointSize() * 2;
  },
  
  avatarURL: function() {
    var avatarURL = this.props.user.avatar_url;
    if (avatarURL == null) {
      avatarURL = "https://avatars.githubusercontent.com/u/" + this.props.user.id + "?v=3";
    }
    avatarURL += "&s=" + this.pixelSize();
    return avatarURL;
  },
  
  fail: function() {
    this.setState(Object.assign({}, this.state, {failed:true}));
  },
  
  loaded: function() {
    this.setState(Object.assign({}, this.state, {loading:false}));
  },
  
  render: function() {    
    var s = this.pointSize();
    if (this.state.failed || this.state.loading) {
      return h('img',
               Object.assign({},
                             this.props,
                             {
                               className: "avatar",
                               src:this.state.identicon,
                               width:s,
                               height:s,
                             }));
    } else {
      return h('img',
               Object.assign({},
                             this.props,
                             {
                               className: "avatar",
                               src:this.avatarURL(),
                               width:s,
                               height:s,
                               onerror:this.fail,
                             }));
    }
  },
  
  componentWillMount: function() {
    var url = this.avatarURL();
    var cacheKey = url;
    if (!window.identiconCache) {
      window.identiconCache = {};
    }
    var myIdenticon = window.identiconCache[cacheKey];
    if (myIdenticon == null) {
      var hash = md5(this.props.user.login);
      myIdenticon = "data:image/png;base64," + new Identicon(hash, { size: this.pixelSize(), margin: 0.05 }).toString();
      window.identiconCache[cacheKey] = myIdenticon;
    }
    
    this.setState(Object.assign({}, this.state, {identicon: myIdenticon}));
    
    var img = document.createElement('img');
    img.onload = () => { this.loaded(); };
    img.src = url;
  }
});

var EventIcon = React.createClass({
  propTypes: {
    event: React.PropTypes.string.isRequired
  },
  
  render: function() {
    var icon;
    var pushX = 0;
    var color = null;
    switch (this.props.event) {
      case "assigned":
        icon = "user";
        break;
      case "unassigned":
        icon = "user-times";
        break;
      case "labeled":
        icon = "tags";
        break;
      case "unlabeled":
        icon = "tags";
        break;
      case "opened":
      case "reopened":
        icon = "circle-o";
        color = "green";
        break;
      case "closed":
        icon = "times-circle-o";
        color = "red";
        break;
      case "milestoned":
        icon = "calendar";
        break;
      case "unmilestoned":
      case "demilestoned":
        icon = "calendar-times-o";
        break;
      case "locked":
        icon = "lock";
        pushX = "2";
        break;
      case "unlocked":
        icon = "unlock";
        break;
      case "renamed":
        icon = "pencil-square";
        break;
      case "referenced":
      case "merged":
        icon = "git-square";
        break;
      case "cross-referenced":
        icon = "hand-o-right";
        break;
      default:
        console.log("unknown event", this.props.event);
        icon = "exclamation-circle";
        break;
    }
    
    var opts = {className:"eventIcon fa fa-" + icon, style: {}};
    if (pushX != 0) {
      opts.style.paddingLeft = pushX;
    }
    if (color) {
      opts.style.color = color;
    }
    return h("i", opts);
  }
});

var EventUser = React.createClass({
  propTypes: { user: React.PropTypes.object },
  getDefaultProps: function() {
    return {
      user: ghost
    };
  },
  
  render: function() {
    var user = this.props.user || ghost;
    return h("span", {className:"eventUser"},
      h(AvatarIMG, {user:user, size:16}),
      user.login
    );
  }
});

var AssignedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    var actor = this.props.event.assigner || this.props.event.actor;
    if (this.props.event.assignee.id == actor.id) {
      return h("span", {}, "self assigned this");
    } else {
      return h("span", {},
        h("span", {}, "assigned this to "),
        h(EventUser, {user:this.props.event.assignee})
      );
    }
  }
});

var UnassignedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    // XXX: GitHub bug always sets the actor to the assignee.
    return h("span", {}, "is no longer assigned");
  }
});

var MilestoneEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    if (this.props.event.milestone) {
      if (this.props.event.event == "milestoned") {
        return h("span", {},
          "modified the milestone: ",
          h("span", {className: "eventMilestone"}, this.props.event.milestone.title)
        );
      } else {
        return h("span", {},
          "removed the milestone: ",
          h("span", {className: "eventMilestone"}, this.props.event.milestone.title)
        );
      }
    } else {
      return h("span", {}, "unset the milestone");
    }
  }
});

var Label = React.createClass({
  propTypes: { 
    label: React.PropTypes.object.isRequired,
    canDelete: React.PropTypes.bool,
    onDelete: React.PropTypes.func,
  },
  
  onDeleteClick: function() {
    if (this.props.onDelete) {
      this.props.onDelete(this.props.label);
    }
  },
  
  render: function() {
    // See http://stackoverflow.com/questions/12043187/how-to-check-if-hex-color-is-too-black
    var rgb = parseInt(this.props.label.color, 16);   // convert rrggbb to decimal
    var r = (rgb >> 16) & 0xff;  // extract red
    var g = (rgb >>  8) & 0xff;  // extract green
    var b = (rgb >>  0) & 0xff;  // extract blue

    var luma = 0.2126 * r + 0.7152 * g + 0.0722 * b; // per ITU-R BT.709

    var textColor = luma < 128 ? "white" : "black";
    
    var extra = [];
    var style = {backgroundColor:"#"+this.props.label.color, color:textColor};
    
    if (this.props.canDelete) {
      extra.push(h('span', {className:'LabelDelete Clickable', onClick:this.onDeleteClick}, 
        h('i', {className:'fa fa-trash-o'})
      ));
      style = Object.assign({}, style, {borderTopRightRadius:"0px", borderBottomRightRadius:"0px"});
    }
    
    return h("span", {className:"LabelContainer"},
      h("span", {className:"label", style:style},
        this.props.label.name
      ),
      ...extra
    );
  }
});

var LabelEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    var elements = [];
    elements.push(this.props.event.event);
    var labels = this.props.event.labels.filter(function(l) { return l != null && l.name != null; });
    elements = elements.concat(labels.map(function(l, i) {
      return [" ", h(Label, {key:i, label:l})]
    }).reduce(function(c, v) { return c.concat(v); }, []));
    return h("span", {}, elements);
  }
});

var RenameEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    return h("span", {}, 
      "changed the title from ",
      h("span", {className:"eventTitle"}, this.props.event.rename.from || "empty"),
      " to ",
      h("span", {className:"eventTitle"}, this.props.event.rename.to || "empty")
    );
  }
});

function expandCommit(event) {
  try {
    var committish = event.commit_id.slice(0, 10);
    var commitURL = event.commit_url.replace("api.github.com/repos/", "github.com/").replace("/commits/", "/commit/");
    return [committish, commitURL];
  } catch (exc) {
    console.log("Unable to expand commit", exc, event);
    return ["", ""];
  }
}

var ReferencedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    var [committish, commitURL] = expandCommit(this.props.event);

    var authoredBy = null;
    if (this.props.event.ship_commit_author &&
        this.props.event.ship_commit_author.login !=
        this.props.event.actor.login) {
      authoredBy = h("span", {},
                     "(authored by ",
                     h(EventUser, {user: this.props.event.ship_commit_author}),
                     ")"
                    );
    }

    return h("span", {},
      "referenced this issue in commit ",
      h("a", {className: "shaLink", href:commitURL, target:"_blank"}, committish),
      authoredBy
    );
  }
});

function getOwnerRepoTypeNumberFromURL(url) {
  if (!url) url = "";
  var capture = url.match(
    /https:\/\/api.github.com\/repos\/([^\/]+)\/([^\/]+)\/(issues|pulls|commits)\/([a-z0-9]+)/);

  if (capture) {
    return {
      owner: capture[1],
      repo: capture[2],
      type: capture[3],
      number: capture[4],
    };
  } else {
    return { owner: "", repo: "", type: "", number: "" };
  }
}

var CrossReferencedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    var urlParts = getOwnerRepoTypeNumberFromURL(
      this.props.event.source.url);

    var referencedRepoName = `${urlParts.owner}/${urlParts.repo}`;
    var repoName = getIvars().issue._bare_owner + "/" + getIvars().issue._bare_repo;

    if (repoName === referencedRepoName) {
      return h("span", {}, "referenced this issue");
    } else {
      // Only bother to show the repo name if the reference comes from another repo.
      return h("span", {},
               "referenced this issue in ",
               h("b", {}, referencedRepoName)
              );
    }
  }
});

var MergedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    var [committish, commitURL] = expandCommit(this.props.event);
    return h("span", {},
      "merged this request with commit ",
      h("a", {href:commitURL, target:"_blank"}, committish)
    );
  }
});

var ClosedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    if (typeof(this.props.event.commit_id) === "string") {
      var [committish, commitURL] = expandCommit(this.props.event);

      var authoredBy = null;
      if (this.props.event.ship_commit_author &&
          this.props.event.ship_commit_author.login !=
          this.props.event.actor.login) {
        authoredBy = h("span", {key:"authoredBy"},
                       "(authored by ",
                       h(EventUser, {user: this.props.event.ship_commit_author}),
                       ")"
                      );
      }

      return h("span", {key:"with"},
        "closed this issue with commit ",
        h("a",
          {
            className: "shaLink",
            href:commitURL,
            target:"_blank"
          },
          committish),
        authoredBy
      );
    } else {
      return h("span", {key:"without"}, "closed this issue");
    }
  }
});
      
var UnknownEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    return h("span", {}, this.props.event.event);
  }
});

var ClassForEventDescription = function(event) {
  switch (event.event) {
    case "assigned": return AssignedEventDescription;
    case "unassigned": return UnassignedEventDescription;
    case "milestoned":
    case "demilestoned": return MilestoneEventDescription;
    case "labeled": 
    case "unlabeled": return LabelEventDescription;
    case "renamed": return RenameEventDescription;
    case "referenced": return ReferencedEventDescription;
    case "merged": return MergedEventDescription;
    case "closed": return ClosedEventDescription;
    case "cross-referenced": return CrossReferencedEventDescription;
    default: return UnknownEventDescription
  }
}

var CrossReferencedEventBody = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    var issueStateLabel = (this.props.event.ship_issue_state === "open") ? "Open" : "Closed";
    var issueStateClass = (this.props.event.ship_issue_state === "open") ? "issueStateOpen" : "issueStateClosed";

    if (this.props.event.ship_is_pull_request) {
      if (this.props.event.ship_issue_state === "closed" &&
          this.props.event.ship_pull_request_merged) {
        issueStateLabel = "Merged";
        issueStateClass = "issueStateMerged";
      }
    }

    var urlParts = getOwnerRepoTypeNumberFromURL(this.props.event.source.url);
    var destURL =
      `https://github.com/${urlParts.owner}/${urlParts.repo}/` +
      (this.props.event.ship_is_pull_request ? "pull" : "issues") +
      `/${urlParts.number}`;

    return h("div", {},
             h("a",
               {
                 className: "issueTitle",
                 href: destURL,
                 target: "_blank"
               },
               this.props.event.ship_issue_title,
               " ",
               h("span",
                 {className: "issueNumber"},
                 "#",
                 urlParts.number)
              ),
              " ",
              h("span",
                {className: "issueState " + issueStateClass},
                issueStateLabel)
            );
  }
});

var CommitInfoEventBody = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },

  getInitialState: function() {
    return {
      showBody: false,
    };
  },

  toggleBody: function(clickEvent) {
    this.setState({showBody: !this.state.showBody});
    clickEvent.preventDefault();
  },

  getSubjectAndBodyFromMessage: function(message) {
    // GitHub never shows more than the first 69 characters
    // of a commit message without truncation.
    const maxSubjectLength = 69;
    var subject;
    var body;

    var lines = message.split(/\n/);
    var firstLine = lines[0];

    if (firstLine.length > maxSubjectLength) {
      subject = firstLine.substr(0, maxSubjectLength) + "\u2026";
      body = "\u2026" + message.substr(maxSubjectLength).trim();
    } else if (lines.length > 1) {
      subject = firstLine;
      body = lines.slice(1).join("\n").trim();
    } else {
      subject = message;
      body = null;
    }

    return [subject, body];
  },

  render: function() {
    var commitMessage = this.props.event.ship_commit_message || "";
    var message = commitMessage.trim();
    const [subject, body] = this.getSubjectAndBodyFromMessage(message);

    var bodyContent = null;
    if (this.state.showBody && body) {
      const linkifiedBody = githubLinkify(
        getIvars().issue._bare_owner,
        getIvars().issue._bare_repo,
        linkify(escape(body), {escape: false}));
      bodyContent = h("pre",
                      {
                        className: "referencedCommitBody",
                        dangerouslySetInnerHTML: {__html: linkifiedBody},
                      });
    }

    var expander = null;
    if (body && body.length > 0) {
      expander =
        h("a",
          {
            href: "#",
            onClick: this.toggleBody
          },
          h("button", {className: "referencedCommitExpander"}, "\u2026")
        );
    }

    const urlParts = getOwnerRepoTypeNumberFromURL(this.props.event.commit_url);
    return h("div", {},
             h("a",
               {
                 className: "referencedCommitSubject",
                 href: `https://github.com/${urlParts.owner}/${urlParts.repo}/commit/${this.props.event.commit_id}`,
               },
               subject
              ),
             expander,
             h("br", {}),
             bodyContent
           );
  },
});

var ClassForEventBody = function(event) {
  switch (event.event) {
    case "cross-referenced": return CrossReferencedEventBody;
    case "referenced": return CommitInfoEventBody;
    case "closed":
      if (typeof(event.commit_id) === "string") {
        return CommitInfoEventBody;
      } else {
        return null;
      }
    default: return null;
  }
}

var Event = React.createClass({
  propTypes: {
    event: React.PropTypes.object.isRequired,
    last: React.PropTypes.bool,
    veryLast: React.PropTypes.bool
  },
  
  render: function() {
    var className = "event";
    if (this.props.first) {
      className += " eventFirst";
    }
    if (this.props.veryLast) {
      className += " eventVeryLast";
    } else if (!this.props.last) {
      className += " eventDelimited";
    } else {
      className += " eventLast";
    }

    var user;
    if (this.props.event.event === 'cross-referenced') {
      user = this.props.event.source.actor;
    } else {
      user = this.props.event.actor;
    }

    var eventBodyClass = ClassForEventBody(this.props.event);

    return h('div', {className:className},
      h(EventIcon, {event: this.props.event.event }),
      h("div", {className: "eventContent"},
        h("div", {},
          h(EventUser, {user: user}),
          " ",
          h(ClassForEventDescription(this.props.event), {event: this.props.event}),
          " ",
          h(TimeAgo, {className:"eventTime", live:true, date:this.props.event.created_at})),
        eventBodyClass ? h(eventBodyClass, {event: this.props.event}) : null
      )
    );
  }
});

var ActivityList = React.createClass({
  propTypes: {
    issue: React.PropTypes.object.isRequired
  },
  
  allComments: function() {
    var comments = [];
    for (var k in this.refs) {
      if (k.indexOf("comment.") == 0) {
        var c = this.refs[k];
        comments.push(c);
      }
    }
    return comments;
  },
  
  needsSave: function() {
    var comments = this.allComments();
    return comments.length > 0 && comments.reduce((a, x) => a || x.needsSave(), false);
  },
  
  activeComment: function() {
    var cs = this.allComments().filter((c) => c.hasFocus());
    if (cs.length > 0) return cs[0];
    return null;
  },
  
  save: function() {
    var c = this.allComments();
    return Promise.all(c.filter((x) => x.needsSave()).map((x) => x.save()));
  },
  
  render: function() {        
    var firstComment = {
      body: this.props.issue.body,
      user: this.props.issue.user,
      id: this.props.issue.id,
      updated_at: this.props.issue.updated_at || new Date().toISOString(),
      created_at: this.props.issue.created_at || new Date().toISOString(),
      reactions: this.props.issue.reactions
    };
    
    // need to merge events and comments together into one array, ordered by date
    var eventsAndComments = (!!(firstComment.id) || this.props.issue.savePending) ? [firstComment] : [];
    
    eventsAndComments = eventsAndComments.concat(this.props.issue.allEvents || []);
    eventsAndComments = eventsAndComments.concat(this.props.issue.allComments || []);
    
    eventsAndComments = eventsAndComments.sort(function(a, b) {
      var da = new Date(a.created_at);
      var db = new Date(b.created_at);
      if (da < db) {
        return -1;
      } else if (db < da) {
        return 1;
      } else {
        if (a.id < b.id) {
          return -1;
        } else if (b.id < a.id) {
          return 1;
        } else {
          return 0;
        }
      }
    });
    
    // need to filter certain types of events from displaying
    eventsAndComments = eventsAndComments.filter(function(e) {
      if (e.event == undefined) {
        return true;
      } else {
        switch (e.event) {
          case "subscribed": return false;
          case "mentioned": return false; // mention events are beyond worthless in the GitHub API
          case "referenced": return e.commit_id != null;
          default: return true;
        }
      }
    });
    
    // roll up successive label elements into a single event
    var labelRollup = null;
    eventsAndComments.forEach(function(e) {
      if (e.event == "labeled" || e.event == "unlabeled") {
        if (labelRollup != null) {
          if (labelRollup.event == e.event 
              && labelRollup.actor.id == e.actor.id 
              && new Date(e.created_at) - new Date(labelRollup.created_at) < (2*60*1000 /*2mins*/)) {
            labelRollup.labels.push(e.label);
            e._rolledUp = true;
          } else {
            labelRollup = null;
          }
        }
        if (labelRollup == null) {
          labelRollup = e;
          e.labels = [e.label];
        }
      } else {
        labelRollup = null;
      }
    });
    
    // now filter rolled up labels
    eventsAndComments = eventsAndComments.filter(function(e) { 
      return !(e._rolledUp);
    });
    
    var counter = { c: 0, e: 0 };
    return h('div', {className:'activityContainer'},
      h('div', {className:'activityList'}, 
        eventsAndComments.map(function(e, i, a) {
          if (e.event != undefined) {
            counter.e = counter.e + 1;
            var next = a[i+1];
            return h(Event, {
              key:(e.id?(e.id+"-"+i):""+i), 
              event:e, 
              first:(i==0 || a[i-1].event == undefined),
              last:(next!=undefined && next.event==undefined),
              veryLast:(next==undefined)
            });
          } else {
            counter.c = counter.c + 1;
            return h(Comment, {key:(e.id?(e.id+"-"+i):""+i), ref:"comment." + i, comment:e, first:i==0, commentIdx:counter.c-1})
          }
        })
      )
    );
  }
});

var AddCommentHeader = React.createClass({
  render: function() {
    var buttons = [];
    
    if (this.props.previewing) {
      buttons.push(h('i', {key:"eye-slash", className:'fa fa-eye-slash', title:"Toggle Preview", onClick:this.props.togglePreview}));
    } else {
      buttons.push(h('i', {key:"paperclip", className:'fa fa-paperclip fa-flip-horizontal', title:"Attach Files", onClick:this.props.attachFiles}));
      if (this.props.hasContents) {
        buttons.push(h('i', {key:"eye", className:'fa fa-eye', title:"Toggle Preview", onClick:this.props.togglePreview}));
      }
    }
  
    return h('div', {className:'commentHeader'},
      h(AvatarIMG, {user:getIvars().me, size:32}),
      h('span', {className:'addCommentLabel'}, 'Add Comment'),
      h('div', {className:'commentControls'}, buttons)
    );
  }
});

var AddCommentFooter = React.createClass({
  render: function() {
    var issue = getIvars().issue;
    var isNewIssue = !(issue.number);
    var canSave = false;
    
    if (isNewIssue) {
      canSave = (issue.title || "").trim().length > 0 && !!(issue._bare_owner) && !!(issue._bare_repo);
    } else {
      canSave = this.props.hasContents;
    }
    
    var contents = [];
    
    if (!this.props.previewing) {
      contents.push(h('a', {
        key:'markdown', 
        className:'markdown-mark formattingHelpButton', 
        target:"_blank", 
        href:"https://guides.github.com/features/mastering-markdown/", 
        title:"Open Markdown Formatting Guide"
      }));
    }
    
    if (this.props.canClose) {
      contents.push(h('div', {
        key:'close', 
        className:'Clickable addCommentButton addCommentCloseButton', 
        onClick:this.props.onClose}, 
        'Close Issue'
      ));
    } else if (this.props.editingExisting) {
      contents.push(h('div', {
        key:'cancel', 
        className:'Clickable addCommentButton addCommentCloseButton', 
        onClick:this.props.onCancel}, 
        'Cancel'
      ));
    }
    
    if (canSave) {
      contents.push(h('div', {
        key:'save', 
        className:'Clickable addCommentButton addCommentSaveButton', 
        onClick:this.props.onSave}, 
        (this.props.editingExisting ? 'Update' : (isNewIssue ? 'Save' : 'Comment'))
      ));
    } else {
      contents.push(h('div', {
        key:'save', 
        className:'Clickable addCommentButton addCommentSaveButton addCommentSaveButtonDisabled'}, 
        (this.props.editingExisting ? 'Update' : (isNewIssue ? 'Save' : 'Comment'))
      ));
    }
    
    return h('div', {className:'commentFooter'}, contents);
  }
});

var AddCommentUploadProgress = React.createClass({
  render: function() {
    return h('div', {className:'commentFooter'},
      h('span', {className:'commentUploadingLabel'}, "Uploading files "),
      h('i', {className:'fa fa-circle-o-notch fa-spin fa-3x fa-fw margin-bottom'})
    );
  }
});

var AddReactionOption = React.createClass({
  render: function() {
    return h('div', {className:'addReactionOption Clickable', onClick:this.props.onClick},
      h('span', {className:'addReactionOptionContent'}, emojifyReaction(this.props.reaction))
    );
  }
});

var AddReactionOptions = React.createClass({
  propTypes: {
    onEnd: React.PropTypes.func
  },
  
  onAdd: function(reaction) {
    if (this.props.onEnd) {
      this.props.onEnd();
    }
    if (this.props.onAdd) {
      this.props.onAdd(reaction);
    }
  },
  
  render: function() {
    var reactions = ["+1", "-1", "laugh", "confused", "heart", "hooray"];
    
    var buttons = reactions.map((r) => h(AddReactionOption, {key:r, reaction:r, onClick:()=>{this.onAdd(r);}}));
    buttons.push(h('i', {key:"close", className:'fa fa-times addReactionClose Clickable', onClick:this.props.onEnd}));
  
    return h('span', {className:'addReactionOptions'}, buttons);
  }
});

var AddReactionButton = React.createClass({
  render: function() {
    var button = h('i', Object.assign({}, this.props, {className:'fa fa-smile-o addReactionIcon'}));
    return button;
  }
});

var CommentControls = React.createClass({
  propTypes: {
    comment: React.PropTypes.object.isRequired,
    first: React.PropTypes.bool,
    editing: React.PropTypes.bool,
    hasContents: React.PropTypes.bool,
    previewing: React.PropTypes.bool,
    needsSave : React.PropTypes.func,
    togglePreview: React.PropTypes.func,
    attachFiles: React.PropTypes.func,
    beginEditing: React.PropTypes.func,
    cancelEditing: React.PropTypes.func,
    deleteComment: React.PropTypes.func,
    addReaction: React.PropTypes.func
  },
  
  getInitialState: function() {
    return {
      confirmingDelete: false,
      confirmingCancelEditing: false,
      addingReaction: false
    }
  },
  
  componentWillReceiveProps: function(newProps) {
    if (!newProps.editing) {
      this.setState({}); // cancel all confirmations
    }
  },
  
  confirmDelete: function() {
    this.setState({confirmingDelete: true});
  },
  
  cancelDelete: function() {
    this.setState({confirmingDelete: false});
  },
  
  performDelete: function() {
    this.setState({confirmingDelete: false});
    if (this.props.deleteComment) {
      this.props.deleteComment();
    }
  },

  confirmCancelEditing: function() {
    if (this.props.needsSave()) {
      this.setState({confirmingCancelEditing: true});
    } else {
      this.performCancelEditing();
    }
  },

  performCancelEditing: function() {
    this.setState({confirmingCancelEditing: false});
    if (this.props.cancelEditing) {
      this.props.cancelEditing();
    }
  },

  abortCancelEditing: function() {
    this.setState({confirmingCancelEditing: false});
  },
  
  toggleReactionOptions: function() {
    this.setState({addingReaction: !this.state.addingReaction});
  },
  
  render: function() {
    var buttons = [];
    if (this.props.editing) {
      if (this.state.confirmingCancelEditing) {
          buttons.push(h('span', {key:'confirm', className:'confirmCommentDelete'}, 
            " ",
            h('span', {key:'discard', className:'confirmDeleteControl Clickable', onClick:this.performCancelEditing}, 'Discard Changes'),
            " | ",
            h('span', {key:'cancel', className:'confirmDeleteControl Clickable', onClick:this.abortCancelEditing}, 'Save Changes')
          ));
      } else {
        if (this.props.previewing) {
          buttons.push(h('i', {key:"eye-slash", className:'fa fa-eye-slash', title:"Toggle Preview", onClick:this.props.togglePreview}));
        } else {
          buttons.push(h('i', {key:"paperclip", className:'fa fa-paperclip fa-flip-horizontal', title:"Attach Files", onClick:this.props.attachFiles}));
          if (this.props.hasContents) {
            buttons.push(h('i', {key:"eye", className:'fa fa-eye', title:"Toggle Preview", onClick:this.props.togglePreview}));
          }
        }
        buttons.push(h('i', {key:"edit", className:'fa fa-pencil-square', onClick:this.confirmCancelEditing}));
      }
    } else {
      if (this.state.confirmingDelete) {
        buttons.push(h('span', {key:'confirm', className:'confirmCommentDelete'}, 
          "Really delete this comment? ",
          h('span', {key:'no', className:'confirmDeleteControl Clickable', onClick:this.cancelDelete}, 'No'),
          " ",
          h('span', {key:'yes', className:'confirmDeleteControl Clickable', onClick:this.performDelete}, 'Yes')
        ));
      } else if (this.state.addingReaction) {
        buttons.push(h(AddReactionOptions, {key:"reactionOptions", onEnd:this.toggleReactionOptions, onAdd:this.props.addReaction}));
      } else {     
        buttons.push(h(AddReactionButton, {key:"addReaction", title: "Add Reaction", onClick:this.toggleReactionOptions})); 
        buttons.push(h('i', {key:"edit", className:'fa fa-pencil', onClick:this.props.beginEditing}));
        if (!this.props.first) {
          buttons.push(h('i', {key:"trash", className:'fa fa-trash-o', onClick:this.confirmDelete}));
        }
      }
    }
    return h('div', {className:'commentControls'}, buttons);
  }
});

var CommentHeader = React.createClass({  
  render: function() {
    var user = this.props.comment.user||this.props.comment.author;
    if (!user) user = ghost;
    var desc = " commented ";
    if (this.props.first) {
      desc = " filed ";
    }
    return h('div', {className:'commentHeader'},
      h(AvatarIMG, {user:user, size:32}),
      h('span', {className:'commentAuthor'}, user.login),
      h('span', {className:'commentTimeAgo'}, desc),
      h(TimeAgo, {className:'commentTimeAgo', live:true, date:this.props.comment.created_at}),
      h(CommentControls, this.props)
    );
  }
});

var CommentReaction = React.createClass({
  propTypes: { reactions: React.PropTypes.array },
  
  onClick: function() {
    if (this.props.onToggle) {
      this.props.onToggle(this.props.reactions[0].content);
    }
  },
  
  render: function() {
    var r0 = this.props.reactions[0];
    var title;
    if (this.props.reactions.length == 1) {
      title = r0.user.login + " reacted " + TimeAgoString(r0.created_at);
    } else if (this.props.reactions.length <= 3) {
      title = this.props.reactions.slice(0, 3).map((r) => r.user.login).join(", ")
    } else {
      title = r0.user.login + " and " + (this.props.reactions.length-1) + " others";
    }
    var me = getIvars().me.login;
    var mine = this.props.reactions.filter((r) => r.user.login === me).length > 0;
    return h("div", {className:"CommentReaction Clickable", title: title, key:r0.content, onClick:this.onClick}, 
      h("span", {className:"CommentReactionEmoji"}, emojifyReaction(r0.content)),
      h("span", {className:"CommentReactionCount" + (mine?" CommentReactionCountMine":"")}, ""+this.props.reactions.length)
    );
  }
});

var CommentReactions = React.createClass({
  propTypes: { reactions: React.PropTypes.array },
  
  render: function() {
    var reactions = this.props.reactions || [];
    
    reactions.sort((a, b) => {
      if (a.created_at < b.created_at) {
        return -1;
      } else if (a.created_at == b.created_at) {
        return 0;
      } else {
        return 1;
      }
    });
    
    var partitionMap = {};
    reactions.forEach((r) => {
      var l = partitionMap[r.content];
      if (!l) {
        partitionMap[r.content] = l = [];
      }
      l.push(r);
    });
    
    var partitions = [];
    for (var contentKey in partitionMap) {
      partitions.push(partitionMap[contentKey]);
    }
    
    partitions.sort((a, b) => {
      var d1 = new Date(a[0].created_at);
      var d2 = new Date(b[0].created_at);
      
      if (d1 < d2) {
        return -1;
      } else if (d1 == d2) {
        return 0;
      } else {
        return 1;
      }
    });
    
    var count = partitions.length;
    return h("div", {className:"ReactionsBar"},
      partitions.map((r, i) => h(CommentReaction, {key:r[0].content + "-" + i, reactions:r, onToggle:this.props.onToggle}))
    );
  }
});

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

function matchAll(re, str) {
  var matches = [];
  var match;
  while ((match = re.exec(str)) !== null) {
    matches.push(match);
  }
  return matches;
}

var CommentBody = React.createClass({
  propTypes: {
    body: React.PropTypes.string,
    onEdit: React.PropTypes.func /* function(newBody) */
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
        dangerouslySetInnerHTML: {__html:marked(body, markdownOpts)}
      });
    }
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
    var pattern = /(?:(?:\d+\.)|(?:\-)|(?:\*))\s+\[[x ]\].*(?:\n|$)/g;
    var matches = matchAll(pattern, body);
    
    if (srcIdx < matches.length && dstIdx < matches.length) {
      var srcMatch = matches[srcIdx];
      var dstMatch = matches[dstIdx];
      
      var withoutSrc = body.slice(0, srcMatch.index) + body.slice(srcMatch.index+srcMatch[0].length);
      var insertionPoint;
      insertionPoint = dstMatch.index;
      if (srcIdx < dstIdx) {
        insertionPoint += dstMatch[0].length - srcMatch[0].length;
      }
      
      var insertion = srcMatch[0];
      if (!insertion.endsWith("\n")) {
        insertion += "\n";
      }
      if (!dstMatch[0].endsWith("\n")) {
        insertion = "\n" + insertion;
      }
      body = withoutSrc.slice(0, insertionPoint) + insertion + withoutSrc.slice(insertionPoint)
      body = body.trim();
      
      this.updateLastRendered(body);
      this.props.onEdit(body);
    }
  },
  
  findTaskItems: function() {
    var el = ReactDOM.findDOMNode(this.refs.commentBody);
    
    // traverse dom, pre-order, rooted at el, looking for checkboxes
    // we're going to bind to those guys as we find them
    
    var nodes = [];
    preOrderTraverseDOM(el, (x) => nodes.push(x));
    
    var checks = nodes.filter((x) => x.nodeName == 'INPUT' && x.type == 'checkbox');
    
    checks.forEach((x, i) => {
      x.onchange = (evt) => {
        var checked = evt.target.checked;
        this.updateCheckbox(i, checked);
      };
    });


    // Find and bind sortables to task lists
    var rootTaskList = (x) => {
      var k = x.parentElement;
      while (k && k != el) {
        if (k.nodeName == 'UL' || k.nodeName == 'OL') {
          return false;
        }
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
        preOrderTraverseDOM(x, (li) => {
          if (li.nodeName == 'LI') {
            var handle = document.createElement('i');
            handle.className = "fa fa-bars taskHandle";
            li.insertBefore(handle, li.firstChild);
            handles.push(handle);
            counter.i++;
          }
        });
        var s = Sortable.create(x, {
          animation: 150,
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
              var srcIdx = offset + evt.oldIndex;
              var dstIdx = offset + evt.newIndex;
              this.moveTaskItem(srcIdx, dstIdx);
            }
          }
        });
      }
    });
  },
  
  componentDidMount: function() {
    this.findTaskItems();
  },
  
  componentDidUpdate: function() {
    this.findTaskItems();
  }
});

var Comment = React.createClass({
  propTypes: {
    comment: React.PropTypes.object,
    commentIdx: React.PropTypes.number,
    first: React.PropTypes.bool
  },

  getInitialState: function() {
    return {
      editing: !(this.props.comment),
      code: "",
      previewing: false,
      uploadCount: 0,
    };
  },
  
  componentWillReceiveProps: function(nextProps) {
    if (this.state.editing && nextProps.comment && this.props.comment && nextProps.comment.id != this.props.comment.id) {
      this.setState(Object.assign({}, this.state, {editing: false}));
    }
  },
  
  setInitialContents: function(contents) {
    this.setState(Object.assign({}, this.state, {code: contents}));
  },
  
  updateCode: function(newCode) {
    this.setState(Object.assign({}, this.state, {code: newCode}));
    if (window.documentEditedHelper) {
      window.documentEditedHelper.postMessage({});
    }
  },
  
  replaceInCode: function(original, replacement) {
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
  },
  
  beginEditing: function() {
    if (!this.state.editing) {
      this.setState(Object.assign({}, this.state, {
        previewing: false,
        editing: true,
        code: this.props.comment.body || ""
      }));
    }
  },
  
  cancelEditing: function() {
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
  },
  
  deleteComment: function() {
    deleteComment(this.props.commentIdx);
  },
  
  /* Called for task list edits that occur 
     e.g. checked a task button or reordered a task list
   */
  onTaskListEdit: function(newBody) {
    if (!this.props.comment || this.state.editing) {
      this.updateCode(newBody);
    } else {
      editComment(this.props.commentIdx, newBody);
    }
  },
  
  findReaction: function(reaction) {
    var me = getIvars().me;
    var existing = this.props.comment.reactions.filter((r) => r.content === reaction && r.user.login === me.login);
    return existing.length > 0 ? existing[0] : null;
  },
  
  addReaction: function(reaction) {
    var existing = this.findReaction(reaction);
    if (!existing) {
      addReaction(this.props.commentIdx, reaction);
    }
  },

  toggleReaction: function(reaction) {
    var existing = this.findReaction(reaction);
    if (existing) {
      deleteReaction(this.props.commentIdx, existing.id);
    } else {
      addReaction(this.props.commentIdx, reaction);
    }
  },
  
  togglePreview: function() {
    var previewing = !this.state.previewing;
    this.doFocus = !previewing;
    this.setState(Object.assign({}, this.state, {previewing:previewing}));
    var el = ReactDOM.findDOMNode(this);
    setTimeout(() => { 
      el.scrollIntoView();
      if (!previewing) {
        this.focusCodemirror();
      }
    }, 0);
  },
  
  hasFocus: function() {
    if (this.refs.codemirror) {
      var cm = this.refs.codemirror.getCodeMirror();
      return cm && cm.hasFocus(); 
    }
    return false;
  },
  
  focusCodemirror: function() {
    this.refs.codemirror.focus()
  },
  
  onBlur: function() {
    var isNewIssue = !(getIvars().issue.number);
    if (isNewIssue) {
      editComment(0, this.state.code);
    }
  },
  
  save: function() {
    var issue = getIvars().issue;
    var isNewIssue = !(issue.number);
    var isAddNew = !(this.props.comment);
    var body = this.state.code;
    
    var resetState = () => {
      this.setState(Object.assign({}, this.state, {code: "", previewing: false, editing: isAddNew}));
    };
    
    if (isNewIssue) {
      var canSave = (issue.title || "").trim().length > 0 && !!(issue._bare_owner) && !!(issue._bare_repo);
      if (canSave) {
        resetState();
        editComment(0, body);
        return saveNewIssue();
      }
    } else {
      resetState();
      if (body.trim().length > 0) {
        if (this.props.comment) {
          if (this.props.comment.body != body) {
            return editComment(this.props.commentIdx, body);
          }
        } else {
          return addComment(body);
        }
      }
    }
    
    return Promise.resolve();
  },
  
  saveAndClose: function() {
    patchIssue({state: "closed"});
    this.save();    
  },
  
  needsSave: function() {
    var issue = getIvars().issue;
    var isNewIssue = !(issue.number);
    var isAddNew = !(this.props.comment);
    var body = this.state.code;
    
    if (isNewIssue) {
      var canSave = (issue.title || "").trim().length > 0 && !!(issue._bare_owner) && !!(issue._bare_repo);
      return canSave;
    } else {
      if (this.props.comment && !this.state.editing) {
        return false;
      }
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
  },

  renderCodemirror: function() {
    var isNewIssue = !(getIvars().issue.number);
  
    return h('div', {className: 'CodeMirrorContainer', onClick:this.focusCodemirror},
      h(Codemirror, {
        ref: 'codemirror',
        value: this.state.code,
        onChange: this.updateCode,
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
  },
  
  renderCommentBody: function(body) {
    return h(CommentBody, { body: body, onEdit:this.onTaskListEdit });
  },
  
  renderHeader: function() {
    if (this.props.comment) {
      return h(CommentHeader, {
        ref:'header',
        comment:this.props.comment, 
        first:this.props.first,
        editing:this.state.editing,
        hasContents:this.state.code.trim().length>0,
        previewing:this.state.previewing,
        needsSave:this.needsSave,
        togglePreview:this.togglePreview,
        attachFiles:this.selectFiles,
        beginEditing:this.beginEditing,
        cancelEditing:this.cancelEditing,
        deleteComment:this.deleteComment,
        addReaction:this.addReaction
      });
    } else {
      return h(AddCommentHeader, {
        ref:'header', 
        hasContents:this.state.code.trim().length>0,
        previewing:this.state.previewing,
        togglePreview:this.togglePreview,
        attachFiles:this.selectFiles
      });
    }
  },
  
  renderFooter: function() {
    if (this.state.editing) {
      if (this.state.uploadCount > 0) {
        return h(AddCommentUploadProgress, {ref:'uploadProgress'});
      } else {
        var editingExisting = !!(this.props.comment);
        var canClose = !editingExisting && getIvars().issue.number > 0 && getIvars().issue.state === "open";
        return h(AddCommentFooter, {
          ref:'footer', 
          canClose: canClose,
          previewing: this.state.previewing,
          onClose: this.saveAndClose, 
          onSave: this.save,
          onCancel: this.cancelEditing,
          hasContents: this.state.code.trim().length > 0,
          editingExisting: !!(this.props.comment)
        })
      }
    } else if ((keypath(this.props, "comment.reactions")||[]).length > 0) {
      return h(CommentReactions, {reactions:this.props.comment.reactions, onToggle:this.toggleReaction});
    } else {
      return h('div', {className:'commentEmptyFooter'});
    }
  },

  render: function() {
    if (!this.state.editing && !this.props.comment) {
      console.log("Invalid state detected! Must always be editing if no comment");
    }
  
    var showEditor = this.state.editing && !this.state.previewing;
    var body = this.state.editing ? this.state.code : this.props.comment.body;
    
    var outerClass = 'comment';
    
    if (!this.props.comment) {
      outerClass += ' addComment';
    }

    return h('div', {className:outerClass},
      this.renderHeader(),
      (showEditor ? this.renderCodemirror() : this.renderCommentBody(body)),
      this.renderFooter()
    );
  },
  
  selectFiles: function() {
    FilePicker({
      multiple: true
    }, (files) => {
      this.attachFiles(files);
    });
  },
  
  updateUploadCount: function(delta) {
    this.setState(Object.assign({}, this.state, {uploadCount:this.state.uploadCount+delta}));
  },
  
  attachFiles: function(fileList) {
    if (!(this.refs.codemirror)) {
      return;
    }
    
    var files = [];
    for (var i = 0; i < fileList.length; i++) {
      files.push(fileList[i]);
    }
    
    this.updateUploadCount(files.length);
    var cm = this.refs.codemirror.getCodeMirror();
    files.forEach((file) => {
      var filename = file.name;
      var isImage = file.type.indexOf("image/") == 0;
      var placeholder = `[Uploading ${filename}](...)`;
      if (isImage) {
        placeholder = "!" + placeholder;
      }
      cm.replaceSelection(placeholder + "\n");
      
      uploadAttachment(getIvars().token, file).then((url) => {
        var link = `[${filename}](${url})`
        if (isImage) {
          link = "!" + link;
        }
        this.replaceInCode(placeholder, link);
        this.updateUploadCount(-1);
      }).catch((err) => {
        console.log(err);
        this.replaceInCode(placeholder, "");
        this.updateUploadCount(-1);
        alert(err);
      });
    });
  },
  
  configureCM: function() {
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
            words: getIvars().assignees.map((a) => '@' + a.login),
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
        } else {
          // handle the upload natively in the browser
          var files = e.dataTransfer.files;
          if (files.length > 0) {
            this.attachFiles(files);
            e.stopPropagation();
            e.preventDefault();
            return true;
          } else {
            return false;
          }
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
        )
      };
      
      // Configure some formatting controls
      cm.setOption('extraKeys', {
        'Cmd-B': cm.extraCommands.bold,
        'Cmd-I': cm.extraCommands.italic,
        'Cmd-S': () => { this.save(); },
        'Shift-Tab': shiftTab,
        'Tab': 'indentMore'
      });
      
      cm.on('blur', () => { this.onBlur(); });
    }
  },
  
  applyMarkdownFormat: function(format) {
    if (!(this.refs.codemirror)) {
      return;
    }
    
    var cm = this.refs.codemirror.getCodeMirror();
    if (format in cm.extraCommands) {
      cm.extraCommands[format](cm);
    } else {
      cm.execCommand(format);
    }
  },
  
  componentDidUpdate: function() {
    this.configureCM();
  },
  
  componentDidMount: function() {
    this.configureCM();
  }
});

var IssueIdentifier = React.createClass({
  propTypes: { issue: React.PropTypes.object },
  
  render: function() {
    return h('div', { className: 'IssueIdentifier' },
      h('span', { className: 'IssueIdentifierOwnerRepo' },
        this.props.issue._bare_owner + "/" + this.props.issue._bare_repo
      ),
      h('span', { className: 'IssueIdentifierNumber' },
        "#" + this.props.issue.number
      )
    );
  }
});

var HeaderLabel = React.createClass({
  propTypes: { title: React.PropTypes.string },
  
  render: function() {
    return h('span', {className:'HeaderLabel'}, this.props.title + ": ");
  }
});

var HeaderSeparator = React.createClass({
  render: function() {
    return h('div', {className:'HeaderSeparator'});
  }
});

var InputSaveButton = React.createClass({
  
  render: function() {
    var props = Object.assign({}, {className:'InputSaveButton'}, this.props);
    return h('span', props, 'Save ↩︎');
  }
});

var IssueTitle = React.createClass({
  propTypes: { issue: React.PropTypes.object },
  
  titleChanged: function(newTitle, goNext) {
    var promise = null;
    if (this.state.edited) {
      this.setState({edited: false});
      promise = patchIssue({title: newTitle});
    }
    if (goNext) {
      this.props.focusNext("title");
    }
    return promise || Promise.resolve();
  },

  getInitialState: function() {
    return { edited: false };
  },
  
  componentWillReceiveProps: function(newProps) {
    if (this.state.edited) {
      if (newProps.issue.number == this.props.issue.number) {
        // ignore the change, we're editing!
      } else {
        this.setState({edited: false})
      }
    } else {
      this.setState({edited: false})
    }
  },
  
  onEdit: function(didEdit, editedVal) {
    this.setState({edited: this.props.issue.title != editedVal, editedValue: editedVal})
  },
  
  titleSaveClicked: function(evt) {
    return this.titleChanged(this.state.editedValue, false);
  },
  
  focus: function() {
    this.refs.input.focus()
  },
  
  hasFocus: function() {
    return this.refs.input.hasFocus();
  },
  
  needsSave: function() {
    if (this.refs.input) {
      return this.refs.input.isEdited();
    } else {
      return false;
    }
  },
  
  save: function() {
    if (this.needsSave()) {
      return this.titleSaveClicked();
    } else {
      return Promise.resolve();
    }
  },
  
  componentDidMount: function() {
    if (!window.inColumnBrowser) {
      this.focus();
    }
  },
  
  render: function() {
    var val = this.props.issue.title;
    if (this.state.edited) {
      val = this.state.editedValue;
    }
  
    var children = [
      h(HeaderLabel, {title:'Title'}),
      h(SmartInput, {ref:"input", element:Textarea, initialValue:this.props.issue.title, value:val, className:'TitleArea', onChange:this.titleChanged, onEdit:this.onEdit, placeholder:"Required"}),
      h(IssueNumber, {issue: this.props.issue})
    ];
    
    if (this.state.edited && this.props.issue.number != null) {
      children.splice(2, 0, h(InputSaveButton, {key: "titleSave", onClick: this.titleSaveClicked, style: { marginRight: "8px" } }));
    }
  
    return h('div', {className:'IssueTitle'}, ...children);
  }
});

var IssueNumber = React.createClass({
  propTypes: { issue: React.PropTypes.object },
  render: function() {
    var val = "";
    if (this.props.issue.number) {
      val = this.props.issue.number;
    }
    return h('div', {className:'IssueNumber'},
      val      
    );
  }
});

var RepoField = React.createClass({
  propTypes: { 
    issue: React.PropTypes.object
  },
  
  onChange: function(newRepo, goNext) {
    var fail = () => {
      setTimeout(() => {
        this.refs.input.refs.typeInput.setState({value: this.repoValue()});
      }, 1);
    };
  
    if (newRepo.indexOf('/') == -1) {
      fail();
      return Promise.reject("Invalid repo");
    }
    
    var [owner, repo] = newRepo.split("/");
    
    var repoInfo = getIvars().repos.find((x) => x.full_name == newRepo);
    
    if (!repoInfo) {
      fail();
      return Promise.reject("Invalid repo");
    }
    
    var state = getIvars();
    state = Object.assign({}, state);
    state.issue = Object.assign({}, state.issue, { 
      _bare_repo: repo, 
      _bare_owner: owner,
      repository: null,
      milestone: null,
      assignees: [],
      labels: []
    });
    applyIssueState(state);
    
    return new Promise((resolve, reject) => {
      // fetch new metadata and merge it in
      loadMetadata(newRepo).then((meta) => {
        var state = getIvars();
        state = Object.assign({}, state, meta);
        state.issue = Object.assign({}, state.issue, { 
          _bare_repo: repo, 
          _bare_owner: owner,
          milestone: null,
          assignees: [],
          labels: []
        });
        applyIssueState(state);
        resolve();
      }).catch((err) => {
        console.log("Could not load metadata for repo", newRepo, err);
        fail();
        reject();
      });      
    });
  },
  
  onEnter: function() {
    var completer = this.refs.input;
    var el = ReactDOM.findDOMNode(completer.refs.typeInput);
    var val = el.value;
    
    var promises = [];
    completer.props.matcher(val, (results) => {
      if (results.length >= 1) {
        var result = results[0];
        promises.push(this.onChange(result));
      }
    });
    
    this.props.focusNext("repo");
    
    return Promise.all(promises);
  },
  
  focus: function() {
    if (this.refs.input) {
      this.refs.input.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.completer) {
      return this.refs.input.hasFocus();
    } else {
      return false;
    }
  },
  
  needsSave: function() {
    if (this.refs.input) {
      var canEdit = this.props.issue.number == null;
      return canEdit && this.refs.input.isEdited();
    } else {
      return false;
    }
  },
  
  save: function() {
    if (this.needsSave()) {
      return this.onEnter();
    } else {
      return Promise.resolve();
    }
  },
  
  repoValue: function() {
    var repoValue = "";
    if (this.props.issue._bare_owner && this.props.issue._bare_repo) {
      repoValue = "" + this.props.issue._bare_owner + "/" + this.props.issue._bare_repo;
    }
    return repoValue;
  },
  
  render: function() {  
    var opts = getIvars().repos.map((r) => r.full_name);
    var matcher = Completer.SubstrMatcher(opts);
    
    var canEdit = this.props.issue.number == null;
    var inputType = Completer;
    if (!canEdit) {
      inputType = 'input';
    }
    
    return h('div', {className: 'IssueInput RepoField'},
      h(HeaderLabel, {title: 'Repo'}),
      h(inputType, {ref:'input', placeholder: 'Required', onChange:this.onChange, onEnter:this.onEnter, value:this.repoValue(), matcher: matcher, readOnly:!canEdit}),
      h(StateField, {issue: this.props.issue})
    );
  }
});

var MilestoneField = React.createClass({
  propTypes: { 
    issue: React.PropTypes.object,
  },
  
  lookupMilestone: function(value) {
    var ms = getIvars().milestones.filter((m) => m.title === value);
    if (ms.length == 0) {
      return null;
    } else {
      return ms[0];
    }
  },
  
  milestoneChanged: function(value) {
    var initial = keypath(this.props.issue, "milestone.title") || "";
    if (value != initial) {
      if (value == null || value.length == 0) { 
        value = null;
      }
      
      return patchIssue({milestone: this.lookupMilestone(value)});
    } else {
      return Promise.resolve();
    }
  },
  
  onEnter: function() {
    var completer = this.refs.completer;    
    var promises = [];
    
    completer.completeOrFail(() => {
      var val = completer.value();
      if (val == null || val == "") {
        promises.push(this.milestoneChanged(null));
      } else {
        promises.push(this.milestoneChanged(val));
      }
      this.props.focusNext("milestone");
    });
    
    return Promise.all(promises);
  },
  
  onAddNew: function(initialNewTitle) {
    return new Promise((resolve, reject) => {
      var cb = (newMilestones) => {
        if (newMilestones === undefined) {
          // error creating
          reject();
        } else if (newMilestones == null || newMilestones.length == 0) {
          // user cancelled
          this.focus();
          resolve();
        } else {
          // success
          var m = newMilestones[0];
          getIvars().milestones.push(m);
          this.props.issue.milestone = m;
          return this.milestoneChanged(m.title).then(resolve, reject);
        }
      };
      window.newMilestone(initialNewTitle, 
                          this.props.issue._bare_owner, 
                          this.props.issue._bare_repo,
                          cb);
    });
  },
  
  focus: function() {
    if (this.refs.completer) {
      this.refs.completer.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.completer) {
      return this.refs.completer.hasFocus();
    } else {
      return false;
    }
  },
  
  needsSave: function() {
    if (this.refs.completer) {
      return (this.refs.completer.value() || "") != (keypath(this.props.issue, "milestone.title") || "");
    } else {
      return false;
    }
  },
  
  save: function() {
    if (this.needsSave()) {
      return this.onEnter();
    } else {
      return Promise.resolve();
    }
  },
  
  shouldComponentUpdate: function(nextProps, nextState) {
    var nextNum = keypath(nextProps, "issue.number");
    var oldNum = keypath(this.props, "issue.number");
    
    if (nextNum && nextNum == oldNum && this.refs.completer.isEdited()) {
      return false;
    }
    return true;
  },
  
  render: function() {
    var canAddNew = !!this.props.issue._bare_repo;
    var opts = getIvars().milestones.map((m) => m.title);
    var matcher = Completer.SubstrMatcher(opts);
    
    return h('div', {className: 'IssueInput MilestoneField'},
      h(HeaderLabel, {title:"Milestone"}),
      h(Completer, {
        ref: 'completer',
        placeholder: 'Backlog',
        onChange: this.milestoneChanged,
        onEnter: this.onEnter,
        newItem: canAddNew ? 'New Milestone' : undefined,
        onAddNew: canAddNew ? this.onAddNew : undefined,
        value: keypath(this.props.issue, "milestone.title"),
        matcher: matcher
      })
    );
  }
});

var StateField = React.createClass({
  propTypes: { 
    issue: React.PropTypes.object
  },
  
  stateChanged: function(evt) {
    patchIssue({state: evt.target.value});
  },
  
  needsSave: function() {
    return false;
  },
  
  save: function() {
    return Promise.resolve();
  },
  
  render: function() {
    var isNewIssue = !(this.props.issue.number);
    
    if (isNewIssue) {
      return h('span');
    }
  
    return h('select', {className:'IssueState', value:this.props.issue.state, onChange:this.stateChanged},
      h('option', {value: 'open'}, "Open"),
      h('option', {value: 'closed'}, "Closed")
    );
  }
});

var AssigneeInput = React.createClass({
  propTypes: {
    issue: React.PropTypes.object
  },
  
  lookupAssignee: function(value) {
    var us = getIvars().assignees.filter((a) => a.login === value);
    if (us.length == 0) {
      return null;
    } else {
      return us[0];
    }
  },
  
  assigneeChanged: function(value) {
    var initial = keypath(this.props.issue, "assignees[0].login") || "";
    if (value != initial) {
      if (value == null || value.length == 0) {
        value = null;
      }
      var assignee = this.lookupAssignee(value);
      if (assignee) {
        return patchIssue({assignees: [assignee]});
      } else {
        return patchIssue({assignees: []});
      }
    } else {
      return Promise.resolve();
    }
  },
  
  onEnter: function() {
    var completer = this.refs.completer;
    
    var promises = [];
    completer.completeOrFail(() => {
      var val = completer.value();
      if (val == null || val == "") {
        promises.push(this.assigneeChanged(null));
      } else {
        promises.push(this.assigneeChanged(val));
      }
      this.props.focusNext("assignee");
    });
    
    return Promise.all(promises);
  },
  
  focus: function() {
    if (this.refs.completer) {
      this.refs.completer.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.completer) {
      return this.refs.completer.hasFocus();
    } else {
      return false;
    }
  },
  
  needsSave: function() {
    if (this.refs.completer) {
      return (this.refs.completer.value() || "") != (keypath(this.props.issue, "assignees[0].login") || "");
    } else {
      return false;
    }
  },
  
  save: function() {
    if (this.needsSave()) {
      return this.onEnter();
    } else {
      return Promise.resolve();
    }
  },
  
  shouldComponentUpdate: function(nextProps, nextState) {
    var nextNum = keypath(nextProps, "issue.number");
    var oldNum = keypath(this.props, "issue.number");
    
    if (nextNum && nextNum == oldNum && this.refs.completer.isEdited()) {
      return false;
    }
    return true;
  },
    
  render: function() {
    var ls = getIvars().assignees.map((a) => {
      var lowerLogin = a.login.toLowerCase();
      var lowerName = null;
      if (a.name != null) {
        lowerName = a.name.toLowerCase();
      }
      return Object.assign({}, a, { lowerLogin: lowerLogin, lowerName: lowerName });
    });
    
    ls.sort((a, b) => a.lowerLogin.localeCompare(b.lowerLogin));
    
    var matcher = (q, cb) => {
      var yieldAssignees = function(a) {
        cb(a.map((x) => x.login));
      };
      
      q = q.toLowerCase();
        
      if (q === '') {
        yieldAssignees(ls);
        return;
      }
      
      var matches = ls.filter((a) => {
        var lowerLogin = a.lowerLogin;
        var lowerName = a.lowerName;
        
        return lowerLogin.indexOf(q) != -1 ||
          (lowerName != null && lowerName.indexOf(q) != -1);
      });
          
      yieldAssignees(matches);      
    };
    
    return h(Completer, {
      ref: 'completer',
      placeholder: 'Unassigned', 
      onChange: this.assigneeChanged,
      onEnter: this.onEnter,
      value: keypath(this.props.issue, "assignees[0].login"),
      matcher: matcher
    });
  }
});

var AddAssignee = React.createClass({
  propTypes: {
    issue:React.PropTypes.object,
  },
  
  addAssignee: function(login) {
    var user = null;
    var matches = getIvars().assignees.filter((u) => u.login == login);
    if (matches.length > 0) {
      user = matches[0];
      var assignees = [user, ...this.props.issue.assignees];
      return patchIssue({assignees});
    }
  },
  
  focus: function() {
    if (this.refs.picker) {
      this.refs.picker.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.picker) {
      return this.refs.picker.hasFocus();
    } else {
      return false;
    }
  },
  
  needsSave: function() {
    if (this.refs.picker) {
      return this.refs.picker.containsCompleteValue();
    } else {
      return false;
    }
  },
  
  save: function() {
    if (this.needsSave()) {
      return this.refs.picker.addLabel();
    } else {
      return Promise.resolve();
    }
  },
  
  render: function() {
    var allAssignees = getIvars().assignees;
    var chosenAssignees = keypath(this.props.issue, "assignees") || [];
    
    var chosenAssigneesLookup = chosenAssignees.reduce((o, l) => { o[l.login] = l; return o; }, {});
    var availableAssignees = allAssignees.filter((l) => !(l.login in chosenAssigneesLookup));

    if (this.props.issue._bare_owner == null ||
        this.props.issue._bare_repo == null) {
      return h("span", {className: "AddAssigneesEmpty"});
    } else {
      return h(AssigneesPicker, {
        ref: "picker",
        availableAssigneeLogins: availableAssignees.map((l) => (l.login)),
        onAdd: this.addAssignee,
      });
    }
  }
});

var AssigneeAtom = React.createClass({
  propTypes: { 
    user: React.PropTypes.object.isRequired,
    onDelete: React.PropTypes.func,
  },
  
  onDeleteClick: function() {
    if (this.props.onDelete) {
      this.props.onDelete(this.props.user);
    }
  },
  
  render: function() {
    return h("span", {className:"AssigneeAtom"},
      h("span", {className:"AssigneeAtomName"},
        this.props.user.login
      ),
      h('span', {className:'AssigneeAtomDelete Clickable', onClick:this.onDeleteClick}, 
        h('i', {className:'fa fa-times'})
      )
    );
  }
});

var MultipleAssignees = React.createClass({
  propTypes: { issue: React.PropTypes.object },
  
  deleteAssignee: function(login) {
    var assignees = this.props.issue.assignees.filter((l) => (l.login != login));
    patchIssue({assignees});
  },
  
  focus: function() {
    if (this.refs.add) {
      this.refs.add.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.add) {
      return this.refs.add.hasFocus();
    } else {
      return false;
    }
  },
  
  needsSave: function() {
    if (this.refs.add) {
      return this.refs.add.needsSave();
    } else {
      return false;
    }
  },
  
  save: function() {
    if (this.refs.add && this.refs.add.needsSave()) {
      return this.refs.add.save();
    } else {
      return Promise.resolve();
    }
  },
  
  render: function() {
    // this is lame, but it's what GitHub does: sorts em by identifier
    var sortedAssignees = [...this.props.issue.assignees].sort((a, b) => {
      if (a.id < b.id) { return -1; }
      else if (a.id > b.id) { return 1; }
      else { return 0; }
    });
    
    return h('span', {className:'MultipleAssignees'},
      h(AddAssignee, {issue: this.props.issue, ref:"add"}),
      sortedAssignees.map((l, i) => { 
        return [" ", h(AssigneeAtom, {key:i, user:l, onDelete: this.deleteLabel})];
      }).reduce(function(c, v) { return c.concat(v); }, [])
    );
  }
});

var AssigneeField = React.createClass({
  propTypes: {
    issue: React.PropTypes.object
  },
  
  getInitialState: function() {
    var assignees = keypath(this.props.issue, "assignees") || [];
    return { multi: assignees.length > 1 };
  },
  
  componentWillReceiveProps: function(nextProps) {
    var nextNum = keypath(nextProps, "issue.number");
    var oldNum = keypath(this.props, "issue.number");
    
    var assignees = keypath(nextProps, "issue.assignees") || [];
    if ((oldNum && nextNum != oldNum) || assignees.length > 1) {
      this.setState({ multi: assignees.length > 1 });
    }
  },

  focus: function() {
    if (this.refs.assignee) {
      this.refs.assignee.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.assignee) {
      return this.refs.assignee.hasFocus();
    } else {
      return false;
    }
  },
  
  needsSave: function() {
    if (this.refs.assignee) {
      return this.refs.assignee.needsSave();
    } else {
      return false;
    }
  },
  
  save: function() {
    if (this.refs.assignee) {
      return this.refs.assignee.save();
    } else {
      return Promise.resolve();
    }
  },
  
  toggleMultiAssignee: function() {
    this.goingMulti = true;
    this.setState({multi: true});
  },

  render: function() {
    var inputField;
    if (this.state.multi) {
      inputField = h(MultipleAssignees, {key:'assignees', ref:'assignee', issue:this.props.issue, focusNext:this.props.focusNext});
    } else {
      inputField = h(AssigneeInput, {key:'assignee', ref:"assignee", issue: this.props.issue, focusNext:this.props.focusNext});
    }
  
    return h('div', {className: 'IssueInput AssigneeField'},
      h(HeaderLabel, {title:this.state.multi?"Assignees":"Assignee"}),
      inputField,
      h('i', {
        className:"fa fa-user-plus toggleMultiAssignee",
        style: {display: this.state.multi?"none":"inline"},
        title: "Multiple Assignees",
        onClick: this.toggleMultiAssignee
      })
    );
  },
  
  componentDidUpdate: function() {
    if (this.goingMulti) {
      this.goingMulti = false;
      this.focus();
    }
  }
});

var AddLabel = React.createClass({
  propTypes: { 
    issue: React.PropTypes.object,
  },
  
  addExistingLabel: function(label) {
    var labels = [label, ...this.props.issue.labels];
    return patchIssue({labels: labels});
  },

  newLabel: function(prefillName) {
    var _this = this;
    return new Promise(function(resolve, reject) {
      window.newLabel(prefillName ? prefillName : "",
                      getIvars().labels,
                      _this.props.issue._bare_owner,
                      _this.props.issue._bare_repo,
                      function(succeeded, label) {
                        _this.focus();
                        if (succeeded) {
                          getIvars().labels.push({
                            name: label.name,
                            color: label.color,
                          });
                          _this.forceUpdate();

                          return _this.addExistingLabel(label).then(resolve, reject);
                        }
                        resolve();
                      });
    });
  },

  focus: function() {
    if (this.refs.picker) {
      this.refs.picker.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.picker) {
      return this.refs.picker.hasFocus();
    } else {
      return false;
    }
  },
  
  needsSave: function() {
    if (this.refs.picker) {
      return this.refs.picker.containsCompleteValue();
    } else {
      return false;
    }
  },
  
  save: function() {
    if (this.needsSave()) {
      return this.refs.picker.addLabel();
    } else {
      return Promise.resolve();
    }
  },
    
  render: function() {
    var allLabels = getIvars().labels;
    var chosenLabels = keypath(this.props.issue, "labels") || [];
    
    chosenLabels = [...chosenLabels].sort((a, b) => {
      return a.name.localeCompare(b.name);
    });
    
    var chosenLabelsLookup = chosenLabels.reduce((o, l) => { o[l.name] = l; return o; }, {});  
    var availableLabels = allLabels.filter((l) => !(l.name in chosenLabelsLookup));

    if (this.props.issue._bare_owner == null ||
        this.props.issue._bare_repo == null) {
      return h("div", {className: "AddLabelEmpty"});
    } else {
      return h(LabelPicker, {
        ref: "picker",
        chosenLabels: chosenLabels,
        availableLabels: availableLabels,
        onAddExistingLabel: this.addExistingLabel,
        onNewLabel: this.newLabel,
      });
    }
  }
});

var IssueLabels = React.createClass({
  propTypes: { issue: React.PropTypes.object },
  
  deleteLabel: function(label) {
    var labels = this.props.issue.labels.filter((l) => (l.name != label.name));
    patchIssue({labels: labels});
  },
  
  focus: function() {
    if (this.refs.add) {
      this.refs.add.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.add) {
      return this.refs.add.hasFocus();
    } else {
      return false;
    }
  },
  
  needsSave: function() {
    if (this.refs.add) {
      return this.refs.add.needsSave();
    } else {
      return false;
    }
  },
  
  save: function() {
    if (this.refs.add && this.refs.add.needsSave()) {
      return this.refs.add.save();
    } else {
      return Promise.resolve();
    }
  },
  
  render: function() {
    return h('div', {className:'IssueLabels'},
      h(HeaderLabel, {title:"Labels"}),
      h(AddLabel, {issue: this.props.issue, ref:"add"}),
      this.props.issue.labels.map((l, i) => { 
        return [" ", h(Label, {key:i, label:l, canDelete:true, onDelete: this.deleteLabel})];
      }).reduce(function(c, v) { return c.concat(v); }, [])
    );
  }
});

var Header = React.createClass({
  propTypes: { issue: React.PropTypes.object },
  
  focussed: function() {
    if (this.queuedFocus) {
      return this.queuedFocus;
    }
    
    var a = ["title", "repo", "milestone", "assignee", "labels"];
    
    for (var i = 0; i < a.length; i++) {
      var n = a[i];
      var x = this.refs[n];
      if (x && x.hasFocus()) {
        return n;
      }
    }
    
    return null;
  },
  
  focusField: function(field) {
    if (this.refs[field]) {
      var x = this.refs[field];
      x.focus();
    } else {
      this.queuedFocus = field;
    }
  },
  
  focusNext: function(current) {
    var next = null;
    switch (current) {
      case "title": next = "repo"; break;
      case "repo": next = "milestone"; break;
      case "milestone": next = "assignee"; break;
      case "assignee": next = "labels"; break;
      case "labels": next = "labels"; break;
    }
    
    this.focusField(next);
  },
  
  dequeueFocus: function() {
    if (this.queuedFocus) {
      var x = this.refs[this.queuedFocus];
      this.queuedFocus = null;
      x.focus();
    }
  },
  
  componentDidMount: function() {
    this.dequeueFocus();
  },
  
  componentDidUpdate: function() {
    this.dequeueFocus();
  },
  
  needsSave: function() {
//     console.log("header needsSave: ", 
//       {"title": this.refs.title.needsSave()},
//       {"repo": this.refs.repo.needsSave()},
//       {"milestone": this.refs.milestone.needsSave()},
//       {"assignee": this.refs.assignee.needsSave()},
//       {"labels": this.refs.labels.needsSave()}
//     );
  
    return (
      this.refs.title.needsSave()
      || this.refs.repo.needsSave()
      || this.refs.milestone.needsSave()
      || this.refs.assignee.needsSave()
      || this.refs.labels.needsSave()
    );
  },
  
  save: function() {
    var promises = [];
    for (var k in this.refs) {
      var r = this.refs[k];
      if (r && r.needsSave && r.needsSave()) {
        promises.push(r.save());
      }      
    }
    return Promise.all(promises);
  },
  
  render: function() {
    var hasRepo = this.props.issue._bare_repo && this.props.issue._bare_owner;
    var els = [];
    
    els.push(h(IssueTitle, {key:"title", ref:"title", issue: this.props.issue, focusNext:this.focusNext}),
             h(HeaderSeparator, {key:"sep0"}),
             h(RepoField, {key:"repo", ref:"repo", issue: this.props.issue, focusNext:this.focusNext}));
             
    els.push(h(HeaderSeparator, {key:"sep1"}),
             h(MilestoneField, {key:"milestone", ref:"milestone", issue: this.props.issue, focusNext:this.focusNext}),
             h(HeaderSeparator, {key:"sep2"}),
             h(AssigneeField, {key:"assignee", ref:"assignee", issue: this.props.issue, focusNext:this.focusNext}),
             h(HeaderSeparator, {key:"sep3"}),
             h(IssueLabels, {key:"labels", ref:"labels", issue: this.props.issue}));
  
    return h('div', {className: 'IssueHeader'}, els);
  }
});

var DebugLoader = React.createClass({
  propTypes: { issue: React.PropTypes.object },
  render: function() {
    var ghURL = "https://github.com/" + this.props.issue._bare_owner + "/" + this.props.issue._bare_repo + "/issues/" + this.props.issue.number;
    var val = "" + this.props.issue._bare_owner + "/" + this.props.issue._bare_repo + "#" + this.props.issue.number;
    
    return h("div", {className:"debugLoader"},
      h("span", {}, "Load Problem: "),
      h(SmartInput, {type:"text", size:40, value:val, onChange:this.loadProblem}),
      h("a", {href:ghURL, target:"_blank"}, "source"),
      h("input", {type:"button", onClick:this.rerender, value:"Rerender"})
    );
  },
  loadProblem: function(problemRef) {
    var [owner, repo, number] = problemRef.split(/[\/#]/);
    updateIssue(...problemRef.split(/[\/#]/));          
  },
  rerender: function() {
    applyIssueState(getIvars());
  }
});
      
function simpleFetch(url) {
  return api(url, { headers: { Authorization: "token " + getIvars().token }, method: "GET" });
}
      
function pagedFetch(url) /* => Promise */ {
  if (window.inApp) {
    return simpleFetch(url);
  }

  var opts = { headers: { Authorization: "token " + getIvars().token }, method: "GET" };
  var initial = fetch(url, opts);
  return initial.then(function(resp) {
    var pages = []
    var link = resp.headers.get("Link");
    if (link) {
      var [next, last] = link.split(", ");
      var matchNext = next.match(/\<(.*?)\>; rel="next"/);
      var matchLast = last.match(/\<(.*?)\>; rel="last"/);
      if (matchNext && matchLast) {
        var second = parseInt(matchNext[1].match(/page=(\d+)/)[1]);
        var last = parseInt(matchLast[1].match(/page=(\d+)/)[1]);
        for (var i = second; i <= last; i++) {
          var pageURL = matchNext[1].replace(/page=\d+/, "page=" + i);
          pages.push(fetch(pageURL, opts).then(function(resp) { return resp.json(); }));
        }
      }
    }
    return Promise.all([resp.json()].concat(pages));
  }).then(function(pages) {
    return pages.reduce(function(a, b) { return a.concat(b); });
  });
}

function updateIssue(owner, repo, number) {
  var reqs = [simpleFetch("https://api.github.com/repos/" + owner + "/" + repo + "/issues/" + number),
              pagedFetch("https://api.github.com/repos/" + owner + "/" + repo + "/issues/" + number + "/events"),
              pagedFetch("https://api.github.com/repos/" + owner + "/" + repo + "/issues/" + number + "/comments"),
              pagedFetch("https://api.github.com/user/repos"),
              pagedFetch("https://api.github.com/repos/" + owner + "/" + repo + "/assignees"),
              pagedFetch("https://api.github.com/repos/" + owner + "/" + repo + "/milestones"),
              pagedFetch("https://api.github.com/repos/" + owner + "/" + repo + "/labels"),
              simpleFetch("https://api.github.com/user")];
  
  Promise.all(reqs).then(function(parts) {
    var issue = parts[0];
    issue.allEvents = parts[1];
    issue.allComments = parts[2];
    
    var state = { 
      issue: issue,
      repos: parts[3].filter((r) => r.has_issues),
      assignees: parts[4],
      milestones: parts[5],
      labels: parts[6],
      me: parts[7],
      token: getIvars().token
    }
    
    if (issue.id) {
      applyIssueState(state);
    }
  }).catch(function(err) {
    console.log(err);
  });
}

function loadMetadata(repoFullName) {
  var owner = null;
  var repo = null;
  
  if (repoFullName) {
    [owner, repo] = repoFullName.split("/");
  }

  var reqs = [pagedFetch("https://api.github.com/user/repos"),
              simpleFetch("https://api.github.com/user")];
              
  if (owner && repo) {
    reqs.push(pagedFetch("https://api.github.com/repos/" + owner + "/" + repo + "/assignees"),
              pagedFetch("https://api.github.com/repos/" + owner + "/" + repo + "/milestones"),
              pagedFetch("https://api.github.com/repos/" + owner + "/" + repo + "/labels"));
  }
  
  return Promise.all(reqs).then(function(parts) {
    var meta = {
      repos: parts[0].filter((r) => r.has_issues),
      me: parts[1],
      assignees: (parts.length > 2 ? parts[2] : []),
      milestones: (parts.length > 3 ? parts[3] : []),
      labels: (parts.length > 4 ? parts[4] : []),
      token: getIvars().token,
    };
    
    return new Promise((resolve, reject) => {
      resolve(meta);
    });
  }).catch(function(err) {
    console.log(err);
  });
}

var App = React.createClass({
  propTypes: { issue: React.PropTypes.object },
  
  render: function() {
    var issue = this.props.issue;

    var header = h(Header, {ref:"header", issue: issue});
    var activity = h(ActivityList, {key:issue["id"], ref:"activity", issue:issue});
    var addComment = h(Comment, {ref:"addComment"});
    
    var issueElement = h('div', {},
      header,
      activity,
      addComment
    );
    
    var outerElement = issueElement;
    if (debugToken && !window.inApp) {
      outerElement = h("div", {},
        h(DebugLoader, {issue:issue}),
        issueElement
      );
    }
    
    return outerElement;
  },
  
  componentDidMount: function() {
    this.registerGlobalEventHandlers();
    
    // If we're doing New Clone in the app, we have an issue body already.
    // Set it, but don't dirty the save state
    var isNewIssue = !(getIvars().issue.number);
    var addComment = this.refs.addComment;
    if (isNewIssue && this.props.issue && this.props.issue.body && this.props.issue.body.length > 0) {
      addComment.setInitialContents(this.props.issue.body);
    }
  },
  
  componentDidUpdate: function() {
    this.registerGlobalEventHandlers();  
  },
  
  needsSave: function() {
    var l = [this.refs.header, this.refs.activity, this.refs.addComment];
    var edited = l.reduce((a, x) => a || x.needsSave(), false)
    var isNewIssue = !(getIvars().issue.number);
    var isEmptyNewIssue = getIvars().issue.title == null || getIvars().issue.title == "";
    return edited || (isNewIssue && !isEmptyNewIssue);
  },
  
  save: function() {
    var isNewIssue = !(this.props.issue.number);
    if (isNewIssue) {
      this.refs.header.save(); // commit any pending changes      
      var title = getIvars().issue.title;
      var repo = getIvars().issue._bare_repo;
      
      if (!title || title.trim().length == 0) {
        var reason = "Cannot save issue. Title is required.";
        alert(reason);
        return Promise.reject(reason);
      } else if (!repo || repo.trim().length == 0) {
        var reason = "Cannot save issue. Repo is required."
        alert(reason);
        return Promise.reject(reason);
      } else {
        return this.refs.addComment.save();
      }
    } else {
      var l = [this.refs.header, this.refs.activity, this.refs.addComment];
      var promises = l.filter((x) => x.needsSave()).map((x) => x.save());
      return Promise.all(promises);
    }
  },
  
  registerGlobalEventHandlers: function() {
    var doc = window.document;
    doc.onkeypress = (evt) => {
      if (evt.which == 115 && evt.metaKey) {
        console.log("global save");
        this.save();
        evt.preventDefault();
      }
    };
  },
  
  activeComment: function() {
    var activity = this.refs.activity;
    var addComment = this.refs.addComment;
    
    if (activity && addComment) {
      var c = activity.activeComment();
      if (!c) {
        c = addComment;
      }
      return c;
    }
    
    return null;
  },
  
  applyMarkdownFormat: function(format) {
    var c = this.activeComment();
    if (c) { 
      c.applyMarkdownFormat(format);
    }
  }
});

function applyIssueState(state) {
  console.log("rendering:", state);
  
  var issue = state.issue;
  
  window.document.title = issue.title || "New Issue";
  
  if (issue.repository_url) {
    var comps = issue.repository_url.replace("https://", "").split("/");
    issue._bare_owner = comps[comps.length-2]
    issue._bare_repo = comps[comps.length-1]
  } else {
    if (issue.repository) {
      var comps = issue.repository.full_name.split("/");
      issue._bare_owner = comps[0];
      issue._bare_repo = comps[1];
    }
  }
  
  if (Array.isArray(issue.events)) {
    issue.allEvents = issue.events;
  }
  if (Array.isArray(issue.comments)) {
    issue.allComments = issue.comments;
  }
  
  if (issue.originator) {
    issue.user = issue.originator;
  }
  
  setIvars(state);
  
  if (window.lastErr) {
    console.log("Rerendering everything");
    delete window.lastErr;
    var node = document.getElementById('react-app');
    try {
      ReactDOM.unmountComponentAtNode(node);
    } catch (exc) {
      node.remove();
      var body = document.getElementsByTagName('body')[0];
      node = document.createElement('div');
      node.setAttribute('id', 'react-app');
      body.appendChild(node);
    }
  }
  
  window.topLevelComponent = ReactDOM.render(
    h(App, {issue: issue}),
    document.getElementById('react-app')
  )
}

function configureNewIssue(initialRepo, meta) {
  if (!meta) {
    loadMetadata(initialRepo).then((meta) => {
      configureNewIssue(initialRepo, meta);
    }).catch((err) => {
      console.log("error rendering new issue", err);
    });
    return;
  }
  
  var owner = null, repo = null;
  
  if (initialRepo) {
    [owner, repo] = initialRepo.split("/");
  }
  
  var issue = {
    title: "",
    state: "open",
    milestone: null,
    assignees: [],
    labels: [],
    comments: [],
    events: [],
    _bare_owner: owner,
    _bare_repo: repo,
    user: meta.me
  };
  
  var state = Object.assign({}, meta, {
    issue: issue
  });
  
  applyIssueState(state);
}

window.apiCallback = apiCallback;
window.updateIssue = updateIssue;
window.applyIssueState = applyIssueState;
window.configureNewIssue = configureNewIssue;
window.renderIssue = function(issue) {
  applyIssueState({issue: issue});
};

window.needsSave = function() {
  return window.topLevelComponent && window.topLevelComponent.needsSave();
}

window.save = function(token) {
  if (window.topLevelComponent) {
    var p = window.topLevelComponent.save();
    if (window.documentSaveHandler) {
      if (p) {
        p.then(function(success) {
          window.documentSaveHandler.postMessage({token:token, error:null});
        }).catch(function(error) {
          window.documentSaveHandler.postMessage({token:token, error:error});
        });
      } else {
        window.documentSaveHandler.postMessage({token:token, error:null});
      }
    }
  }
}

window.pasteCallback = pasteCallback;

if (!window.inApp) {
  //updateIssue("realartists", "shiphub-server", "10")
  configureNewIssue();
}

function findCSSRule(selector) {
  var sheets = document.styleSheets;
  for (var i = 0; i < sheets.length; i++) {
    var rules = sheets[i].cssRules;
    for (var j = 0; j < rules.length; j++) {
      if (rules[j].selectorText == selector) {
        return rules[j];
      }
    }
  }
  return null;
}

function setInColumnBrowser(inBrowser) {
  window.inColumnBrowser = inBrowser;
  
  var body = document.getElementsByTagName('body')[0];
  body.style.padding = inBrowser ? '14px' : '0px';
  
  var commentRule = findCSSRule('div.comment');
  commentRule.style.borderLeft = inBrowser ? commentRule.style.borderTop : '0px';
  commentRule.style.borderRight = inBrowser ? commentRule.style.borderTop : '0px';
  
  var headerRule = findCSSRule('div.IssueHeader');
  headerRule.style.borderLeft = inBrowser ? headerRule.style.borderBottom : '0px';
  headerRule.style.borderRight = inBrowser ? headerRule.style.borderBottom : '0px';
  headerRule.style.borderTop = inBrowser ? headerRule.style.borderBottom : '0px';
}

window.setInColumnBrowser = setInColumnBrowser;

function applyMarkdownFormat(format) {
  if (window.topLevelComponent) {
    window.topLevelComponent.applyMarkdownFormat(format);
  } 
}

window.applyMarkdownFormat = applyMarkdownFormat;

window.loadComplete.postMessage({});

if (__DEBUG__) {
  console.log("*** Debug build ***");
}

window.onerror = function() {
  window.lastErr = true;
}
