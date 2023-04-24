import tweetlogpkg/twitter_api, tweetlogpkg/server
import threadpool
import tweetlogpkg/auth
import httpClient, base64, uri, json, os, strformat, sequtils, strutils, options
import timezones, times

from xmltree import escape

when isMainModule:
  #echo "weskerfoot".listTweets
  #echo 10.getHome
  #for tweet in "1355971359168466945".getThread:
    #echo ""
    #echo tweet.text
    #echo ""

  #for tweet in "strivev4".listTweets2(){"data"}:
    #echo tweet
    #echo tweet{"id"}.getStr.getTweetConvo
  spawn handleRenders()
  startServer()
