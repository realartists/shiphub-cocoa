import React, { createElement as h } from 'react'

/* Component which calls its onChange only if the value is changed on enter or blur */
var SmartInput = React.createClass({
  propTypes: {
    onChange: React.PropTypes.func,
    onKeyPress: React.PropTypes.func,
    onEdit: React.PropTypes.func /* function onEdit(editedBool) */
  },

  getInitialState: function() {
    return { value: this.props.value };
  },
  
  componentWillReceiveProps: function(newProps) {
    this.setState({value: newProps.value})
  },
  
  onChange: function(e) {
    var val = e.target.value;
    this.setState({value: val});
    if (this.props.onEdit != null) {
      this.props.onEdit(this.isEdited(), val);
    }
  },
  
  isEdited: function() {
    if (this.props.initialValue != null) {
      return this.props.initialValue != this.state.value;
    } else {
      return this.props.value != this.state.value;
    }
  },
  
  dispatchChangeIfNeeded: function() {
    if (this.props.onChange != null && this.isEdited()) {
      this.props.onChange(this.state.value);
    }
  },
  
  onBlur: function(e) {
    this.dispatchChangeIfNeeded();
  },
  
  onKeyPress: function(evt) {
    if (evt.which == 13) {
      this.dispatchChangeIfNeeded();
      evt.preventDefault();
    }
  },
  
  
  
  render: function() {
    var elementType = this.props.element || 'input';
    var props = Object.assign({}, this.props, this.state, {onChange:this.onChange, onKeyPress:this.onKeyPress, onBlur:this.onBlur});
    return h(elementType, props, this.children);
  }
});

export { SmartInput };
export default SmartInput;
