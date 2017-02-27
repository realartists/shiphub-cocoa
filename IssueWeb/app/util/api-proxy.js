var pendingAPIHandlers = [];
var apiHandle = 0;

// either performs the request directly or proxies it through the app
function api(url, opts) {
  if (window.inApp) {
    var handle = ++apiHandle;
    console.log("Making api call", handle, url, opts);
    return new Promise((resolve, reject) => {
      try {
        pendingAPIHandlers[handle] = {resolve, reject};
        window.postAppMessage({handle, url, opts});
      } catch (exc) {
        console.log(exc);
        reject(exc);
      }
    });
  } else {
    return fetch(url, opts).then(function(resp) {
      if (resp.status == 204) {
        return Promise.resolve(null); // no content
      } else {
        return resp.json();
      }
    });
  }
}

// used by the app to return an api call result
function apiCallback(handle, result, err) {
  console.log("Received apiCallback", handle, result, err);
  if (!(handle in pendingAPIHandlers)) {
    console.log("Received unknown apiCallback", handle, result, err);
    return;
  }
  
  var callbacks = pendingAPIHandlers[handle];
  delete pendingAPIHandlers[handle];
  
  if (err) {
    callbacks.reject(err);
  } else {
    callbacks.resolve(result);
  }
};

window.apiCallback = apiCallback;
export { api };
