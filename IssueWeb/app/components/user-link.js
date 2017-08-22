import React, { createElement as h } from 'react'

import ghost from 'util/ghost.js'

import './user-link.css'


class UserLink extends React.Component {
  render() {
    var user = this.props.user || ghost;
    var className = this.props.className||"";
    className += " UserLink";
    className = className.trim();
    var text;
    var title;
    var href;
    if (user.login) {
      href = `https://github.com/${user.login}`;
      text = user.login;
      title = user.name;
    } else if (user.email) {
      href = `mailto:${user.email}`;
      text = user.name || user.email;
      title = user.email;
    }
    if (!text) text = user.login || user.name || user.email || ghost.login;
    if (!href) {
      return h('span', {className, title}, text);
    } else {
      return h('a', {className, href, title}, text);
    }
  }
}

export default UserLink;
