import React, { createElement as h } from 'react'
import AvatarIMG from 'components/AvatarIMG.js'

var AddCommentHeader = React.createClass({
  render: function() {
    var buttons = [];
    
    if (this.props.previewing) {
      buttons.push(h('i', {key:"eye-slash", className:'fa fa-eye-slash', title:"Toggle Preview (⌥⌘P)", onClick:this.props.togglePreview}));
    } else {
      buttons.push(h('i', {key:"paperclip", className:'fa fa-paperclip fa-flip-horizontal', title:"Attach Files", onClick:this.props.attachFiles}));
      if (this.props.hasContents) {
        buttons.push(h('i', {key:"eye", className:'fa fa-eye', title:"Toggle Preview (⌥⌘P)", onClick:this.props.togglePreview}));
      }
    }
  
    return h('div', {className:'commentHeader'},
      h(AvatarIMG, {user:this.props.me, size:32}),
      h('span', {className:'addCommentLabel'}, 'Add Comment'),
      h('div', {className:'commentControls'}, buttons)
    );
  }
});

export default AddCommentHeader;
