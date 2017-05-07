import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'

import { HeaderLabel, HeaderSeparator } from './issue-header.js'
import { keypath, setKeypath } from 'util/keypath.js'
import IssueState from 'issue-state.js'

import './pr-actions-bar.css'
import PRMergeIcon from '../../../image/MergeIcon.svg'
import PRMergeIconDisabled from '../../../image/MergeIconDisabled.svg'

class PRChangeSummary extends React.Component {
  render() {
    var issue = this.props.issue;
    
    if (!Number.isInteger(issue.changed_files) /* we don't have the summary loaded yet */) {
      return h('div', {className:'PRChangeSummary'});
    }
    
    var changedFiles = issue.changed_files;
    var additions = issue.additions||0;
    var deletions = issue.deletions||0;
    var linesChanged = additions+deletions;
    
    var addFrac = linesChanged?(additions/linesChanged):0;
    var deleteFrac = linesChanged?(deletions/linesChanged):0;
    
    var addBoxes = Math.round(4.0 * addFrac);
    var delBoxes = 4 - addBoxes;
    
    var numFormat = new Intl.NumberFormat();
        
    var summary;
    if (changedFiles == 1) {
      summary = "1 changed file";
    } else {
      summary = `${numFormat.format(changedFiles)} changed files`;
    }
    
    var boxes = [];
    for (var i = 0; linesChanged > 0 && i < 5; i++) {
      var color;
      if (i == 4) color = '#CCC';
      else if (i+1 > addBoxes) color = 'red';
      else color = 'green';
      boxes.push(h('span', {key:`box.${i}`, className:'PRChangeBox', style:{backgroundColor:color}}));
    }
        
    var addLineSummary = h('span', {key:'+', className:'PRChangedLinesLabel', style:{color:'green'}}, `+${numFormat.format(additions)}`);
    var delLineSummary = h('span', {key:'-', className:'PRChangedLinesLabel', style:{color:'red'}}, `-${numFormat.format(deletions)}`);
    var lineSummary = null;
    if (additions > 0 && deletions > 0) {
      lineSummary = [addLineSummary, ' ', delLineSummary];
    } else if (additions > 0) {
      lineSummary = addLineSummary;
    } else if (deletions > 0) {
      lineSummary = delLineSummary;
    }
    
    var totalSummary;
    if (linesChanged == 1) {
      totalSummary = '1 line changed';
    } else {
      totalSummary = `${numFormat.format(linesChanged)} lines changed`;
    }
    
    return h('div', {className:'PRChangeSummary', title:totalSummary},
      h('div', {key:'f', className:'PRChangedFiles'}, summary),
      h('div', {key:'l', className:'PRChangedLines'},
        lineSummary,
        " ",
        boxes
      )
    );
  }
}

class PRMergeChangesButton extends React.Component {
  click() {
    var el = ReactDOM.findDOMNode(this.refs.button);
    var bbox = el.getBoundingClientRect();
    window.mergePopover.postMessage({
      bbox
    });
  }
  
  render() {
    var issue = IssueState.current.issue;
    var canMerge = issue.mergeable && issue.state == 'open';
    
    if (canMerge) {
      return h('div', {ref:'button', className:'PRActionsBarButton PRMergeChangesButton', onClick:this.click.bind(this)},
        h('img', {src:PRMergeIcon}),
        "Merge ..."
      );
    } else {
      return h('span', {});
    }
  }
}

class PRReviewChangesButton extends React.Component {
  click() {
    window.diffViewer.postMessage({});
  }
  
  render() {
    return h('div', {className:'PRActionsBarButton PRReviewChangesButton', onClick:this.click.bind(this)},
      "Review Changes"
    );
  }
}

class PRActionsBar extends React.Component {
  render() {
    return h('div', {className:'PRActionsBar'},
      h(PRChangeSummary, {issue:this.props.issue}),
      h('div', {className:'PRActionsBarButtons'},
        h(PRMergeChangesButton, {}),
        h(PRReviewChangesButton, {}),
      )
    )
  }
}

export { PRActionsBar, PRReviewChangesButton };
