# Package

version       = "0.11.0"
author        = "Wesley Kerfoot"
description   = "Turn Your Tweets Into Blog Posts"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["tweetlog"]

# Dependencies
requires "nim >= 1.0"
requires "https://github.com/dom96/jester"
requires "https://github.com/pragmagic/karax"
requires "https://github.com/GULPF/timezones"
requires "https://github.com/cheatfate/nimcrypto"
requires "https://github.com/yglukhov/nim-jwt"
requires "https://github.com/snus-kin/twitter.nim"

task bookmark, "Builds the minified bookmarklet":
  "echo -n 'javascript:' > ./bookmarklet.min.js".exec
  "uglifyjs bookmarklet.js >> ./bookmarklet.min.js".exec
