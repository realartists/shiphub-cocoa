function shortenCommittish(committish) {
  if (committish.length == 40) {
    return committish.slice(0, 7);
  }
  return committish;
}

export function githubLinkify(owner, repo, text) {
  var issues = /(^|[^\&<>])([\w+\-\d]+)?\/?([\w+\-\d]+)?#(\d+)/g;
  var mentions = /(^| )@([\w+\-\d]+)/g;
  var hashes = /(^|[^\w\d])([\w+\-\d]+\/)?([\w+\-\d]+@)?([A-Fa-f0-9]{7,40})(?=[^g-zG-Z]|$)/g;

  try {
    return text.replace(issues, function(g0, g1, g2, g3, g4) {
      if (g2 == undefined && g3 == undefined) {
        return g1 + '<a class="issueLink" href="https://github.com/' + owner + '/' + repo + '/issues/' + g4 + '">' + g0.substr(g1.length) + "</a>";
      } else if (g3 == undefined) {
        return g1 + '<a class="issueLink" href="https://github.com/' + owner + '/' + g2 + '/issues/' + g4 + '">' + g0.substr(g1.length) + "</a>";
      } else {
        return g1 + '<a class="issueLink" href="https://github.com/' + g2 + '/' + g3 + '/issues/' + g4 + '">' + g0.substr(g1.length) + "</a>";
      }
    }).replace(mentions, function(g0, g1, g2) {
      return g1 + '<a class="mentionLink" href="https://github.com/' + g2 + '">' + g0.substr(g1.length) + "</a>";
    }).replace(hashes, function(g0, g1, g2, g3, g4) {
      if (g2 && g3) {
        return g1 + '<a class="shaLink" href="https://github.com/' + g2.slice(0, -1) + '/' + g3.slice(0, -1) + '/commit/' + g4 + '">' + g2 + g3 + shortenCommittish(g4) + "</a>";
      } else if (g3) {
        return g1 + '<a class="shaLink" href="https://github.com/' + owner + '/' + repo + '/commit/' + g4 + '">' + g3 + shortenCommittish(g4) + "</a>";
      } else {
        return g1 + '<a class="shaLink" href="https://github.com/' + owner + '/' + repo + '/commit/' + g4 + '">' + shortenCommittish(g4) + "</a>";
      }
    });
  } catch (ex) {
    console.log(ex);
    console.log("error parsing " + text);
    return text;
  }
}
