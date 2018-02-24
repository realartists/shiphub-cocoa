import sys
import json
import re
import getopt
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

optlist, args = getopt.getopt(sys.argv[1:], "cj")

js = True
objc = False

for opt in optlist:
  if opt[0] == '-c':
    js = False
    objc = True
  elif opt[1] == '-j':
    js = True
    objc = False


if js:
  print("""
  var EmojiList = %s;

  export default EmojiList;
  """ % json.dumps(mappedEmojis, indent=2))
else: # objc
  print("@{")
  for emoji, path in mappedEmojis.items():
    uniescaped = path
    if not path.startswith("https://"):
      parts = path.split("-")
      uniescaped = ""
      for part in parts:
        num = int(part, 16)
        if num < 0xFF:
          uniescaped += chr(num)
        elif num < 0xFFFF:
          uniescaped += "\\u%04x" % num
        else:
          uniescaped += "\\U%08x" % num
    print("    @\"%s\": @\"%s\"," % (emoji, uniescaped))
  print("};")
  