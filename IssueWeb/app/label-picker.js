import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import { htmlEncode } from 'js-htmlencode'
import Completer from './completer.js'


var LabelPicker = React.createClass({
  propTypes: {
    onAddExistingLabel: React.PropTypes.func, /* function onAdd(label) { ... } */
    labels: React.PropTypes.array,
    allLabelNames: React.PropTypes.array,
  },
  
  addLabel: function() {
    var completer = this.refs.completer;
    if (!completer || !(completer.refs.typeInput)) return;
    
    var el = ReactDOM.findDOMNode(completer.refs.typeInput);
    var val = el.value;
    
    if (val === "") {
      // Ignore the empty strings.  I think these come right after you select
      // a label.
      return;
    }

    const newLabelWithInputRegex = /^New Label: (.*?)$/;
    const existingLabelMatch = this.props.labels.find(
      (label) => (label.name === val));

    var promise;
    if (val === "New Label...") {
      promise = this.props.onNewLabel(null);
    } else if (newLabelWithInputRegex.test(val)) {
      var newLabel = val.match(newLabelWithInputRegex)[1];
      promise = this.props.onNewLabel(newLabel);
    } else if (existingLabelMatch) {
      promise = this.props.onAddExistingLabel(existingLabelMatch)
    } else {
      throw new Error("Unexpected label value: " + val);
    }

    $(el).typeahead('val', "");
    $(el).focus();

    return promise;
  },
  
  onChange: function() {
    if (!this.handlingMouseDown && !this.hasFocus() && this.isEdited()) {
      this.refs.completer.clear();
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
    const matcher = function(text, cb) {
      const labelNames = this.props.labels
        .map((l) => l.name)
        .sort((a, b) => (a.toLowerCase().localeCompare(b.toLowerCase())));

      var r = new RegExp(text, 'i');
      var results = labelNames.filter((o) => (r.test(o)));

      if (text.trim().length > 0 && labelNames.indexOf(text) == -1) {
        // To appear when a string is entered that does not match
        // existing label names.
        results.push("New Label: " + text.trim());
      } else if (text.trim().length == 0) {
        // To appear only when the label drop down is first expanded.
        // Will disappear if someone starts typing a string.
        results.push("New Label...");
      }

      cb(results);
    }.bind(this);

    var labelLookup = {};
    this.props.labels.forEach((l) => { labelLookup[l.name] = l })
    
    var formatter = (value) => {
      var inner = "";
      var l = labelLookup[value];
      if (l != null) {
        inner = `<div class='LabelSuggestionColor' style='background-color: #${l.color}'></div><span class='tt-label-suggestion-text'>${htmlEncode(value)}</span>`
      } else {
        var match = value.match(/^New Label: (.*?)$/);
        var renderedValue;
        if (match) {
          renderedValue = `
            <span class="no-highlight">
              New Label: <span class="highlight">${match[1]}</span>
            </span>`;
        } else {
          renderedValue = `<span class="no-highlight">New Label...</span>`;
        }

        inner = `
          <i class="NewLabelSuggestionIcon fa fa-plus" aria-hidden="true"></i>
          <span class='tt-label-suggestion-text'>
            ${renderedValue}
          </span>`;
      }
      
      return `<div class='tt-suggestion tt-label-suggestion'>${inner}</div>`
    }
  
    return h('span', {className:"LabelPicker"},
      h(Completer, {
        value: "",
        ref: 'completer',
        placeholder: "Add Label",
        onEnter: this.addLabel,
        onChange: this.onChange,
        matcher: matcher,
        suggestionFormatter: formatter
      }),
      h('div', {style: { display: 'inline-block' } },
        h('i', {className: 'fa fa-plus-circle AddLabel Clickable',
          onClick: this.addLabel,
          onMouseDown: this.onPlusMouseDown,
          onMouseUp: this.onPlusMouseUp
        })
      )
    );
  }
});

export default LabelPicker;
