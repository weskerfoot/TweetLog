import httpClient, base64, uri, json, os, strformat, sequtils, strutils, options, sugar, timezones, times, types
import tables, algorithm, base64, math, options
import nimcrypto

from nimcrypto.sysrand import randomBytes
from xmltree import escape

proc parseTwitterTS(ts : string) : DateTime =
  ts.parse("ddd MMM dd hh:mm:ss YYYY")

# echo "Sun Feb 16 18:19:17 +0000 2020".parseTwitterTS.repr

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
  # Lists tweets from a given user
  # XXX use Tweet type
  let client = tweetClient()
  let userIdReq = fmt"/2/users/by?usernames={user}"
  var url = fmt"https://api.twitter.com{userIdReq}"

  let userId = client.request(url, httpMethod = HttpGet).body.parseJson{"data"}[0]{"id"}.getStr

  let tweetsReq = fmt"/2/users/{userId}/tweets"
  url = fmt"https://api.twitter.com{tweetsReq}"
  return client.request(url, httpMethod = HttpGet).body.parseJson

proc getTweetConvo*(tweetID : string) : JsonNode =
  # Gets the conversation info for a given tweet
  let client = tweetClient()
  let userIdReq = fmt"/2/tweets?ids={tweetID}&tweet.fields=conversation_id,author_id"
  var url = fmt"https://api.twitter.com{userIdReq}"

  let tweetInfo = client.request(url, httpMethod = HttpGet).body.parseJson

  tweetInfo

proc getTweet*(tweetID : string) : string =
  # Grabs a single tweet
  # XXX use Tweet type
  let client = tweetClient()
  let reqTarget = fmt"/1.1/statuses/show.json?id={tweetID}&tweet_mode=extended"
  let url = fmt"https://api.twitter.com{reqTarget}"

  client.request(url, httpMethod = HttpGet).body

proc getHome*(count: int) : string =
  # Gets your home timeline 
  let client = tweetClient()
  let reqTarget = fmt"/1.1/statuses/user_timeline.json?count={count}&trim_user=1&exclude_replies=1"
  let url = fmt"https://api.twitter.com{reqTarget}"

  client.request(url, httpMethod = HttpGet).body

iterator getThread*(tweetStart : string) : Tweet =
  let client = tweetClient()
  var reqTarget = fmt"/2/tweets/search/recent?query=conversation_id:{tweetStart}&tweet.fields=in_reply_to_user_id,author_id,created_at,conversation_id"
  var url = fmt"https://api.twitter.com{reqTarget}"

  var currentPage : JsonNode

  currentPage = client.request(url, httpMethod = HttpGet).body.parseJson

  while true:
    if currentPage{"meta", "result_count"}.getInt == 0:
      break
    for tweet in currentPage{"data"}:
      yield Tweet(
              id: tweet{"id"}.getStr,
              in_reply: tweet{"in_reply_to_user_id"}.getStr,
              author_id: tweet{"author_id"}.getStr,
              text: tweet{"text"}.getStr,
              created_at: tweet{"created_at"}.getStr,
              conversation_id: tweet{"conversation_id"}.getStr
            )

    let paginationToken = currentPage{"meta"}{"next_token"}

    if paginationToken == nil:
      break

    reqTarget = fmt"/2/tweets/search/recent?query=conversation_id:{tweetStart}&tweet.fields=in_reply_to_user_id,author_id,created_at,conversation_id&next_token={paginationToken.getStr}"
    url = fmt"https://api.twitter.com{reqTarget}"
    currentPage = client.request(url, httpMethod = HttpGet).body.parseJson

proc convertWords(tweet : Tweet) : string =
  let words = tweet.text.split(" ")
  var stripped : seq[string]
  for chunk in words:
    for word in chunk.splitLines:
      if word.len > 3 and word[0..3] == "http":
        let parsedUri = word.parseUri
        let scheme = parsedUri.scheme
        let hostname = parsedUri.hostname
        let path = parsedUri.path
        if (scheme.len > 0 and hostname.len > 0):
          let url = xmltree.escape(fmt"{scheme}://{hostname}{path}")
          stripped &= url
      elif word.len > 0 and word[0] != '@':
        stripped &= word
      else:
        continue
  stripped.join(" ")

proc renderThread*(tweetID : string) : Option[seq[string]] =
  let thread = toSeq(getThread(tweetID)).map(convertWords).map(capitalizeAscii)
  if thread.len == 0:
    return none(seq[string])
  some(thread)

# 3-legged OAuth stuff
type Params = Table[string, string]
type OAuthToken = tuple[token: string, token_secret: string]

proc generateNonce*() : string =
  let alphabet = map(toSeq(65..90).concat(
                     toSeq(97..122)).concat(
                     toSeq(49..57)), (c) => char(c))

  var randBytes : array[50, uint8]
  discard randomBytes(randBytes)
  return map(randBytes, (c) => alphabet[(c.int %% alphabet.len)]).join

proc constructEncodedString(params : Params, sep : string, include_quotes : bool) : string =
  var encodedPairs : seq[string] = @[]
  var keyPairs : seq[tuple[key: string, value: string]] = toSeq(params.pairs)

  keyPairs.sort((a, b) => cmp(a.key.encodeUrl, b.key.encodeUrl))

  for pair in keyPairs:
    if include_quotes:
      encodedPairs &= pair[0].encodeUrl & "=" & "\"" & pair[1].encodeUrl & "\""
    else:
      encodedPairs &= pair[0].encodeUrl & "=" & pair[1].encodeUrl

  encodedPairs.join(sep)

proc constructParameterString(params : Params) : string =
  params.constructEncodedString("&", include_quotes=false)

proc constructHeaderString(params : Params) : string =
  "OAuth " & params.constructEncodedString(", ", include_quotes=true)

proc sign(reqMethod : string,
          paramString : string,
          baseUrl : string,
          accessToken : string = "") : string =
  let sigBaseString : string = reqMethod.toUpperAscii & "&" & baseUrl.encodeUrl & "&" & paramString.encodeUrl

  let signingKey : string = getEnv("TWITTER_CONSUMER_SECRET").encodeUrl & "&" & accessToken
  sha256.hmac(signingKey, sigBaseString).data.encode

proc requestToken*(requestUrl : string, requestMethod : string, requestBody : string) : Option[OAuthToken] =
  # Obtain a request token for OAuth
  # as well as a request token secret
  # these are used to authenticate a specific user
  let client = tweetClient()
  let callback = getEnv("TWITTER_OAUTH_CALLBACK")
  let consumerKey = getEnv("TWITTER_CONSUMER_KEY")

  var headers = newHttpHeaders([])

  let oauth_nonce = generateNonce()

  # The twitter documentation uses SHA1, but this works and is future-proof
  let oauth_signature_method = "HMAC-SHA256"
  let oauth_timestamp : string = $trunc(epochTime()).uint64

  var params : Params = {
    "oauth_nonce" : oauth_nonce,
    "oauth_signature_method" : oauth_signature_method,
    "oauth_callback" : callback,
    "oauth_timestamp" : oauth_timestamp,
    "oauth_consumer_key" : consumerKey,
    "oauth_version" : "1.0"
    }.toTable

  let paramString = params.constructParameterString

  let signature = sign(requestMethod, paramString, requestUrl)

  params["oauth_signature"] = signature
  headers["Authorization"] = @[params.constructHeaderString]

  let resp = client.request(requestUrl, httpMethod = HttpPost, headers = headers, body = requestBody)

  if resp.status != "200 OK":
    echo resp.body
    return none(OAuthToken)

  let keyPairs : Table[string, string] = toTable(
      map(resp.body.split("&"),
          proc(pair : string) : tuple[a: string, b: string] =
            let split = pair.split("=")
            (split[0], split[1])))

  if not (keyPairs.hasKey("oauth_token") and keyPairs.hasKey("oauth_token_secret")):
    return none(OAuthToken)

  some((token: keyPairs["oauth_token"], token_secret: keyPairs["oauth_token_secret"]))
