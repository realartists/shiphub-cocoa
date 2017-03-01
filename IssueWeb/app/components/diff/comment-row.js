import 'components/comment/comment.css'
import './comment.css'

import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'

import AbstractComment from 'components/comment/AbstractComment.js'
import ghost from 'util/ghost.js'

import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'

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
  
  deleteComment() { }
  
  saveAndClose() { return this.save(); }
  
  loginCompletions() { return [] }
  
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
    this.state = { hasReply: false }
  }
  
  addReply() {
    this.setState(Object.assign({}, this.state, {hasReply: true}));
  }
  
  cancelReply() {
    this.setState(Object.assign({}, this.state, {hasReply: false}));
  }
    
  render() {
    var buttonIdx = this.state.hasReply ? -1 : this.props.comments.length - 1;
    var comments = this.props.comments.map((c, i) => {
      return h(Comment, {
        key:c.id||c.temporary_id||c.created_at, 
        comment:c, 
        first:false,
        commentIdx:i,
        issueIdentifier:this.props.issueIdentifier,
        me:this.props.me,
        buttons:i==buttonIdx?[{"title": "Reply", "action": this.addReply.bind(this)}]:[],
        didRender:this.props.didRender
      })
    });
        
    if (this.state.hasReply) {
      comments.push(h(Comment, {
        key:'add',
        issueIdentifier:this.props.issueIdentifier,
        me:this.props.me,
        onCancel:this.cancelReply.bind(this),
        didRender:this.props.didRender
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
        didRender:()=>this.delegate.updateMiniMap()
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
