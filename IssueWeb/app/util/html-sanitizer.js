// Based on ideas from https://www.quaxio.com/html_white_listed_sanitizer/
class HTMLSanitizer {
  constructor() {
    this.nodeBlacklist = new Set(["HTML", "HEAD", "BODY", "SCRIPT", "STYLE"]);
    this.doc = document.implementation.createHTMLDocument();
  }
  
  sanitize(html) {
    try {
      var el = this.doc.createElement('div');
      el.innerHTML = html;
    
      return this.filter(el).innerHTML;
    } catch (ex) {
      console.error("HTMLSanitizer error", ex);
      return this.doc.createTextNode(html).innerHTML;
    }
  }
  
  hasBlacklistedAttributes(node) {
    for (var i = 0; i < node.attributes.length; i++) {
      if (node.attributes.item(i).name.toLowerCase().startsWith("on")) {
        return true;
      }
    }
  }
  
  filter(node) {
    if (node.nodeName == '#text') {
    // text nodes are always safe
    return node;
    }
    if (node.nodeName == '#comment') {
      // always strip comments
      return this.doc.createTextNode('');
    }
    if (this.nodeBlacklist.has(node.nodeName) || this.hasBlacklistedAttributes(node)) {
      return this.doc.createTextNode(node.outerHTML);
    }
    
    for (var i = 0; i < node.childNodes.length; i++) {
      var originalChild = node.childNodes[i];
      var filteredChild = this.filter(originalChild);
      if (filteredChild !== originalChild) {
        node.replaceChild(filteredChild, originalChild);
      }
    }
    
    return node;
  }
}

export default HTMLSanitizer;
