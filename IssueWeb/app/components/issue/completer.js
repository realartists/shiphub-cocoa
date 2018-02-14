import React, { createElement as h } from 'react'
import ReactDOM from 'react-dom'
import { htmlEncode } from 'js-htmlencode'
import escapeStringForRegex from 'util/escape-regex.js'

import 'ext/typeahead.js/typeahead.jquery.js'



var Completer = React.createClass({
  propTypes: {
    value: React.PropTypes.string,
    readOnly: React.PropTypes.bool,
    placeholder: React.PropTypes.string,
    newItem: React.PropTypes.string, /* e.g "New Milestone" */
    onChange: React.PropTypes.func,
    onEnter: React.PropTypes.func,
    onAddNew: React.PropTypes.func, /* function onAddNew(initialNewItemName) */
    matcher: React.PropTypes.func.isRequired, /* function matcher(text, callback) => ( callback([match1, match2, ...]) ) */
    suggestionFormatter: React.PropTypes.func /* function formatter(value) => "html" */
  },
        
  render: function() {
    return h('span', {'ref':'span', style:{width: '100%'}});
  },
  
  focus: function() {
    var input = this._input();
    if (input) input.focus();
  },
  
  blur: function() {
    var input = this._input();
    if (input) input.blur();
  },
  
  hasFocus: function() {
    var input = this._input();
    return input == document.activeElement;
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
    var span = ReactDOM.findDOMNode(this.refs.span);

    function findTypeahead(node) {
      if (node.tagName === 'INPUT' && node.className.indexOf('tt-input') != -1) {
        return node;
      }
      for (var i = 0; i < node.children.length; i++) {
        var found = findTypeahead(node.children[i]);
        if (found) return found;
      }
      return null;
    }    
    
    var hadTypeahead = true;
    var input = findTypeahead(span);
    if (!input) {
      input = document.createElement('input');
      span.appendChild(input);
      input.className = 'typeahead';
      input.onChange = (evt) => this.onChange(evt);
      input.placeholder = this.props.placeholder;
      input.value = this.props.value;
      this._inputElement = input;
      hadTypeahead = false;
    }
    
    var baseMatcher = this.props.matcher;
    
    var matcherPlusInitial = (text, cb) => {
      if (this.opening) {
        /* 
          If opening for the first time, show all possible choices, but put the
          current choice (if any) first
        */
        baseMatcher("", function(results) {
          // move text to front of results
          var re = new RegExp("^" + escapeStringForRegex(text) + "$", 'i');
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
        
    if (this.props.readOnly) {
      if (hadTypeahead) {
        $(input).typeahead('destroy');
        $(input).off();
      }
      return;
    }

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
    
    this.typeaheadDataOpts = typeaheadDataOpts;
        
    
    if (!hadTypeahead) {
      var dataThunks = {
        limit: typeaheadDataOpts.limit,
        source: (text, cb) => this._data_source(text, cb),
        display: (x) => this._data_display(x),
        templates: {
          suggestion: (x) => this._data_formatter(x)
        }
      };
      
      var typeaheadConfigOpts = {
        hint: true,
        highlight: true,
        minLength: 0,
        autoselect: true,
      };
    
      $(input).typeahead(typeaheadConfigOpts, dataThunks)
    
      $(input).on('typeahead:beforeautocomplete', () => {
        this.completeOrFail();
        return false;
      });
    
      $(input).on('typeahead:beforeopen', () => {
        var wasOpening = this.opening;
        this.opening = true;
        if (!wasOpening) {
          this.updateMenu();
        }
      });
      
      $(input).on('typeahead:close', () => {
        this.opening = false;
      });
    
      // work around a bug where WebKit doesn't draw the text caret
      // when tabbing to the field and nothing is in it.
      $(input).on('focus', function() {
        setTimeout(function() {
          if (input.value.length == 0) {
            input.setSelectionRange(0, input.value.length);
          }
        }, 0);
      });
    
      $(input).on('typeahead:select', (evt, obj) => {
        this.onSelect(evt, obj);
      });
    
      $(input).on('blur', (evt) => this.onBlur(evt));

      $(input).keypress((evt) => {
        this.opening = false;
        if (evt.which == 13) {
          evt.preventDefault();
          this.completeOrFail(() => {
            if (this.props.onEnter) {
              this.props.onEnter();
            }
          });
        }
      });
    
      this.remounting = false;
    } else {
      this.typeahead('val', this.props.value);
      this.updateMenu();
    }
  },
  
  componentDidUpdate: function() {
    this.updateTypeahead();
  },
  
  componentDidMount: function() {
    this.updateTypeahead();
  },
  
  componentWillUnmount: function() {
    if (this._inputElement) {
      $(this._inputElement).typeahead('destroy');
      $(this._inputElement).off();
      delete this._inputElement;
    }
  },
  
  updateMenu() {
    this.typeahead('updateMenu');
  },
  
  _data_source: function(text, cb) {
    this.cb = cb;
    return this.typeaheadDataOpts.source(text, cb);
  },
  
  _data_display: function(x) {
    return this.typeaheadDataOpts.display(x);
  },
  
  _data_formatter: function(value) {
    if (this.typeaheadDataOpts.templates) {
      return this.typeaheadDataOpts.templates.suggestion(value);
    } else {
      return `<div class='tt-suggestion'>${htmlEncode(value.content||value)}</div>`;
    }
  },
    
  completeOrFail: function(completion) {
    if (!this.matcher || !this._input()) {
      if (completion) completion();
      return;
    }

    var val = this.typeahead('val') || "";
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
      this.typeahead('val', newVal);
      if (completion) completion();
    });
  },
  
  _input: function() {
    return this._inputElement;
  },
  
  domValue: function() {
    return this.typeahead('val');
  },
  
  typeahead: function() {
    var input = this._input();
    if (input) return $(input).typeahead(...arguments);
  },
  
  value: function() {
    return this.domValue();
  },
    
  clear: function() {
    this.typeahead('val', '');
  },
  
  revert: function() {
    this.typeahead('val', this.props.value||'');
  },
  
  onBlur: function() {
    if (this.remounting || this.handlingNew) return; 
    this.completeOrFail(() => {
      this.dispatchChangeIfNeeded(false);
    });
    if (this.props.onBlur) {
      this.props.onBlur();
    }
    return true;
  },
  
  isEdited: function() {
    if (this.props.readOnly) return false;
    return (this.props.value || "") != (this.domValue() || "");
  },
  
  dispatchChangeIfNeeded: function(goNext) {
    if (this.props.onChange != null && this.isEdited()) {
      this.props.onChange(this.domValue(), goNext);
    }
  },
  
  containsCompleteValue: function() {
    var val = this.typeahead('val') || "";
    
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
    var r = new RegExp(escapeStringForRegex(text), 'i');
    var x = options.filter((o) => (r.test(o)));
    x.sort((a, b) => a.localeCompare(b));
    cb(x);
  }
}

export default Completer;
