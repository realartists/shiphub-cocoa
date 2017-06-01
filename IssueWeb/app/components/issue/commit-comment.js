import React, { createElement as h } from 'react'

import AbstractComment from 'components/comment/AbstractComment.js'
import CommentHeader from 'components/comment/CommentHeader.js'

import { keypath } from 'util/keypath.js'
import { promiseQueue } from 'util/promise-queue.js'
import IssueState from 'issue-state.js'
import { api } from 'util/api-proxy.js'
import { storeCommentDraft, clearCommentDraft, getCommentDraft } from 'util/draft-storage.js'

class CommitComment extends AbstractComment {
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
      beginEditing:this.beginEditing.bind(this),
      cancelEditing:this.cancelEditing.bind(this),
      deleteComment:this.deleteComment.bind(this),
      addReaction:this.addReaction.bind(this),
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
    var q = "editCommitComment";
    var initialId = this.props.comment.id;
    // PATCH /repos/:owner/:repo/comments/:id
    var url = `https://api.github.com/repos/${owner}/${repo}/comments/${initialId}`
          
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
          window.documentEditedHelper.postMessage({});
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
