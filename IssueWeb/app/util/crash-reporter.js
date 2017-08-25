import rg4js from 'raygun4js';

if (__DEBUG__) {
  rg4js('apiKey', 'Win/NOKN7rXlqXoWiRKmrw==');
} else {
  rg4js('apiKey', 'D44HWYe8zJo99KHgPXDbJw==');
}

var beforeSend = function(payload) {
  var stacktrace = payload.Details.Error.StackTrace;

  var normalizeFilename = function(filename) {
    var indexOfRoot = filename.indexOf("IssueWeb");
    return `file://${__BUILD_ID__}${filename.substring(indexOfRoot)}`;
  }

  for(var i = 0 ; i < stacktrace.length; i++) {
    var stackline = stacktrace[i];
    stackline.FileName = normalizeFilename(stackline.FileName);
  }
  return payload;
}

rg4js('onBeforeSend', beforeSend);
rg4js('enableCrashReporting', true);

window.configureRaygun = function(user, version, extra) {
  console.log("configureRaygun", user, version, extra);
  rg4js('setUser', user);
  rg4js('setVersion', version);
  rg4js('withCustomData', extra);
}
