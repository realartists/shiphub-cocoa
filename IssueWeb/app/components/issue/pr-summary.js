import React, { createElement as h } from 'react'

import { HeaderLabel, HeaderSeparator } from './issue-header.js'
import { CommitStatuses, findLatestCommitStatuses } from './commit-group.js'
import ghost from 'util/ghost.js'

import './pr-summary.css'

class CommitStatusTableRow extends React.Component {
  render() {
    return h('tr', {},
      h('td', {className:'PRSummaryCommitTableStatus'}, h(CommitStatuses, {statuses:[this.props.status]})),
      h('td', {className:'PRSummaryCommitTableContext'}, this.props.status.context),
      h('td', {className:'PRSummaryCommitTableStatusDescription'}, this.props.status.status_description),
      h('td', {className:'PRSummaryCommitTableLink'},
        h('a', {href:this.props.status.target_url, className:'fa fa-arrow-circle-right'})
      )
    );
  }
}

class CommitStatusTable extends React.Component {
  render() {
    return h('table', {className:'PRSummaryCommitStatusTable'},
      h('tbody', {},
        this.props.statuses.map(cs => h(CommitStatusTableRow, {key:cs.id, status:cs}))
      )
    );
  }
}

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
    var statuses = this.props.issue.commit_statuses;
    var tot = this.props.issue.head.sha;
    statuses = statuses.filter(cs => cs.reference = tot);
    statuses = findLatestCommitStatuses(statuses);
    
    var headRepo = this.props.issue.head.repo.full_name;
    var baseRepo = this.props.issue.base.repo.full_name;
    
    var headBranch = this.props.issue.head.ref;
    var baseBranch = this.props.issue.base.ref;
    
    var summary;
    var author = (this.props.issue.user||ghost).login;
    
    var baseRef;
    if (headRepo != baseRepo) {
      baseRef = `${headRepo}:headBranch`;
    } else {
      baseRef = headBranch;
    }
    
    summary = h('div', {key:'summary', className:'PRSummary'},
      `${author} wants to merge `,
      h('span', {className:'PRSummaryRef'}, baseRef),
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
        h(CommitStatusTable, { statuses })
      ));
    }
    
    return h('div', {}, els);
  }
}

export default PRSummary;
