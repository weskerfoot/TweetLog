import httpClient, uri, json, os, strformat, sequtils, strutils, options, sugar, types
import tables, options, times
import auth

from nimcrypto.sysrand import randomBytes
from xmltree import escape

proc parseTwitterTS(ts : string) : DateTime =
  ts.parse("ddd MMM dd hh:mm:ss YYYY")

proc listTweets*(user : string) : JsonNode =
  # Lists tweets from a given user
  # XXX use Tweet type
  let client = tweetClient(getBearerToken())
  let userIdReq = fmt"/2/users/by?usernames={user}"
  var url = fmt"https://api.twitter.com{userIdReq}"

  let userId = client.request(url, httpMethod = HttpGet).body.parseJson{"data"}[0]{"id"}.getStr

  let tweetsReq = fmt"/2/users/{userId}/tweets"
  url = fmt"https://api.twitter.com{tweetsReq}"
  return client.request(url, httpMethod = HttpGet).body.parseJson

proc getTweetConvo*(tweetID : string) : JsonNode =
  # Gets the conversation info for a given tweet
  let client = tweetClient(getBearerToken())
  let userIdReq = fmt"/2/tweets?ids={tweetID}&tweet.fields=conversation_id,author_id"
  var url = fmt"https://api.twitter.com{userIdReq}"

  let tweetInfo = client.request(url, httpMethod = HttpGet).body.parseJson

  tweetInfo

proc getTweet*(tweetID : string) : string =
  # Grabs a single tweet
  # XXX use Tweet type
  let client = tweetClient(getBearerToken())
  let reqTarget = fmt"/1.1/statuses/show.json?id={tweetID}&tweet_mode=extended"
  let url = fmt"https://api.twitter.com{reqTarget}"

  client.request(url, httpMethod = HttpGet).body

proc getHome*(count: int) : string =
  # Gets your home timeline 
  let client = tweetClient(getBearerToken())
  let reqTarget = fmt"/1.1/statuses/user_timeline.json?count={count}&trim_user=1&exclude_replies=1"
  let url = fmt"https://api.twitter.com{reqTarget}"

  client.request(url, httpMethod = HttpGet).body

iterator getThread*(tweetStart : string) : Tweet =
  let client = tweetClient(getBearerToken())
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
