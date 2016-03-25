export function githubLinkify(owner, repo, text) {
  var issues = /(^|[^\&<>])([\w+\-\d]+)?\/?([\w+\-\d]+)?#(\d+)/g;
  var mentions = /(^|[^<>])@([\w+\-\d]+)/g;

  try {
    return text.replace(issues, function(g0, g1, g2, g3, g4) {
      if (g2 == undefined && g3 == undefined) {
        return g1 + '<a class="issueLink" href="https://github.com/' + owner + '/' + repo + '/issues/' + g4 + '">' + g0 + "</a>";
      } else if (g2 == undefined) {
        return g1 + '<a class="issueLink" href="https://github.com/' + owner + '/' + g3 + '/issues/' + g4 + '">' + g0 + "</a>";
      } else {
        return g1 + '<a class="issueLink" href="https://github.com/' + g2 + '/' + g3 + '/issues/' + g4 + '">' + g0 + "</a>";
      }
    }).replace(mentions, function(g0, g1, g2) {
      return g1 + '<a class="mentionLink" href="https://github.com/' + g2 + '">' + g0 + "</a>";
    });
  } catch (ex) {
    console.log(ex);
    console.log("error parsing " + text);
    return text;
  }
}
