/* Represents the model and mutations on the model for IssueWeb */

import { promiseQueue } from 'util/promise-queue.js'
import { api } from 'util/api-proxy.js'
import { keypath, setKeypath } from 'util/keypath.js'

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
      });
    });
  }
  
  patchIssue(patch) {
    this.state.issue = Object.assign({}, this.state.issue, patch);
    this._renderState();
    return this.applyPatch(patch);
  }
  
  editComment(commentIdx, newBody) {
    if (commentIdx == 0) {
      return this.patchIssue({body: newBody});
    } else {
      commentIdx--;
      this.state.issue.comments[commentIdx].body = newBody;
      this._renderState();
      return this.applyCommentEdit(this.state.issue.comments[commentIdx].id, newBody);
    }
  }
  
  deleteComment(commentIdx) {
    if (commentIdx == 0) return; // cannot delete first comment
    commentIdx--;
    var c = this.state.issue.comments[commentIdx];
    this.state.issue.comments.splice(commentIdx, 1);
    this._renderState();
    return this.applyCommentDelete(c.id);
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
    this._renderState();
    return this.applyComment(body);
  }
  
  addReaction(commentIdx, reactionContent) {
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
        reject(err);
      });
    });
  }
  
  deleteReaction(commentIdx, reactionID) {
    if (reactionID === "new") {
      console.log("Cannot delete pending reaction");
      return;
    }

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
        console.error("Add reaction failed", err);
        reject(err);
      });
    });
  }
}

var _current = new IssueState();

window.setAPIToken = function(token) {
  IssueState.current.token = token;
}

export default IssueState;


