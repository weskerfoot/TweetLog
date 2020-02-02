import strutils, options, sugar, sequtils, asyncdispatch, threadpool, db_sqlite, strformat
import twitter
import jester

from htmlgen import nil

# one thread just receives messages with thread ID / username
# thread then passes messages to worker threads in round-robin fashion
# worker threads gather thread contents, then update Redis DB (or sqlite) with thread ID mapped to content
# user can go back to page with thread ID / user combo (or unique ID we give them?) and see compiled thread

type
  ThreadRequest = object
    tweetID: string
    author: string

type TwitterThread = ref object of RootObj
  tweetID: string
  author: string
  tweets: string

var chan : Channel[ThreadRequest]

# Max 20 items processing
chan.open(20)

let db = open("twit2blog.db", "", "", "")

proc createTweetTable() =
  db.exec(sql"""CREATE TABLE IF NOT EXISTS threads (
                   id INTEGER PRIMARY KEY,
                   tid TEXT,
                   author TEXT,
                   tweets TEXT
                )""")

proc threadExists(threadID : string, author : string) : Option[TwitterThread] =
  let row = db.getRow(sql"SELECT * FROM threads WHERE tid=? AND author=?", threadID, author)

  if row.all(col => col == ""):
    return none(TwitterThread)
  some(
    TwitterThread(tweetID: row[1],
                  author: row[2],
                  tweets: row[3])
  )

iterator allAuthors() : string =
  for author in db.getAllRows(sql"SELECT DISTINCT author FROM threads"):
    yield author[0]

iterator threadIDs(author : string) : string =
  for threadID in db.getAllRows(sql"SELECT tid from threads WHERE author=?", author):
    yield threadID[0]

proc insertThread(thread : TwitterThread) =
  db.exec(sql"INSERT INTO threads (tid, author, tweets) VALUES (?, ?, ?)",
          thread.tweetID,
          thread.author,
          thread.tweets)

router twitblog:
  get "/thread/@author/status/@tweetID":
    let tweetID = @"tweetID"
    let author = @"author"
    let thread = threadExists(tweetID, author)

    if thread.isSome:
      let title = fmt"Thread by {author}"
      let tweets = thread.get.tweets.split("\n")
      resp htmlgen.body(
        htmlgen.a(href=fmt"/author/{author}/threads", fmt"See all of {author}'s threads"),
        htmlgen.h4(title),
        htmlgen.ul(tweets.map((t) => htmlgen.li(t)).join(""))
      )
    else:
      chan.send(ThreadRequest(tweetID: tweetID, author: author))
      resp htmlgen.h4("Check back later")

  get "/":
    # lists all authors
    let authors = allAuthors.toSeq
    let title = "Authors"
    resp htmlgen.body(
      htmlgen.h4(title),
      htmlgen.ul(
        authors.map((author) =>
          htmlgen.li(
            htmlgen.a(href=fmt"/author/{author}/threads", author)
          )
        ).join("")
      )
    )

  get "/author/@author/threads":
    let author = @"author"
    let title = fmt"Threads for {author}"
    let threads = toSeq(threadIDs(author))
    resp htmlgen.body(
      htmlgen.h4(title),
      htmlgen.ul(
        threads.map((thread) =>
          htmlgen.li(
            htmlgen.a(href=fmt"/thread/{author}/status/{thread}", thread)
          )
        ).join("")
      )
    )

proc startServer* =
  createTweetTable()
  defer: db.close()
  let port = 8080.Port
  let settings = newSettings(port=port)
  var jester = initJester(twitblog, settings=settings)
  jester.serve()

proc handleRenders* =
  while true:
    let t : ThreadRequest = chan.recv()
    if threadExists(t.tweetID, t.author).isSome:
      echo "We already have this thread, so we're skipping it"
      continue

    let tweets = t.tweetID.renderThread(t.author)

    if tweets.isSome:
      insertThread(
        TwitterThread(tweetID: t.tweetID,
                      author: t.author,
                      tweets: tweets.get.join("\n"))
      )
