import React, { createElement as h } from 'react'
import ghost from 'util/ghost.js'
import { TimeAgo, TimeAgoString } from 'components/time-ago.js'
import CommentControls from './CommentControls.js'
import AvatarIMG from 'components/AvatarIMG.js'

var CommentHeader = React.createClass({  
  render: function() {
    var user = this.props.comment.user||this.props.comment.author;
    if (!user) user = ghost;
    var desc = " commented ";
    if (this.props.first) {
      desc = " filed ";
    }
    return h('div', {className:'commentHeader'},
      h(AvatarIMG, {user:user, size:32}),
      h('span', {className:'commentAuthor'}, user.login),
      h('span', {className:'commentTimeAgo'}, desc),
      h(TimeAgo, {className:'commentTimeAgo', live:true, date:this.props.comment.created_at}),
      !!(this.props.comment.pending_id)?h('span', {className:'commentPending'}, 'Pending'):"",
      h(CommentControls, this.props)
    );
  }
});

export default CommentHeader;
