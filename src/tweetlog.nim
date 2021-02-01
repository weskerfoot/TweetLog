import tweetlogpkg/twitter, tweetlogpkg/server
import threadpool

import httpClient, base64, uri, json, os, strformat, sequtils, strutils, options
import timezones, times

from xmltree import escape

when isMainModule:
  echo "Running"
  for tweet in "1355971359168466945".getThread:
    echo ""
    echo tweet.text
    echo ""

  #for tweet in "strivev4".listTweets2(){"data"}:
    #echo tweet
    #echo tweet{"id"}.getStr.getTweetConvo
  #spawn handleRenders()
  #startServer()
