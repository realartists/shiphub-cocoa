#  Ship: A GitHub Issues and Pull Requests App for macOS

Ship was formerly a commercial GitHub Issues and Pull Requests client distributed by [Real Artists, Inc](https://www.realartists.com). The product is now discontinued, and the source code as well as the previously private issue tracker are now publicly available here.

While Real Artists has no intention of developing the product further, and therefore we will not be reviewing or accepting pull requests, anyone so inclined is welcome to fork the repository or copy any parts of the code.

## Building

```
xcodebuild -configuration Release -scheme Ship
```

## Running

To actually use Ship, you'll need to have an installation of [Ship Server](https://github.com/realartists/shiphub-server) up and running somewhere. From the Ship sign in window, you'll need to click on "Choose Server ..." at the lower left and enter the hostname for your Ship Server instance.
