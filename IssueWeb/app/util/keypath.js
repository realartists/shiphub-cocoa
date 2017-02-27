var keypath = function(obj, path) {
  if (!obj) return null;
  if (!path) return obj;
  var pattern = /(\w[\w\d]+)\[(\d+)\]/;
  path = path.split('.')
  for (var i = 0; i < path.length; i++) {
    var prop = path[i];
    var match = prop.match(pattern);
    var idx = null;
    if (match) {
      prop = match[1];
      idx = parseInt(match[2]);
    }
    if (obj != null && typeof(obj) === 'object' && prop in obj) {
      obj = obj[prop];
      if (idx !== null) {
        if (Array.isArray(obj)) {
          obj = obj[idx];
        } else {
          return null;
        }
      }
    } else {
      return null;
    }
  }
  return obj;
}

var setKeypath = function(obj, path, value) {
  if (!obj) return;
  if (!path) return;
  path = path.split('.')
  for (var i = 0; i < path.length - 1; i++) {
    var prop = path[i];
    if (obj != null && prop in obj) {
      obj = obj[prop];
    } else {
      return;
    }
  }
  
  var prop = path[path.length-1];
  obj[prop] = value;
}

export { keypath, setKeypath }
