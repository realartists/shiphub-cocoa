// Abstract super class for diff table rows

class DiffRow {
  codeColContents(code) {
    if (!code || code.length == 0) return "<pre>\xA0\n</pre>";
    if (code.endsWith("\n")) return "<pre>"+code+"</pre>";
    return "<pre>"+code+"\n</pre>";
  }
  
  configureGutterCol(gutter, lineNum, diffIdx, onclick) {
    var content = gutter.innerHTML = lineNum === undefined ? "" : ("" + (1+lineNum));
    if (diffIdx !== undefined) {
      gutter.classList.add('gutter-commentable');
      gutter.onclick = onclick;
      gutter.onmouseover = () => gutter.innerHTML = "+";
      gutter.onmouseleave = () => gutter.innerHTML = content;
    }
  }
}

export default DiffRow;

