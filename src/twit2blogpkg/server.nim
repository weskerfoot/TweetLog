import strutils, options, sugar, sequtils, asyncdispatch, threadpool, db_sqlite, strformat
import twitter
import xander

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

get "/thread/:author/status/:tweetID":
  let tweetID = data{"tweetID"}.getStr()
  let author = data{"author"}.getStr()
  let thread = threadExists(tweetID, author)

  if thread.isSome:
    data["title"] = fmt"Thread by {author}"
    data["tweets"] = thread.get.tweets.split("\n")
    respond tmplt("thread", data)
  else:
    chan.send(ThreadRequest(tweetID: tweetID, author: author))
    data["title"] = "Check back later"
    respond tmplt("nonexistent", data)

get "/":
  # lists all authors
  data["authors"] = allAuthors.toSeq
  data["title"] = "Authors"
  respond tmplt("authors", data)

get "/author/:author/threads":
  let author = data{"author"}.getStr()
  data["author"] = author
  data["title"] = fmt"Threads for {author}"
  data["threads"] = toSeq(threadIDs(author))
  respond tmplt("threads", data)

proc startServer* =
  createTweetTable()
  defer: db.close()
  runForever(8080)

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
