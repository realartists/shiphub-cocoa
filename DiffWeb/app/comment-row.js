import './comment.css'

import DiffRow from './diff-row.js'
import MiniMap from './minimap.js'

import React, { createElement as h } from 'react'
import hljs from 'highlight.js'

import { emojify, emojifyReaction } from '../../IssueWeb/app/emojify.js'
import { githubLinkify } from '../../IssueWeb/app/github_linkify.js'
import marked from '../../IssueWeb/app/marked.min.js'

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

markedRenderer.defaultLink = markedRenderer.link;
markedRenderer.link = function(href, title, text) {
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

class Comment extends React.Component {
  render() {
    var parts = issueIdentifier.split('/#');
    markedRenderer.text = function(text) {
      return emojify(githubLinkify(parts[0], parts[1], text));
    }
    var commentBody = h('div', {
      className:'commentBody',
      dangerouslySetInnerHTML: marked(this.props.comment.body, markdownOpts)
    });
    var commentDiv = h('div', {className:'comment'}, commentBody);
    return commentDiv;
  }
}

class CommentRow extends DiffRow {
  render() {
    var comments = this.props.comments.map((c) => h(Comment, {comment:c, issueIdentifier:this.props.issueIdentifier}));
    var commentBlock = h('div', {className:'commentBlock'}, 
      h('div', {className:'commentShadowTop'}),
      ...comments
    );
    var td = h('td', {colSpan:""+colspan, className:'comment-cell'}, commentBlock);
    var row = h('tr', {}, td);
    
    return row;
  }
}

export default CommentRow;
