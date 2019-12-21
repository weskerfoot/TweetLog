import httpClient, base64, uri, json, os, strformat, sequtils

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

