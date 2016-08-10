import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import SmartInput from './smart-input.js'
import { htmlEncode } from 'js-htmlencode'

import 'typeahead.js'

var Completer = React.createClass({
  propTypes: {
    value: React.PropTypes.string,
    placeholder: React.PropTypes.string,
    newItem: React.PropTypes.string, /* e.g "New Milestone" */
    onChange: React.PropTypes.func,
    onEnter: React.PropTypes.func,
    onAddNew: React.PropTypes.func, /* function onAddNew(initialNewItemName) */
    matcher: React.PropTypes.func.isRequired, /* function matcher(text, callback) => ( callback([match1, match2, ...]) ) */
    suggestionFormatter: React.PropTypes.func /* function formatter(value) => "html" */
  },
  
  render: function() {
    var props = Object.assign({}, this.props, {
      className: 'typeahead',
      ref: 'typeInput',
      onBlur: this.onBlur
    });
  
    return h(SmartInput, props);
  },
  
  focus: function() {
    if (this.refs.typeInput) {
      this.refs.typeInput.focus();
    }
  },
  
  blur: function() {
    if (this.refs.typeInput) {
      this.refs.typeInput.blur();
    }
  },
  
  hasFocus: function() {
    if (this.refs.typeInput) {
      this.refs.typeInput.hasFocus();
    }
  },
  
  isEdited: function() {
    return this.refs.typeInput != null && this.refs.typeInput.isEdited();
  },
  
  onSelect: function(evt, obj) {
    if (this.props.newItem) {
      var content = obj.content;
      if (obj.newItem) {
        this.handlingNew = true;
        this.blur();
        if (this.props.onAddNew) {
          setTimeout(() => {
            this.props.onAddNew(content);
          }, 1);
        } else {
          console.error(`New item ${content} selected, but no onAddNew hander for completer`);
        }
      } else if (this.props.onEnter) {
        this.props.onEnter();
      }
    } else {
      if (this.props.onEnter) {
        this.props.onEnter();
      }
    }
  },
  
  updateTypeahead: function() {
    var el = ReactDOM.findDOMNode(this.refs.typeInput);
    var baseMatcher = this.props.matcher;
    
    var matcherPlusInitial = (text, cb) => {
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
    this.matcher = matcherPlusInitial;
    
    var display, matcher, formatter;
    display = matcher = formatter = null;
    if (this.props.newItem) {
      display = (x) => x.content;
      matcher = (text, cb) => {
        matcherPlusInitial(text, (results) => {
          var trimmedText = text.trim();
          var lowerText = trimmedText.toLowerCase();
          var exactResults = results.filter((r) => r.toLowerCase() == lowerText);
          var augmentedResults = results.map((r) => { return { content: r } });
          if (exactResults.length == 0) {
            augmentedResults.push({ newItem: true, content: trimmedText });
          }
          cb(augmentedResults);
        });
      };
      var newItemText = this.props.newItem;
      formatter = (value) => {
        var inner = "";
        if (value.newItem) {
          var renderedValue;
          if (value.content.length == 0) {
            renderedValue = `<span class="no-highlight">${newItemText}...</span>`;
          } else {
            renderedValue = `
              <span class="no-highlight">
                ${newItemText}: <span class="highlight">${htmlEncode(value.content)}</span>
              </span>`;
          }

          inner = `
            <i class="fa fa-plus" aria-hidden="true"></i>
            <span>${renderedValue}</span>`;
        } else {
          inner = htmlEncode(value.content);
        }
    
        return `<div class='tt-suggestion'>${inner}</div>`
      };
    } else {
      display = (x) => x;
      matcher = matcherPlusInitial;
    }
    
    var hadFocus = this.refs.typeInput.hasFocus();
    this.remounting = true;
    
    $(el).typeahead('destroy');
    $(el).off();

    var typeaheadDataOpts = {
      // Never limit the drop down - we don't want to risk that the "New
      // Label..." option at the end of the dropdown is stripped.  If we find
      // we do want a limit, we'll have to prune the list of options we send
      // to typeahead.js.
      limit: Number.MAX_VALUE,
      source: matcher,
      display: display
    };
    
    if (this.props.suggestionFormatter) {
      typeaheadDataOpts.templates = {
        suggestion: this.props.suggestionFormatter
      };
    } else if (formatter) {
      typeaheadDataOpts.templates = {
        suggestion: formatter
      };
    }
    
    var typeaheadConfigOpts = {
      hint: true,
      highlight: true,
      minLength: 0,
      autoselect: true,
    };
    
    $(el).typeahead(typeaheadConfigOpts, typeaheadDataOpts)
    
    $(el).on('typeahead:beforeautocomplete', () => {
      this.completeOrFail();
      return false;
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
    
    $(el).on('typeahead:select', (evt, obj) => {
      this.onSelect(evt, obj);
    });

    $(el).keypress((evt) => {
      if (evt.which == 13) {
        evt.preventDefault();
        this.completeOrFail(() => {
          if (this.props.onEnter) {
            this.props.onEnter();
          }
        });
      }
    });
    
    if (hadFocus) {
      this.refs.typeInput.focus();
      $(el).typeahead('open');
    }
    this.remounting = false;
  },
  
  componentDidUpdate: function() {
    this.updateTypeahead();
  },
  
  componentDidMount: function() {
    this.updateTypeahead();
  },
  
  completeOrFail: function(completion) {
    if (!this.matcher || !this.refs.typeInput) {
      completion();
      return;
    }

    var el = ReactDOM.findDOMNode(this.refs.typeInput);
    var val = $(el).typeahead('val') || "";
    this.matcher(val, (matches) => {
      var newVal = "";
      if (val.length == 0 || matches.length == 0) {
        newVal = "";
      } else {
        // prefer an exact match if there is one
        // realartists/shiphub-cocoa#160 Cannot assign issues to users whose logins are substrings of other users
        var exact = matches.filter((x) => x === val);        
        if (exact.length != 0) {
          newVal = exact[0];
        } else {
          newVal = matches[0];
        }
      }
      $(el).typeahead('val', newVal);
      this.refs.typeInput.setState({value: newVal}, completion);
    });
  },
  
  value: function() {
    if (this.refs.typeInput) {
      return this.refs.typeInput.state.value;
    } else {
      return this.props.value;
    }
  },
  
  clear: function() {
    if (this.refs.typeInput) {
      var el = ReactDOM.findDOMNode(this.refs.typeInput);
      $(el).typeahead('val', "");
      this.refs.typeInput.setState({value: ""});
    }
  },
  
  onBlur: function() {
    if (this.remounting || this.handlingNew) return;  
    this.completeOrFail(() => {
      this.refs.typeInput.dispatchChangeIfNeeded(false);
    });
    return true;
  },
  
  containsCompleteValue: function() {
    var el = ReactDOM.findDOMNode(this.refs.typeInput);
    var val = $(el).typeahead('val') || "";
    
    if (val === "") return false;
    var allMatches = [];
    var match = this.matcher(val, (matches) => {
      allMatches.push(...matches);
    });
    
    return allMatches.length == 1 && allMatches[0] === val;
  }
});

Completer.SubstrMatcher = function(options) {
  return function(text, cb) {
    var r = new RegExp(text, 'i');
    var x = options.filter((o) => (r.test(o)));
    x.sort((a, b) => a.localeCompare(b));
    cb(x);
  }
}

export default Completer;