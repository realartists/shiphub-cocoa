var pendingPasteHandlers = [];
var pasteHandle = 0;

function pasteHelper(pasteboard, pasteText, uploadsStarted, uploadFinished, uploadFailed) {
  var handle = ++pasteHandle;
  pendingPasteHandlers[handle] = { pasteText, uploadsStarted, uploadFinished, uploadFailed };
  window.inAppPasteHelper.postMessage({handle, pasteboard});
}

function pasteCallback(handle, type, data) {
  var handlers = pendingPasteHandlers[handle];
  switch (type) {
    case 'pasteText':
      handlers.pasteText(data);
      break;
    case 'uploadsStarted':
      handlers.uploadsStarted(data);
      break;
    case 'uploadFinished':
      handlers.uploadFinished(data.placeholder, data.link);
      break;
    case 'uploadFailed':
      handlers.uploadFailed(data.placeholder, data.err);
      break;
    case 'completed':
      delete handlers[handle];
      break;
    default:
      console.log("Unknown pasteCallback type", type);
      break;
  }
}

window.pasteCallback = pasteCallback;

export { pasteHelper };
