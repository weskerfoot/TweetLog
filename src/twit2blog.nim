# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.

import twit2blogpkg/twitter

when isMainModule:
  echo "weskerfoot".listTweets.repr
