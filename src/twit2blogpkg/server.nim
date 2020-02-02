import strutils, options, sugar, sequtils, asyncdispatch, threadpool, db_sqlite, json
import twitter
import templates
import jester

type ThreadRequest = object
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
  get "/":
    # Lists all authors
    let authors = allAuthors.toSeq
    let title = "Authors"
    resp authors.mainPage

  post "/thread":
    let params = request.formData
    if not ("tweetID" in params and "author" in params):
      resp "nope"

    let tweetID = params["tweetID"].body
    let author = params["author"].body

    let thread = threadExists(tweetID, author)

    chan.send(ThreadRequest(tweetID: tweetID, author: author))
    resp checkBack()

  get "/thread/@author/status/@tweetID":
    let tweetID = @"tweetID"
    let author = @"author"
    let thread = threadExists(tweetID, author)

    if thread.isSome:
      # Lists all the tweets in a thread
      let tweets = thread.get.tweets.split("\n")
      resp tweetThread(author, thread.get.tweets.split("\n"))
    else:
      # Send it off to the rendering thread for processing
      # Let them know to check back later
      chan.send(ThreadRequest(tweetID: tweetID, author: author))
      resp checkBack()

  get "/author/@author/threads":
    # Lists all threads by an author
    let author = @"author"
    let threads = toSeq(threadIDs(author))
    resp author.listThreads(threads)

proc startServer* =
  createTweetTable()
  defer: db.close()
  let port = 8080.Port
  let settings = newSettings(port=port)
  var jester = initJester(twitblog, settings=settings)
  jester.serve()

proc handleRenders* =
  echo "Starting processing queue"
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
