import DiffRow from './diff-row.js'

import AttributedString from './attributed-string.js'
import h from 'hyperscript'

class TrailerRow extends DiffRow {
  constructor(mode) {
    super();
    
    console.log("TrailerRow: ", mode);
    
    var gutterLeft = h('td', { className:'gutter gutter-left' });
    var gutterRight = h('td', { className:'gutter gutter-right' });
    
    if (mode === 'unified') {
      var blank = h('td', {style:{height:'100%'}});
      var row = h('tr', {style:{height:'100%', backgroundColor: 'white'}}, gutterLeft, gutterRight, blank);
    } else {
      var left = h('td', {style:{height:'100%'}});
      var right = h('td', {style:{height:'100%'}});
      var row = h('tr', {style:{height:'100%', backgroundColor: 'white'}}, gutterLeft, left, gutterRight, right);
    }
    this.node = row;
  }
  updateHighlight() { }
}

export default TrailerRow;
