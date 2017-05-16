import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'

import AvatarIMG from 'components/AvatarIMG.js'
import { TimeAgo, TimeAgoString } from 'components/time-ago.js'
import DiffHunk from './diff-hunk.js'
import ghost from 'util/ghost.js'
import AbstractComment from 'components/comment/AbstractComment.js'
import CommentHeader from 'components/comment/CommentHeader.js'
import { keypath } from 'util/keypath.js'
import { promiseQueue } from 'util/promise-queue.js'
import IssueState from 'issue-state.js'
import { api } from 'util/api-proxy.js'
import { storeCommentDraft, clearCommentDraft, getCommentDraft } from 'util/draft-storage.js'
import { ReviewState, reviewStateToUI } from './review-state.js'

import './review.css'

class ReviewHeader extends React.Component {
  render() {
    var user = this.props.review.user || ghost;
    
    var { icon, action, bg } = reviewStateToUI(this.props.review.state);
    
    var style = {};
    if (this.props.empty) {
      style.borderBottom = "0px";
    }
    
    var info = null;
    var actions = null;
    var iconStyle = {};
    if (this.props.review.state == ReviewState.Dismiss) {
      iconStyle.position = 'relative';
      iconStyle.top = '0px';
      info = [
        h('span', { key:'dismiss_action', className: 'reviewAction' }, ' added a review '),
        h(TimeAgo, { key:'dismiss_time', className:'commentTimeAgo', live:true, date:this.props.review.submitted_at||this.props.review.created_at}),
        h('span', { key:'dismiss_action2', className: 'reviewAction' }, ' that was dismissed. '),
        h('a', { 
          key:'toggle', 
          className:'reviewToggle',
          onClick:this.props.toggleCollapsed
        }, this.props.collapsed ? 'Show Review' : 'Hide Review')
      ];
    } else if (this.props.review.state == ReviewState.Pending) {
      info = [
        h('span', { key:'action', className: 'reviewAction' }, ` ${action}`)
      ];
      actions = [
        h('button',
          { key:'delete_review', type:'button', className: 'ActionButton reviewDeletePendingButton', onClick: this.props.deletePendingReview },
          'Delete Review'
        ),
        h('button', 
          { key:'submit_review', type:'button', className: 'ActionButton reviewSubmitPendingButton', onClick: this.props.submitPendingReview },
          'Send Review'
        )
      ];
    } else {
      info = [
        h('span', { key:'action', className: 'reviewAction' }, ` ${action} `),
        h(TimeAgo, { key:'time', className:'commentTimeAgo', live:true, date:this.props.review.submitted_at||this.props.review.created_at})
      ];
    }
    
    return h('div', { className: 'reviewHeader', style },
      h('div', { className: 'reviewHeaderDetails' },
        h('span', { className:'reviewIcon', style: { backgroundColor: bg } },
          h('i', { className: `fa ${icon} fa-inverse`, style:iconStyle})
        ),
        h(AvatarIMG, { className: 'reviewAuthorIcon', user:user, size:16 }),
        h('span', { className: 'reviewAuthor' }, user.login),
        info
      ),
      h('div', { className:'reviewHeaderActions' },
        actions
      )
    );
  }
}

class ReviewAbstractComment extends AbstractComment {
  me() { return IssueState.current.me; }
  issue() { return IssueState.current.issue; }
  isNewIssue() { return false; } 
  canClose() { return false; }
  repoOwner() { return IssueState.current.repoOwner; }
  repoName() { return IssueState.current.repoName; }
  saveDraftState() { }
  restoreDraftState() { }
  loginCompletions() {
    return IssueState.current.allLoginCompletions
  }
}

class ReviewSummaryComment extends ReviewAbstractComment {
  renderHeader() /* overridden */ {
    return h('span', {});
  }
}

class ReviewSummary extends React.Component {
  render() {
    return h(ReviewSummaryComment, {
      comment: this.props.review,
      ref: "comment",
      className: 'comment reviewComment'
    });
  }
  
  comment() {
    return this.refs.comment;
  }
}

class ReviewCodeComment extends ReviewAbstractComment {

  deleteComment() {
    this.props.deleteComment(this.props.comment);
  }

  needsSave() {
    if (this.state.saving) return false;
    return super.needsSave();
  }
  
  renderFooter() {
    if (this.state.saving) {
      return h('div', {className:'reviewCodeCommentSavingReply'}, 'Saving Reply ...');
    }
    return super.renderFooter();
  }
  
  togglePreview() {
    if (this.state.saving) return;
    super.togglePreview();
  }
  
  renderHeader() {
    if (this.state.saving) {
      return h(CommentHeader, {
        ref:'header',
        comment:this.state.pendingNewComment,
        elideAction: true,
        first:false,
        editing:false,
        hasContents:true,
        previewing:true,
        togglePreview:this.togglePreview.bind(this),
        attachFiles:this.selectFiles.bind(this),
        beginEditing:this.beginEditing.bind(this),
        cancelEditing:this.cancelEditing.bind(this),
        deleteComment:this.deleteComment.bind(this),
        addReaction:this.addReaction.bind(this)
      });
    } else {
      return super.renderHeader();
    }
  }
    
  _save() {
    var issue = IssueState.current.issue;
    var isAddNew = !(this.props.comment);
    var body = this.state.code;
    
    if (isAddNew) {
      var now = new Date().toISOString();
      var prComment = {
        id: "new",
        updated_at: now,
        created_at: now,
        user: this.me(),
        body: body,
        in_reply_to: this.props.inReplyTo.id,
      };
      
      var owner = this.repoOwner();
      var repo = this.repoName();
      var num = this.issue().number;
      
      var url = `https://api.github.com/repos/${owner}/${repo}/pulls/${num}/comments`
      
      this.setState(Object.assign({}, this.state, { 
        previewing: true, 
        saving:true,
        pendingNewComment:prComment 
      }));
      
      return promiseQueue('addPRComment', () => {
        var request = api(url, {
          method: "POST",
          body: JSON.stringify(prComment),
        });
        
        return new Promise((resolve, reject) => {
          request.then((body) => {
            this.setState(Object.assign({}, this.state, {
              code: "",
              previewing: false,
              saving: false,
              pendingNewComment: null
            }));
            this.props.didSaveNewReply(body);
            resolve();
            if (window.documentEditedHelper) {
              window.documentEditedHelper.postMessage({});
            }
          }).catch((err) => {
            console.log(err);
            reject(err);
          });
        });
      });
      
    } else {
      this.props.comment.body = body;
      this.setState(Object.assign({}, this.state, {code: "", previewing: false, editing: false}));
      return this.onEdit(body);
    }
  }

  /* Called for task list edits that occur 
     e.g. checked a task button or reordered a task list 
  */
  onTaskListEdit(newBody) {
    if (!this.props.comment || this.state.editing) {
      this.updateCode(newBody);
      return Promise.resolve();
    } else {
      return this.onEdit(newBody);
    }
  }
  
  onEdit(newBody) {
    this.setState(Object.assign({}, this.state, {pendingEditBody: newBody}));
    
    var owner = IssueState.current.repoOwner;
    var repo = IssueState.current.repoName;
    var num = IssueState.current.issue.number;
    var patch = { body: newBody };
    var q = "editPRComment";
    var initialId = this.props.comment.id;
    var url = `https://api.github.com/repos/${owner}/${repo}/pulls/comments/${initialId}`
          
    return promiseQueue(q, () => {
      var currentId = keypath(this.props, "comment.id") || "";
      if (currentId == initialId && newBody != this.state.pendingEditBody) {
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
        if (this.state.pendingEditBody == newBody) {
          this.setState(Object.assign({}, this.state, {pendingEditBody: null}));
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
  
  addReaction(reaction) {
    var existing = this.findReaction(reaction);
    if (!existing) {
      IssueState.current.addPRCommentReaction(this.props.comment.id, reaction);
    }
  }
  
  toggleReaction(reaction) {
    var existing = this.findReaction(reaction);
    if (existing) {
      IssueState.current.deletePRCommentReaction(this.props.comment.id, existing.id);
    } else {
      IssueState.current.addPRCommentReaction(this.props.comment.id, reaction);
    }
  }
}

class ReviewCodeReplyComment extends ReviewCodeComment {
  componentDidMount() {
    super.componentDidMount();
    
    this.focusCodemirror();
  }
}

class ReviewCommentBlock extends React.Component {
  constructor(props) {
    super(props);
    
    this.state = { collapsed: this.canCollapse() }
  }
  
  allComments() {
    var comments = [];
    if (this.refs.comment) {
      comments.push(this.refs.comment);
    }
    for (var k in this.refs) {
      if (k.indexOf("reply.") == 0) {
        comments.push(this.refs[k]);
      }
    }
    if (this.refs.addComment) {
      comments.push(this.refs.addComment);
    }
    return comments;
  }
  
  canCollapse() {
    return (this.props.comment.position === undefined);
  }
  
  onCollapse() {
    var canCollapse = this.canCollapse();
    if (canCollapse) {
      this.setState(Object.assign({}, this.state, {
        collapsed:!this.state.collapsed,
        hasReply:false
      }));
    } else if (this.state.collapsed) {
      this.setState(Object.assign({}, this.state, {collapsed:false}));
    }
  }
  
  beginReply() {
    this.setState(Object.assign({}, this.state, {hasReply:true}));
  }
  
  cancelReply() {
    this.setState(Object.assign({}, this.state, {hasReply:false}));
  }
  
  didSaveNewReply(comment) {
    if (!this.props.comment.replies) {
      this.props.comment.replies = [];
    }
    this.props.comment.replies.push(comment);
    this.setState(Object.assign({}, this.state, {hasReply:false}));
  }
    
  renderReply() {
    var lastComment = (this.props.comment.replies||[]).length > 0 
                      ? this.props.comment.replies[this.props.comment.replies.length-1]
                      : this.props.comment;
                      
    return h(ReviewCodeReplyComment, {
      key:'add',
      ref:'addComment',
      onCancel:this.cancelReply.bind(this),
      inReplyTo:lastComment,
      didSaveNewReply:this.didSaveNewReply.bind(this),
      className: 'comment reviewComment', 
    });
  }
  
  renderClickToReply() {
    return h('div', {className:'reviewAddReply', key:'reviewAddReply', onClick: this.beginReply.bind(this) },
      h(AvatarIMG, { user: IssueState.current.me, size: 16, key: 'replyAvatar' }),
      h('span', { className: 'reviewAddReplyBox', key: 'replyBox' }, 'Reply ...')
    );
  }
  
  render() {
    var comps = [];
    var canCollapse = this.canCollapse();
    var collapsed = this.state.collapsed;
    
    comps.push(h(DiffHunk, { 
      key:"diff", 
      comment: this.props.comment,
      canCollapse: canCollapse,
      collapsed: collapsed,
      onCollapse: this.onCollapse.bind(this) 
    }));
    
    if (!collapsed) {
      comps.push(h(ReviewCodeComment, { 
        key:"comment",
        ref:"comment",
        className: 'comment reviewComment', 
        comment: this.props.comment,
        elideHeaderAction: true,
        deleteComment:this.props.deleteComment
      }));
      
      (this.props.comment.replies||[]).forEach((c, i) => {
        comps.push(h(ReviewCodeComment, { 
          key:"reply."+(c.id||i), 
          ref:"reply."+(c.id||i),
          className: 'comment reviewComment', 
          comment: c,
          elideHeaderAction: true,
          deleteComment:this.props.deleteComment
        }));
      });
      
      if (this.state.hasReply) {
        comps.push(this.renderReply());
      } else {
        comps.push(this.renderClickToReply());
      }
    }
    
    return h('div', { className:'reviewCommentBlock' }, comps);
  }
}

class Review extends React.Component {
  constructor(props) {
    super(props);
    
    this.state = { collapsed: this.props.review.state == ReviewState.Dismiss };
  }


  allComments() {
    var comments = [];
    if (this.refs.summary) {
      comments.push(this.refs.summary.comment());
    }
    for (var k in this.refs) {
      if (k.indexOf("commentBlock.") == 0) {
        comments.push(...this.refs[k].allComments());
      }
    }
    return comments;
  }
  
  deleteComment(comment) {
    if (!comment.id || comment.id == 'new') {
      return;
    }
    
    IssueState.current.deletePRComment(comment);
  }
  
  toggleCollapsed(evt) {
    this.setState({collapsed:!this.state.collapsed});
    evt.preventDefault();
  }
  
  submitPendingReview(evt) {
    var el = evt.target;
    var bbox = el.getBoundingClientRect();
    window.submitPendingReview.postMessage({bbox});  
    evt.preventDefault();
  }
  
  deletePendingReview(evt) {
    var el = evt.target;
    var bbox = el.getBoundingClientRect();
    window.deletePendingReview.postMessage({bbox});
    evt.preventDefault();
  }

  render() {
    var hasSummary = this.props.review.body && this.props.review.body.trim().length > 0;
    
    var sortedComments = Array.from(this.props.review.comments).filter(c => !(c.in_reply_to));
    sortedComments.sort((a, b) => {
      var da = new Date(a.created_at);
      var db = new Date(b.created_at);
      
      if (da < db) return -1;
      else if (da > db) return 1;
      else if (a.id < b.id) return -1;
      else if (a.id > b.id) return 1;
      else return 0;
    });
    
    var comps = [];
    var id = null;
    if (this.props.review.id) {
      id = `review.${this.props.review.id}`
    }
    
    var noBodyAndNoComments = !hasSummary && sortedComments.length == 0;
    
    comps.push(h(ReviewHeader, { 
      key:"header", 
      review: this.props.review, 
      empty: this.state.collapsed||noBodyAndNoComments,
      collapsed: this.state.collapsed,
      toggleCollapsed: this.toggleCollapsed.bind(this),
      submitPendingReview: this.submitPendingReview.bind(this),
      deletePendingReview: this.deletePendingReview.bind(this)
    }));
    
    if (!this.state.collapsed) {
      if (hasSummary) {
        comps.push(h(ReviewSummary, { key:"summary", ref:"summary", review: this.props.review }));
      } else if (sortedComments.length) {
        comps.push(h('div', { key:'summaryPlaceholder', className: 'reviewSummaryPlaceholder' }));
      }
      comps = comps.concat(sortedComments.map((c) => h(ReviewCommentBlock, { 
        key:c.id, 
        ref:"commentBlock."+c.id,
        review: this.props.review, 
        deleteComment: this.deleteComment.bind(this),
        comment: c 
      })));
    }
    
    return h('div', { className: 'review', id:id }, comps);
  }
}

export default Review;
