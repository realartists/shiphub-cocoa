// Abstract super class for diff table rows

import React, { createElement as h } from 'react'

class DiffRow extends React.Component {
  codeColContents(code) {
    if (!code || code.length == 0) return "<pre>\xA0\n</pre>";
    return "<pre>"+code+"\n</pre>";
  }
}

export default DiffRow;

