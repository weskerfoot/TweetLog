import httpClient, base64, uri, json, os, strformat, sequtils, strutils, options

proc buildAuthHeader() : string =
  let consumerKey = "TWITTER_CONSUMER_KEY".getEnv
  let secret = "TWITTER_CONSUMER_SECRET".getEnv
  "Basic " & (consumerKey.encodeUrl & ":"  & secret.encodeUrl).encode

proc getToken*() : string =
  var client = newHttpClient()
  client.headers = newHttpHeaders(
    {
      "Content-Type" : "application/x-www-form-urlencoded;charset=UTF-8",
      "Authorization" : buildAuthHeader()
    }
  )

  let body = "grant_type=client_credentials"

  let response = client.request("https://api.twitter.com/oauth2/token",
                                httpMethod = HttpPost,
                                body = body).body.parseJson

  let responseType = response["token_type"].getStr

  assert(responseType == "bearer")

  "Bearer " & response["access_token"].getStr

proc tweetClient() : HttpClient =
  var client = newHttpClient()
  client.headers = newHttpHeaders(
    {
      "Authorization" : getToken()
    }
  )
  client

proc listTweets*(user : string) : JsonNode =
  let client = tweetClient()
  let reqTarget = fmt"/1.1/statuses/user_timeline.json?count=100&screen_name={user}"
  let url = fmt"https://api.twitter.com{reqTarget}"

  client.request(url, httpMethod = HttpGet).body.parseJson

proc getTweet*(tweetID : string) : string =
  let client = tweetClient()
  let reqTarget = fmt"/1.1/statuses/show.json?id={tweetID}&tweet_mode=extended"
  let url = fmt"https://api.twitter.com{reqTarget}"

  client.request(url, httpMethod = HttpGet).body

proc getThread*(tweetStart : string, user : string) : seq[string] =
  let parsed = tweetStart.getTweet.parseJson
  let nextTweetID = parsed{"in_reply_to_status_id_str"}.getStr()

  if nextTweetID == "":
    if parsed{"user", "screen_name"}.getStr() == user:
      return @[parsed{"full_text"}.getStr()]
    else:
      return @[]
  else:
    if parsed{"user", "screen_name"}.getStr() == user:
      return nextTweetID.getThread(user) & @[parsed{"full_text"}.getStr()]
    else:
      return nextTweetID.getThread(user)

proc convertWords(tweet : string) : string =
  let words = tweet.split(" ")
  var stripped : seq[string]
  for chunk in words:
    for word in chunk.splitLines:
      if word.len > 3 and word[0..3] == "http":
        let parsedUri = word.parseUri
        let scheme = parsedUri.scheme
        let hostname = parsedUri.hostname
        let path = parsedUri.path
        if (scheme.len > 0 and hostname.len > 0):
          stripped &= fmt"[{scheme}://{hostname}{path}]({scheme}://{hostname}{path})"
      elif word.len > 0 and word[0] != '@':
        stripped &= word
      else:
        continue
  stripped.join(" ")

proc renderThread*(tweetID : string, user : string) : Option[seq[string]] =
  let thread = tweetID.getThread(user).map(convertWords).map(capitalizeAscii)
  if thread.len == 0:
    return none(seq[string])
  some(thread)
