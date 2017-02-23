import React, { createElement as h } from 'react'
import { emojify, emojifyReaction } from '../../emojify.js'

var AddReactionOption = React.createClass({
  render: function() {
    return h('div', {className:'addReactionOption Clickable', onClick:this.props.onClick},
      h('span', {className:'addReactionOptionContent'}, emojifyReaction(this.props.reaction))
    );
  }
});

var AddReactionOptions = React.createClass({
  propTypes: {
    onEnd: React.PropTypes.func
  },
  
  onAdd: function(reaction) {
    if (this.props.onEnd) {
      this.props.onEnd();
    }
    if (this.props.onAdd) {
      this.props.onAdd(reaction);
    }
  },
  
  render: function() {
    var reactions = ["+1", "-1", "laugh", "confused", "heart", "hooray"];
    
    var buttons = reactions.map((r) => h(AddReactionOption, {key:r, reaction:r, onClick:()=>{this.onAdd(r);}}));
    buttons.push(h('i', {key:"close", className:'fa fa-times addReactionClose Clickable', onClick:this.props.onEnd}));
  
    return h('span', {className:'addReactionOptions'}, buttons);
  }
});

var AddReactionButton = React.createClass({
  render: function() {
    var button = h('i', Object.assign({}, this.props, {className:'fa fa-smile-o addReactionIcon'}));
    return button;
  }
});

var CommentControls = React.createClass({
  propTypes: {
    comment: React.PropTypes.object.isRequired,
    first: React.PropTypes.bool,
    editing: React.PropTypes.bool,
    hasContents: React.PropTypes.bool,
    previewing: React.PropTypes.bool,
    needsSave : React.PropTypes.func,
    togglePreview: React.PropTypes.func,
    attachFiles: React.PropTypes.func,
    beginEditing: React.PropTypes.func,
    cancelEditing: React.PropTypes.func,
    deleteComment: React.PropTypes.func,
    addReaction: React.PropTypes.func
  },
  
  getInitialState: function() {
    return {
      confirmingDelete: false,
      confirmingCancelEditing: false,
      addingReaction: false
    }
  },
  
  componentWillReceiveProps: function(newProps) {
    if (!newProps.editing) {
      this.setState({}); // cancel all confirmations
    }
  },
  
  confirmDelete: function() {
    this.setState({confirmingDelete: true});
  },
  
  cancelDelete: function() {
    this.setState({confirmingDelete: false});
  },
  
  performDelete: function() {
    this.setState({confirmingDelete: false});
    if (this.props.deleteComment) {
      this.props.deleteComment();
    }
  },

  confirmCancelEditing: function() {
    if (this.props.needsSave()) {
      this.setState({confirmingCancelEditing: true});
    } else {
      this.performCancelEditing();
    }
  },

  performCancelEditing: function() {
    this.setState({confirmingCancelEditing: false});
    if (this.props.cancelEditing) {
      this.props.cancelEditing();
    }
  },

  abortCancelEditing: function() {
    this.setState({confirmingCancelEditing: false});
  },
  
  toggleReactionOptions: function() {
    this.setState({addingReaction: !this.state.addingReaction});
  },
  
  render: function() {
    var buttons = [];
    if (this.props.editing) {
      if (this.state.confirmingCancelEditing) {
          buttons.push(h('span', {key:'confirm', className:'confirmCommentDelete'}, 
            " ",
            h('span', {key:'discard', className:'confirmDeleteControl Clickable', onClick:this.performCancelEditing}, 'Discard Changes'),
            " | ",
            h('span', {key:'cancel', className:'confirmDeleteControl Clickable', onClick:this.abortCancelEditing}, 'Save Changes')
          ));
      } else {
        if (this.props.previewing) {
          buttons.push(h('i', {key:"eye-slash", className:'fa fa-eye-slash', title:"Toggle Preview", onClick:this.props.togglePreview}));
        } else {
          buttons.push(h('i', {key:"paperclip", className:'fa fa-paperclip fa-flip-horizontal', title:"Attach Files", onClick:this.props.attachFiles}));
          if (this.props.hasContents) {
            buttons.push(h('i', {key:"eye", className:'fa fa-eye', title:"Toggle Preview", onClick:this.props.togglePreview}));
          }
        }
        buttons.push(h('i', {key:"edit", className:'fa fa-pencil-square', onClick:this.confirmCancelEditing}));
      }
    } else {
      if (this.state.confirmingDelete) {
        buttons.push(h('span', {key:'confirm', className:'confirmCommentDelete'}, 
          "Really delete this comment? ",
          h('span', {key:'no', className:'confirmDeleteControl Clickable', onClick:this.cancelDelete}, 'No'),
          " ",
          h('span', {key:'yes', className:'confirmDeleteControl Clickable', onClick:this.performDelete}, 'Yes')
        ));
      } else if (this.state.addingReaction) {
        buttons.push(h(AddReactionOptions, {key:"reactionOptions", onEnd:this.toggleReactionOptions, onAdd:this.props.addReaction}));
      } else {     
        buttons.push(h(AddReactionButton, {key:"addReaction", title: "Add Reaction", onClick:this.toggleReactionOptions})); 
        buttons.push(h('i', {key:"edit", className:'fa fa-pencil', onClick:this.props.beginEditing}));
        if (!this.props.first) {
          buttons.push(h('i', {key:"trash", className:'fa fa-trash-o', onClick:this.confirmDelete}));
        }
      }
    }
    return h('div', {className:'commentControls'}, buttons);
  }
});

export default CommentControls;
