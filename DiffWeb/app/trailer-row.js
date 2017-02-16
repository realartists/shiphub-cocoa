import DiffRow from './diff-row.js'
import AttributedString from './attributed-string.js'

import React, { createElement as h } from 'react'

class TrailerRow extends DiffRow {
  render() {
    var gutterLeft = h('td', { className:'gutter gutter-left' });
    var gutterRight = h('td', { className:'gutter gutter-right' });
    
    if (this.props.mode === 'unified') {
      var blank = h('td', {style:{height:'100%'}});
      var row = h('tr', {style:{height:'100%', backgroundColor: 'white'}}, gutterLeft, gutterRight, blank);
    } else {
      var left = h('td', {style:{height:'100%'}});
      var right = h('td', {style:{height:'100%'}});
      var row = h('tr', {style:{height:'100%', backgroundColor: 'white'}}, gutterLeft, left, gutterRight, right);
    }
    
    return row;
  }
}

export default TrailerRow;
