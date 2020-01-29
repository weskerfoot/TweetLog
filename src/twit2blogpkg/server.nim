import strutils, sets, options, sugar, sequtils, asyncdispatch, threadpool, db_sqlite
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

proc insertThread(thread : TwitterThread) =
  db.exec(sql"INSERT INTO threads (tid, author, tweets) VALUES (?, ?, ?)",
          thread.tweetID,
          thread.author,
          thread.tweets)

get "/thread/:author/status/:threadID":
  let threadID = data{"threadID"}.getStr()
  let author = data{"author"}.getStr()

  let thread = threadExists(threadID, author)

  if thread.isSome:
    respond thread.get.tweets
  else:
    chan.send(
      ThreadRequest(tweetID: data{"threadID"}.getStr(),
                    author: data{"author"}.getStr())
    )
    respond "Hang on, we're grabbing your thread :) Come back to this page later."

proc startServer* =
  createTweetTable()
  defer: db.close()
  runForever(8080)

proc handleRenders* =
  var processing = initHashSet[string]()

  while true:
    let t : ThreadRequest = chan.recv()

    if processing.contains(t.author & t.tweetID):
      continue

    processing.incl(t.author & t.tweetID)

    let tweets = t.tweetID.renderThread(t.author)

    if tweets.isSome:
      insertThread(
        TwitterThread(tweetID: t.tweetID,
                      author: t.author,
                      tweets: tweets.get.join("\n"))
      )
