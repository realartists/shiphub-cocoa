import codeHighlighter from 'util/code-highlighter.js'

onmessage = function(event) {
  var result = codeHighlighter(event.data);
  postMessage(result);
}
