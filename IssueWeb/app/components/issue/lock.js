import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import IssueState from 'issue-state.js'

import './lock.css'

class IssueLock extends React.Component {
  toggleLock(evt) {
    var el = ReactDOM.findDOMNode(this.refs.icon);
    var bbox = el.getBoundingClientRect();
    
    window.toggleLock.postMessage({bbox});
    
    evt.preventDefault();
  }
  
  render() {
    var locked = this.props.issue.locked;
    var icon = locked ? "lock" : "unlock";
    var canChange = IssueState.current.repoCanPush;
    var title;
    
    if (locked && canChange) {
      title = "Click to unlock conversation";
    } else if (locked && !canChange) {
      title = "Issue conversation is locked";
    } else if (!locked && canChange) {
      title = "Click to lock conversation";
    } else if (!locked && !canChange) {
      title = "";
    }
    
    return h('i', {
      ref:'icon', 
      key:'icon',
      className:`IssueLock fa fa-${icon}`,
      title,
      onClick:this.toggleLock.bind(this)
    });
  }
}

IssueLock.PropTypes = {
  issue: React.PropTypes.object
};

export default IssueLock;