import './index.css'
import 'font-awesome/css/font-awesome.css'

import React from 'react'
import ReactDOM from 'react-dom'
import hljs from 'highlight.js'
import pnglib from 'pnglib'
window.PNGlib = pnglib;
import identicon from 'identicon.js'
import md5 from 'md5'
import 'whatwg-fetch'

import { emojify } from './emojify.js'
import marked from './marked.min.js'
import { githubLinkify } from './github_linkify.js'

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
  return emojify(githubLinkify(window.currentIssue._bare_owner, window.currentIssue._bare_repo, text));
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
      return hljs.highlightAuto(code, [lang]).value;
    } else {
      return code;
    }
  }
};

var TimeAgo = React.createClass(
  { displayName: 'Time-Ago'
  , timeoutId: 0
  , getDefaultProps: function(){
      return { live: true
             , component: 'span'
             , minPeriod: 0
             , maxPeriod: Infinity
             , formatter: function (value, unit, suffix) {
                 if(value !== 1){
                   unit += 's'
                 }
                 return value + ' ' + unit + ' ' + suffix
               }
             }
    }
  , propTypes:
      { live: React.PropTypes.bool.isRequired
      , minPeriod: React.PropTypes.number.isRequired
      , maxPeriod: React.PropTypes.number.isRequired
      , component: React.PropTypes.oneOfType([React.PropTypes.string, React.PropTypes.func]).isRequired
      , formatter: React.PropTypes.func.isRequired
      , date: React.PropTypes.oneOfType(
          [ React.PropTypes.string
          , React.PropTypes.number
          , React.PropTypes.instanceOf(Date)
          ]
        ).isRequired
      }
  , componentDidMount: function(){
      if(this.props.live) {
        this.tick(true)
      }
    }
  , componentDidUpdate: function(lastProps){
      if(this.props.live !== lastProps.live || this.props.date !== lastProps.date){
        if(!this.props.live && this.timeoutId){
          clearTimeout(this.timeoutId);
          this.timeoutId = undefined;
        }
        this.tick()
      }
    }
  , componentWillUnmount: function() {
    if(this.timeoutId) {
      clearTimeout(this.timeoutId);
      this.timeoutId = undefined;
    }
  }
  , tick: function(refresh){
      if(!this.isMounted() || !this.props.live){
        return
      }

      var period = 1000

      var then = (new Date(this.props.date)).valueOf()
      var now = Date.now()
      var seconds = Math.round(Math.abs(now-then)/1000)

      if(seconds < 60){
        period = 1000
      } else if(seconds < 60*60) {
        period = 1000 * 60
      } else if(seconds < 60*60*24) {
        period = 1000 * 60 * 60
      } else {
        period = 0
      }

      period = Math.min(Math.max(period, this.props.minPeriod), this.props.maxPeriod)

      if(!!period){
        this.timeoutId = setTimeout(this.tick, period)
      }

      if(!refresh){
        this.forceUpdate()
      }
    }
  , render: function(){
      var then = (new Date(this.props.date)).valueOf()
      var now = Date.now()
      var seconds = Math.round(Math.abs(now-then)/1000)

      var suffix = then < now ? 'ago' : 'from now'

      var value, unit

      if(seconds < 60){
        value = Math.round(seconds)
        unit = 'second'
      } else if(seconds < 60*60) {
        value = Math.round(seconds/60)
        unit = 'minute'
      } else if(seconds < 60*60*24) {
        value = Math.round(seconds/(60*60))
        unit = 'hour'
      } else if(seconds < 60*60*24*7) {
        value = Math.round(seconds/(60*60*24))
        unit = 'day'
      } else if(seconds < 60*60*24*30) {
        value = Math.round(seconds/(60*60*24*7))
        unit = 'week'
      } else if(seconds < 60*60*24*365) {
        value = Math.round(seconds/(60*60*24*30))
        unit = 'month'
      } else {
        value = Math.round(seconds/(60*60*24*365))
        unit = 'year'
      }

      var props = this.props;

      return React.createElement( this.props.component, props, this.props.formatter(value, unit, suffix, then) )
    }
  }
);

var AvatarIMG = React.createClass({
  propTypes: {
    user: React.PropTypes.object.isRequired,
    size: React.PropTypes.number
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
      return React.createElement('img', Object.assign({}, this.props, {src:this.state.identicon, width:s, height:s}));
    } else {
      return React.createElement('img', Object.assign({}, this.props, {src:this.avatarURL(), width:s, height:s, onerror:this.fail}));
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
      console.log("identicon len: " + myIdenticon.length);
      window.identiconCache[cacheKey] = myIdenticon;
    }
    
    this.setState(Object.assign({}, this.state, {identicon: myIdenticon}));
    
    var img = document.createElement('img');
    img.onload = () => { this.loaded(); };
    img.src = url;
  }
});

var CommentControls = React.createClass({
  propTypes: {
    comment: React.PropTypes.object.isRequired,
    first: React.PropTypes.bool
  },
  
  render: function() {
    var els = [];
    els.push(React.createElement('i', {key:"edit", className:'fa fa-pencil'}));
    if (!this.props.first) {
      els.push(React.createElement('i', {key:"trash", className:'fa fa-trash-o'}));
    }
    return React.createElement('div', {className:'commentControls'}, els);
  }
});

var CommentHeader = React.createClass({
  propTypes: {
    comment: React.PropTypes.object.isRequired,
    first: React.PropTypes.bool
  },
  
  render: function() {
    console.log(this.props.comment);
    return React.createElement('div', {className:'commentHeader'},
      React.createElement(AvatarIMG, {user:this.props.comment.user||this.props.comment.author, size:32}),
      React.createElement('span', {className:'commentAuthor'}, this.props.comment.user.login),
      React.createElement('span', {className:'commentTimeAgo'}, " commented "),
      React.createElement(TimeAgo, {className:'commentTimeAgo', live:true, date:this.props.comment.created_at}),
      React.createElement(CommentControls, {comment:this.props.comment, first:this.props.first})
    );
  }
});

var Comment = React.createClass({
  propTypes: {
    comment: React.PropTypes.object.isRequired,
    first: React.PropTypes.bool
  },
  
  render: function() {
    return React.createElement('div', {className:'comment'},
      React.createElement(CommentHeader, {comment:this.props.comment, first:this.props.first}),            
      React.createElement('div', { 
        className:'commentBody', 
        dangerouslySetInnerHTML: {__html:marked(this.props.comment.body, markdownOpts)}
      })
    );
  }
});

var EventIcon = React.createClass({
  propTypes: {
    event: React.PropTypes.string.isRequired
  },
  
  render: function() {
    var icon;
    var pushX = 0;
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
        icon = "circle-o";
        break;
      case "closed":
        icon = "times-circle-o";
        break;
      case "reopened":
        icon = "circle-o";
        break;
      case "milestoned":
        icon = "calendar";
        break;
      case "unmilestoned":
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
        icon = "exclamation-circle";
        break;
    }
    
    var opts = {className:"eventIcon fa fa-" + icon};
    if (pushX != 0) {
      opts.style = { paddingLeft: pushX };
    }
    return React.createElement("i", opts);
  }
});

var EventUser = React.createClass({
  propTypes: { user: React.PropTypes.object.isRequired },
  
  render: function() {
    return React.createElement("span", {className:"eventUser"},
      React.createElement(AvatarIMG, {user:this.props.user, size:16, className:"eventAvatar"}),
      this.props.user.login
    );
  }
});

var AssignedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    // XXX: GitHub bug always sets the actor to the assignee.
    return React.createElement("span", {}, "was assigned");
    
    /*
    if (this.props.event.assignee.id == this.props.event.actor.id) {
      return React.createElement("span", {}, "self assigned this");
    } else {
      return React.createElement("span", {},
        React.createElement("span", {}, "assigned this to "),
        React.createElement(EventUser, {user:this.props.event.assignee})
      );
    }*/
  }
});

var UnassignedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    // XXX: GitHub bug always sets the actor to the assignee.
    return React.createElement("span", {}, "is no longer assigned");
  }
});

var MilestoneEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    if (this.props.event.milestone) {
      return React.createElement("span", {},
        "modified the milestone: ",
        React.createElement("span", {className: "eventMilestone"}, this.props.event.milestone.title)
      );
    } else {
      return React.createElement("span", {}, "unset the milestone");
    }
  }
});

var Label = React.createClass({
  propTypes: { label: React.PropTypes.object.isRequired },
  render: function() {
    // See http://stackoverflow.com/questions/12043187/how-to-check-if-hex-color-is-too-black
    var rgb = parseInt(this.props.label.color, 16);   // convert rrggbb to decimal
    var r = (rgb >> 16) & 0xff;  // extract red
    var g = (rgb >>  8) & 0xff;  // extract green
    var b = (rgb >>  0) & 0xff;  // extract blue

    var luma = 0.2126 * r + 0.7152 * g + 0.0722 * b; // per ITU-R BT.709

    var textColor = luma < 128 ? "white" : "black";
    
    return React.createElement("span", 
      {className:"label", style:{backgroundColor:"#"+this.props.label.color, color:textColor}},
      this.props.label.name
    );
  }
});

var LabelEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    var elements = [];
    elements.push(this.props.event.event);
    elements = elements.concat(this.props.event.labels.map(function(l) {
      return React.createElement(Label, {key:l.name, label:l});
    }));
    return React.createElement("span", {}, elements);
  }
});

var RenameEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    return React.createElement("span", {}, 
      "changed the title from ",
      React.createElement("span", {className:"eventTitle"}, this.props.event.rename.from || "empty"),
      " to ",
      React.createElement("span", {className:"eventTitle"}, this.props.event.rename.to || "empty")
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
    return React.createElement("span", {},
      "referenced this issue in commit ",
      React.createElement("a", {href:commitURL, target:"_blank"}, committish)
    );
  }
});

var MergedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    var [committish, commitURL] = expandCommit(this.props.event);
    return React.createElement("span", {},
      "merged this request with commit ",
      React.createElement("a", {href:commitURL, target:"_blank"}, committish)
    );
  }
});

var ClosedEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    if (typeof(this.props.event.commit_id) === "string") {
      var [committish, commitURL] = expandCommit(this.props.event);
      return React.createElement("span", {},
        "closed this issue with commit ",
        React.createElement("a", {href:commitURL, target:"_blank"}, committish)
      );
    } else {
      return React.createElement("span", {}, "closed this issue");
    }
  }
});
      
var UnknownEventDescription = React.createClass({
  propTypes: { event: React.PropTypes.object.isRequired },
  render: function() {
    return React.createElement("span", {}, this.props.event.event);
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
    return React.createElement('div', {className:className},
      React.createElement(EventIcon, {event: this.props.event.event }),
      React.createElement("div", {className: "eventContent"},
        React.createElement(EventUser, {user: this.props.event.actor }),
        " ",
        React.createElement(ClassForEvent(this.props.event), {event: this.props.event}),
        " ",
        React.createElement(TimeAgo, {className:"eventTime", live:true, date:this.props.event.created_at})
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
    var eventsAndComments = [firstComment];

    eventsAndComments = eventsAndComments.concat(this.props.issue.allEvents);
    eventsAndComments = eventsAndComments.concat(this.props.issue.allComments);
    
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
    
    return React.createElement('div', {className:'activityContainer'},
      React.createElement('div', {className:'activityList'}, 
        eventsAndComments.map(function(e, i, a) {
          if (e.event != undefined) {
            var next = a[i+1];
            console.log(e.id);
            return React.createElement(Event, {
              key:e.id, 
              event:e, 
              first:(i==0 || a[i-1].event == undefined),
              last:(next!=undefined && next.event==undefined),
              veryLast:(next==undefined)
            });
          } else {
            console.log(e.id);
            return React.createElement(Comment, {key:e.id, comment:e, first:i==0})
          }
        })
      )
    );
  }
});

var debugToken = "8de44b7cf7050c827165d3f509abb1bd187a62e4";

var DebugLoader = React.createClass({
  propTypes: { issue: React.PropTypes.object },
  render: function() {
    var ghURL = "https://github.com/" + this.props.issue._bare_owner + "/" + this.props.issue._bare_repo + "/issues/" + this.props.issue.number;
  
    return React.createElement("div", {className:"debugLoader"},
      React.createElement("form", {onSubmit:this.loadProblem},
        React.createElement("span", {}, "Load Problem: "),
        React.createElement("input", {type:"text", id:"debugInput", size:40, defaultValue:"" + this.props.issue._bare_owner + "/" + this.props.issue._bare_repo + "#" + this.props.issue.number}),
        React.createElement("a", {href:ghURL, target:"_blank"}, "source")
      )
    );
  },
  loadProblem: function(e) {
    e.preventDefault();
    
    var problemEl = document.getElementById("debugInput");
    var problemRef = problemEl.value;
    var [owner, repo, number] = problemRef.split(/[\/#]/);
    updateIssue(...problemRef.split(/[\/#]/));          
  }
});
      
function simpleFetch(url) {
  return new Promise(function(resolve, reject) {
    var initial = fetch(url, { headers: { Authorization: "token " + debugToken }, method: "GET" });
    initial.then(function(resp) {
      return resp.json();
    }).then(function(body) {
      resolve(body);
    }).catch(function(err) {
      reject(err);
    });
  });
}
      
function pagedFetch(url) /* => Promise */ {
  var opts = { headers: { Authorization: "token " + debugToken }, method: "GET" };
  var initial = fetch(url, opts);
  return initial.then(function(resp) {
    var pages = []
    var link = resp.headers.get("Link");
    if (link) {
      var [next, last] = link.split(", ");
      var matchNext = next.match(/\<(.*?)\>; rel="next"/);
      var matchLast = last.match(/\<(.*?)\>; rel="last"/);
      console.log(matchNext);
      console.log(matchLast);
      if (matchNext && matchLast) {
        var second = parseInt(matchNext[1].match(/page=(\d+)/)[1]);
        var last = parseInt(matchLast[1].match(/page=(\d+)/)[1]);
        console.log("second: " + second + " last: " + last);
        for (var i = second; i <= last; i++) {
          var pageURL = matchNext[1].replace(/page=\d+/, "page=" + i);
          console.log("Adding pageURL: " + pageURL);
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
              pagedFetch("https://api.github.com/repos/" + owner + "/" + repo + "/issues/" + number + "/comments")];
  
  Promise.all(reqs).then(function(parts) {
    console.log("all resolved");
    var issue = parts[0];
    issue.allEvents = parts[1];
    issue.allComments = parts[2];
    console.log(issue);
    
    if (issue.id) {
      renderIssue(issue);
    }
  }).catch(function(err) {
    console.log(err);
  });
}

function renderIssue(issue) {
  console.log("rendering:");
  console.log(issue);
  
  window.document.title = issue.title;
  
  if (issue.repository_url) {
    var comps = issue.repository_url.replace("https://", "").split("/");
    issue._bare_owner = comps[comps.length-2]
    issue._bare_repo = comps[comps.length-1]
  } else {
    if (issue.owner) {
      issue._bare_owner = issue.owner.login;
    }
    if (issue.repository) {
      issue._bare_repo = issue.repository.name;
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
  
  window.currentIssue = issue;
  
  var activityElement = React.createElement(ActivityList, {key:issue["id"], issue:issue});
  var outerElement = activityElement;
  if (debugToken && !window.inApp) {
    outerElement = React.createElement("div", {},
      React.createElement(DebugLoader, {issue:issue}),
      activityElement
    );
  }
  ReactDOM.render(
    outerElement,
    document.getElementById('react-app')
  )
}

window.updateIssue = updateIssue;
window.renderIssue = renderIssue;

// if (!window.inApp) {
//   updateIssue("realartists", "shiphub-server", "10")
// }

renderIssue({"id":132304507,"body":"- [ ] Pass through to Github for now.","events":[{"id":543761951,"actor":{"login":"kogir","id":87309},"event":"milestoned","created_at":"2016-02-09T01:16:24.0000000Z"},{"id":543761950,"actor":{"login":"kogir","id":87309},"event":"milestoned","created_at":"2016-02-09T01:16:24.0000000Z"},{"assignee":{"login":"kogir","id":87309},"id":543762077,"actor":{"login":"kogir","id":87309},"event":"assigned","created_at":"2016-02-09T01:16:32.0000000Z"},{"assignee":{"login":"kogir","id":87309},"id":549212855,"actor":{"login":"kogir","id":87309},"event":"unassigned","created_at":"2016-02-12T23:49:39.0000000Z"},{"assignee":{"login":"kogir","id":87309},"id":549212943,"actor":{"login":"kogir","id":87309},"event":"assigned","created_at":"2016-02-12T23:49:51.0000000Z"},{"assignee":{"login":"james-howard","id":2006254},"id":557234562,"actor":{"login":"james-howard","id":2006254},"event":"assigned","created_at":"2016-02-19T23:12:34.0000000Z"},{"assignee":{"login":"kogir","id":87309},"id":557234561,"actor":{"login":"kogir","id":87309},"event":"unassigned","created_at":"2016-02-19T23:12:34.0000000Z"},{"id":562310307,"actor":{"login":"james-howard","id":2006254},"event":"labeled","created_at":"2016-02-23T20:21:26.0000000Z"},{"id":562329516,"actor":{"login":"james-howard","id":2006254},"event":"labeled","created_at":"2016-02-23T20:33:07.0000000Z"},{"id":562346774,"actor":{"login":"james-howard","id":2006254},"event":"unlabeled","created_at":"2016-02-23T20:44:55.0000000Z"},{"id":562346772,"actor":{"login":"james-howard","id":2006254},"event":"unlabeled","created_at":"2016-02-23T20:44:55.0000000Z"},{"id":562587856,"actor":{"login":"james-howard","id":2006254},"event":"locked","created_at":"2016-02-23T23:19:29.0000000Z"},{"id":562590752,"actor":{"login":"james-howard","id":2006254},"event":"unlocked","created_at":"2016-02-23T23:21:46.0000000Z"},{"id":602479909,"actor":{"login":"kogir","id":87309},"event":"milestoned","created_at":"2016-03-24T23:22:17.0000000Z"},{"id":602479910,"actor":{"login":"kogir","id":87309},"event":"milestoned","created_at":"2016-03-24T23:22:17.0000000Z"},{"id":602479908,"actor":{"login":"kogir","id":87309},"event":"demilestoned","created_at":"2016-03-24T23:22:17.0000000Z"},{"id":602479911,"actor":{"login":"kogir","id":87309},"event":"demilestoned","created_at":"2016-03-24T23:22:17.0000000Z"},{"id":602480259,"actor":{"login":"kogir","id":87309},"event":"demilestoned","created_at":"2016-03-24T23:22:36.0000000Z"},{"id":602480258,"actor":{"login":"kogir","id":87309},"event":"demilestoned","created_at":"2016-03-24T23:22:36.0000000Z"},{"id":602481375,"actor":{"login":"kogir","id":87309},"event":"milestoned","created_at":"2016-03-24T23:23:43.0000000Z"},{"id":602481376,"actor":{"login":"kogir","id":87309},"event":"milestoned","created_at":"2016-03-24T23:23:43.0000000Z"}],"full_identifier":"realartists\/shiphub-server#10","closed":0,"originator":{"login":"kogir","id":87309},"created_at":"2016-02-09T01:16:10.0000000Z","assignee":{"login":"james-howard","id":2006254},"labels":[],"comments":[],"title":"Support watching","milestone":{"id":1664918,"title":"Public Beta","updated_at":"2016-03-24T23:23:44.0000000Z","due_on":"2016-06-05T07:00:00.0000000Z"},"number":10,"locked":0,"updated_at":"2016-03-24T23:23:43.0000000Z","repository":{"full_name":"realartists\/shiphub-server","private":1,"id":51336290,"name":"shiphub-server","hidden":0}})
