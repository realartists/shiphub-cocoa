import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import SmartInput from './smart-input.js'

import 'typeahead.js'

var Completer = React.createClass({
  propTypes: {
    value: React.PropTypes.string,
    placeholder: React.PropTypes.string,
    onChange: React.PropTypes.func,
    onEnter: React.PropTypes.func,
    matcher: React.PropTypes.func.isRequired, /* function matcher(text, callback) => ( callback([match1, match2, ...]) ) */
    suggestionFormatter: React.PropTypes.func /* function formatter(value) => "html" */
  },
  
  render: function() {
    var props = Object.assign({}, this.props, {
      className: 'typeahead',
      ref: 'typeInput'
    });
  
    return h(SmartInput, props);
  },
  
  updateTypeahead: function() {
    var el = ReactDOM.findDOMNode(this.refs.typeInput);
    var baseMatcher = this.props.matcher;
    
    var matcher = (text, cb) => {
      if (this.opening) {
        /* 
          If opening for the first time, show all possible choices, but put the
          current choice (if any) first
        */
        this.opening = false;
        baseMatcher("", function(results) {
          // move text to front of results
          var re = new RegExp("^" + text + "$", 'i');
          var ft = results.filter((r) => {
            return !re.test(r);
          });
          if (ft.length < results.length) {
            ft = [text, ...ft];
          }
          cb(ft);
        });
      } else {
        baseMatcher(text, cb);
      }
    };
    
    $(el).typeahead('destroy');
    
    var typeaheadDataOpts = {
      limit: 20,
      source: matcher
    };
    
    if (this.props.suggestionFormatter) {
      typeaheadDataOpts.templates = {
        suggestion: this.props.suggestionFormatter
      };
    }
    
    var typeaheadConfigOpts = {
      hint: true,
      highlight: true,
      minLength: 0,
      autoselect: true,
    };
    
    $(el).typeahead(typeaheadConfigOpts, typeaheadDataOpts)
    
    // avoid choosing the first option if we're empty
    // (allow empty to be chosen)
    $(el).on('typeahead:beforeautocomplete', function() {
      return (el.value !== '');
    });
    
    $(el).on('typeahead:beforeopen', () => {
      this.opening = true;
    });
    
    // work around a bug where WebKit doesn't draw the text caret
    // when tabbing to the field and nothing is in it.
    $(el).focus(function() {
      setTimeout(function() {
        if (el.value.length == 0) {
          el.setSelectionRange(0, el.value.length);
        }
      }, 0);
    });
    
    if (this.props.onEnter) {
      $(el).on('typeahead:select', (evt, obj) => {
        this.props.onEnter();
      });
    }
    
    var completeOrFail = () => {
      var val = el.value;
      matcher(val, (matches) => {
        if (val.length == 0 || matches.length == 0) {
          el.value = "";
        } else {
          var first = matches[0];
          el.value = first;
        }
      });
    }
    
    $(el).blur(completeOrFail);
    
    $(el).keypress((evt) => {
      if (evt.which == 13) {
        completeOrFail();
        evt.preventDefault();
        
        if (this.props.onEnter) {
          this.props.onEnter();
        }
      }
    });
  },
  
  componentDidUpdate: function() {
    this.updateTypeahead();
  },
  
  componentDidMount: function() {
    this.updateTypeahead();
  }
});

Completer.PrefixMatcher = function(options) {
  return function(text, cb) {
    var r = new RegExp("^" + text, 'i');
    cb(options.filter((o) => (r.test(o))));
  }
}

Completer.SubstrMatcher = function(options) {
  return function(text, cb) {
    var r = new RegExp(text, 'i');
    cb(options.filter((o) => (r.test(o))));
  }
}

export default Completer;