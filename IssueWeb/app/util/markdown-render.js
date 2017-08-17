import marked from './marked.min.js'
import hljs from 'highlight.js'
import { emojify, emojifyReaction } from './emojify.js'
import { githubLinkify } from './github-linkify.js'

var markedRenderer = new marked.Renderer();

markedRenderer.defaultListItem = markedRenderer.listitem;
markedRenderer.listitem = function(text) {
  if (/\[[ x]\]/.test(text)) {
    text = text.replace(/\[ \]/, '<input type="checkbox">');
    text = text.replace(/\[x\]/, '<input type="checkbox" checked>');
    return "<li class='taskItem'>" + text + "</li>";
  } else {
    return this.defaultListItem(text);
  }
  return result;
}

markedRenderer.list = function(body, ordered) {
  if (body.indexOf('<input type="checkbox"') != -1) {
    return "<ul class='taskList'>" + body + "</ul>";
  } else {
    if (ordered) {
      return "<ol>" + body + "</ol>";
    } else {
      return "<ul>" + body + "</ul>";
    }
  }
}

var snippetRE = /https:\/\/github.com\/([^\/\s]+\/[^\/\s]+)\/blob\/([A-Fa-f0-9]{40})\/(.*?)#L(\d+)(?:\-L(\d+))?/;

function renderCodeSnippet(match) {
  var el = document.createElement('div');
  el.className = 'codeSnippet';
  el.setAttribute('data-repo', match[1]);
  el.setAttribute('data-sha', match[2]);
  el.setAttribute('data-path', match[3]);
  el.setAttribute('data-start-line', match[4]);
  el.setAttribute('data-end-line', match[5]||match[4]);
  return el.outerHTML;
}

markedRenderer.defaultLink = markedRenderer.link;
markedRenderer.link = function(href, title, text) {
  var codeSnippetMatch = href.match(snippetRE);
  if (codeSnippetMatch) {
    return renderCodeSnippet(codeSnippetMatch);
  }
  var lowerHref = href.toLowerCase();
  if (lowerHref.indexOf("?") != -1) {
    lowerHref = lowerHref.substring(0, lowerHref.indexOf("?"));
  }
  if (lowerHref.endsWith('.mov') || lowerHref.endsWith('.mp4')) {
    if (href.indexOf("://www.dropbox.com") != -1 && href.endsWith("?dl=0")) {
      href = href.replace("?dl=0", "?dl=1");
    }
    return `<video src="${href}" title="${title}" controls></video>`;
  } else {
    return markedRenderer.defaultLink(href, title, text);
  }
};

markedRenderer.defaultImage = markedRenderer.image;
markedRenderer.image = function(href, title, text) {
  var lowerHref = href.toLowerCase();
  if (lowerHref.indexOf("http://") == 0) {
    // turn it into a link
    return markedRenderer.defaultLink(href, title || href || "image", text || href || "image");
  } else {
    return markedRenderer.defaultImage(href, title, text);
  }
};

var _repoOwner = "";
var _repoName = "";

markedRenderer.text = function(text) {
  return emojify(githubLinkify(_repoOwner, _repoName, text));
}

var langMapping = {
  'objective-c': 'objc',
  'c#' : 'cs'
}

var markdownOpts = {
  renderer: markedRenderer,
  gfm: true,
  tables: true,
  breaks: true,
  pedantic: false,
  sanitize: false,
  smartLists: true,
  smartypants: false,
  highlight: function (code, lang) {
    if (lang) {
      lang = langMapping[lang.toLowerCase()] || lang;
      return hljs.highlightAuto(code, [lang]).value;
    } else {
      return code;
    }
  }
};

function markdownRender(markdown, repoOwner, repoName) {
  _repoOwner = repoOwner
  _repoName = repoName;
  return marked(markdown, markdownOpts);
}

export { markdownRender };
