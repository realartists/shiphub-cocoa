// Abstract super class for diff table rows

class DiffRow {
  codeColContents(code) {
    if (!code || code.length == 0) return "<pre>\xA0\n</pre>";
    return "<pre>"+code+"\n</pre>";
  }  
}

export default DiffRow;

