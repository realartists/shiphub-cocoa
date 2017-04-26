import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import AvatarIMG from 'components/AvatarIMG.js'
import { TimeAgo, TimeAgoString } from 'components/time-ago.js'
import ghost from 'util/ghost.js'

import './commit-group.css'
import CommitAvatar from '../../../image/CommitAvatar.png'
import CommitBullet from '../../../image/CommitBullet.png'

class CommitGroupHeader extends React.Component {
  render() {
    var commits = this.props.commits;
    
    var committers = commits.map((x) => x.committer || x.author || ghost);
    committers = committers.filter((x) => x.email != 'noreply@github.com');
    
    var user = committers.length > 0 ? committers[0] : ghost;
    var hasOthers = committers.some((x) => x.email != user.email);
    
    var timestamp = commits.length > 0 ? commits[0].created_at : new Date();
    var desc = "";
    if (commits.length == 1) {
      desc = " added a commit ";
    } else {
      desc = ` added ${commits.length} commits `;
    }
    
    
    
    return h('div', { className:'commitGroupHeader' },
      h('span', { className: 'commitGroupIcon fa fa-git-square' }),
      h('span', {className:'commitGroupAuthor', title:user.email}, user.name),
      hasOthers ? h('span', {className:'commitGroupOthers'}, ' and others') : "",
      h('span', {className:'commitGroupTimeAgo'}, desc),
      h(TimeAgo, {className:'commentTimeAgo', live:true, date:timestamp}),
    );
  }
}

class Commit extends React.Component {
  render() {
    return h('div', { className:'commitItem' },
      h('img', { className:'commitItemBullet', src:CommitBullet, width: "12", height: "12" }),
      h('a', { className:'commitItemHash', href:this.props.commit.html_url }, this.props.commit.sha.substr(0, 7)),
      h('span', { className:'commitItemMsg' }, " " + this.props.commit.message)
    );
  }
}

class CommitGroup extends React.Component {
  render() {
    var commits = this.props.commits;
    return h('div', { className:'commitGroup' },
      h(CommitGroupHeader, { commits: this.props.commits }),
      h('div', {className:'commitBody'},
        commits.map((commit) => h(Commit, { key:commit.sha, commit }))
      )
    );
  }
}

export default CommitGroup;
