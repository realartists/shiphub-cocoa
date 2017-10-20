import Promise from 'bluebird';
import { SendCrashReport } from './crash-reporter.js'

Promise.config({
  longStackTraces: true,
  warnings: true
});

// NOTE: event name is all lower case as per DOM convention
window.addEventListener("unhandledrejection", function(e) {
    // NOTE: e.preventDefault() must be manually called to prevent the default
    // action which is currently to log the stack trace to console.warn
    e.preventDefault();
    // NOTE: parameters are properties of the event detail property
    var reason = e.detail.reason;
    var promise = e.detail.promise;
    
    console.error(reason);
    SendCrashReport(reason);
    if (window.onerror) {
      window.onerror(reason);
    }
});

var BBPromise = Promise;

export default BBPromise;
