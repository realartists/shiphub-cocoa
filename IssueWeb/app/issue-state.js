/* Represents the model and mutations on the model for IssueWeb */

import { promiseQueue } from 'util/promise-queue.js'
import { api } from 'util/api-proxy.js'
import { keypath, setKeypath } from 'util/keypath.js'
import clone from 'clone';

class IssueState {
  constructor(state) {
    this.state = state || {
      issue: {},
      repos: [],
      assignees: [],
      milestones: [],
      labels: [],
      me: null,
      token: ""
    };
  }

  static get current() {
    return _current;
  }
  
  get token() { return this.state.token; }
  set token(newToken) { this.state.token = newToken; }
  
  get issueFullIdentifier() { 
    return `${this.repoOwner}/${this.repoName}#${this.issueNumber}`;
  }
  
  get repoOwner() { return this.state.issue._bare_owner; }
  set repoOwner(newOwner) { this.state.issue._bare_owner = newOwner; }
  
  get repoName() { return this.state.issue._bare_repo; }
  set repoName(newName) { this.state.issue._bare_repo = newName; }
  
  get repoFullName() {
    if (this.state.issue._bare_owner && this.state.issue._bare_repo) {
      return this.state.issue._bare_owner + "/" + this.state.issue._bare_repo;
    } else {
      return null;
    }
  }
  
  get repo() {
    return this.state.issue.repository;
  }
  
  get repoCanPush() {
    return (this.state.issue.repository||{can_push:true}).can_push;
  }
  
  get issueFiledByCurrentUser() {
    return (this.state.issue.user||this.state.issue.originator).id == this.state.me.id;
  }
  
  get repos() { return this.state.repos; }
  get assignees() { return this.state.assignees; }
  get milestones() { return this.state.milestones; }
  get labels() { return this.state.labels; }
  get me() { return this.state.me; }
  
  get allLoginCompletions() { return this.state.allLoginCompletions; }
  
  get issueNumber() { return this.state.issue.number; }
  
  get issue() { return this.state.issue; }
  
  // ApplyIssueState = function(state, scrollToCommentIdentifier)
  get applyIssueState() { return this._applyIssueState; }
  set applyIssueState(fun) { this._applyIssueState = fun; }
  
  _renderState() {
    var apply = this.applyIssueState;
    if (apply) apply(this.state);
  }
  
  snapshotState() {
    return clone(this.state);
  }
  
  restoreStateSnapshot(snapshot) {
    var curState = this.state;
    if (snapshot.issue.id == curState.issue.id) {
      this.state = snapshot;
      this._renderState();
    }
  }
  
  mergeIssueChanges(owner, repo, num, mergeFun, failFun) {
    var nowOwner = IssueState.current.repoOwner;
    var nowRepo = IssueState.current.repoName;
    var nowNum = IssueState.current.issueNumber;
  
    if (num == null || (nowOwner == owner && nowRepo == repo && nowNum == num)) {
      mergeFun();
    } else {
      if (failFun) failFun();
    }
  }
  
  applyPatch(patch) {
    var ghPatch = Object.assign({}, patch);

    if (patch.milestone != null) {
      ghPatch.milestone = patch.milestone.number;
    }

    if (patch.assignees != null) {
      ghPatch.assignees = patch.assignees.map((u) => u.login);
    }

    console.log("patching", patch, ghPatch);
  
    // PATCH /repos/:owner/:repo/issues/:number
    var owner = this.repoOwner;
    var repo = this.repoName;
    var num = this.issueNumber;
  
    if (num != null) {
      return promiseQueue("applyPatch", () => {
        var url = `https://api.github.com/repos/${owner}/${repo}/issues/${num}`
        var request = api(url, { 
          headers: { 
            Authorization: "token " + this.token,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }, 
          method: "PATCH",
          body: JSON.stringify(ghPatch)
        });
        return new Promise((resolve, reject) => {
          request.then((body) => {
            console.log(body);
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
      return Promise.resolve();
    }
  }
  
  applyCommentEdit(commentIdentifier, newBody) {
    // PATCH /repos/:owner/:repo/issues/comments/:id
    var owner = this.repoOwner;
    var repo = this.repoName;
    var num = this.issueNumber;
  
    if (num != null) {
      return promiseQueue("applyCommentEdit", () => {
        var url = `https://api.github.com/repos/${owner}/${repo}/issues/comments/${commentIdentifier}`
        var request = api(url, { 
          headers: { 
            Authorization: "token " + this.token,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }, 
          method: "PATCH",
          body: JSON.stringify({body: newBody})
        });
        return new Promise((resolve, reject) => {
          request.then((body) => {
            console.log(body);
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
      return Promise.reject("Issue does not exist.");
    }
  }
  
  applyCommentDelete(commentIdentifier) {
    // DELETE /repos/:owner/:repo/issues/comments/:id
  
    var owner = this.repoOwner;
    var repo = this.repoName;
    var num = this.issueNumber;
  
    if (num != null) {
      var url = `https://api.github.com/repos/${owner}/${repo}/issues/comments/${commentIdentifier}`
      var request = api(url, { 
        headers: { 
          Authorization: "token " + this.token,
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
  
  applyComment(commentBody) {
    // POST /repos/:owner/:repo/issues/:number/comments
  
    var owner = this.repoOwner;
    var repo = this.repoName;
    var num = this.issueNumber;
  
    if (num != null) {
      return promiseQueue("applyComment", () => {
        var url = `https://api.github.com/repos/${owner}/${repo}/issues/${num}/comments`
        var request = api(url, { 
          headers: { 
            Authorization: "token " + this.token,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }, 
          method: "POST",
          body: JSON.stringify({body: commentBody})
        });
        return new Promise((resolve, reject) => {
          request.then((body) => {
            this.mergeIssueChanges(owner, repo, num, () => {
              var id = body.id;
              this.state.issue.comments.forEach((m) => {
                if (m.id === 'new') {
                  m.id = id;
                }
              });
              this._renderState();
              if (window.documentEditedHelper) {
                window.documentEditedHelper.postMessage({});
              }
            });
            resolve();
          }).catch((err) => {
            console.log(err);
            reject(err);
          });
        });
      });
    } else {
      return Promise.reject("Issue does not exist.");
    }
  }
  
  saveNewIssue() {
    // POST /repos/:owner/:repo/issues
  
    console.log("saveNewIssue");
  
    var issue = this.issue;
  
    if (issue.number) {
      console.log("already have a number");
      return;
    }
  
    if (!issue.title || issue.title.trim().length == 0) {
      return;
    }
  
    var owner = issue._bare_owner;
    var repo = issue._bare_repo;
    var isPR = !!(issue.pull_request);
  
    if (!owner || !repo) {
      return;
    }
  
    if (issue.savePending) {
      console.log("Queueing save ...");
      if (!issue.savePendingQueue) {
        issue.savePendingQueue = [];
      }
      var q = issue.savePendingQueue;
      var p = new Promise((resolve, reject) => {
        q.append({resolve, reject});
      });
      return p;
    }
  
    issue.savePending = true;
    this._renderState();
  
    var assignees = issue.assignees.map((u) => u.login);
  
    var url, request;
    if (isPR) {
      url = `https://api.github.com/repos/${owner}/${repo}/pulls`;
      var head;
      var [headOwner, headRepo] = issue.head.repo.full_name.split(/\//);
      if (issue.head.repo.full_name == `${owner}/${repo}`) {
        head = issue.head.ref;
      } else if (headOwner == owner) {
        head = headOwner + ":" + issue.head.ref;
      } else {
        head = issue.head.repo.full_name + ":" + issue.head.ref;
      }
      request = api(url, {
        headers: { 
          Authorization: "token " + this.token,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }, 
        method: "POST",
        body: JSON.stringify({
          title: issue.title,
          body: issue.body,
          assignees: assignees,
          milestone: keypath(issue, "milestone.number"),
          labels: issue.labels.map((l) => l.name),
          head: head,
          base: issue.base.ref
        })
      });
    } else {
      url = `https://api.github.com/repos/${owner}/${repo}/issues`;
      request = api(url, {
        headers: { 
          Authorization: "token " + this.token,
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
    }
  
    return new Promise((resolve, reject) => {
      request.then((body) => {
        var q = issue.savePendingQueue;
        this.state.issue = body;
        this._renderState();
        resolve();
        if (q) {
          q.forEach((p) => {
            p.resolve();
          });
        }
      }).catch((err) => {
        var q = issue.savePendingQueue;
        issue.savePending = false;
        if (q) {
          delete issue.savePendingQueue;
        }
        console.log(err);
        reject(err);
        if (q) {
          q.forEach((p) => {
            p.reject(err);
          });
        }
        this._renderState();
      });
    });
  }
  
  patchIssue(patch) {
    var rollback = {};
    for (var k in patch) {
      if (this.state.issue.number || k != "body") {
        rollback[k] = this.state.issue[k];
      }
    }
    
    var undo = (err) => {
      for (k in rollback) {
        this.state.issue[k] = rollback[k];
      }
      this._renderState();
      throw err;
    }
  
    this.state.issue = Object.assign({}, this.state.issue, patch);
    this._renderState();
    return this.applyPatch(patch).catch(undo);
  }
  
  editComment(commentIdx, newBody) {
    if (commentIdx == 0) {
      return this.patchIssue({body: newBody});
    } else {
      commentIdx--;
      var commentId = this.state.issue.comments[commentIdx].id;
      var oldBody = this.state.issue.comments[commentIdx].body;
      var undo = (err) => {
        this.state.issue.comments.forEach(c => {
          if (c.id == commentId) {
            c.body = oldBody;
          }
        });
        this._renderState();
        throw err;
      }
      this.state.issue.comments[commentIdx].body = newBody;
      this._renderState();
      return this.applyCommentEdit(commentId, newBody).catch(undo);
    }
  }
  
  deleteComment(commentIdx) {
    if (commentIdx == 0) return; // cannot delete first comment
    commentIdx--;
    var c = this.state.issue.comments[commentIdx];
    var issueFullIdentifier = this.issueFullIdentifier;
    var undo = (err) => {
      if (issueFullIdentifier == this.issueFullIdentifier) {
        this.state.issue.comments.splice(commentIdx, 0, c);
        this._renderState();
      }
      throw err;
    };
    this.state.issue.comments.splice(commentIdx, 1);
    this._renderState();
    return this.applyCommentDelete(c.id).catch(undo);
  }
  
  deletePRComment(comment) {
    if (!comment.id) return;
    
    var oldState = this.snapshotState();
        
    // delete the comment from our state    
    this.state.issue.pr_comments = this.state.issue.pr_comments.filter(c => c.id != comment.id);
    this.state.issue.reviews.forEach(r => {
      r.comments = r.comments.filter(c => c.id != comment.id);
    });
    this._renderState();
    
    var owner = this.repoOwner;
    var repo = this.repoName;
    var num = this.issueNumber;
    
    if (num != null) {
      var url = `https://api.github.com/repos/${owner}/${repo}/pulls/comments/${comment.id}`
      var request = api(url, { 
        method: "DELETE"
      });
      return request.catch((err) => {
        this.restoreStateSnapshot(oldState);
        throw err;
      });
    } else {
      return Promise.reject("Issue does not exist.");
    }
  }
  
  deleteCommitComment(comment) {
    if (!comment.id) return;
    
    var oldState = this.snapshotState();
    
    // delete the comment from our state
    this.state.issue.commit_comments = this.state.issue.commit_comments.filter(c => c.id != comment.id);
    this._renderState();
    
    var owner = this.repoOwner;
    var repo = this.repoName;
    var num = this.issueNumber;
    
    if (num != null) {
      // DELETE /repos/:owner/:repo/comments/:id
      var url = `https://api.github.com/repos/${owner}/${repo}/comments/${comment.id}`
      var request = api(url, { 
        method: "DELETE"
      });
      return request.catch((err) => {
        this.restoreStateSnapshot(oldState);
        throw err;
      });
    } else {
      return Promise.reject("Issue does not exist.");
    }
  }
  
  addComment(body) {
    var now = new Date().toISOString();
    this.state.issue.comments.push({
      body: body,
      user: this.state.me,
      id: "new",
      updated_at: now,
      created_at: now
    });
    var rollback = () => {
      this.state.issue.comments = this.state.issue.comments.filter(c => c.id != "new");
      this._renderState();
    };
    this._renderState();
    return new Promise((resolve, reject) => {
      this.applyComment(body)
      .then(resolve)
      .catch(() => {
        rollback();
        reject(arguments);
      });
    });
  }
  
  addReaction(commentIdx, reactionContent) {
    var oldState = this.snapshotState();
  
    var reaction = {
      id: "new",
      user: this.state.me,
      content: reactionContent,
      created_at: new Date().toISOString()
    };
    var owner = this.repoOwner;
    var repo = this.repoName;
    var num = this.issueNumber;
  
    var url;
    if (commentIdx == 0) {
      this.state.issue.reactions.push(reaction);
      url = `https://api.github.com/repos/${owner}/${repo}/issues/${num}/reactions`
    } else {
      commentIdx--;
      var c = this.state.issue.comments[commentIdx];
      c.reactions.push(reaction);
      url = `https://api.github.com/repos/${owner}/${repo}/issues/comments/${c.id}/reactions`
    }

    this._renderState();
        
    var request = api(url, {
      headers: {
        Authorization: "token " + this.token,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github.squirrel-girl-preview'
      },
      method: 'POST',
      body: JSON.stringify({content: reactionContent})
    });
    return new Promise((resolve, reject) => {
      request.then((body) => {
        this.mergeIssueChanges(owner, repo, num, () => {
          reaction.id = body.id;
          this._renderState();
        });
        resolve();
      }).catch((err) => {
        console.error("Add reaction failed", err);
        this.restoreStateSnapshot(oldState);
        reject(err);
      });
    });
  }
  
  deleteReaction(commentIdx, reactionID) {
    if (reactionID === "new") {
      return Promise.reject("Cannot delete pending reaction");
    }
    
    var oldState = this.snapshotState();

    if (commentIdx == 0) {
      this.state.issue.reactions = this.state.issue.reactions.filter((r) => r.id !== reactionID);
    } else {
      commentIdx--;
      var c = this.state.issue.comments[commentIdx];
      c.reactions = c.reactions.filter((r) => r.id !== reactionID);
    }
  
    this._renderState();
    
    var url = `https://api.github.com/reactions/${reactionID}`
    var request = api(url, {
      headers: {
        Authorization: "token " + this.token,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github.squirrel-girl-preview'
      },
      method: 'DELETE'
    });
    return new Promise((resolve, reject) => {
      request.then((body) => {
        resolve();
      }).catch((err) => {
        console.error("Delete reaction failed", err);
        this.restoreStateSnapshot(oldState);
        reject(err);
      });
    });
  }
  
  _prCommentWithId(prCommentId) {
    var singleComments = this.state.issue.pr_comments;
    var reviews = this.state.issue.reviews;
    var allReviewComments = reviews.reduce((accum, r) => {
      return accum.concat(r.comments||[]);
    }, []);
    var allComments = singleComments.concat(allReviewComments);
    var c = allComments.find(c => c.id == prCommentId);
    return c;
  }
  
  addPRCommentReaction(prCommentId, reactionContent) {
    var oldState = this.snapshotState();
  
    var reaction = {
      id: "new",
      user: this.state.me,
      content: reactionContent,
      created_at: new Date().toISOString()
    };
    
    var owner = this.repoOwner;
    var repo = this.repoName;
    var num = this.issueNumber;
    
    var url = `https://api.github.com/repos/${owner}/${repo}/pulls/comments/${prCommentId}/reactions`;
    var c = this._prCommentWithId(prCommentId);
    
    // eagerly add the reaction
    c.reactions.push(reaction);
    
    this._renderState();
    
    var request = api(url, {
      method: 'POST',
      body: JSON.stringify({content: reactionContent})
    });
    
    return new Promise((resolve, reject) => {
      request.then((body) => {
        this.mergeIssueChanges(owner, repo, num, () => {
          reaction.id = body.id;
          this._renderState();
        });
        resolve();
      }).catch((err) => {
        console.error("Add reaction failed", err);
        this.restoreStateSnapshot(oldState);
        reject(err);
      });
    });
  }
  
  deletePRCommentReaction(prCommentId, reactionID) {
    var oldState = this.snapshotState();
  
    if (reactionID === "new") {
      console.log("Cannot delete pending reaction");
      return;
    }
    
    var c = this._prCommentWithId(prCommentId);
    c.reactions = c.reactions.filter(r => r.id !== reactionID);
    this._renderState();
    
    var url = `https://api.github.com/reactions/${reactionID}`
    var request = api(url, {
      method: 'DELETE'
    });
    return new Promise((resolve, reject) => {
      request.then((body) => {
        resolve();
      }).catch((err) => {
        console.error("Delete reaction failed", err);
        this.restoreStateSnapshot(oldState);
        reject(err);
      });
    });
  }
  
  _commitCommentWithId(id) {
    return this.state.issue.commit_comments.find(c => c.id == id);
  }
  
  addCommitCommentReaction(id, reactionContent) {
    var oldState = this.snapshotState();
  
    var reaction = {
      id: "new",
      user: this.state.me,
      content: reactionContent,
      created_at: new Date().toISOString()
    };
    
    var owner = this.repoOwner;
    var repo = this.repoName;
    var num = this.issueNumber;
    
    // POST /repos/:owner/:repo/comments/:id/reactions
    var url = `https://api.github.com/repos/${owner}/${repo}/comments/${id}/reactions`;
    var c = this._commitCommentWithId(id);
    
    // eagerly add the reaction
    c.reactions.push(reaction);
    
    this._renderState();
    
    var request = api(url, {
      method: 'POST',
      body: JSON.stringify({content: reactionContent})
    });
    
    return new Promise((resolve, reject) => {
      request.then((body) => {
        this.mergeIssueChanges(owner, repo, num, () => {
          reaction.id = body.id;
          this._renderState();
        });
        resolve();
      }).catch((err) => {
        console.error("Add reaction failed", err);
        this.restoreStateSnapshot(oldState);
        reject(err);
      });
    });
  }
  
  deleteCommitCommentReaction(id, reactionID) {
    if (reactionID === "new") {
      return Promise.reject("Cannot delete pending reaction");
    }
    
    var oldState = this.snapshotState();
    
    var c = this._commitCommentWithId(id);
    c.reactions = c.reactions.filter(r => r.id !== reactionID);
    this._renderState();
    
    var url = `https://api.github.com/reactions/${reactionID}`
    var request = api(url, {
      method: 'DELETE'
    });
    return new Promise((resolve, reject) => {
      request.then((body) => {
        resolve();
      }).catch((err) => {
        console.error("Delete reaction failed", err);
        this.restoreStateSnapshot(oldState);
        reject(err);
      });
    });
  }
  
  addReviewer(user) {
    if (!user) {
      return Promise.reject("User not specified");
    }
    if (!this.issue.pull_request) {
      return Promise.reject("Cannot add reviewer on non-PR");
    }
    
    if (this.issue.requested_reviewers.find(rv => rv.id == user.id)) {
      return Promise.resolve();
    }
    
    var oldState = this.snapshotState();
    
    // eagerly patch the issue
    this.issue.requested_reviewers.push(user);
    this._renderState();
    
    var url = `https://api.github.com/repos/${this.repoOwner}/${this.repoName}/pulls/${this.issue.number}/requested_reviewers`;
    return promiseQueue('applyPatch', () => {
      var request = api(url, {
        method: 'POST',
        body: JSON.stringify({reviewers:[user.login]})
      });
      return new Promise((resolve, reject) => {
        request.then((body) => {
          resolve();
        }).catch((err) => {
          console.error("Add reviewer failed", err);
          this.restoreStateSnapshot(oldState);
          reject(err);
        });
      });
    });
  }
  
  deleteReviewer(user) {
    if (!user) {
      return Promise.reject("User not specified");
    }
    if (!this.issue.pull_request) {
      return Promise.reject("Cannot delete reviewer on non-PR");
    }
    
    var oldState = this.snapshotState();
    
    // eagerly patch the issue
    this.issue.requested_reviewers = (this.issue.requested_reviewers||[]).filter(u => u.id != user.id);
    this._renderState();
    
    var url = `https://api.github.com/repos/${this.repoOwner}/${this.repoName}/pulls/${this.issue.number}/requested_reviewers`;
    return promiseQueue('applyPatch', () => {
      var request = api(url, {
        method: 'DELETE',
        body: JSON.stringify({reviewers:[user.login]})
      });
      return new Promise((resolve, reject) => {
        request.then((body) => {
          resolve();
        }).catch((err) => {
          console.error("Delete reviewer failed", err);
          this.restoreStateSnapshot(oldState);
          reject(err);
        });
      });
    });
  }
  
  dismissReview(id, reason) {
    if (!id) {
      return Promise.reject("id not specified");
    }
    if (!reason) {
      return Promise.reject("reason not specified");
    }
    
    var oldState = this.snapshotState();
    
    // eagerly dismiss the review
    this.issue.reviews = Array.from(this.issue.reviews).map(r => {
      if (r.id == id) {
        return Object.assign({}, r, { 
          state: 4, 
          dismissal_event: { 
            actor: this.state.me, 
            dismissed_review: { 
              id: id, 
              dismissal_message: reason 
            } 
          } 
        });
      }
      return r;
    });
    this._renderState();
    
    var url = `https://api.github.com/repos/${this.repoOwner}/${this.repoName}/pulls/${this.issue.number}/reviews/${id}/dismissals`;
    return promiseQueue('applyPatch', () => {
      var request = api(url, {
        method: 'PUT',
        body: JSON.stringify({message:reason})
      });
      return new Promise((resolve, reject) => {
        request.then((body) => {
          resolve();
        }).catch((err) => {
          console.error("Dismiss review failed", err);
          this.restoreStateSnapshot();
          reject(err);
        });
      });
    });
  }
  
  
}

var _current = new IssueState();

window.setAPIToken = function(token) {
  IssueState.current.token = token;
}

export default IssueState;


