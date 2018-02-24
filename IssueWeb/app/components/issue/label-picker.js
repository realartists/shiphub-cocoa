import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import { htmlEncode } from 'js-htmlencode'
import { emojify } from 'util/emojify.js'
import Completer from './completer.js'


var LabelPicker = React.createClass({
  propTypes: {
    onAddExistingLabel: React.PropTypes.func, /* function onAdd(label) { ... } */
    availableLabels: React.PropTypes.array,
    chosenLabels: React.PropTypes.array,
  },
  
  onNewLabel: function(initialName) {
    return this.props.onNewLabel(initialName)
  },
  
  addLabel: function() {
    var completer = this.refs.completer;
    if (!completer) return;
    
    var val = completer.domValue();
    
    if (val === "") {
      return;
    }

    const existingLabelMatch = this.props.availableLabels.find(
      (label) => (label.name === val));

    var promise;
    if (existingLabelMatch) {
      promise = this.props.onAddExistingLabel(existingLabelMatch)
      completer.focus();
    }

    completer.typeahead('val', "");

    return promise;
  },
  
  onChange: function() {
    if (!this.handlingMouseDown && !this.hasFocus() && this.isEdited()) {
      this.refs.completer.clear();
    }
  },
  
  onPlusClick: function() {
    var completer = this.refs.completer;
    if (!completer) return;
    var val = completer.domValue();
    
    if (val === "") {
      this.focus();
    } else {
      this.addLabel();
    }
  },
  
  onPlusMouseDown: function() {
    this.handlingMouseDown = true;
  },
  
  onPlusMouseUp: function() {
    this.handlingMouseDown = false;
  },
  
  focus: function() {
    if (this.refs.completer) {
      this.refs.completer.focus();
    }
  },
  
  blur: function() {
    if (this.refs.completer) {
      this.refs.completer.focus();
    }
  },
  
  hasFocus: function() {
    if (this.refs.completer) {
      return this.refs.completer.hasFocus();
    } else {
      return false;
    }
  },
  
  isEdited: function() {
    if (this.refs.completer) {
      return this.refs.completer.isEdited();
    } else {
      return false;
    }
  },
  
  containsCompleteValue: function() {
    if (this.refs.completer) {
      return this.refs.completer.containsCompleteValue();
    } else {
      return false;
    }
  },
  
  render: function() {
    var matcher = Completer.SubstrMatcher(this.props.availableLabels.map((l) => l.name));
    var labelLookup = {};
    this.props.availableLabels.forEach((l) => { labelLookup[l.name] = l })
    
    var formatter = (value) => {
      var inner = "";
      
      if (value.newItem) {
        var renderedValue;
        if (value.content.length == 0) {
          renderedValue = `<span class="no-highlight">New Label...</span>`;
        } else {
          renderedValue = `
            <span class="no-highlight">
              New Label: <span class="highlight">${value.content}</span>
            </span>`;
        }

        inner = `
          <i class="NewLabelSuggestionIcon fa fa-plus" aria-hidden="true"></i>
          <span class='tt-label-suggestion-text'>
            ${renderedValue}
          </span>`;
      } else {
        var l = labelLookup[value.content];
        inner = `<div class='LabelSuggestionColor' style='background-color: #${l.color}'></div><span class='tt-label-suggestion-text'>${emojify(htmlEncode(l.name), {size:13})}</span>`
      }
      
      return `<div class='tt-suggestion tt-label-suggestion'>${inner}</div>`
    };
    
    var prevValue = "";
    var completer = this.refs.completer;
    if (completer) {
      prevValue = completer.domValue() || "";
    }
  
    return h('span', {className:"LabelPicker"},
      h(Completer, {
        value: prevValue,
        ref: 'completer',
        placeholder: "Add Label",
        onEnter: this.addLabel,
        onChange: this.onChange,
        newItem: "New Label",
        onAddNew: this.onNewLabel,
        matcher: matcher,
        suggestionFormatter: formatter,
        readOnly: this.props.readOnly
      }),
      this.props.readOnly ? null :
      h('div', {style: { display: 'inline-block' } },
        h('i', {className: 'fa fa-plus-circle AddLabel Clickable',
          onClick: this.onPlusClick,
          onMouseDown: this.onPlusMouseDown,
          onMouseUp: this.onPlusMouseUp
        })
      )
    );
  }
});

export default LabelPicker;
