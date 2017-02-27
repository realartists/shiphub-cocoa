import htmlEscape from 'html-escape';

class Range {
  constructor(location, length) {
    this.location = location;
    this.length = length;
  }
  
  maxRange() {
    return this.location + this.length;
  }
  
  contains(i) {
    return i >= this.location && i < this.location + this.length;
  }
}

/* visitor = function(textNode, previousValue) */
function reduceText(root, accum, visitor) {
  for (var i = 0; i < root.childNodes.length; i++) {
    var n = root.childNodes[i];
    if (n.nodeType == Node.TEXT_NODE) {
      accum = visitor(n, accum);
    } else {
      reduceText(n, accum, visitor);
    }
  }
  return accum;
}

class AttributedString {
  constructor(str) {
    this.string = str;
    this.attrs = [];
  }
  
  static fromHTML(html) {
    var el = document.createElement('span');
    el.innerHTML = html;
    return reduceText(el, new AttributedString(""), (textNode, accum) => {
      var n = textNode.parentNode;
      var classes = [];
      while (n != el) {
        var cls = n.className.split(' ');
        classes = classes.concat(cls);
        n = n.parentNode;
      }
      var astr = new AttributedString(textNode.textContent);
      astr.addAttributes(new Range(0, astr.string.length), classes);
      accum.append(astr);
      return accum;
    });
  }
  
  /*  range is a Range object
      attrs is an array of css classNames
  */
  addAttributes(range, attrs) {
    this.attrs.push({range, attrs});
  }
  
  append(str /* either AttributedString or string */) {
    if (typeof(str) == 'string') str = new AttributedString(str);
    
    var offset = this.string.length;
    this.string += str.string;
    this.attrs = this.attrs.concat(str.attrs.map((attr) => {
      return { 
        range: new Range(attr.range.location + offset, attr.range.length),
        attrs: attr.attrs
      };
    }));
  }
  
  /* visitor = function(substr, classNames, previousValue) */
  reduce(visitor, initial) {
    if (this.attrs.length == 0) {
      return visitor(this.string, [], initial);
    }
    
    var accum = initial;
    
    var active = [];
    var offset = 0;
    for (var i = 0; i <= this.string.length; i++) {
    
      var next = active.slice();
      next = next.filter((attr) => attr.range.contains(i));
      var changedActive = next.length != active.length;
      
      var more = this.attrs.filter((attr) => attr.range.location == i && attr.range.length != 0);
      next = next.concat(more);
      var changedActive = changedActive || more.length > 0;
            
      if (changedActive) {
        if (offset != i) {
          var substr = this.string.slice(offset, i);
          var classNames = active.map((a) => a.attrs).reduce((p, c) => p.concat(c), []);
          accum = visitor(substr, classNames, accum);
        }
        offset = i;
        active = next;
      }
    }
        
    return accum;
  }
  
  toHTML() {
    return this.reduce((substr, classNames, previousValue) => {
      var cls = classNames.join(" ");
      if (cls.length > 0) {
        return previousValue + "<span class='" + cls + "'>" + htmlEscape(substr) + '</span>';
      } else {
        return previousValue + htmlEscape(substr);
      }
    }, "")
  }
  
  toPlainText() {
    return this.reduce((substr, classNames, previousValue) => {
      return previousValue + substr;
    }, "")
  }
}

AttributedString.Range = Range;
export default AttributedString;

