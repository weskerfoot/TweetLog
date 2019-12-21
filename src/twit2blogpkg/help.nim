import system

const
  help = """
Usage: twit2blog [opts]

Options:
  -u, --user   The screen name of the twitter user. E.g. If your twitter is https://twitter.com/foobar, then `foobar`.
  -t, --thread The ID of the last tweet in your thread. E.g. 12345.

For more information read the Github readme:
  https://github.com/weskerfoot/Twit2Blog#readme
"""

proc writeHelp*(quit=true) =
  echo(help)
  if quit:
    quit(1)
