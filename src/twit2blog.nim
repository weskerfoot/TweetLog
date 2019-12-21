import twit2blogpkg/twitter
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
    stderr.writeLine("Invalid Arguments. Must provide both --user and --thread (or -u and -t). E.g. -u:foo -t:123")
    quit(1)

  echo twitterParams["thread"].renderThread(twitterParams["user"])
