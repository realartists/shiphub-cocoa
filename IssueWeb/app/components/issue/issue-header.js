import React, { createElement as h } from 'react'

var HeaderLabel = React.createClass({
  propTypes: { title: React.PropTypes.string },
  
  render: function() {
    return h('span', {className:'HeaderLabel'}, this.props.title + ": ");
  }
});

var HeaderSeparator = React.createClass({
  render: function() {
    return h('div', {className:'HeaderSeparator', style:this.props.style});
  }
});

export { HeaderLabel, HeaderSeparator };
