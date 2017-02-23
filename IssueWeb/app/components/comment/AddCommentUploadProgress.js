import React, { createElement as h } from 'react'

var AddCommentUploadProgress = React.createClass({
  render: function() {
    return h('div', {className:'commentFooter'},
      h('span', {className:'commentUploadingLabel'}, "Uploading files "),
      h('i', {className:'fa fa-circle-o-notch fa-spin fa-3x fa-fw margin-bottom'})
    );
  }
});

export default AddCommentUploadProgress;
