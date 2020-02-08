import tweetlogpkg/twitter, tweetlogpkg/server
import threadpool

when isMainModule:
  spawn handleRenders()
  startServer()
