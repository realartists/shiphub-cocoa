import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'

import { keypath, setKeypath } from 'util/keypath.js'
import IssueState from 'issue-state.js'
import { PRMergeChangesButton } from './pr-actions-bar.js'
import Reviewers from './reviewers.js'
import { ReviewState, reviewStateToUI } from './review-state.js'
import { CommitStatuses, findLatestCommitStatuses, CommitStatusTable } from './commit-group.js'
import ghost from 'util/ghost.js'
import AvatarIMG from '../AvatarIMG.js'
import DonutGraph from './donut-graph.js'

import './pr-mergeability.css'
import PRMergeAvatar from '../../../image/MergeAvatar.svg'

var redColor = '#CB2431';
var greenColor = "#2CBE4E";
var yellowColor = '#FFC500';

class PRMergeabilitySection extends React.Component {
  render() {
    var subheading = this.props.subheading
    var heading = this.props.heading;
    var state = this.props.state;
    var parts = this.props.parts;
    
    var extra = null;
    if (this.props.children) {
      extra = h('div', { className:'PRMergeabilitySectionActions' },
        this.props.children
      );
    }
    
    var headingStyle = { };
    
    if (state == "error") {
      headingStyle.color = redColor;
    }
    
    var icon;
    if (parts) {
      var total = parts.reduce((accum, p) => accum + p.count, 0);
      var green = parts.filter(p => p.color != greenColor).length;
      
      if (total == green) {
        icon = h(PRMergeabilityIcon, { state:"ok" });
      } else {
        icon = h(DonutGraph, { parts, size: 30 });
      }
    } else {
      icon = h(PRMergeabilityIcon, { state });
    }
        
    return h('div', { className:'PRMergeabilitySection' },
      icon, 
      h('div', { className:'PRMergeabilitySectionText' },
        h('div', { className: 'PRMergeabilitySectionHeading', style: headingStyle }, heading),
        h('div', { className: 'PRMergeabilitySectionSubheading' }, subheading)
      ),
      extra
    );
  }
}

class PRMergeabilityIcon extends React.Component {
  render() {
    var icon, color;
    if (this.props.state == 'ok') {
      icon = 'fa-check-circle';
      color = greenColor;
    } else if (this.props.state == 'warning' || this.props.state == 'pending') {
      icon = 'fa-circle-o';
      color = yellowColor;
    } else {
      icon = 'fa-circle-o';
      color = redColor;
    }
    
    var className = `fa ${icon} PRMergeabilityIcon`;
    if (this.props.className) {
      className += " " + this.props.className;
    }
    
    return h('i', { className, style: { color } });
  }
}

class PRMergeabilityHeader extends React.Component {
  render() {    
    return h('div', { className:'PRMergeabilityHeader' },
      h('img', { className: 'PRMergeabilityImg', src: PRMergeAvatar }),
      h('span', { }, 'Merge Checklist')
    );
  }
}


class PRMergeabilityReview extends React.Component {
  constructor(props) {
    super(props);
    
    this.state = { dismiss: false };
  }

  jump(evt) {
    var id = `review.${this.props.item.review.id}`;
    var el = document.getElementById(id);
    
    if (el) {
      el.scrollIntoView();
    }
    
    evt.preventDefault();
  }
  
  toggleDismiss(evt) {
    this.needsInputFocus = !this.state.dismiss;
    this.setState({dismiss:!this.state.dismiss});
    evt.preventDefault();
  }
  
  dismiss(evt) {
    try {
      var dismissText = this.state.dismissText;
      this.setState({dismiss:false, dismissText:""});
      IssueState.current.dismissReview(this.props.item.review.id, dismissText);
    } finally {
      evt.preventDefault();
    }
  }
  
  updateDismissText(evt) {
    this.setState({dismissText:evt.target.value});
  }
  
  componentDidUpdate() {
    if (this.needsInputFocus) {
      this.needsInputFocus = false;
    }
    if (this.refs.dismissInput) {
      this.refs.dismissInput.focus();
    }
  }

  render() {
    var user = this.props.item.user||ghost;
    if (this.state.dismiss) {
      var text = this.state.dismissText||"";
      return h('form', {onSubmit:this.dismiss.bind(this)}, 
        h('div', {className:'PRMergeabilityReview PRMergeabilityReviewDismiss'},
          h('input', { 
            className:'PRMergeabilityDismissText',
            ref:'dismissInput',
            type:'text',
            value:text,
            placeholder:`Why are you dismissing ${user.login}'s review?`,
            onChange:this.updateDismissText.bind(this),
          }),
          h('button', {
            type:'button',
            className:'PRMergeabilityDismissCancel', 
            onClick:this.toggleDismiss.bind(this)
          }, "Cancel"),
          h('button', {
            type:'submit',
            enabled:text.trim().length>0, 
            className:'PRMergeabilityDismissSubmit', 
            onClick:this.dismiss.bind(this),
            onSubmit:this.dismiss.bind(this)
          }, "Dismiss Review")
        )
      );
    } else {
      var icon, bg, action, click;
      var state = keypath(this.props.item, "review.state");
      var reviewUI = reviewStateToUI(state);
      icon = reviewUI.icon;
      bg = reviewUI.bg;
      action = reviewUI.action;
      click = this.jump.bind(this);
    
      var actions = [];
      if (this.props.item.review) {
        actions.push(h('a', {key:'see', href:'#', onClick:this.jump.bind(this)}, 'See Review'));
      } 
      if (state == ReviewState.RequestChanges) {
        actions.push(h('a', {key:'dismiss', href:'#', onClick:this.toggleDismiss.bind(this)}, 'Dismiss Review'));
      }
      
      return h('div', { className: 'PRMergeabilityReview' },
        h('i', {key:'icon', className:`fa ${icon}`, style:{ color: bg }}),
        h(AvatarIMG, {key:'avatar', size:16, user:user}),
        h('span', {key:'user', className:'PRMergeabilityReviewUser'}, user.login),
        h('span', {key:'summary', className:'PRMergeabilityReviewSummary'}, ` ${action}`),
        h('div', {key:'actions', className:'PRMergeabilityReviewActions'},
          actions
        )
      );     
    }
  }
}

class PRMergeabilityReviewers extends React.Component {
  constructor(props) {
    super(props);
    
    var hasPendingOrRequestChanges = props.reviewItems.some(r => !r.review || r.review.state == ReviewState.RequestChanges);
    
    this.state = { expanded: hasPendingOrRequestChanges };
  }
  
  toggleExpanded() {
    this.setState({expanded: !this.state.expanded});
  }
  
  render() {
    var items = this.props.reviewItems.filter(r => {
      return !r.review || 
              r.review.state == ReviewState.Pending || 
              r.review.state == ReviewState.Approve ||
              r.review.state == ReviewState.RequestChanges;
    });
  
    if (items.length == 0) {
      return h('span', {}); // no reviews.
    }
  
    var body = null;
    if (this.state.expanded) {
      body = items.map((r, idx) => {
        return h(PRMergeabilityReview, {
          key:r.review?r.review.id:idx,
          item:r
        });
      });
    }

    var count = {
      pending: 0,
      requestChanges: 0,
      commented: 0,
      approve: 0,
      dismiss: 0,
    };
    
    items.forEach((ri, idx) => {
      if (!ri.review) count.pending++;
      else switch (ri.review.state) {
        case ReviewState.Pending: count.pending++; break;
        case ReviewState.Approve: count.approve++; break;
        case ReviewState.RequestChanges: count.requestChanges++; break;
      } 
    });
    
    var state = "ok";
    var heading = "";
    var subheading = "";
    
    if (count.requestChanges == 1) {
      state = "error";
      heading = "Changes requested";
      subheading = "1 review requesting changes";
    } else if (count.requestChanges > 1) {
      state = "error";
      heading = "Changes requested";
      subheading = `${count.requestChanges} reviews requesting changes`;
    } else if (count.pending == 1) {
      state = "warning";
      heading = "Review needed";
      subheading = "1 review pending";
    } else if (count.pending > 1) {
      state = "warning";
      heading = "Reviews needed";
      subheading = `${count.pending} reviews pending`;
    } else if (count.approve == 1) {
      state = "ok";
      heading = "Changes approved";
      subheading = "1 review approving these changes";
    } else /* (count.approve > 1) */ {
      state = "ok";
      heading = "Changes approved";
      subheading = `${count.approve} reviews approving these changes`;
    }
    
    var parts = [ { color: redColor, count: count.requestChanges },
                  { color: yellowColor, count: count.pending },
                  { color: greenColor, count: count.approve } ];
    
    var caretType = this.state.expanded ? 'fa-caret-up' : 'fa-caret-down';
    
    return h('div', { className:'PRMergeabilityReviewersContainer' },
      h(PRMergeabilitySection, { heading, subheading, state, parts },
        h('i', { className:`fa ${caretType} PRMergeabilityCaret`, onClick: this.toggleExpanded.bind(this) })
      ),
      body
    );
  }
}

class PRMergeabilityStatuses extends React.Component {
  constructor(props) {
    super(props);
    
    this.state = { expanded: props.statuses.some(cs => cs.state != 'success' ) };
  }
  
  toggleExpanded() {
    this.setState({expanded: !this.state.expanded});
  }
  
  render() {
    var statuses = this.props.statuses;
    
    if (statuses.length == 0) {
      return h('span', {}); // nop
    }
    
    var parts = {
      pending: [],
      success: [],
      failure: []
    };
    
    statuses.forEach(cs => {
      switch (cs.state) {
        case "error":
        case "failure": parts.failure.push(cs); break;
        case "success": parts.success.push(cs); break;
        case "unknown": 
        case "pending": 
        default: parts.pending.push(cs); break;
      }
    });
    
    var state = "ok";
    var heading = "";
    var subheading = "";
    if (parts.failure.length == 1) {
      state = "error";
      heading = "1 check failed";
      subheading = parts.failure[0].status_description;
    } else if (parts.failure.length > 1) {
      state = "error";
      heading = `${parts.failure.length} checks failed`;
      subheading = parts.failure.slice(0, 3).map(cs => cs.context).join(", ");
      if (parts.failure.slice.length > 3) {
        subheading += " …";
      }
    } else if (parts.pending.length == 1) {
      state = "pending";
      heading = "1 check pending";
      subheading = parts.pending[0].context;
    } else if (parts.pending.length > 1) {
      state = "pending";
      heading = `${parts.pending.length} checks pending`;
      subheading = parts.pending.slice(0, 3).map(cs => cs.context).join(", ");
      if (parts.failure.slice.length > 3) {
        subheading += " …";
      }
    } else if (parts.success.length == 1) {
      state = "ok";
      heading = "Check successful";
      subheading = parts.success[0].status_description;
    } else if (parts.success.length > 1) {
      state = "ok";
      heading = "All checks have passed";
      subheading = `${parts.success.length} successful checks`;
    }
    
    var body;
    if (this.state.expanded) {
      body = h('div', {className:'PRMergeabilityStatusesTableContainer'},
        h(CommitStatusTable, { statuses })
      );
    }
    
    var caretType = this.state.expanded ? 'fa-caret-up' : 'fa-caret-down';
    
    var sectionParts = [ { color: redColor, count: parts.failure.length },
                         { color: yellowColor, count: parts.pending.length },
                         { color: greenColor, count: parts.success.length } ];
    
    return h('div', { className:'PRMergeabilityStatusesContainer' },
      h(PRMergeabilitySection, { heading, subheading, state, parts:sectionParts },
        h('i', { className:`fa ${caretType} PRMergeabilityCaret`, onClick: this.toggleExpanded.bind(this) })
      ),
      body
    );
  }
}

class PRMergeabilityMergeStatus extends React.Component {
  editConflicts(evt) {
    window.editConflicts.postMessage({});
    evt.preventDefault();
  }
  
  render() {
    var state = "ok";
    var msg = "";
    
    var headRepo = keypath(this.props.issue, "head.repo.full_name");
    var baseRepo = keypath(this.props.issue, "base.repo.full_name");
    
    var headBranch = keypath(this.props.issue, "head.ref");
    var baseBranch = keypath(this.props.issue, "base.ref");
    
    var summary;
    var author = (this.props.issue.user||ghost).login;
    
    var headRef;
    if (headRepo != baseRepo) {
      headRef = `${headRepo}:headBranch`;
    } else {
      headRef = headBranch;
    }
    
    var mergeable = this.props.issue.mergeable;
    var mergeable_state = this.props.issue.mergeable_state;
    var button = null;
    var state = "ok";
    var heading = "";
    var subheading = "";
    if (mergeable === undefined || mergeable === null) {
      state = "pending";
      heading = "Test merge pending";
      subheading = `Computing mergeability of ${headRef} into ${baseBranch} ...`;
    } else if (mergeable || mergeable_state != "dirty") {
      state = "ok";
      heading = "This branch is up-to-date with the base branch";
      subheading = "Merging can be performed automatically";
    } else {
      state = "error";
      heading = "This branch has conflicts that must be resolved";
      subheading = `Resolve the conflicts and push your changes to ${headRef}`;
      button = h('button', { className:'PRMergeabilityMergeStatusConflictsButton', onClick:this.editConflicts.bind(this) },
        "Resolve Conflicts"
      );
    }
    
    var parts = [ { color: redColor, count: state == "error" ? 1 : 0, },
                  { color: yellowColor, count: state == "pending" ? 1 : 0 },
                  { color: greenColor, count: state == "ok" ? 1 : 0 } ];
  
    return h(PRMergeabilitySection, { state, heading, subheading, parts },
      button
    );
  }
}

class PRMergeabilityActions extends React.Component {
  render() {
    return h('div', { className:'PRMergeabilityActions' },
      h(PRMergeChangesButton, { issue: this.props.issue })
    );
  }
}

class PRMergeability extends React.Component {
  render() {
    if (this.props.issue.state == 'closed' || !this.props.issue.number || !this.props.issue.pull_request) {
      return h('span', {}); // we're closed. go home.
    }
    
    var reviewItems = Reviewers.latestReviews(this.props.issue, this.props.allReviews);
  
    var statuses = this.props.issue.commit_statuses||[];
    var tot = keypath(this.props.issue, "head.sha");
    statuses = statuses.filter(cs => cs.reference = tot);
    statuses = findLatestCommitStatuses(statuses);
  
    return h('div', {className:'PRMergeability'},
      h(PRMergeabilityHeader, {issue:this.props.issue, statuses, reviewItems}),
      h('div', {className:'PRMergeabilityBody'},
        h(PRMergeabilityReviewers, {issue:this.props.issue, reviewItems}),
        h(PRMergeabilityStatuses, {statuses}),
        h(PRMergeabilityMergeStatus, {issue:this.props.issue}),
        h(PRMergeabilityActions, {issue:this.props.issue})
      )
    );
  }
}

export default PRMergeability;
