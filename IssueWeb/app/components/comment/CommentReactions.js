import React, { createElement as h } from 'react'
import { emojify, emojifyReaction } from 'util/emojify.js'
import { TimeAgo, TimeAgoString } from 'components/time-ago.js'

var CommentReaction = React.createClass({
  propTypes: { 
    reactions: React.PropTypes.array,
    me: React.PropTypes.object
  },
  
  onClick: function() {
    if (this.props.onToggle) {
      this.props.onToggle(this.props.reactions[0].content);
    }
  },
  
  render: function() {
    var r0 = this.props.reactions[0];
    var title;
    if (this.props.reactions.length == 1) {
      title = r0.user.login + " reacted " + TimeAgoString(r0.created_at);
    } else if (this.props.reactions.length <= 3) {
      title = this.props.reactions.slice(0, 3).map((r) => r.user.login).join(", ")
    } else {
      title = r0.user.login + " and " + (this.props.reactions.length-1) + " others";
    }
    var me = this.props.me.login;
    var mine = this.props.reactions.filter((r) => r.user.login === me).length > 0;
    return h("div", {className:"CommentReaction Clickable", title: title, key:r0.content, onClick:this.onClick}, 
      h("span", {className:"CommentReactionEmoji"}, emojifyReaction(r0.content)),
      h("span", {className:"CommentReactionCount" + (mine?" CommentReactionCountMine":"")}, ""+this.props.reactions.length)
    );
  }
});

var CommentReactions = React.createClass({
  propTypes: { 
    reactions: React.PropTypes.array,
    me: React.PropTypes.object
  },
  
  render: function() {
    var reactions = this.props.reactions || [];
    
    reactions.sort((a, b) => {
      if (a.created_at < b.created_at) {
        return -1;
      } else if (a.created_at == b.created_at) {
        return 0;
      } else {
        return 1;
      }
    });
    
    var partitionMap = {};
    reactions.forEach((r) => {
      var l = partitionMap[r.content];
      if (!l) {
        partitionMap[r.content] = l = [];
      }
      l.push(r);
    });
    
    var partitions = [];
    for (var contentKey in partitionMap) {
      partitions.push(partitionMap[contentKey]);
    }
    
    partitions.sort((a, b) => {
      var d1 = new Date(a[0].created_at);
      var d2 = new Date(b[0].created_at);
      
      if (d1 < d2) {
        return -1;
      } else if (d1 == d2) {
        return 0;
      } else {
        return 1;
      }
    });
    
    var contents = partitions.map((r, i) => {
      return h(CommentReaction, {
        key:r[0].content + "-" + i, 
        reactions:r, 
        me:this.props.me, 
        onToggle:this.props.onToggle
      })
    });
    
    if (this.props.children) {
      if (Array.isArray(this.props.children)) {
        contents.push(...this.props.children);
      } else {
        contents.push(this.props.children);
      }
    }
    
    return h("div", {className:"ReactionsBar"}, contents);
  }
});

export default CommentReactions;
