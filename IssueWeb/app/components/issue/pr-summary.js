import React, { createElement as h } from 'react'

import { HeaderLabel, HeaderSeparator } from './issue-header.js'
import { CommitStatuses, findLatestCommitStatuses, CommitStatusTable } from './commit-group.js'
import ghost from 'util/ghost.js'
import { keypath, setKeypath } from 'util/keypath.js'

import './pr-summary.css'

class PRSummary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { expandStatuses: false };
  }
  
  componentWillReceiveProps(newProps) {
    if (this.props.issue.id != newProps.issue.id) {
      this.setState({expandStatuses: false});
    }
  }
  
  toggleExpandStatuses(evt) {
    this.setState({expandStatuses: !this.state.expandStatuses});
    evt.preventDefault();
  }

  render() {
    var statuses = this.props.issue.commit_statuses||[];
    var tot = keypath(this.props.issue, "head.sha");
    statuses = statuses.filter(cs => cs.reference == tot);
    statuses = findLatestCommitStatuses(statuses);
    
    var headRepo = keypath(this.props.issue, "head.repo.full_name");
    var baseRepo = keypath(this.props.issue, "base.repo.full_name");
    
    var headBranch = keypath(this.props.issue, "head.ref");
    var baseBranch = keypath(this.props.issue, "base.ref");
    
    var summary;
    var author = (this.props.issue.user||ghost).login;
    
    var headRef;
    if (headRepo != baseRepo) {
      headRef = `${headRepo}:${headBranch}`;
    } else {
      headRef = headBranch;
    }
    
    summary = h('div', {key:'summary', className:'PRSummary'},
      `${author} wants to merge `,
      h('span', {className:'PRSummaryRef'}, headRef),
      ' into ',
      h('span', {className:'PRSummaryRef'}, baseBranch)
    );

    var commitStatus = null;
    if (statuses.length > 0) {
      var caretType = this.state.expandStatuses ? 'fa-caret-up' : 'fa-caret-down';
      commitStatus = 
        h('div', {key:'status', className:'PRSummaryCommitStatus'},
          h(CommitStatuses, { statuses: statuses, onClick: this.toggleExpandStatuses.bind(this) }),
          h('i', {className:`fa ${caretType} PRSummaryCommitStatusCaret`, onClick: this.toggleExpandStatuses.bind(this) })
        );
    }
    
    var els = [];
    els.push(h('div', {key:'input', className: 'IssueInput'},
      h(HeaderLabel, {key:'label', title:"Pull Request"}),
      summary,
      commitStatus
    ));
             
    if (this.state.expandStatuses) {
      els.push(h('div', {key:'table', className:'PRSummaryCommitStatuses'},
        h(CommitStatusTable, { statuses, issue:this.props.issue })
      ));
    }
    
    return h('div', {}, els);
  }
}

export default PRSummary;
