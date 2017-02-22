import './comment.css'

import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'

import h from 'hyperscript'

import { markdownRender } from '../../IssueWeb/app/markdown-render.js'

class Avatar {
  constructor(user, size) {
    this.user = user || ghost;
    this.pointSize = size || 32;
    
    var img = h('img', {
      className: "avatar",
      src: this.avatarURL(),
      width: this.pointSize,
      height: this.pointSize
    });
    
    this.node = img;
  }
  
  avatarURL() {
    var avatarURL = this.user.avatar_url;
    if (avatarURL == null) {
      avatarURL = "https://avatars.githubusercontent.com/u/" + this.props.user.id + "?v=3";
    }
    avatarURL += "&s=" + this.pixelSize();
    return avatarURL;
  }
  
  pixelSize() {
    return this.pointSize * 2;
  }
}

class Comment {
  constructor(prComment, issueIdentifier) {
    this.issueIdentifier = issueIdentifier;
    
    var commentBody = this.commentBody = h('div', {className:'commentBody'});
    var commentDiv = h('div', {className:'comment'}, commentBody);
    
    this.node = commentDiv;
    
    this._code = "";
    this._editing = false;
    this.comment = prComment;
  }
  
  get editing() { return this._editing; }
  
  set code(newCode) {
    if (this._code !== newCode) {
      this._code = newCode;
      var parts = this.issueIdentifier.split('/#');
      this.commentBody.innerHTML = markdownRender(newCode, parts[0], parts[1]);
    }
  }
  
  get code() { return _code; }
  
  set comment(prComment) {
    this.prComment = prComment;
    if (!this.editing) {
      this.code = prComment.body;
    }
  }
  
  get comment() {
    return this.prComment;
  }
}

class CommentRow extends DiffRow {
  constructor(issueIdentifier) {
    super();
    
    this.issueIdentifier = issueIdentifier;
    
    this.commentViews = []; // Array of Comment objects
    this.prComments = []; // Array of PRComments
    
    var commentsContainer = this.commentsContainer = h('div', {className:'commentsContainer'});
    var commentBlock = h('div', {className:'commentBlock'}, 
      h('div', {className:'commentShadowTop'}), 
      commentsContainer,
      h('div', {className:'commentShadowBottom'})
    );
    this._colspan = 1;
    var td = h('td', {className:'comment-cell'}, commentBlock);
    this.cell = td;
    
    var row = h('tr', {}, td);
    this.node = row;
    
    this.miniMapRegions = [new MiniMap.Region(commentsContainer, 'purple')];
  }
    
  set colspan(x) {
    if (this._colspan != x) {
      this._colspan = x;
      this.cell.colSpan = x;
    }
  }
  
  get colspan() {
    return this._colspan;
  }
  
  set comments(comments /*[PRComment]*/) {
    var commentsById = comments.reduce((accum, c) => {
      accum[c.id] = c;
      return accum;
    }, {});
    
    var commentViewsById = this.commentViews.reduce((accum, c) => {
      accum[c.comment.id] = c;
      return accum;
    }, {});
    
    var removeTheseViews = this.commentViews.filter((cv) => !(commentsById[cv.comment.id]));
    var insertTheseComments = comments.filter((c) => !(commentViewsById[c.id]));
    
    removeTheseViews.forEach((cv) => cv.row.remove());
    
    var newViews = insertTheseComments.map((c) => new Comment(c, this.issueIdentifier));
    var existingViews = this.commentViews.filter((cv) => !!(commentsById[cv.comment.id]));
    var commentViews = [];
    // merge newViews and existingViews
    var i, j, k;
    i = j = k = 0;
    for (; i < newViews.length && j < existingViews.length; k++) {
      var a = newViews[i];
      var b = existingViews[j];
      if (a.comment.created_at < b.comment.created_at) {
        commentViews[k] = a;
        i++;
      } else if (a.comment.created_at >= b.comment.created_at) {
        commentViews[k] = b;
        j++;
      }
    }
    for (; i < newViews.length; i++, k++) {
      commentViews[k] = newViews[i];
    }
    for (; j < existingViews.length; j++, k++) {
      commentViews[k] = newViews[k];
    }
    
    // update dom from back to front
    var last = null;
    for (i = commentViews.length-1; i >= 0; i--) {
      var cv = commentViews[i];
      if (!cv.node.parentNode) {
        this.commentsContainer.insertBefore(cv.node, last);
      }
      last = cv.node;
    }
    
    this.commentViews = commentViews;
    this.prComments = comments;
  }
  
  get comments() {
    return this.prComments;
  }
  
  get diffIdx() {
    if (this.prComments.length == 0) return -1;
    
    return this.prComments[0].diffIdx;
  }
}

export default CommentRow;
