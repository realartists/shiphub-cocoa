import json
import re
import requests

pathRE = re.compile(r'.*?/unicode/([A-Fa-f0-9\-]+).png.*')
emojis = requests.get("https://api.github.com/emojis").json()

overrides = {
  "heart": "2764-fe0f"
}

def normalizeEmoji(name, emoji):
  # https://assets-cdn.github.com/images/icons/emoji/unicode/1f44d.png?v7
  if name in overrides:
    return overrides[name]
  match = pathRE.match(emoji)
  if match:
    return match.group(1)
  else:
    return emoji

mappedEmojis = { name : normalizeEmoji(name, url) for name, url in emojis.items() }

print("""
var EmojiList = %s;

export default EmojiList;
""" % json.dumps(mappedEmojis, indent=2))
