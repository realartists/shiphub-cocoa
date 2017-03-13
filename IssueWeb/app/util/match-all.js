export default function matchAll(re, str) {
  var matches = [];
  var match;
  while ((match = re.exec(str)) !== null) {
    matches.push(match);
  }
  return matches;
}
