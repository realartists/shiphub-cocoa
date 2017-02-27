import AbstractComment from './AbstractComment.js'
import { keypath } from 'util/keypath.js'
import { promiseQueue } from 'util/promise-queue.js'
import IssueState from 'issue-state.js'
import { storeCommentDraft, clearCommentDraft, getCommentDraft } from 'util/draft-storage.js'

class Comment extends AbstractComment {
  me() { return IssueState.current.me; }
  editComment() {
    IssueState.current.editComment(this.props.commentIdx||0, this.state.code);
  }
  
  issue() { return IssueState.current.issue; }
  
  isNewIssue() { return !(this.issue().number); }
  
  canClose() {
    var editingExisting = !!(this.props.comment);
    var canClose = !editingExisting && IssueState.current.issue.number > 0 && IssueState.current.issue.state === "open";
    return canClose;
  }
  
  repoOwner() { return IssueState.current.repoOwner; }
  
  repoName() { return IssueState.current.repoName; }
  
  shouldShowCommentPRBar() { return !!(IssueState.current.issue.pull_request); }
  
  saveDraftState() {
    var issue = this.issue();
    var isNewIssue = this.isNewIssue();
    
    if (!isNewIssue) {
      if (this.state.editing && this.state.code.trim().length > 0) {
        storeCommentDraft(IssueState.current.repoOwner, IssueState.current.repoName, issue.number, keypath(this.props, "comment.id"), this.state.code);
      } else {
        clearCommentDraft(IssueState.current.repoOwner, IssueState.current.repoName, issue.number, keypath(this.props, "comment.id"));
      }
    }
  }
  
  restoreDraftState() {
    var issue = IssueState.current.issue;
    var isNewIssue = !(issue.number);
    
    if (!isNewIssue) {
      var draft = getCommentDraft(IssueState.current.repoOwner, IssueState.current.repoName, issue.number, keypath(this.props, "comment.id"));
      if (draft && draft.trim().length > 0) {
        this.beginEditing();
        this.updateCode(draft);
      } else if (this.state.code.length > 0) {
        if (this.props.comment && this.state.editing) {
          this.cancelEditing();
        } else {
          this.updateCode("");
        }
      }
    }
  }
  
  deleteComment() {
    IssueState.current.deleteComment(this.props.commentIdx);
  }
  
  editCommentURL() {
    var editCommentURL;
  
    if (this.props.commentIdx == 0) {
      url = `https://api.github.com/repos/${owner}/${repo}/issues/${num}`;
    } else {
      var commentIdentifier = this.props.comment.id;
      url = `https://api.github.com/repos/${owner}/${repo}/issues/comments/${commentIdentifier}`
    }
    
    return url;
  }

  editCommentQueue() {  
    var q;
    if (this.props.commentIdx == 0) {
      q = "applyPatch";
    } else {
      q = "applyCommentEdit";
    }
    return q;
  }
  
  addReaction(reaction) {
    var existing = this.findReaction(reaction);
    if (!existing) {
      IssueState.current.addReaction(this.props.commentIdx, reaction);
    }
  }
  
  toggleReaction(reaction) {
    var existing = this.findReaction(reaction);
    if (existing) {
      IssueState.current.deleteReaction(this.props.commentIdx, existing.id);
    } else {
      IssueState.current.addReaction(this.props.commentIdx, reaction);
    }
  }
  
  _save() {
    var issue = IssueState.current.issue;
    var isNewIssue = !(issue.number);
    var isAddNew = !(this.props.comment);
    var body = this.state.code;
    
    var resetState = () => {
      this.setState(Object.assign({}, this.state, {code: "", previewing: false, editing: isAddNew}));
      if (!isNewIssue) {
        clearCommentDraft(IssueState.current.repoOwner, IssueState.current.repoName, issue.number, keypath(this.props, "comment.id"));
      }
    };
    
    if (isNewIssue) {
      var canSave = (issue.title || "").trim().length > 0 && !!(IssueState.current.repoOwner) && !!(IssueState.current.repoName);
      if (canSave) {
        resetState();
        IssueState.current.editComment(0, body);
        return IssueState.current.saveNewIssue();
      }
    } else {
      resetState();
      if (body.trim().length > 0) {
        if (this.props.comment) {
          if (this.props.comment.body != body) {
            return IssueState.current.editComment(this.props.commentIdx, body);
          }
        } else {
          return IssueState.current.addComment(body);
        }
      }
    }
    
    return Promise.resolve();
  }
  
  saveAndClose() {
    IssueState.current.patchIssue({state: "closed"});
    this.save();
  }
  
  loginCompletions() {
    return IssueState.current.allLoginCompletions
  }
  
  needsSave() {
    var issue = IssueState.current.issue;
    var isNewIssue = !(issue.number);
    var isAddNew = !(this.props.comment);
    var body = this.state.code;
    
    if (isNewIssue) {
      var canSave = (issue.title || "").trim().length > 0 && !!(IssueState.current.repoOwner) && !!(IssueState.current.repoName);
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
  }
}

export default Comment;
