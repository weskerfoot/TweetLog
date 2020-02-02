# Package

version       = "0.1.0"
author        = "Wesley Kerfoot"
description   = "Turn Your Tweets Into Blog Posts"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["twit2blog"]

# Dependencies
requires "nim >= 1.0.9"
requires "https://github.com/dom96/jester"
requires "https://github.com/pragmagic/karax"
