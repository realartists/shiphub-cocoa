import AbstractComment from './AbstractComment.js'
import { keypath } from 'util/keypath.js'
import { promiseQueue } from 'util/promise-queue.js'
import IssueState from 'issue-state.js'
import { api } from 'util/api-proxy.js'

class AbstractEditableComment extends AbstractComment {
  // subclassers can make use of this method to implement _save and onTaskListEdit if they wish
  onEdit(newBody) {
    this.setState(Object.assign({}, this.state, {pendingEditBody: newBody}));
    
    var undo = () => {
      this.setState(Object.assign({}, this.state, {pendingEditBody: null, code: newBody, editing: true, previewing: false}));
    };
    
    var owner = IssueState.current.repoOwner;
    var repo = IssueState.current.repoName;
    var num = IssueState.current.issue.number;
    var patch = { body: newBody };
    var q = this.editCommentQueue();
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
            undo();
            reject(err);
          }, 1500);
        });
      });
    });
  }
}

export default AbstractEditableComment;
