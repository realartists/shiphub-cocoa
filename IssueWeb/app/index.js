import 'font-awesome/css/font-awesome.css'
import '../markdown-mark/style.css'
import 'codemirror/lib/codemirror.css'
import 'highlight.js/styles/xcode.css'
import './index.css'

import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import hljs from 'highlight.js'
import pnglib from 'pnglib'
window.PNGlib = pnglib;
import identicon from 'identicon.js'
import md5 from 'md5'
import 'whatwg-fetch'
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

import $ from 'jquery'
window.$ = $;
window.jQuery = $;
window.jquery = $;

import Completer from './completer.js'
import SmartInput from './smart-input.js'
import { emojify } from './emojify.js'
import marked from './marked.min.js'
import { githubLinkify } from './github_linkify.js'
import LabelPicker from './label-picker.js'
import uploadAttachment from './file-uploader.js'
import FilePicker from './file-picker.js'
import TimeAgo from './time-ago'

var debugToken = "8de44b7cf7050c827165d3f509abb1bd187a62e4";

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

  if (patch.assignee != null) {
    ghPatch.assignee = patch.assignee.login;
  }

  console.log("patching", patch, ghPatch);
  
  // PATCH /repos/:owner/:repo/issues/:number
  var owner = getIvars().issue._bare_owner;
  var repo = getIvars().issue._bare_repo;
  var num = getIvars().issue.number;
  
  if (num != null) {
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
    request.then(function(body) {
      console.log(body);
    }).catch(function(err) {
      console.log(err);
    });
  }
}

function applyCommentEdit(commentIdentifier, newBody) {
  // PATCH /repos/:owner/:repo/issues/comments/:id
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
      method: "PATCH",
      body: JSON.stringify({body: newBody})
    });
    request.then(function(body) {
      console.log(body);
    }).catch(function(err) {
      console.log(err);
    });
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
    request.then(function(resp) {
      // success
    }).catch(function(err) {
      console.log(err);
    });
  }
}

function applyComment(commentBody) {
  // POST /repos/:owner/:repo/issues/:number/comments
  
  var owner = getIvars().issue._bare_owner;
  var repo = getIvars().issue._bare_repo;
  var num = getIvars().issue.number;
  
  if (num != null) {
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
    request.then(function(body) {
      var id = body.id;
      window.ivars.issue.allComments.forEach((m) => {
        if (m.id === 'new') {
          m.id = id;
        }
      });
      applyIssueState(window.ivars);
    }).catch(function(err) {
      console.log(err);
    });
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
      assignee: keypath(issue, "assignee.login"),
      milestone: keypath(issue, "milestone.number"),
      labels: issue.labels.map((l) => l.name)
    })
  });
  request.then(function(body) {
    window.ivars.issue = body;
    applyIssueState(window.ivars);
  }).catch(function(err) {
    console.log(err);
  });
}

function patchIssue(patch) {
  window.ivars.issue = Object.assign({}, window.ivars.issue, patch);
  applyIssueState(window.ivars);
  applyPatch(patch);
}

function editComment(commentIdx, newBody) {
  if (commentIdx == 0) {
    patchIssue({body: newBody});
  } else {
    commentIdx--;
    window.ivars.issue.allComments[commentIdx].body = newBody;
    applyIssueState(window.ivars);
    applyCommentEdit(window.ivars.issue.allComments[commentIdx].id, newBody);
  }
}

function deleteComment(commentIdx) {
  if (commentIdx == 0) return; // cannot delete first comment
  commentIdx--;
  var c = window.ivars.issue.allComments[commentIdx];
  window.ivars.issue.allComments = window.ivars.issue.allComments.splice(commentIdx+1, 1);
  applyIssueState(window.ivars);
  applyCommentDelete(c.id);
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
  applyComment(body);
}

var keypath = function(obj, path) {
  if (!obj) return null;
  if (!path) return obj;
  path = path.split('.')
  for (var i = 0; i < path.length; i++) {
    var prop = path[i];
    if (obj != null && typeof(obj) === 'object' && prop in obj) {
      obj = obj[prop];
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
    if (ordered) {
      return "<ol class='taskList'>" + body + "</ol>";
    } else {
      return "<ul class='taskList'>" + body + "</ul>";
    }
  } else {
    if (ordered) {
      return "<ol>" + body + "</ol>";
    } else {
      return "<ul>" + body + "</ul>";
    }
  }
}

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
  sanitize: true,
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
      return h('img', Object.assign({}, this.props, {src:this.state.identicon, width:s, height:s}));
    } else {
      return h('img', Object.assign({}, this.props, {src:this.avatarURL(), width:s, height:s, onerror:this.fail}));
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
      h(AvatarIMG, {user:user, size:16, className:"eventAvatar"}),
      user.login
    );
  }
});

var AssignedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    // XXX: GitHub bug always sets the actor to the assignee.
    return h("span", {}, "was assigned");
    
    /*
    if (this.props.event.assignee.id == this.props.event.actor.id) {
      return h("span", {}, "self assigned this");
    } else {
      return h("span", {},
        h("span", {}, "assigned this to "),
        h(EventUser, {user:this.props.event.assignee})
      );
    }*/
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
  var committish = event.commit_id.slice(0, 10);
  var commitURL = event.commit_url.replace("api.github.com/repos/", "github.com/").replace("/commits/", "/commit/");
  return [committish, commitURL];
}

var ReferencedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    var [committish, commitURL] = expandCommit(this.props.event);
    return h("span", {},
      "referenced this issue in commit ",
      h("a", {href:commitURL, target:"_blank"}, committish)
    );
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
      return h("span", {},
        "closed this issue with commit ",
        h("a", {href:commitURL, target:"_blank"}, committish)
      );
    } else {
      return h("span", {}, "closed this issue");
    }
  }
});
      
var UnknownEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    return h("span", {}, this.props.event.event);
  }
});

var ClassForEvent = function(event) {
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
    default: return UnknownEventDescription
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
    var user = this.props.event.actor;
    return h('div', {className:className},
      h(EventIcon, {event: this.props.event.event }),
      h("div", {className: "eventContent"},
        h(EventUser, {user: user}),
        " ",
        h(ClassForEvent(this.props.event), {event: this.props.event}),
        " ",
        h(TimeAgo, {className:"eventTime", live:true, date:this.props.event.created_at})
      )
    );
  }
});

var ActivityList = React.createClass({
  propTypes: {
    issue: React.PropTypes.object.isRequired
  },
  
  render: function() {        
    var firstComment = {
      body: this.props.issue.body,
      user: this.props.issue.user,
      id: this.props.issue.id,
      updated_at: this.props.issue.updated_at,
      created_at: this.props.issue.created_at
    };
    
    // need to merge events and comments together into one array, ordered by date
    var eventsAndComments = !!(firstComment.id) ? [firstComment] : [];
    
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
              key:e.id, 
              event:e, 
              first:(i==0 || a[i-1].event == undefined),
              last:(next!=undefined && next.event==undefined),
              veryLast:(next==undefined)
            });
          } else {
            counter.c = counter.c + 1;
            return h(Comment, {key:e.id, comment:e, first:i==0, commentIdx:counter.c-1})
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

var CommentControls = React.createClass({
  propTypes: {
    comment: React.PropTypes.object.isRequired,
    first: React.PropTypes.bool,
    editing: React.PropTypes.bool,
    hasContents: React.PropTypes.bool,
    previewing: React.PropTypes.bool,
    togglePreview: React.PropTypes.func,
    attachFiles: React.PropTypes.func,
    beginEditing: React.PropTypes.func,
    cancelEditing: React.PropTypes.func,
    deleteComment: React.PropTypes.func,
  },
  
  getInitialState: function() {
    return {
      confirmingDelete: false
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
    
  render: function() {
    var buttons = [];
    if (this.props.editing) {
      if (this.props.previewing) {
        buttons.push(h('i', {key:"eye-slash", className:'fa fa-eye-slash', title:"Toggle Preview", onClick:this.props.togglePreview}));
      } else {
        buttons.push(h('i', {key:"paperclip", className:'fa fa-paperclip fa-flip-horizontal', title:"Attach Files", onClick:this.props.attachFiles}));
        if (this.props.hasContents) {
          buttons.push(h('i', {key:"eye", className:'fa fa-eye', title:"Toggle Preview", onClick:this.props.togglePreview}));
        }
      }
      buttons.push(h('i', {key:"edit", className:'fa fa-pencil-square', onClick:this.props.cancelEditing}));
    } else {  
      if (this.state.confirmingDelete) {
        buttons.push(h('span', {key:'confirm', className:'confirmCommentDelete'}, 
          "Really delete this comment? ",
          h('span', {key:'no', className:'confirmDeleteControl Clickable', onClick:this.cancelDelete}, 'No'),
          " ",
          h('span', {key:'yes', className:'confirmDeleteControl Clickable', onClick:this.performDelete}, 'Yes')
        ));
      } else {
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
	
	updateCode: function(newCode) {
	  this.setState(Object.assign({}, this.state, {code: newCode}));
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
    }
	},
	
	deleteComment: function() {
	  deleteComment(this.props.commentIdx);
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
        saveNewIssue();
      }
    } else {
      resetState();
      if (body.trim().length > 0) {
        if (this.props.comment) {
          if (this.props.comment.body != body) {
            editComment(this.props.commentIdx, body);
          }
        } else {
          addComment(body);
        }
      }
    }
	},
	
	saveAndClose: function() {
    patchIssue({state: "closed"});
	  this.save();	  
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
          lineWrapping: true
        }
      })
    )
  },
  
  renderCommentBody: function(body) {
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
  
  renderHeader: function() {
    if (this.props.comment) {
      return h(CommentHeader, {
        ref:'header',
        comment:this.props.comment, 
        first:this.props.first,
        editing:this.state.editing,
        hasContents:this.state.code.trim().length>0,
        previewing:this.state.previewing,
        togglePreview:this.togglePreview,
        attachFiles:this.selectFiles,
        beginEditing:this.beginEditing,
        cancelEditing:this.cancelEditing,
        deleteComment:this.deleteComment,
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
    } else {
      return h('span');
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

    return h('div', {className:'comment addComment'},
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
        var newCode = this.state.code;
        if (newCode.indexOf(placeholder) == -1) {
          console.log("Couldn't find placeholder", placeholder, "in", newCode);
        }
        newCode = newCode.replace(placeholder, link);
        this.updateCode(newCode);
        this.updateUploadCount(-1);
      }).catch((err) => {
        console.log(err);
        this.updateUploadCount(-1);
        var newCode = this.state.code.replace(placeholder, "");
        this.updateCode(newCode);
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
      
      // Configure file attachment handling
      cm.on('drop', (cm, e) => {
        var files = e.dataTransfer.files;
        if (files.length > 0) {
          this.attachFiles(files);
          e.stopPropagation();
          e.preventDefault();
          return true;
        } else {
          return false;
        }
      });
      
      // Configure some formatting controls
      function searchForward(cm, startPos, needle) {
        var line = startPos.line;
        var ch = startPos.ch;
        
        var lc = cm.lineCount();
        while (line < lc) {
          var lt = cm.getLine(line);
          var ls = lt.slice(ch);
          var p = ls.indexOf(needle);
          if (p != -1) {
            p += ch;
            return {from:{line:line, ch:p}, to:{line:line, ch:p+needle.length}};
          }
          line++;
          ch = 0;
        }
      }
      
      function searchBackward(cm, startPos, needle) {
        var line = startPos.line;
        var ch = startPos.ch;
        
        while (line >= 0) {
          var lt = cm.getLine(line);
          var ls = ch == -1 ? lt : lt.slice(0, ch);
          var p = ls.lastIndexOf(needle);
          if (p != -1) {
            return {from:{line:line, ch:p}, to:{line:line, ch:p+needle.length}};
          }
          line--;
          ch = -1;
        }
      }
      
      var toggleFormat = function(operator, tokenType) {
        return function(cm) {
          var from = cm.getCursor("from");
          var to = cm.getCursor("to");
          
          var fromMode = cm.getModeAt(from).name;
          var toMode = cm.getModeAt(to).name;
          
          if (fromMode != 'markdown' || toMode != 'markdown') {
            return;
          }
          
          // special case: if the current word is just the 2**operator, then
          // delete the current word
          var wordRange = cm.findWordAt(from);
          var word = cm.getRange(wordRange.anchor, wordRange.head);
          var doubleOp = operator+operator;
          if (word == doubleOp) {
            cm.replaceRange("", wordRange.anchor, wordRange.head);
            return;
          }
          
          // Use the editor's syntax parsing to determine the format on the selection
          var fromType = cm.getTokenTypeAt(from);
          var toType = cm.getTokenTypeAt(to);
          
          if (fromType && toType && fromType.indexOf(tokenType) != -1 && toType.indexOf(tokenType) != -1) {
            // it would seem that we're already apply the formatting, and so should undo it

            // walk forward from to and see if we can find operator and delete it.
            if (to.ch >= operator.length) to.ch-=operator.length; // step in a bit in case we have the operator selected
            var end = searchForward(cm, to, operator);
            if (end) {
              cm.replaceRange("", end.from, end.to, "+input");
            }
            
            from.ch+=operator.length; // step out a bit in case we have the operator selected
            var start = searchBackward(cm, from, operator);
            if (start) {
              cm.replaceRange("", start.from, start.to, "+input");
            }
            
            if (start && end) {
              if (end.from.line == start.from.line) {
                end.from.ch -= operator.length;
              }
            
              cm.setSelection(start.from, end.from, "+input");
            }
            
          } else {
            // need to add formatting to the selection
            
            var selection = cm.getSelection();
            // use Object.assign as "from" and "to" can return identical objects and we don't want that.
            var from = Object.assign({}, cm.getCursor("from"));
            var to = Object.assign({}, cm.getCursor("to"));
            cm.replaceSelection(operator + selection + operator, "+input");
            from.ch += operator.length;
            if (to.line == from.line) to.ch += operator.length;
            cm.setSelection(from, to, "+input");
          }
        };
      }
            
      cm.setOption('extraKeys', {
        'Cmd-B': toggleFormat('**', 'strong'),
        'Cmd-I': toggleFormat('_', 'em'),
        'Cmd-S': () => { this.save(); }
      });
      
      cm.on('blur', () => { this.onBlur(); });
    }
  },
  
  updateCheckbox: function(i, checked) {
    if (!(this.props.comment)) return;
    
    // find the i-th checkbox in the markdown
    var body = this.props.comment.body;
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
      
      editComment(this.props.commentIdx, body);
    }
  },
  
  findTaskItems: function() {
    if (!(this.props.comment) || this.state.editing) return;
  
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
  },
  
  componentDidUpdate: function() {
    this.configureCM();
    this.findTaskItems();
  },
  
  componentDidMount: function() {
    this.configureCM();
    this.findTaskItems();
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
    if (this.state.edited) {
      this.setState({edited: false});
      patchIssue({title: newTitle});
    }
    if (goNext) {
      this.props.focusNext("title");
    }
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
    this.titleChanged(this.state.editedValue, false);
  },
  
  focus: function() {
    this.refs.input.focus()
  },
  
  hasFocus: function() {
    return this.refs.input.hasFocus();
  },
  
  componentDidMount: function() {
    this.focus();
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
      return;
    }
    
    var [owner, repo] = newRepo.split("/");
    
    var repoInfo = getIvars().repos.find((x) => x.full_name == newRepo);
    
    if (!repoInfo) {
      fail();
      return;
    }
    
    // fetch new metadata and merge it in
    loadMetadata(newRepo).then((meta) => {
      var state = getIvars();
      state = Object.assign({}, state, meta);
      state.issue = Object.assign({}, state.issue, { 
        _bare_repo: repo, 
        _bare_owner: owner,
        milestone: null,
        assignee: null,
        labels: []
      });
      applyIssueState(state);
    }).catch((err) => {
      console.log("Could not load metadata for repo", newRepo, err);
      fail();
    });      
  },
  
  onEnter: function() {
    var completer = this.refs.input;
    var el = ReactDOM.findDOMNode(completer.refs.typeInput);
    var val = el.value;
    
    completer.props.matcher(val, (results) => {
      if (results.length >= 1) {
        var result = results[0];
        this.onChange(result);
      }
    });
    
    this.props.focusNext("repo");
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
      h(inputType, {ref:'input', placeholder: 'Required', onChange:this.onChange, onEnter:this.onEnter, value:this.repoValue(), matcher: matcher, readOnly:!canEdit})
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
      if (value.length == 0) { 
        value = null;
      }
      
      patchIssue({milestone: this.lookupMilestone(value)});
    }
  },
  
  onEnter: function() {
    var completer = this.refs.completer;
    var el = ReactDOM.findDOMNode(completer.refs.typeInput);
    var val = el.value;
    
    completer.props.matcher(val, (results) => {
      if (results.length >= 1) {
        var result = results[0];
        this.milestoneChanged(result);
      } else {
        this.milestoneChanged(null);
      }
      this.props.focusNext("milestone");
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
  
  shouldComponentUpdate: function(nextProps, nextState) {
    var nextNum = keypath(nextProps, "issue.number");
    var oldNum = keypath(this.props, "issue.number");
    
    if (nextNum && nextNum == oldNum && this.refs.completer.isEdited()) {
      return false;
    }
    return true;
  },
  
  render: function() {
    var opts = getIvars().milestones.map((m) => m.title);
    var matcher = Completer.SubstrMatcher(opts);
    
    return h('div', {className: 'IssueInput MilestoneField'},
      h(HeaderLabel, {title:"Milestone"}),
      h(Completer, {
        ref: 'completer',
        placeholder: 'Backlog',
        onChange: this.milestoneChanged,
        onEnter: this.onEnter,
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
    var initial = keypath(this.props.issue, "assignee.login") || "";
    if (value != initial) {
      if (value.length == 0) {
        value = null;
      }
      patchIssue({assignee: this.lookupAssignee(value)});
    }
  },
  
  onEnter: function() {
    var completer = this.refs.completer;
    var el = ReactDOM.findDOMNode(completer.refs.typeInput);
    var val = el.value;
    
    completer.props.matcher(val, (results) => {
      if (results.length >= 1) {
        var result = results[0];
        this.assigneeChanged(result);
      } else {
        this.assigneeChanged(null);
      }
      this.props.focusNext("assignee");
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
      value: keypath(this.props.issue, "assignee.login"),
      matcher: matcher
    });
  }
});

var AssigneeField = React.createClass({
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

  render: function() {
    return h('div', {className: 'IssueInput AssigneeField'},
      h(HeaderLabel, {title:"Assignee"}),
      h(AssigneeInput, {key:'assignee', issue: this.props.issue, focusNext:this.props.focusNext}),
      h(StateField, {issue: this.props.issue})
    );
  }
});

var AddLabel = React.createClass({
  propTypes: { 
    issue: React.PropTypes.object,
  },
  
  addLabel: function(label) {
    var labels = [label, ...this.props.issue.labels];
    patchIssue({labels: labels});
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
    
  render: function() {
    var allLabels = getIvars().labels;
    var chosenLabels = keypath(this.props.issue, "labels") || [];
    
    var chosenLabelsLookup = chosenLabels.reduce((o, l) => { o[l.name] = l; return o; }, {});  
    var filteredLabels = allLabels.filter((l) => !(l.name in chosenLabelsLookup));
    
    if (filteredLabels.length == 0) {
      return h('div', {className:'AddLabelEmpty'});
    } else {
      return h(LabelPicker, {
        ref: "picker",
        labels: filteredLabels,
        onAdd: this.addLabel
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
      setTimeout(() => { x.focus() }, 1);
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

    var header = h(Header, {issue: issue});
    var activity = h(ActivityList, {key:issue["id"], issue:issue});
    var addComment = h(Comment);
    
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
  },
  
  componentDidUpdate: function() {
    this.registerGlobalEventHandlers();  
  },
  
  registerGlobalEventHandlers() {
    var doc = window.document;
    doc.onkeypress = function(evt) {
      if (evt.which == 115 && evt.metaKey) {
        console.log("global save");
        saveNewIssue();
        evt.preventDefault();
      }
    };
  },
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
  
  ReactDOM.render(
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
    assignee: null,
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

if (!window.inApp) {
  //updateIssue("realartists", "shiphub-server", "10")
  configureNewIssue();
}

