import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'

import AvatarIMG from 'components/AvatarIMG.js'
import { TimeAgo, TimeAgoString } from 'components/time-ago.js'
import DiffHunk from './diff-hunk.js'
import ghost from 'util/ghost.js'
import AbstractComment from 'components/comment/AbstractComment.js'
import { keypath } from 'util/keypath.js'
import { promiseQueue } from 'util/promise-queue.js'
import IssueState from 'issue-state.js'
import { api } from 'util/api-proxy.js'
import { storeCommentDraft, clearCommentDraft, getCommentDraft } from 'util/draft-storage.js'

import './review.css'

// See PRReviewState enum in PRReview.m
var ReviewState = {
  Pending: 0,
  Approve: 1,
  RequestChanges: 2,
  Comment: 3,
  Dismiss: 4
}

class ReviewHeader extends React.Component {
  render() {
    var user = this.props.review.user || ghost;
    
    var icon, action, bg = '#555';
    switch (this.props.review.state) {
      case ReviewState.Pending:
        icon = 'fa-commenting';
        action = 'saved a pending review';
        break;
      case ReviewState.Approve:
        icon = 'fa-thumbs-up';
        action = 'approved these changes';
        bg = 'green';
        break;
      case ReviewState.RequestChanges:
        icon = 'fa-thumbs-down'
        action = 'requested changes';
        bg = 'red';
        break;
      case ReviewState.Comment:
        icon = 'fa-comments';
        action = 'reviewed';
        break;
    }
    
    return h('div', { className: 'reviewHeader' },
      h('span', { className:'reviewIcon', style: { backgroundColor: bg } },
        h('i', { className: `fa ${icon} fa-inverse`})
      ),
      h(AvatarIMG, { className: 'reviewAuthorIcon', user:user, size:16 }),
      h('span', { className: 'reviewAuthor' }, user.login),
      h('span', { className: 'reviewAction' }, ` ${action} `),
      h(TimeAgo, {className:'commentTimeAgo', live:true, date:this.props.review.submitted_at||this.props.review.created_at})
    );
  }
}

class ReviewAbstractComment extends AbstractComment {
  me() { return IssueState.me; }
  issue() { return IssueState.current.issue; }
  isNewIssue() { return false; } 
  canClose() { return false; }
  repoOwner() { return IssueState.current.repoOwner; }
  repoName() { return IssueState.current.repoName; }
  shouldShowCommentPRBar() { return false; }
  saveDraftState() { }
  restoreDraftState() { }
  loginCompletions() {
    return IssueState.current.allLoginCompletions
  }
  renderHeader() /* overridden */ {
    return h('span', {});
  }
}

class ReviewSummaryComment extends ReviewAbstractComment {
  
}

class ReviewSummary extends React.Component {
  render() {
    return h(ReviewSummaryComment, {
      comment: this.props.review,
      className: 'reviewComment'
    });
  }
}

class ReviewCodeComment extends ReviewAbstractComment {
  
}

class ReviewCommentBlock extends React.Component {
  constructor(props) {
    super(props);
    
    this.state = { collapsed: this.canCollapse() }
  }
  
  canCollapse() {
    return (this.props.comment.position === undefined);
  }
  
  onCollapse() {
    var canCollapse = this.canCollapse();
    if (canCollapse) {
      this.setState(Object.assign({}, this.state, {collapsed:!this.state.collapsed}));
    } else if (this.state.collapsed) {
      this.setState(Object.assign({}, this.state, {collapsed:false}));
    }
  }
  
  render() {
    var comps = [];
    var canCollapse = this.canCollapse();
    var collapsed = this.state.collapsed;
    
    console.log("ReviewCommentBlock collapsed", collapsed);

    comps.push(h(DiffHunk, { 
      key:"diff", 
      comment: this.props.comment,
      canCollapse: canCollapse,
      collapsed: collapsed,
      onCollapse: this.onCollapse.bind(this) 
    }));
    
    if (!collapsed) {
      comps.push(h(ReviewCodeComment, { key:"comment", className: 'reviewComment', comment: this.props.comment }));
    } 
    
    return h('div', { className:'reviewCommentBlock' }, comps);
  }
}

class Review extends React.Component {
  render() {
    var hasSummary = this.props.review.body && this.props.review.body.trim().length > 0;
    
    var sortedComments = Array.from(this.props.review.comments).filter(c => !(c.in_reply_to));
    sortedComments.sort((a, b) => {
      var da = new Date(a.created_at);
      var db = new Date(b.created_at);
      
      if (da < db) return -1;
      else if (da > db) return 1;
      else return 0;
    });
    
    var comps = [];
    comps.push(h(ReviewHeader, { key:"header", review: this.props.review }));
    if (hasSummary) {
      comps.push(h(ReviewSummary, { key:"summary", review: this.props.review }));
    } else {
      comps.push(h('div', { key:'summaryPlaceholder', className: 'reviewSummaryPlaceholder' }));
    }
    comps = comps.concat(sortedComments.map((c) => h(ReviewCommentBlock, { key:c.id, review: this.props.review, comment: c })));
    
    return h('div', { className: 'review' }, comps);
  }
}

export default Review;
