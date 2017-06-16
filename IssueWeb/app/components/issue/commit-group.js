import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import escape from 'html-escape'
import linkify from 'html-linkify'

import AvatarIMG from 'components/AvatarIMG.js'
import { TimeAgo, TimeAgoString } from 'components/time-ago.js'
import ghost from 'util/ghost.js'
import { githubLinkify } from 'util/github-linkify.js'
import { PRReviewChangesButton } from './pr-actions-bar.js'
import { keypath } from 'util/keypath.js'

import './commit-group.css'
import CommitBullet from '../../../image/CommitBullet.png'

function getSubjectAndBodyFromCommitMessage(message) {
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
}

function findLatestCommitStatuses(statuses) {
  statuses = Array.from(statuses);

  // sort statuses by (reference, context, updated_at DESC, [identifier])
  statuses.sort((a, b) => {
    var da, db;
    if (a.reference < b.reference) return -1;
    else if (a.reference > b.reference) return 1;
    else if (a.context < b.context) return -1;
    else if (a.context > b.context) return 1;
    else if ((da = new Date(a.updated_at)) > (db = new Date(b.updated_at))) return -1;
    else if (da < db) return 1;
    else if (a.identifier < b.identifier) return -1;
    else if (a.identifier > b.identifier) return 1;
    else return 0;
  });
  
  // reduce statuses such that we only have the latest status per unique (reference, context)
  statuses = statuses.reduce((accum, status) => {
    if (accum.length == 0) return [status];
    var prev = accum[accum.length-1];
    if (prev.reference != status.reference || prev.context != status.context) {
      return accum.concat([status]);
    } else {
      return accum;
    }
  }, []);
  
  return statuses;
}

class CommitStatusTableRow extends React.Component {
  render() {
    return h('div', {className:'CommitStatusTableRow'},
      h('div', {className:'CommitTableStatus'},
        h(CommitStatuses, {statuses:[this.props.status]})
      ),
      h('div', {className:'CommitTableStatusInfo', title:`${this.props.status.context} — ${this.props.status.status_description}`},
        h('a', {href:this.props.status.target_url},
          h('span', {className:'CommitTableStatusContext'}, this.props.status.context),
          h('span', {className:'CommitTableStatusContextSeparator'}, ' — '),
          h('span', {className:'CommitTableStatusDescription'}, this.props.status.status_description)
        )
      ),
      this.props.required?h('div', {className:'CommitTableStatusRequired'}, 'Required'):null,
      this.props.status.id<0?null:h('div', {className:'CommitTableLink'},
        h('a', {href:this.props.status.target_url, className:'fa fa-arrow-circle-right'})
      )
    );
  }
}

class CommitStatusTable extends React.Component {
  render() {
    var requiredContexts = new Set(keypath(this.props.issue, "base_branch_protection.required_status_checks.contexts")||[]);
    
    var statuses = Array.from(this.props.statuses);
    
    // mix in any required contexts that we don't have anything for
    var presentStatusContexts = new Set(statuses.map(cs => cs.context));
    var missingStatusContexts = Array.from(requiredContexts).filter(c => !presentStatusContexts.has(c));
    
    statuses = missingStatusContexts.
      map((c, i) => { return { id:-i, context:c, status_description:"Waiting for status to be reported", status:"pending" } }).
      concat(statuses);
    
    return h('div', {className:'CommitStatusTable'},
      statuses.map(cs => h(CommitStatusTableRow, {key:cs.id, status:cs, required:requiredContexts.has(cs.context)}))
    );
  }
}

class CommitGroupHeader extends React.Component {
  render() {
    var commits = this.props.commits;
    
    var committers = commits.map((x) => x.committer || x.author || ghost);
    committers = committers.filter((x) => x.email != 'noreply@github.com');
    
    var user = committers.length > 0 ? committers[0] : ghost;
    var hasOthers = committers.some((x) => x.email != user.email);
    
    var timestamp = commits.length > 0 ? commits[0].created_at : new Date();
    var desc = "";
    if (commits.length == 1) {
      desc = " added a commit ";
    } else {
      desc = ` added ${commits.length} commits `;
    }
    
    return h('div', { className:'commitGroupHeader' },
      h('div', { className:'commitGroupHeaderDetails' },
        h('span', { className: 'commitGroupIcon fa fa-git-square' }),
        h('span', {className:'commitGroupAuthor', title:user.email}, user.name),
        hasOthers ? h('span', {className:'commitGroupOthers'}, ' and others') : "",
        h('span', {className:'commitGroupTimeAgo'}, desc),
        h(TimeAgo, {className:'commentTimeAgo', live:true, date:timestamp}),
      ),
      h('div', { className:'commitGroupHeaderActions' },
        h(PRReviewChangesButton, {})
      )
    );
  }
}

class CommitStatuses extends React.Component {
  iconForState(state) {
    if (state == 'pending') {
      return h('i', { className: 'fa fa-clock-o commitStatusIconPending' });
    } else if (state == 'success') {
      return h('i', { className: 'fa fa-check commitStatusIconSuccess' });
    } else if (state == 'failure' || state == 'error') {
      return h('i', { className: 'fa fa-times-circle commitStatusIconFailure' });
    } else {
      return h('i', { className: 'fa fa-question-circle commitStatusIconUnknown' });
    }
  }
  
  overallStateForStatuses() {
    function stateToPriority(state) {
      switch(state) {
        case 'success': return 1;
        case 'pending': return 2;
        case 'error':
        case 'failure': return 3;
        default: return 0;
      }
    }
  
    return this.props.statuses.reduce((accum, status) => {
      var p1 = stateToPriority(accum);
      var p2 = stateToPriority(status.state);
      if (p1 < p2) return status.state;
      else return accum;
    }, "");
  }
  
  summaryDescription() {
    var count = {
      failed: 0,
      success: 0,
      pending: 0
    };
    
    this.props.statuses.forEach(s => {
      switch (s.state) {
        case 'success':
          count.success++;
          break;
        case 'pending':
          count.pending++;
          break;
        case 'failed':
        case 'error':
          count.failed++;
          break;
      }
    });
      
    var d = { msg: "" }
    var msg = (text) => {
      if (d.msg.length == 0) d.msg = text;
      else d.msg += ", " + text;
    } 
    if (count.success == 1) {
      msg("1 check passed");
    } else if (count.success > 1) {
      msg(`${count.success} checks passed`);
    }
    
    if (count.pending == 1) {
      msg("1 check pending");
    } else if (count.pending > 1) {
      msg(`${count.pending} checks pending`);
    }
    
    if (count.failed == 1) {
      msg("1 check failed");
    } else if (count.failed > 1) {
      msg(`${count.failed} checks failed`);
    }
    
    if (d.msg.length > 0) d.msg = ` ${d.msg}.`;
    
    return d.msg;
  }
  
  onClick(evt) {
    this.props.onClick(evt);
    evt.preventDefault();
  }

  render() {
    var statuses = this.props.statuses;
    
    var onClick = this.props.onClick;
    var desc = this.props.expanded ? this.summaryDescription() : null;
    console.log("desc", desc);
    
    if (statuses.length == 1) {
      var status = statuses[0];
      var title = status.statusDescription;
      var opts = { className:'commitStatuses', title: status.status_description };
      if (onClick) {
        opts.href = '#';
        opts.onClick = this.onClick.bind(this);
      } else {
        opts.href = status.target_url;
      }
      return h('a', opts,
        this.iconForState(status.state)
      );
    } else {
      var opts = { className:'commitStatuses', title: 'Click to view multiple commit statuses' };
      if (onClick) {
        opts.href = '#';
        opts.onClick = this.onClick.bind(this);
      } else {
        opts.href = this.props.commitUrl;
      }
      return h('a', opts,
        this.iconForState(this.overallStateForStatuses()),
        desc
      );
    }
  }
}

class Commit extends React.Component {
  constructor(props) {
    super(props);
    this.state = { showBody: false };
  }


  toggleBody(clickEvent) {
    this.setState({showBody: !this.state.showBody});
    clickEvent.preventDefault();
  }

  render() {
    var hasComments = (this.props.commit.sha in this.props.commitCommentsBySha);
    var message = this.props.commit.message;
    const [subject, body] = getSubjectAndBodyFromCommitMessage(message);
    var statuses = this.props.statuses;
    
    var hasStatuses = statuses && statuses.length > 0;
    
    var bodyContent = null;
    if (this.state.showBody && body) {
      var issue = this.props.issue;
      var [repoOwner, repoName] = issue.full_identifier.split(/\//);
      
      const linkifiedBody = githubLinkify(
        repoOwner,
        repoName,
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
            onClick: this.toggleBody.bind(this)
          },
          h("button", {className: "referencedCommitExpander"}, "\u2026")
        );
    }
      
    var commentIcon = null;
    if (hasComments) {
      commentIcon = h('a', {href:this.props.commit.html_url+"#comments", style:{marginLeft:'2px'}},
        h('i', {className:'fa fa-comments-o'})
      );
    }
      
    return h('tr', { className: 'commitGroupRow' },
      h('td', {},
        h('img', { className:'commitItemBullet', src:CommitBullet, width: "12", height: "12"}),
      ),
      h('td', {className:'commitItemMessage', colSpan:hasStatuses?1:2},
        subject, expander, commentIcon, h('br', {}), bodyContent
      ),
      hasStatuses ? h('td', {}, h(CommitStatuses, {statuses, commitUrl: this.props.commit.html_url })) : null,
      h('td', {},
        h('a', { className:'commitItemHash', href:this.props.commit.html_url }, this.props.commit.sha.substr(0, 7))
      )  
    );
  }
}

class CommitGroup extends React.Component {
  render() {
    var issue = this.props.issue;
    var commits = Array.from(this.props.commits);
    var commitCommentsBySha = this.props.commitCommentsBySha;
    
    var commitShas = new Set();
    
    // unique commits
    var uniqueCommits = [];
    commits.forEach(c => {
      if (!commitShas.has(c.sha)) {
        commitShas.add(c.sha);
        uniqueCommits.push(c);
      }
    });
    commits = uniqueCommits;
    
    var commitsBySha = {};
    commits.forEach(c => {
      commitsBySha[c.sha] = c;
    });
    
    // see if we can order our commits using the parent pointer(s)
    commits.forEach(c => {
      c._prev = commitsBySha[c.parents[0].sha];
      if (c._prev) c._prev._next = c;
    });
    
    var head = commits.find(c => !(c._prev));
    
    var depth = 0;
    while (head) {
      head._depth = depth++;
      head = head._next;
    }
    
    // now sort commits by their depth from the first commit in the group
    // or by (date, identifier) failing those things
    commits.sort((a, b) => {
      if (a._depth < b._depth) return -1;
      else if (a._depth > b._depth) return 1;
      
      var da = new Date(a.created_at);
      var db = new Date(b.created_at);
      if (a.identifier < b.identifier) return -1;
      else if (a.identifier > b.identifier) return 1;
      else return 0;
    });
    
    // only care about statuses for commits in this push
    var statuses = this.props.issue.commit_statuses.filter(cs => commitShas.has(cs.reference));
    
    // eliminate obsolete statuses
    statuses = findLatestCommitStatuses(statuses);
        
    var statusesBySha = {};
    statuses.forEach(cs => {
      if (!statusesBySha[cs.reference]) {
        statusesBySha[cs.reference] = [];
      }
      statusesBySha[cs.reference].push(cs);
    });
    
    return h('div', { className:'BlockItem commitGroup' },
      h(CommitGroupHeader, { commits: this.props.commits }),
      
      h('table', {className:'commitGroupTable'},
        h('tbody', {}, 
          commits.map((commit) => h(Commit, { key:commit.sha, commit, statuses: statusesBySha[commit.sha], issue, commitCommentsBySha }))
        )
      )
    );
  }
}

export { 
  CommitStatuses, 
  CommitGroup,
  CommitStatusTable,
  getSubjectAndBodyFromCommitMessage,
  findLatestCommitStatuses,
}
