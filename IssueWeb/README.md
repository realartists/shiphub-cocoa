IssueWeb is built using npm + webpack via a Run Script step in Xcode.

### Updating npm dependencies

To keep the build reproducible, we're using `npm shrinkwrap` to freeze
all node deps to fixed versions.

If you need to update the dependencies, do the following.

```
cd IssueWeb
rm npm-shrinkwrap.json
# optionally edit packages.json to bump any specific packages.
npm install
npm shrinkwrap
# commit the new npm-shrinkwrap.json file.
```

