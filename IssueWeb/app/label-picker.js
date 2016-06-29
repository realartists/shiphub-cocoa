import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import { htmlEncode } from 'js-htmlencode'
import Completer from './completer.js'


var LabelPicker = React.createClass({
  propTypes: {
    onAddExistingLabel: React.PropTypes.func, /* function onAdd(label) { ... } */
    availableLabels: React.PropTypes.array,
    chosenLabels: React.PropTypes.array,
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

    const existingLabelMatch = this.props.availableLabels.find(
      (label) => (label.name === val));

    var promise;
    if (existingLabelMatch) {
      promise = this.props.onAddExistingLabel(existingLabelMatch)
      $(el).focus();
    } else if (val === "New Label...") {
      $(el).blur();
      promise = this.props.onNewLabel(null);
    } else {
      $(el).blur();
      promise = this.props.onNewLabel(val);
    }

    $(el).typeahead('val', "");

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
      const availableLabelNames = this.props.availableLabels
        .map((l) => l.name)
        .sort((a, b) => (a.toLowerCase().localeCompare(b.toLowerCase())));

      var r = new RegExp(text, 'i');
      var results = availableLabelNames.filter((o) => (r.test(o)));
      const textMatchesChosenLabel = this.props.chosenLabels.find(
        (o) => (o.name === text)) != null;

      if (text.trim().length > 0 &&
          availableLabelNames.indexOf(text) == -1 &&
          !textMatchesChosenLabel) {
        // To appear when a string is entered that does not match
        // existing label names.  This will be reformatted to show
        // as "New Label: <input>"
        results.push(text.trim());
      } else if (text.trim().length == 0) {
        // To appear only when the label drop down is first expanded.
        // Will disappear if someone starts typing a string.
        results.push("New Label...");
      }

      cb(results);
    }.bind(this);

    var labelLookup = {};
    this.props.availableLabels.forEach((l) => { labelLookup[l.name] = l })
    
    var formatter = (value) => {
      var inner = "";
      var l = labelLookup[value];
      if (l != null) {
        inner = `<div class='LabelSuggestionColor' style='background-color: #${l.color}'></div><span class='tt-label-suggestion-text'>${htmlEncode(value)}</span>`
      } else {
        var renderedValue;
        if (value === "New Label...") {
          renderedValue = `<span class="no-highlight">New Label...</span>`;
        } else {
          renderedValue = `
            <span class="no-highlight">
              New Label: <span class="highlight">${value}</span>
            </span>`;
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
