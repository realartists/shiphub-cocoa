import EmojiList from './emoji-list.js'

export function emojify(text, opts) {
  var size = 20;
  if (opts && opts.size) {
    size = opts.size;
  }
  try {
    return text.replace(/:([\w\+\-_\d]+?):/g, function(p0, p1) {
      var code = EmojiList[p1];
      if (code == undefined) return p0;
      if (code.indexOf("https") !== -1) {
        return "<img src='" + code + "' class='emoji' alt='" + p0 + "' title='" + p0 + "' width=" + size + " height=" + size + ">";
      } else {
        return String.fromCodePoint(...code.split('-').map(p => parseInt(p, 16)));
      }
    });
  } catch (ex) {
    console.log(ex);
    return text;
  }
}

export function emojifyReaction(content) {
  // why would the reaction values match their emoji names? it would make too much sense.
  if (content === "hooray") content = "tada";
  if (content === "laugh") content = "grinning";
  return emojify(":" + content + ":");
}

emojify.dictionary = EmojiList;

