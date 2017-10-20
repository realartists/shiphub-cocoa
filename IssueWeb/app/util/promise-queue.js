import BBPromise from 'util/bbpromise.js'

var promiseQueues = {};

function runQueue(queue) {
//   console.log("runQueue", queue);
  if (queue.length == 0) return;
  var job = queue[0];
  
  var task = job.task;
  var resolve = job.resolve;
  var reject = job.reject;
  
  task().then(() => {
    queue.shift();
    resolve(...arguments);
    runQueue(queue);
  }).catch(() => {
    queue.shift();
    reject(...arguments);
    runQueue(queue);
  });
}

/* 
  Run a task that returns a BBPromise on queue.
*/
export function promiseQueue(queueName, task) {
  var queue;
  if (queueName in promiseQueues) {
    queue = promiseQueues[queueName];
  } else {
    promiseQueues[queueName] = queue = [];
  }
  
  return new BBPromise((resolve, reject) => {
    queue.push({task, resolve, reject});
    
    if (queue.length == 1) {
      runQueue(queue);
    }
  });
}
