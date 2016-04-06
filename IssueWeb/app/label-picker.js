import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import { htmlEncode } from 'js-htmlencode'
import Completer from './completer.js'


var LabelPicker = React.createClass({
  propTypes: {
    onAdd: React.PropTypes.func, /* function onAdd(label) { ... } */
    labels: React.PropTypes.array
  },
  
  addLabel: function() {
    var completer = this.refs.completer;
    var el = ReactDOM.findDOMNode(completer.refs.typeInput);
    var val = el.value;
    
    if (val.length > 0) {
      completer.props.matcher(val, (results) => {
        if (results.length >= 1) {
          var result = results[0];
        
          for (var i = 0; i < this.props.labels.length; i++) {
            if (this.props.labels[i].name == result) {
              if (this.props.onAdd) {
                this.props.onAdd(this.props.labels[i]);
              }
              break;
            }
          }
        }
      });
    }
        
    $(el).typeahead('val', "");
    $(el).focus();
  },
  
  render: function() {
    var matcher = Completer.SubstrMatcher(
      this.props.labels.map((l) => l.name)
    );
    
    var labelLookup = {};
    this.props.labels.forEach((l) => { labelLookup[l.name] = l })
    
    var formatter = (value) => {
      var inner = "";
      var l = labelLookup[value];
      if (l != null) {
        inner = `<div class='LabelSuggestionColor' style='background-color: #${l.color}'></div><span class='tt-label-suggestion-text'>${htmlEncode(value)}</span>`
      } else {
        inner `<span class='tt-label-suggestion-text'>${htmlEncode(value)}</span>`;
      }
      
      return `<div class='tt-suggestion tt-label-suggestion'>${inner}</div>`
    }
  
    return h('span', {className:"LabelPicker"},
      h(Completer, {
        value: "",
        ref: 'completer',
        placeholder: "Add Label",
        onEnter: this.addLabel,
        matcher: matcher,
        suggestionFormatter: formatter
      }),
      h('div', {style: { display: 'inline-block' } },
        h('i', {className: 'fa fa-plus-circle AddLabel Clickable',
          onClick: this.addLabel
        })
      )
    );
  }
});

export default LabelPicker;
