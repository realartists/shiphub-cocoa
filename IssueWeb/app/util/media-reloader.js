function imageFailedToLoad(img) {
  return img.complete && img.naturalWidth == 0;
}

function reloadImage(img) {
  var src = img.src;
  if (src == false) return;
  img.src = "";
  setTimeout(function() {
    img.src = src;
  }, 0);
}

function videoFailedToLoad(vid) {
  return vid.error != null;
}

function reloadVideo(vid) {
  var src = vid.src;
  if (src == false) return;
  vid.src = "";
  setTimeout(function() {
    vid.src = src;
  }, 0);
}

var reloadFailedMediaEvent = 'reloadFailedMedia';

function reloadFailedMedia() {
  var imgs = document.getElementsByTagName('img');
  var vids = document.getElementsByTagName('video');
  
  for (var i = 0; i < imgs.length; i++) {
    var img = imgs[i];
    if (imageFailedToLoad(img)) {
      reloadImage(img);
    }
  }
  
  for (var i = 0; i < vids.length; i++) {
    var vid = vids[i];
    if (videoFailedToLoad(vid)) {
      reloadVideo(vid);
    }
  }
  
  var event = new Event(reloadFailedMediaEvent);
  document.dispatchEvent(event);
}

// called by app
window.reloadFailedMedia = reloadFailedMedia;

export { reloadFailedMediaEvent };
