import React, { createElement as h } from 'react'
import CommentReactions from './CommentReactions.js'

var CommentPRBar = React.createClass({
  props: {
    issue: React.PropTypes.object,
    comment: React.PropTypes.object,
    onToggleReaction: React.PropTypes.func,
    me: React.PropTypes.object
  },
  
  render: function() {
    var issue = this.props.issue;
    var href = `https://github.com/${issue._bare_owner}/${issue._bare_repo}/pulls/${issue.number}/files`;
    return h('div', {className:'ReactionsBarWithPR'},
      h(CommentReactions, {reactions:this.props.comment.reactions, me:this.props.me, onToggle:this.props.onToggleReaction}, 
        h('a', 
          {className:'Clickable addCommentButton viewDiffButton', href:href},
          'View Code Changes'
        )
      )
    );
  }
});

export default CommentPRBar;

