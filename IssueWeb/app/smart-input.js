import React from 'react'
import h from './h.js'

var SmartInput = React.createClass({
  getInitialState: function() {
    return { value: this.props.value };
  },
  
  componentWillReceiveProps: function(newProps) {
    this.setState({value: newProps.value})
  },
  
  onChange: function(e) {
    this.setState({value: e.target.value});
    if (this.props.onChange != null) {
      this.props.onChange(this.state.value);
    }
  },
  
  render: function() {
    var elementType = this.props.element || 'input';
    var props = Object.assign({}, this.props, this.state, {onChange:this.onChange});
    return h(elementType, props, this.children);
  }
});

export { SmartInput };
export default SmartInput;
