function appendAll(parent, x) {
  if (Array.isArray(x)) {
    for (var i = 0; i < x.length; i++) {
      appendAll(parent, x[i]);
    }
  } else {
    parent.appendChild(x);
  }
}

export default function h(nodeName, options, children) {
  var e = document.createElement(nodeName);
  if (options.style) {
    for (var k in options.style) {
      e.style[k] = options.style[k];
    }
  }
  if (options.className) {
    e.className = options.className;
  }
  for (var i = 2; i < arguments.length; i++) {
    appendAll(e, arguments[i]);
  }
  return e;
}
