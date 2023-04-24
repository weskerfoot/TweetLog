import strutils, options, sugar, sequtils, asyncdispatch, threadpool, db_sqlite, json, strformat, uri, strscans, times
import twitter_api
import templates
import jester
import auth, types

type Author = object
  name: string
  authorID : int

type ThreadRequest = object
  tweetID: string
  author: Author
  token: AccessToken

type TwitterThread = ref object of RootObj
  tweetID: string
  tweets: string
  author: Author
  collectedAt: DateTime

# DateTime format string in ISO8601 format
const dateFmt = "YYYY-MM-dd'T'hh:mm:ss'Z'"

proc parseTweetUrl(url : string, token : AccessToken) : Option[ThreadRequest] =
  let path = url.parseUri.path
  var author : string
  var tweetID : int
  if scanf(path, "/$w/status/$i$.", author, tweetID):
    some(
      ThreadRequest(
        tweetID : $tweetID,
        author: Author(name: author),
        token: token
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

# If using the web app:
#   go to login link, log in, get redirected
#   jwt generated (of access token and other info) and stored in httponly cookie, sent along with req to api endpoints
#   api decodes it using secret
#
# If using api:
#   generate your own oauth token and oauth secret
#   pass to api
#   api generates jwt (of access token and other info) and it is stored client side wherever client wants (filesystem, etc)
#   it is sent along with req to api endpoints
#   api decodes it using secret
#
# In both cases, expire tokens after n hours
# When re-auth is needed, redirect the user for web app or return response code as appropriate (401 error) and let client refresh
# need a way to get refresh tokens
# should I only refresh when the underlying oauth access token expires?

proc decodeToken(cookies: Table[string, string]) : Option[AccessToken] =
  # take cookies, get jwt if it exists, and try to decode it
  # this can definitely fail

  if cookies.hasKey("twitterjwt"):
    let token = cookies["twitterjwt"]
    return token.decode
  else:
    none(AccessToken)

router twitblog:
  # TODO make me configurable
  get "/tweetlog/auth":
    let params = request.params
    if not ("oauth_token" in params and "oauth_verifier" in params):
      redirect getTokenRedirect()
    else:
      let oauth_token = params["oauth_token"]
      let oauth_verifier = params["oauth_verifier"]
      let access_tok = getAccessToken(oauth_token, oauth_verifier)

      if access_tok.isSome:
        echo "Setting cookie"

        # XXX insecure for now
        setCookie("twitterjwt", access_tok.get.generateJWT, domain="localhost", sameSite=Lax, path="/")

        redirect("http://localhost:3030/")

        #resp(200.HttpCode, $(%*{"jwt" : access_tok.get.generateJWT}), contentType="application/json")
      else:
        resp(500.HttpCode, $(%*{"error" : "Failed to create token"}), contentType="application/json")

  get "/":
    # Lists all authors
    let token = request.cookies.decodeToken

    if token.isNone:
      redirect "/tweetlog/auth"

    let authors = allAuthors.toSeq
    let title = "Authors"
    resp authors.mainPage

  post "/thread":
    let token = request.cookies.decodeToken

    if token.isNone:
      redirect "/tweetlog/auth"

    let params = request.params
    if not ("tweetURL" in params):
      resp "Invalid"

    let threadURL = params["tweetURL"].parseTweetUrl(token.get)

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
      let token = request.cookies.decodeToken
      if token.isNone:
        redirect "/tweetlog/auth"
      chan.send(
        ThreadRequest(
          tweetID: tweetID,
          author: Author(name: author),
          token: token.get
        )
      )
      resp checkBack()

  get "/author/@author/threads":
    # Lists all threads by an author
    let author = @"author"
    let threads = toSeq(threadIDs(author))
    resp author.listThreads(threads)

  get "/tweetlog/auth":
    resp ""

# Entry points

proc startServer* =
  createTweetTables()
  defer: db.close()
  let port = 3030.Port
  let settings = newSettings(port=port)
  var jester = initJester(twitblog, settings=settings)
  jester.serve()

proc handleRenders* =
  echo "Starting processing queue"
  while true:
    let t : ThreadRequest = chan.recv()

    echo t

    if threadExists(t.tweetID, t.author.name).isSome:
      continue

    let tweets = t.tweetID.renderThread(t.token)

    echo $tweets

    if tweets.isSome:
      insertThread(
        TwitterThread(
          tweetID: t.tweetID,
          author: t.author,
          tweets: tweets.get.join("\n"),
          collectedAt: now().utc
        )
      )
