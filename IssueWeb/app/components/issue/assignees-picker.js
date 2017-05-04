import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import Completer from './completer.js'

var AssigneesPicker = React.createClass({
  propTypes: {
    onAdd: React.PropTypes.func,
    availableAssigneeLogins: React.PropTypes.array
  },
  
  onAdd: function() {
    var completer = this.refs.completer;
    if (!completer || !(completer.refs.typeInput)) return;
    
    var el = ReactDOM.findDOMNode(completer.refs.typeInput);
    var val = el.value;
    
    if (val === "") {
      return;
    }
    
    var existingMatch = this.props.availableAssigneeLogins.find((login) => (login === val));
    
    var promise = this.props.onAdd(existingMatch);
    
    $(el).typeahead('val', "");

    return promise;
  },
  
  onChange: function() {
    if (!this.handlingMouseDown && !this.hasFocus() && this.isEdited()) {
      this.refs.completer.clear();
    }
  },
  
  onPlusClick: function() {
    var completer = this.refs.completer;
    if (!completer || !(completer.refs.typeInput)) return;
    var el = ReactDOM.findDOMNode(completer.refs.typeInput);
    var val = el.value;
    
    if (val === "") {
      this.focus();
    } else {
      this.onAdd();
    }
  },
  
  onPlusMouseDown: function() {
    this.handlingMouseDown = true;
  },
  
  onPlusMouseUp: function() {
    this.handlingMouseDown = false;
  },
  
  focus: function() {
    if (this.refs.completer) {
      this.refs.completer.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.completer) {
      return this.refs.completer.hasFocus();
    } else {
      return false;
    }
  },
  
  isEdited: function() {
    if (this.refs.completer) {
      return this.refs.completer.isEdited();
    } else {
      return false;
    }
  },
  
  containsCompleteValue: function() {
    if (this.refs.completer) {
      return this.refs.completer.containsCompleteValue();
    } else {
      return false;
    }
  },
  
  render: function() {
    const matcher = Completer.SubstrMatcher(this.props.availableAssigneeLogins);
  
    return h('span', {className:"AssigneesPicker"},
      h(Completer, {
        value: "",
        ref: 'completer',
        placeholder: this.props.placeholder||"Add Assignee",
        onEnter: this.onAdd,
        onChange: this.onChange,
        matcher: matcher,
      }),      
      h('i', {className: 'fa fa-user-plus AddAssignee Clickable',
        onClick: this.onPlusClick,
        onMouseDown: this.onPlusMouseDown,
        onMouseUp: this.onPlusMouseUp
      })
    );
  }
});

export default AssigneesPicker;
