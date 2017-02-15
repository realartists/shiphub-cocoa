var webpack = require('webpack');
var path = require('path');
var HtmlWebpackPlugin = require('html-webpack-plugin');
var HtmlWebpackPluginConfig = new HtmlWebpackPlugin({
  template: __dirname + "/app/index.html",
  filename: "index.html",
  inject: "body"
});

var debugMode = JSON.stringify(JSON.parse(process.env.DEBUG || 'false'));

var definePlugin = new webpack.DefinePlugin({
  __DEBUG__: debugMode
});

module.exports = {
  entry: [
    './app/index.js'
  ],
  output: {
    path: __dirname + "/dist",
    filename: "index_bundle.js"
  },
  module: {
    preLoaders: [
        { test: /\.json$/, loader: 'json'},
    ],
    loaders: [
      { test: /.*?IssueWeb.*?\.js$/, include: path.join(__dirname, "../IssueWeb/app"), loader: "babel-loader", query: {compact: !debugMode} },
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
  plugins: [HtmlWebpackPluginConfig, definePlugin]
}
