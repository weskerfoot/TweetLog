import strutils, options, sugar, sequtils, asyncdispatch, threadpool, db_sqlite, json, strformat, uri, strscans, times
import twitter
import templates
import jester

type Author = object
  name: string
  authorID : int

type ThreadRequest = object
  tweetID: string
  author: Author

type TwitterThread = ref object of RootObj
  tweetID: string
  tweets: string
  author: Author
  collectedAt: DateTime

const dateFmt = "YYYY-MM-dd hh:mm:ss"

proc parseTweetUrl(url : string) : Option[ThreadRequest] =
  let path = url.parseUri.path
  var author : string
  var tweetID : int
  if scanf(path, "/$w/status/$i$.", author, tweetID):
    some(
      ThreadRequest(
        tweetID : $tweetID,
        author: Author(name: author)
      )
    )
  else:
    none(ThreadRequest)

var chan : Channel[ThreadRequest]

# Max 20 items processing
chan.open(20)

# Database functions

let db = open("tweetlog.db", "", "", "")

proc createTweetTables() =
  db.exec(sql"""CREATE TABLE IF NOT EXISTS threads (
                   id INTEGER PRIMARY KEY,
                   tid TEXT,
                   tweets TEXT,
                   collectedAt TEXT,
                   authorID INTEGER
                )""")

  db.exec(sql"""CREATE TABLE IF NOT EXISTS authors (
                   id INTEGER PRIMARY KEY,
                   name TEXT,
                   UNIQUE(name, id)
                )""")

proc authorExists(authorName : string) : Option[Author] =
  let authorID = db.getRow(sql"SELECT * from authors where name=?", authorName)

  if authorID.all(col => col == ""):
    return none(Author)

  return some(
    Author(
      name: authorName,
      authorID: authorID[0].parseInt)
  )

proc threadExists(threadID : string, authorName : string) : Option[TwitterThread] =
  let author = authorName.authorExists

  if not author.isSome:
    return none(TwitterThread)

  let row = db.getRow(sql"SELECT * FROM threads WHERE tid=? AND authorID=?",
                      threadID,
                      author.get.authorID)

  if row.all(col => col == ""):
    return none(TwitterThread)

  let f = initTimeFormat("yyyy-MM-dd")

  some(
    TwitterThread(
      tweetID: row[1],
      author: author.get,
      tweets: row[2],
      collectedAt: row[3].parse(dateFmt)
    )
  )

iterator allAuthors() : string =
  for author in db.getAllRows(sql"SELECT DISTINCT name FROM authors"):
    yield author[0]

iterator threadIDs(author : string) : string =
  let authorID = db.getRow(sql"SELECT * from authors where name=?", author)

  if authorID.all(col => col == ""):
    yield ""
  else:
    for threadID in db.getAllRows(sql"SELECT tid from threads WHERE authorID=?", authorID):
      yield threadID[0]

proc insertThread(thread : TwitterThread) =
  db.exec(sql"INSERT OR IGNORE INTO authors (name) VALUES (?)", thread.author.name)

  let author = thread.author.name.authorExists

  if not author.isSome:
    return

  db.exec(sql"INSERT INTO threads (tid, tweets, collectedAt, authorID) VALUES (?, ?, ?, ?)",
          thread.tweetID,
          thread.tweets,
          thread.collectedAt.format(dateFmt),
          author.get.authorID)

# Routes

router twitblog:
  get "/":
    # Lists all authors
    let authors = allAuthors.toSeq
    let title = "Authors"
    resp authors.mainPage

  post "/thread":
    let params = request.params
    if not ("tweetURL" in params):
      resp "Invalid"

    let threadURL = params["tweetURL"].parseTweetUrl

    if threadURL.isSome:
      redirect (fmt"/thread/{threadURL.get.author}/status/{threadURL.get.tweetID}")
    else:
      resp "Invalid"

  get "/thread/@author/status/@tweetID":
    let tweetID = @"tweetID"
    let author = @"author"
    let thread = threadExists(tweetID, author)

    if thread.isSome:
      # Lists all the tweets in a thread
      let tweets = thread.get.tweets.split("\n")
      resp tweetThread(author,
                       thread.get.tweets.split("\n"),
                       thread.get.collectedAt.format(dateFmt))
    else:
      # Send it off to the rendering thread for processing
      # Let them know to check back later
      chan.send(
        ThreadRequest(
          tweetID: tweetID,
          author: Author(name: author)
        )
      )
      resp checkBack()

  get "/author/@author/threads":
    # Lists all threads by an author
    let author = @"author"
    let threads = toSeq(threadIDs(author))
    resp author.listThreads(threads)

# Entry points

proc startServer* =
  createTweetTables()
  defer: db.close()
  let port = 8080.Port
  let settings = newSettings(port=port)
  var jester = initJester(twitblog, settings=settings)
  jester.serve()

proc handleRenders* =
  echo "Starting processing queue"
  while true:
    let t : ThreadRequest = chan.recv()

    if threadExists(t.tweetID, t.author.name).isSome:
      continue

    let tweets = t.tweetID.renderThread(t.author.name)

    if tweets.isSome:
      insertThread(
        TwitterThread(
          tweetID: t.tweetID,
          author: t.author,
          tweets: tweets.get.join("\n"),
          collectedAt: now().utc
        )
      )
