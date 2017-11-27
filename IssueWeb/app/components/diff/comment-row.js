import 'components/comment/comment.css'
import './comment.css'

import BBPromise from 'util/bbpromise.js'

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
  
  canEdit() {
    if (!this.props.comment) return true;
    if (!this.props.repo) return false;
    var user = this.props.comment.user||this.props.comment.author;
    if (!user) user = ghost;
    return this.props.repo.canPush || this.me().id == user.id;
  }
  
  repoOwner() {
    return this.issueIdentifierParts().repoOwner;
  }
  
  repoName() {
    return this.issueIdentifierParts().repoName;
  }
  
  saveDraftState() { }
  restoreDraftState() { }
  
  deleteComment() {
    this.props.commentDelegate.deleteComment(this.props.comment);
    return BBPromise.resolve();
  }
  
  saveAndClose() { return this.save(); }
  
  loginCompletions() { return this.props.mentionable; }
  
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
        pending_id: uuidV4(),
        user: this.props.me,
        body: this.state.code,
        created_at: now,
        updated_at: now,
        reactions: [],
      }
      if (this.props.inReplyTo && !!(this.props.inReplyTo.id)) {
        newComment.in_reply_to = this.props.inReplyTo.id;
      } else {
        newComment.diffIdx = this.props.diffIdx;
      }
      this.props.commentDelegate.addNewComment(newComment);
    }
    
    if (this.props.didSave) {
      this.props.didSave();
    }
    return BBPromise.resolve();
  }
  
  onTaskListEdit(newBody) {
    if (!this.props.comment || this.state.editing) {
      this.updateCode(newBody);
    } else {
      var newComment = Object.assign({}, this.props.comment, {body:newBody});
      this.props.commentDelegate.editComment(newComment);
    }
  }
  
  addReaction(reaction) {
    var existing = this.findReaction(reaction);
    var comment = this.props.comment;
    if (!existing && comment) {
      window.addReaction.postMessage({comment, reaction});
    }
  }
  
  toggleReaction(reaction) {
    var existing = this.findReaction(reaction);
    var comment = this.props.comment;
    if (comment) {
      if (existing) {
        var reaction_id = existing.id;
        window.deleteReaction.postMessage({comment, reaction_id});
      } else {
        window.addReaction.postMessage({comment, reaction});
      }
    }
  }
  
  canReact() {
    return this.props.comment && !("pending_id" in this.props.comment);
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
  
  onFocus() {
    super.onFocus();
    this.props.onFocus();
  }
  
  onBlur() {
    super.onBlur();
    this.props.onBlur();
  }
  
  updateCode(newCode) {
    super.updateCode(newCode);
    this.props.onUpdateCode();
  }
}

class ReviewFooter extends React.Component {
  render() {
    var canSave = this.props.canSave;
    var contents = [];
    
    if (!this.props.previewing) {
      contents.push(h('a', {
        key:'markdown', 
        className:'markdown-mark formattingHelpButton', 
        target:"_blank", 
        href:"https://guides.github.com/features/mastering-markdown/", 
        title:"Open Markdown Formatting Guide"
      }));
    }
    
    contents.push(h('button', {
      type:'button',
      key:'cancel', 
      className:'ActionButton addCommentButton addCommentCloseButton', 
      onClick:this.props.onCancel}, 
      'Cancel'
    ));
    
    if (!this.props.inReview) {
      contents.push(h('button', {
        key:'addSingle',
        title:'⌘⇧↩︎', 
        className:'ActionButton addCommentButton' + (canSave ? "" : " addCommentSaveButtonDisabled"),
        onClick:canSave?this.props.onAddSingleComment:undefined}, 
        'Add Single Comment'
      ));
    }
    
    contents.push(h('button', {
      key:'addReview',
      title:'⌘↩︎', 
      className:'ActionButton addCommentButton addCommentSaveButton' + (canSave ? "" : " addCommentSaveButtonDisabled"),
      onClick:canSave?this.props.onSave:undefined}, 
      this.props.inReview?'Add review comment':'Start a review'
    ));
    
    return h('div', {className:'commentFooter'}, contents);
  }
}

class AddReviewComment extends Comment {

  canEdit() { return true; }

  save() {
    // default behavior is to begin a review
    this.props.commentDelegate.inReview = true;
    super.save();
  }
  
  saveAndClose() {
    // this is repurposed to mean add single comment
    super.save();
  }
  
  renderFooter() {
    if (this.state.uploadCount > 0) {
      return super.renderFooter();
    } else {
      return h(ReviewFooter, {
        previewing: this.state.previewing,
        inReview: this.props.commentDelegate.inReview,
        canSave: this.needsSave(),
        onAddSingleComment: this.saveAndClose.bind(this),
        onSave: this.save.bind(this),
        onCancel: this.props.onCancel
      });
    }
  }
}

class CommentList extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasReply: this.props.comments.length == 0 }
  }
  
  addReply() {
    if (!this.state.hasReply) {
      this.needsScrollAddComment = true;
      this.setState(Object.assign({}, this.state, {hasReply: true}));
    } else {
      this.refs.addComment.focusCodemirror();
      this.refs.addComment.scrollIntoView();
    }
  }
  
  cancelReply() {
    this.setState(Object.assign({}, this.state, {hasReply: false}));
    this.props.didCancel();
  }
    
  render() {
    var commentsLength = this.props.comments.length;
    var buttonIdx = this.state.hasReply ? -1 : commentsLength - 1;
    var comments = this.props.comments.map((c, i) => {
      return h(Comment, {
        key:c.id||c.pending_id||c.created_at, 
        ref:'comment.' + (c.id||c.pending_id||c.created_at),
        comment:c, 
        first:false,
        commentIdx:i,
        issueIdentifier:this.props.issueIdentifier,
        me:this.props.me,
        repo:this.props.repo,
        mentionable:this.props.mentionable,
        buttons:i==buttonIdx?[{"title": "Reply", "action": this.addReply.bind(this)}]:[],
        didRender:this.props.didRender,
        onFocus:this.props.onFocus,
        onBlur:this.props.onBlur,
        onUpdateCode:this.props.onUpdateCode,
        commentDelegate:this.props.commentDelegate,
        diffIdx:this.props.diffIdx
      })
    });
        
    if (this.state.hasReply) {
      comments.push(h(AddReviewComment, {
        key:'add',
        ref:'addComment',
        issueIdentifier:this.props.issueIdentifier,
        me:this.props.me,
        repo:this.props.repo,
        mentionable:this.props.mentionable,
        onCancel:this.cancelReply.bind(this),
        didRender:this.props.didRender,
        onFocus:this.props.onFocus,
        onBlur:this.props.onBlur,
        onUpdateCode:this.props.onUpdateCode,
        /* send in_reply_to to the first comment in the chain, otherwise a bug
           in the GitHub web UI will prevent it from rendering */
        inReplyTo:commentsLength>0?this.props.comments[0]:undefined,
        commentDelegate:this.props.commentDelegate,
        didSave:this.cancelReply.bind(this),
        diffIdx:this.props.diffIdx
      }));
    }
  
    return h('div', {className:'commentList'},
      comments
    );
  }
  
  scrollToComment(c) {
    var ref = 'comment.' + (c.id||c.pending_id||c.created_at);
    if (ref in this.refs) {
      var comp = this.refs[ref];
      comp.scrollIntoView();
    }
  }
  
  componentDidUpdate() {
    this.props.didRender();
    if (this.needsScrollAddComment && this.refs.addComment) {
      this.needsScrollAddComment = false;
      this.refs.addComment.scrollIntoView();
    }
  }
  
  componentDidMount() {
    this.props.didRender();
  }
  
  activeComment() {
    for (var ref in this.refs) {
      if (ref == "addComment" || ref.startsWith("comment.")) {
        var comment = this.refs[ref];
        if (comment.isActive()) {
          return comment;
        }
      }
    }
    return null;
  }
}

class CommentRow extends DiffRow {
  constructor(issueIdentifier, me, repo, mentionable, delegate) {
    super();
    
    this.issueIdentifier = issueIdentifier;
    this.me = me;
    this.repo = repo;
    this.mentionable = mentionable;
    this.delegate = delegate;

    this.hasNewComment = false;    
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
    this.render();
  }
  
  get comments() {
    return this.prComments;
  }
  
  get diffIdx() {
    if (this.prComments.length == 0) {
      if (this.newCommentDiffIdx !== undefined) {
        return this.newCommentDiffIdx;
      }
      return -1;
    }
    
    return this.prComments[0].diffIdx;
  }
  
  setHasNewComment(flag, diffIdx) {
    this.hasNewComment = flag;
    if (flag) {
      this.newCommentDiffIdx = diffIdx;
    } else {
      delete this.newCommentDiffIdx;
    }
    this.render(() => {
      setTimeout(() => this.showReply(), 0);
    });
  }
    
  showReply() {
    if (this.commentList) {
      this.commentList.addReply();
    }
  }
  
  didCancelReply() {
    this.hasNewComment = false;
    if (this.prComments.length == 0) {
      this.delegate.cancelInsertComment(this.diffIdx);
    }
  }
  
  render(then) {
    this.commentList = ReactDOM.render(
      h(CommentList, {
        comments:this.prComments,
        issueIdentifier:this.issueIdentifier,
        me:this.me,
        repo:this.repo,
        mentionable:this.mentionable,
        didRender:()=>this.delegate.updateMiniMap(),
        didCancel:this.didCancelReply.bind(this),
        onFocus:this.onFocus.bind(this),
        onBlur:this.onBlur.bind(this),
        onUpdateCode:this.onUpdateCode.bind(this),
        commentDelegate:this.delegate,
        diffIdx:this.diffIdx
      }),
      this.commentsContainer,
      then
    );
  }
  
  onFocus() {
    this.delegate.simplify();
  }
  
  onBlur() {
    this.delegate.unsimplify();
  }
  
  onUpdateCode() {
    this.delegate.simplify();
  }
  
  scrollToComment(comment) {
    setTimeout(() => {
      this.commentList.scrollToComment(comment);
    }, 1);
  }
  
  activeComment() {
    if (this.commentList) {
      return this.commentList.activeComment();
    } else {
      return null;
    }
  }
}

export default CommentRow;
