IssueWeb is built using npm + webpack via a Run Script step in Xcode.

### Using live reloading

As an option, you can have ShipHub point itself at a webpack-dev-server
instance.  As you edit IssueWeb files, the issue windows will auto
reload to show changes.

To enable --

1. Choose Product -> Scheme -> Edit Scheme.

2. Switch to Arguments tab.

3. Uncheck the line for UseWebpackDevServer under the 'Arguments Passed
on Launch' section.  If the line is missing, add the following:
`-UseWebpackDevServer YES`

4. Start the webpack dev server --

  ```
cd IssueWeb
npm run dev-server-inline
  ```

5. Build + Launch ShipHub.


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

