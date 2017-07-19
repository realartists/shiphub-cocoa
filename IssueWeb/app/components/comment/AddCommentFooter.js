import React, { createElement as h } from 'react'
import IssueLock from 'components/issue/lock.js'

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
    
    if (this.props.canLock) {
      contents.push(h('span', { key: 'lock-span', className:'addCommentLock' },
        h(IssueLock, { issue: this.props.issue })
      ));
    }
    
    if (this.props.canClose) {
      contents.push(h('button', {
        type:'button',
        key:'close', 
        title: '⌘⇧⏎',
        className:'ActionButton addCommentButton addCommentCloseButton', 
        onClick:this.props.onClose}, 
        this.props.closeButtonTitle||'Close Issue'
      ));
    } else if (this.props.editingExisting||this.props.canCancel) {
      contents.push(h('button', {
        type:'button',
        key:'cancel', 
        className:'ActionButton addCommentButton addCommentCloseButton', 
        onClick:this.props.onCancel}, 
        'Cancel'
      ));
    }
    
    if (canSave) {
      contents.push(h('button', {
        type:'button',
        key:'save', 
        title: '⌘S',
        className:'ActionButton addCommentButton addCommentSaveButton', 
        onClick:this.props.onSave}, 
        (this.props.editingExisting ? 'Update' : (isNewIssue ? 'Save' : 'Comment'))
      ));
    } else {
      contents.push(h('button', {
        type:'button',
        key:'save', 
        disabled:true,
        className:'ActionButton addCommentButton addCommentSaveButton addCommentSaveButtonDisabled'}, 
        (this.props.editingExisting ? 'Update' : (isNewIssue ? 'Save' : 'Comment'))
      ));
    }
    
    return h('div', {className:'commentFooter'}, contents);
  }
});

export default AddCommentFooter;
