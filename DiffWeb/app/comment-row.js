import '../../IssueWeb/app/components/comment/comment.css'
import './comment.css'


import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'

import { markdownRender } from '../../IssueWeb/app/markdown-render.js'

import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'

class Comment extends React.Component {
  constructor(props) {
    super(props);
  }
  
  shouldComponentUpdate(nextProps, nextState) {
    var idChanged = nextProps.comment.id != this.props.comment.id;
    if (idChanged) return true;
    
    var bodyChanged = nextProps.comment.body != this.props.comment.body;
    if (bodyChanged) return true;
    
    return false;
  }
  
  render() {
    var body = this.props.comment.body;
    var [repoOwner, repoName] = this.props.issueIdentifier.split("/#");
    return h('div', {className:'comment'},
      h('div', { 
        className:'commentBody', 
        ref: (e) => this.commentBody = e,
        dangerouslySetInnerHTML: {
          __html:markdownRender(
            body, 
            repoOwner,
            repoName
          )
        }
      })
    );
  }
}

class CommentList extends React.Component {
  constructor(props) {
    super(props);
  }
  
  render() {
    var comments = this.props.comments.map((c) => {
      return h(Comment, {
        key:c.id||"new", 
        comment:c, 
        issueIdentifier:this.props.issueIdentifier
      })
    });
    
    console.log("props.comments", this.props.comments);
    console.log("comments", comments);
  
    return h('div', {className:'commentList'},
      comments
    );
  }
}

class CommentRow extends DiffRow {
  constructor(issueIdentifier) {
    super();
    
    this.issueIdentifier = issueIdentifier;
    
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
      h(CommentList, {comments, issueIdentifier:this.issueIdentifier}),
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
}

export default CommentRow;
