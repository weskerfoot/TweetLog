# Package

version       = "0.11.0"
author        = "Wesley Kerfoot"
description   = "Turn Your Tweets Into Blog Posts"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["tweetlog"]

# Dependencies
requires "nim >= 1.0.9"
requires "https://github.com/dom96/jester"
requires "https://github.com/pragmagic/karax"

task bookmark, "Builds the minified bookmarklet":
  "echo -n 'javascript:' > ./bookmarklet.min.js".exec
  "uglifyjs --mangle --compress toplevel,sequences=false bookmarklet.js >> ./bookmarklet.min.js".exec
