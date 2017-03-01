import React, { createElement as h } from 'react'

var AddCommentFooter = React.createClass({
  render: function() {
    var isNewIssue = this.props.isNewIssue;
    var canSave = this.props.canSave;
    
    var contents = [];
    
    if (!this.props.previewing) {
      contents.push(h('a', {
        key:'markdown', 
        className:'markdown-mark formattingHelpButton', 
        target:"_blank", 
        href:"https://guides.github.com/features/mastering-markdown/", 
        title:"Open Markdown Formatting Guide"
      }));
    }
    
    if (this.props.canClose) {
      contents.push(h('div', {
        key:'close', 
        title: '⌘⇧⏎',
        className:'Clickable addCommentButton addCommentCloseButton', 
        onClick:this.props.onClose}, 
        'Close Issue'
      ));
    } else if (this.props.editingExisting||this.props.canCancel) {
      contents.push(h('div', {
        key:'cancel', 
        className:'Clickable addCommentButton addCommentCloseButton', 
        onClick:this.props.onCancel}, 
        'Cancel'
      ));
    }
    
    if (canSave) {
      contents.push(h('div', {
        key:'save', 
        title: '⌘S',
        className:'Clickable addCommentButton addCommentSaveButton', 
        onClick:this.props.onSave}, 
        (this.props.editingExisting ? 'Update' : (isNewIssue ? 'Save' : 'Comment'))
      ));
    } else {
      contents.push(h('div', {
        key:'save', 
        className:'Clickable addCommentButton addCommentSaveButton addCommentSaveButtonDisabled'}, 
        (this.props.editingExisting ? 'Update' : (isNewIssue ? 'Save' : 'Comment'))
      ));
    }
    
    return h('div', {className:'commentFooter'}, contents);
  }
});

export default AddCommentFooter;
