/* Adapted from https://github.com/component/file-picker */

/**
 * Opens a file picker dialog.
 *
 * @param {Object} options (optional)
 * @param {Function} fn callback function
 * @api public
 */

export default function FilePicker(opts, fn) {
  if ('function' == typeof opts) {
    fn = opts;
    opts = {};
  }
  opts = opts || {};
  
  var form = document.createElement('form');
  form.style.margin = '0px';
  form.innerHTML = '<input type="file" style="top: -1000px; position: absolute" aria-hidden="true">';
  document.body.appendChild(form);
  var input = form.childNodes[0];

  // multiple files support
  input.multiple = !!opts.multiple;

  // directory support
  input.webkitdirectory = input.mozdirectory = input.directory = !!opts.directory;

  // accepted file types support
  if (null == opts.accept) {
    delete input.accept;
  } else if (opts.accept.join) {
    // got an array
    input.accept = opts.accept.join(',');
  } else if (opts.accept) {
    // got a regular string
    input.accept = opts.accept;
  }

  // listen to change event
  function onchange(e) {
    fn(input.files, e, input);
    
    // cleanup form.
    setTimeout(function() {
      document.body.removeChild(form);
    }, 0);
  }

  input.onchange = onchange;

  // reset the form
  form.reset();

  // trigger input dialog
  input.click();
}
