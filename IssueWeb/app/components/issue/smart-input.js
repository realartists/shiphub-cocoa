import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'

/* Component which calls its onChange only if the value is changed on enter or blur */
var SmartInput = React.createClass({
  propTypes: {
    onChange: React.PropTypes.func,
    onKeyPress: React.PropTypes.func,
    readOnly: React.PropTypes.bool,
    onEdit: React.PropTypes.func /* function onEdit(editedBool) */
  },

  getInitialState: function() {
    return { value: this.props.value };
  },
  
  componentWillReceiveProps: function(newProps) {
    this.setState({value: newProps.value || ""})
  },
  
  focus: function() {
    if (this.refs.input) {
      var el = ReactDOM.findDOMNode(this.refs.input);
      if (el) {
        el.focus();
      }
    }
  },
  
  blur: function() {
    if (this.refs.input) {
      var el = ReactDOM.findDOMNode(this.refs.input);
      if (el) {
        el.blur();
      }
    }
  },
  
  hasFocus: function() {
    if (this.refs.input) {
      var el = ReactDOM.findDOMNode(this.refs.input);
      if (el) {
        return document.activeElement == el;
      }
    }
    return false;
  },
  
  onChange: function(e) {
    var val = e.target.value;
    this.setState({value: val});
    if (this.props.onEdit != null) {
      this.props.onEdit(this.isEdited(), val);
    }
  },
  
  isEdited: function() {
    if (this.props.initialValue !== undefined) {
      return (this.props.initialValue || "") != (this.state.value || "");
    } else {
      return (this.props.value || "") != (this.state.value || "");
    }
  },
  
  dispatchChangeIfNeeded: function(goNext) {
    if (this.props.onChange != null && this.isEdited()) {
      this.props.onChange(this.state.value, goNext);
    }
  },
  
  onBlur: function(e) {
    if (this.props.onBlur) {
      this.props.onBlur();
    } else {
      this.dispatchChangeIfNeeded(false);
    }
    return true;
  },
  
  onKeyPress: function(evt) {
    if (evt.which == 13) {
      this.dispatchChangeIfNeeded(true);
      evt.preventDefault();
    }
  },
  
  
  
  render: function() {
    var elementType = this.props.element || 'input';
    var props = Object.assign({}, this.props, this.state, {ref:'input', onChange:this.onChange, onKeyPress:this.onKeyPress, onBlur:this.onBlur});
    return h(elementType, props, this.children);
  }
});

export { SmartInput };
export default SmartInput;
