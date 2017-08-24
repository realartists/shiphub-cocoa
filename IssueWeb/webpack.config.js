var webpack = require('webpack');
var path = require('path');
var HtmlWebpackPlugin = require('html-webpack-plugin');
var HtmlWebpackPluginConfig = new HtmlWebpackPlugin({
  template: __dirname + "/app/index.html",
  filename: "index.html",
  inject: "head"
});

var debugMode = JSON.stringify(JSON.parse(process.env.DEBUG || 'false'));
var buildId = JSON.stringify(process.env.BUILD_ID || 'DEBUG_BUILD');

var definePlugin = new webpack.DefinePlugin({
  __DEBUG__: debugMode,
  __BUILD_ID__: buildId
});

module.exports = {
  resolve: {
    root: [
      path.resolve('./app'),
      path.resolve('./image')
    ]
  },
  entry: {
    issue: './app/issue.js',
    diff: './app/diff.js'
  },
  output: {
    path: __dirname + "/dist",
    filename: "[name].js"
  },
  devtool: 'source-map',
  module: {
    preLoaders: [
        { test: /\.json$/, loader: 'json'},
    ],
    loaders: [
      { test: /\.js$/, include: __dirname + "/app", loader: "babel-loader", query: {compact: !debugMode} },
      { test: /\.jpe?g$|\.gif$|\.png$/, loader: "file" },
      { test: /\.css$/, loader: 'style!css?sourceMap' },
      { test: /\.woff(\?v=\d+\.\d+\.\d+)?$/, loader: "url?limit=10000&mimetype=application/font-woff" }, 
      { test: /\.woff2(\?v=\d+\.\d+\.\d+)?$/, loader: "url?limit=10000&mimetype=application/font-woff" },
      { test: /\.ttf(\?v=\d+\.\d+\.\d+)?$/, loader: "url?limit=10000&mimetype=application/octet-stream" },
      { test: /\.eot(\?v=\d+\.\d+\.\d+)?$/, loader: "file" },
      { test: /\.svg(\?v=\d+\.\d+\.\d+)?$/, loader: "url?limit=10000&mimetype=image/svg+xml" }
    ]
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: __dirname + "/app/issue.html",
      filename: "issue.html",
      inject: "head",
      chunks: ['issue']
    }), 
    new HtmlWebpackPlugin({
      template: __dirname + "/app/diff.html",
      filename: "diff.html",
      inject: "head",
      chunks: ['diff']
    }),
    definePlugin
  ]
}
