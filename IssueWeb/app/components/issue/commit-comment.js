import React, { createElement as h } from 'react'
import BBPromise from 'util/bbpromise.js'

import AbstractEditableComment from 'components/comment/AbstractEditableComment.js'
import CommentHeader from 'components/comment/CommentHeader.js'

import { keypath } from 'util/keypath.js'
import { promiseQueue } from 'util/promise-queue.js'
import IssueState from 'issue-state.js'
import { api } from 'util/api-proxy.js'
import { storeCommentDraft, clearCommentDraft, getCommentDraft } from 'util/draft-storage.js'

class CommitComment extends AbstractEditableComment {
  me() { return IssueState.current.me; }
  issue() { return IssueState.current.issue; }
  isNewIssue() { return false; } 
  canClose() { return false; }
  canEdit() { 
    if (!this.props.comment) return true;
    var user = this.props.comment.user||this.props.comment.author;
    if (!user) user = ghost;
    return IssueState.current.repoCanPush || this.me().id == user.id;
  }
  editCommentQueue() { return "editCommitComment"; }
  repoOwner() { return IssueState.current.repoOwner; }
  repoName() { return IssueState.current.repoName; }
  saveDraftState() { }
  restoreDraftState() { }
  loginCompletions() {
    return IssueState.current.allLoginCompletions
  }
  
  renderHeader() {
    var commitURL = `https://github.com/${this.repoOwner()}/${this.repoName()}/commit/${this.props.comment.commit_id}`;
    var action = h('span', {},
      ' commented on commit ',
      h('a', {className:'CommitCommentLink shaLink', href:commitURL}, this.props.comment.commit_id.substr(0, 7)),
      ' '
    );
    return h(CommentHeader, {
      ref:'header',
      comment:this.props.comment, 
      elideAction: this.props.elideHeaderAction,
      action:action,
      first:this.props.first,
      editing:this.state.editing,
      hasContents:this.state.code.trim().length>0,
      previewing:this.state.previewing,
      togglePreview:this.togglePreview.bind(this),
      attachFiles:this.selectFiles.bind(this),
      canEdit:this.canEdit(),
      beginEditing:this.beginEditing.bind(this),
      cancelEditing:this.cancelEditing.bind(this),
      deleteComment:this.deleteComment.bind(this),
      addReaction:this.addReaction.bind(this),
      canReact:this.canReact(),
      needsSave:this.needsSave.bind(this)
    });
  }

  deleteComment() {
    IssueState.current.deleteCommitComment(this.props.comment);
  }
    
  _save() {
    var issue = IssueState.current.issue;
    var body = this.state.code;
    
    this.props.comment.body = body;
    this.setState(Object.assign({}, this.state, {code: "", previewing: false, editing: false}));
    return this.onEdit(body);
  }

  /* Called for task list edits that occur 
     e.g. checked a task button or reordered a task list 
  */
  onTaskListEdit(newBody) {
    if (!this.props.comment || this.state.editing) {
      this.updateCode(newBody);
      return BBPromise.resolve();
    } else {
      return this.onEdit(newBody);
    }
  }
  
  addReaction(reaction) {
    var existing = this.findReaction(reaction);
    if (!existing) {
      IssueState.current.addCommitCommentReaction(this.props.comment.id, reaction);
    }
  }
  
  toggleReaction(reaction) {
    var existing = this.findReaction(reaction);
    if (existing) {
      IssueState.current.deleteCommitCommentReaction(this.props.comment.id, existing.id);
    } else {
      IssueState.current.addCommitCommentReaction(this.props.comment.id, reaction);
    }
  }
}

export default CommitComment;
