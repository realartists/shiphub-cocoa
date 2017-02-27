import React, { createElement as h } from 'react'
import ghost from 'util/ghost.js'

var AvatarIMG = React.createClass({
  propTypes: {
    user: React.PropTypes.object,
    size: React.PropTypes.number
  },
  
  getDefaultProps: function() {
    return {
      user: ghost,
      size: 32
    };
  },
    
  pointSize: function() {
    var s = 32;
    if (this.props.size) {
      s = this.props.size;
    }
    return s;
  },
  
  pixelSize: function() {
    return this.pointSize() * 2;
  },
  
  avatarURL: function() {
    var avatarURL = this.props.user.avatar_url;
    if (avatarURL == null) {
      avatarURL = "https://avatars.githubusercontent.com/u/" + this.props.user.id + "?v=3";
    }
    avatarURL += "&s=" + this.pixelSize();
    return avatarURL;
  },
  
  render: function() {    
    var s = this.pointSize();
    var imgProps = {
      className: "avatar",
      src: this.avatarURL(),
      width: s,
      height: s
    };
    imgProps = Object.assign({}, this.props, imgProps);
    return h('img', imgProps);
  }
});

export default AvatarIMG;

