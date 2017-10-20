import React, { createElement as h } from 'react'
import BBPromise from 'util/bbpromise.js'
import codeHighlighter from 'util/code-highlighter.js'

import { reloadFailedMediaEvent } from 'util/media-reloader.js'

import "./CodeSnippet.css"

var snippetHandle = 0;
var snippetResults = [];
function loadSnippet(repoFullName, sha, path, startLine, endLine) {
  return new BBPromise((resolve, reject) => {
    if (window.loadCodeSnippet) {
      var handle = ++snippetHandle;
      snippetResults[handle] = resolve;
      window.loadCodeSnippet.postMessage({handle, repoFullName, sha, path, startLine, endLine});
    } else {
      reject("Code snippet loading unavailable");
    }
  });
}

window.loadCodeSnippetResult = function(data) {
  var handle = data.handle;
  var resolve = snippetResults[handle];
  delete snippetResults[handle];
  resolve(data);
}

class CodeSnippetHeader extends React.Component {
  render() {
    var repoName = this.props.repo.split("/")[1];
    var href = `https://github.com/${this.props.repo}/blob/${this.props.sha}/${this.props.path}#L${this.props.startLine}-L${this.props.endLine}`;
    return h('tr', {},
      h('th', {colSpan:2},
        h('a', {className:'CodeSnippetLink', href:href},
          h('span', {className:'CodeSnippetPath'}, `${repoName}/${this.props.path}`),
          h('span', {className:'CodeSnippetRef'}, `@${this.props.sha.substr(0, 7)}`)
        )
      )
    );
  }
}

class CodeSnippetLine extends React.Component {
  render() {
    var contents = this.props.line||"";
    if (!contents.endsWith('\n')) { 
      contents = contents + '\n';
    }
  
    var className = 'unified-codecol';

    return h('tr', {className:'CodeSnippetLine'},
      h('td', {className:'gutter'}, this.props.number),
      h('td', {className},
        h('pre', {dangerouslySetInnerHTML: { __html: contents } })
      )
    );
  }
}

class CodeSnippet extends React.Component {
  constructor(props) {
    super(props);
    
    this.state = {
      loading: true,
      error: false,
      snippet: null
    };
  }
  
  render() {
    var lines = [];
    if (this.state.loading) {
      lines.push("Loading code snippet ...");
    } else if (this.state.error) {
      lines.push("Failed to load snippet");
    } else {
      var { leftHighlighted } = codeHighlighter({
        leftText: this.state.snippet,
        rightText: "",
        filename: this.props.path
      });
      lines = leftHighlighted;
    }
    
    var body = [];
    for (var i = 0, j = this.props.startLine; j <= this.props.endLine; i++, j++) {
      body.push(h(CodeSnippetLine, {key:""+i, number:j, line:lines[i]}));
    }
  
    return h('table', {className:'CodeSnippetTable'},
      h('thead', {},
        h(CodeSnippetHeader, this.props)
      ),
      h('tbody', {}, body)
    );
  }
  
  performLoad() {
    loadSnippet(this.props.repo, 
                this.props.sha, 
                this.props.path, 
                this.props.startLine, 
                this.props.endLine
    ).then(result => {
      console.log(result);
      if (result.error) {
        this.setState({loading: false, error: true});
      } else {
        this.setState({loading: false, snippet: result.snippet});
      }
    }).catch(e => {
      console.log("snippet error", e);
      this.setState({loading: false, error: true});
    });
  }
  
  componentDidMount() {
    this.performLoad();
    if (!this.mediaReloadListener) {
      this.mediaReloadListener = () => {
        if (this.state.error) {
          console.log("Reloading failed snippet");
          this.setState({loading: true, error: false});
          this.performLoad();
        }
      }
      document.addEventListener(reloadFailedMediaEvent, this.mediaReloadListener);
    }
  }
  
  componentWillUnmount() {
    if (this.mediaReloadListener) {
      document.removeEventListener(reloadFailedMediaEvent, this.mediaReloadListener);
    }
  }
}

export default CodeSnippet;

