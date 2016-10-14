# Makefile called by Xcode to build DiffWeb dist

# Note that commands that rely on this path need to be non-simple (e.g. have an && or a ; in them)
# See: http://stackoverflow.com/questions/21708839/problems-setting-path-in-makefile
export PATH := $(PATH):/usr/local/bin

CMD = npm run production
INSTALL_MODS = npm install

INPUT = $(shell find . -path ./node_modules -prune -o -path ./dist -prune -o \( -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.html' \) -print)

dist/index_bundle.js: node_modules/.uptodate $(INPUT)
	$(CMD) && echo

node_modules/.uptodate: npm-shrinkwrap.json
	$(INSTALL_MODS) && touch node_modules/.uptodate

clean:
	rm -r dist/*
