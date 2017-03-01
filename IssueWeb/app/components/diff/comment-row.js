import 'components/comment/comment.css'
import './comment.css'

import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'

import AbstractComment from 'components/comment/AbstractComment.js'
import ghost from 'util/ghost.js'

import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'

import uuidV4 from 'uuid/v4.js'

class Comment extends AbstractComment {
  constructor(props) {
    super(props);
  }
  
  issueIdentifierParts() {
    var [repoOwner, repoName, number] = this.props.issueIdentifier.split("/#");
    return { repoOwner, repoName, number };
  }
  
  issue() {
    var { number } = this.issueIdentifierParts();
    return {
      number: number
    }
  }
  
  isNewIssue() { return false; }
  
  me() { return this.props.me; }
  
  canClose() { return false; }
  
  repoOwner() {
    return this.issueIdentifierParts().repoOwner;
  }
  
  repoName() {
    return this.issueIdentifierParts().repoName;
  }
  
  shouldShowCommentPRBar() { return false; }
  
  saveDraftState() { }
  restoreDraftState() { }
  
  deleteComment() {
    this.props.commentDelegate.deleteComment(this.props.comment);
    return Promise.resolve();
  }
  
  saveAndClose() { return this.save(); }
  
  loginCompletions() { return [] }
  
  _save() {
    if (this.props.comment) {
      var newBody = this.state.code;
      if (newBody != this.props.comment.body) {
        var newComment = Object.assign({}, this.props.comment, {body:newBody});
        this.props.commentDelegate.editComment(newComment);
      }
      this.setState(Object.assign({}, this.state, {editing:false}));
    } else {
      var now = new Date().toISOString();
      var newComment = {
        temporary_id: uuidV4(),
        user: this.props.me,
        body: this.state.code,
        created_at: now,
        updated_at: now,
        reactions: [],
      }
      if (this.props.inReplyTo) {
        newComment.in_reply_to = this.props.inReplyTo.id;
      } else {
        newComment.diffIdx = this.props.diffIdx;
      }
      this.props.commentDelegate.addNewComment(newComment);
    }
    
    if (this.props.didSave) {
      this.props.didSave();
    }
    return Promise.resolve();
  }
  
  componentDidMount() {
    super.componentDidMount();
    if (!this.props.comment) {
      this.focusCodemirror();
    }
    this.props.didRender();
  }
  
  componentDidUpdate() {
    super.componentDidUpdate();
    this.props.didRender();
  }
}

class CommentList extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasReply: this.props.comments.length == 0 }
  }
  
  addReply() {
    this.setState(Object.assign({}, this.state, {hasReply: true}));
  }
  
  cancelReply() {
    this.setState(Object.assign({}, this.state, {hasReply: false}));
  }
    
  render() {
    var commentsLength = this.props.comments.length;
    var buttonIdx = this.state.hasReply ? -1 : commentsLength - 1;
    var comments = this.props.comments.map((c, i) => {
      return h(Comment, {
        key:c.id||c.temporary_id||c.created_at, 
        comment:c, 
        first:false,
        commentIdx:i,
        issueIdentifier:this.props.issueIdentifier,
        me:this.props.me,
        buttons:i==buttonIdx?[{"title": "Reply", "action": this.addReply.bind(this)}]:[],
        didRender:this.props.didRender,
        commentDelegate:this.props.commentDelegate
      })
    });
        
    if (this.state.hasReply) {
      comments.push(h(Comment, {
        key:'add',
        issueIdentifier:this.props.issueIdentifier,
        me:this.props.me,
        onCancel:this.cancelReply.bind(this),
        didRender:this.props.didRender,
        inReplyTo:commentsLength>0?this.props.comments[commentsLength-1]:undefined,
        commentDelegate:this.props.commentDelegate,
        didSave:this.cancelReply.bind(this)
      }));
    }
  
    return h('div', {className:'commentList'},
      comments
    );
  }
  
  componentDidUpdate() {
    this.props.didRender();
  }
  
  componentDidMount() {
    this.props.didRender();
  }
}

class CommentRow extends DiffRow {
  constructor(issueIdentifier, me, delegate) {
    super();
    
    this.issueIdentifier = issueIdentifier;
    this.me = me;
    this.delegate = delegate;
    
    this.prComments = []; // Array of PRComments
    
    var commentsContainer = this.commentsContainer = document.createElement('div');
    commentsContainer.className = 'commentsContainer';
    
    var commentBlock = document.createElement('div');
    commentBlock.className = 'commentBlock';
    
    var shadowTop = document.createElement('div');
    shadowTop.className = 'commentShadowTop';
    
    var shadowBottom = document.createElement('div');
    shadowBottom.className = 'commentShadowBottom';
    
    commentBlock.appendChild(shadowTop);
    commentBlock.appendChild(commentsContainer);
    commentBlock.appendChild(shadowBottom);
    
    this._colspan = 1;
    var td = document.createElement('td');
    td.className = 'comment-cell';
    td.appendChild(commentBlock);
    this.cell = td;
    
    var row = document.createElement('tr');
    row.appendChild(td);
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
    this.prComments = comments;
    ReactDOM.render(
      h(CommentList, {
        comments, 
        issueIdentifier:this.issueIdentifier,
        addComment:this.addComment.bind(this),
        me:this.me,
        didRender:()=>this.delegate.updateMiniMap(),
        commentDelegate:this.delegate
      }),
      this.commentsContainer
    );
  }
  
  get comments() {
    return this.prComments;
  }
  
  get diffIdx() {
    if (this.prComments.length == 0) return -1;
    
    return this.prComments[0].diffIdx;
  }
  
  addComment(comment, options) {
    this.delegate.addComment(comment, options);
  }
}

export default CommentRow;
