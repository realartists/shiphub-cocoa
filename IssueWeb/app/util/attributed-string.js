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
        classes = cls.concat(classes);
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
  
  // turn off css classNames wherever they appear
  // classNames is an array of css classNames
  off(classNames) {
    var attrs = [];
    for (var i = 0; i < this.attrs.length; i++) {
      var origAttr = this.attrs[i];
      var newAttr = { range: new Range(origAttr.range.location, origAttr.range.length),
                      attrs: origAttr.attrs.filter((name) => !classNames.includes(name)) };
      if (newAttr.attrs.length > 0) {
        attrs.push(newAttr);
      }
    }
    
    function equalClasses(a, b) {
      if (a.length != b.length) return false;
      var sa = new Set(a);
      for (var i = 0; i < b.length; i++) {
        if (!sa.has(b[i])) return false;
      }
      return true;
    }

    attrs.sort((a, b) => {
      if (a.location < b.location) return -1;
      else if (a.location > b.location) return 1;
      else return 0;
    });

    var last = null;
    var simple = [];
    for (var i = 0; i < attrs.length; i++) {
      var cur = attrs[i];
      if (!last || (last.range.location + last.range.length) != cur.range.location || !equalClasses(last.attrs, cur.attrs)) {
        last = cur;
        simple.push(cur);
      } else {
        last.range.length += cur.range.length;
      }
    }
    
    this.attrs = simple;
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
    
      var next = active.filter((attr) => attr.range.contains(i));
      var changedActive = next.length != active.length;
      
      var more = this.attrs.filter((attr) => attr.range.location == i && attr.range.length != 0);
      next = next.concat(more);
      changedActive = changedActive || more.length > 0;
            
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
    
    if (offset < this.string.length) {
      var substr = this.string.slice(offset, this.string.length);
      var classNames = active.map((a) => a.attrs).reduce((p, c) => p.concat(c), []);
      accum = visitor(substr, classNames, accum);
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

if (__DEBUG__) {
  function assert(actual, expected, msg) {
    if (actual != expected) {
      throw "Test failed: " + msg + " expected: " + expected + " actual: " + actual;
    }
  }

  var a1HTML = "<span class='a'>a<span class='b'>ab</span></span>";
  var a1 = AttributedString.fromHTML(a1HTML)
  assert(a1.toHTML(), "<span class='a'>a</span><span class='a b'>ab</span>", "a1 parse");
  var a2 = AttributedString.fromHTML(a1.toHTML())
  assert(a1.toHTML(), a2.toHTML(), "a1 => a2");
  
  var a3 = new AttributedString("");
  a3.append(a2);
  a3.off(["b"])
  assert(a3.toHTML(), "<span class='a'>aab</span>", "turn off b");
}

AttributedString.Range = Range;
export default AttributedString;

