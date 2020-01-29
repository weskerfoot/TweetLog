import twit2blogpkg/twitter, twit2blogpkg/server
import threadpool

when isMainModule:
  spawn handleRenders()
  startServer()
