import twit2blogpkg/twitter, twit2blogpkg/help
import os, system, parseopt, strutils, tables

when isMainModule:
  var args = initOptParser(commandLineParams().join(" "))
  var twitterParams = initTable[string, string]()
  let validArgs = @["u", "t", "user", "thread"]
  var currentKey : string

  while true:
    args.next()
    case args.kind
      of cmdEnd: break
      of cmdShortOption, cmdLongOption:
        if (args.key == "help") or (args.key == "h"):
          writeHelp()
        if args.val == "":
          continue
        else:
          if validArgs.contains(args.key):
            twitterParams[args.key] = args.val
      of cmdArgument:
        if validArgs.contains(currentKey):
          twitterParams[currentKey] = args.val

  if twitterParams.hasKey("u"):
    twitterParams["user"] = twitterParams["u"]
  if twitterParams.hasKey("t"):
    twitterParams["thread"] = twitterParams["t"]

  if not (twitterParams.hasKey("user") and twitterParams.hasKey("thread")):
    writeHelp()

  echo twitterParams["thread"].renderThread(twitterParams["user"])
