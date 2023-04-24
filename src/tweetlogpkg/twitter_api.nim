import httpClient, uri, json, os, strformat, sequtils, strutils, options, sugar, types
import tables, options, times, twitter
import auth

from nimcrypto.sysrand import randomBytes
from xmltree import escape

proc parseTwitterTS(ts : string) : DateTime =
  ts.parse("ddd MMM dd hh:mm:ss YYYY")

proc listTweets*(user : string, token : AccessToken) : JsonNode =
  # Lists tweets from a given user
  # XXX use Tweet type
  let client = tweetClient("Bearer " & token.access_token)
  let userIdReq = fmt"/2/users/by?usernames={user}"
  var url = fmt"https://api.twitter.com{userIdReq}"

  let userId = client.request(url, httpMethod = HttpGet).body.parseJson{"data"}[0]{"id"}.getStr

  let tweetsReq = fmt"/2/users/{userId}/tweets"
  url = fmt"https://api.twitter.com{tweetsReq}"
  return client.request(url, httpMethod = HttpGet).body.parseJson

proc getTweetConvo*(tweetID : string, token : AccessToken) : JsonNode =
  # Gets the conversation info for a given tweet
  let client = tweetClient("Bearer " & token.access_token)
  let userIdReq = fmt"/2/tweets?ids={tweetID}&tweet.fields=conversation_id,author_id"
  var url = fmt"https://api.twitter.com{userIdReq}"

  let tweetInfo = client.request(url, httpMethod = HttpGet).body.parseJson

  tweetInfo

proc getTweet*(tweetID : string, token : AccessToken) : string =
  # Grabs a single tweet
  # XXX use Tweet type
  let client = tweetClient("Bearer " & token.access_token)
  let reqTarget = fmt"/1.1/statuses/show.json?id={tweetID}&tweet_mode=extended"
  let url = fmt"https://api.twitter.com{reqTarget}"

  client.request(url, httpMethod = HttpGet).body

proc getHome*(count: int, token : AccessToken) : string =
  # Gets your home timeline 
  let client = tweetClient("Bearer " & token.access_token)
  let reqTarget = fmt"/1.1/statuses/user_timeline.json?count={count}&trim_user=1&exclude_replies=1"
  let url = fmt"https://api.twitter.com{reqTarget}"

  client.request(url, httpMethod = HttpGet).body

iterator getThread*(tweetStart : string, token : AccessToken) : Tweet =

  var reqParams : Params # params for the actual API request

  let consumerKey = "TWITTER_CONSUMER_KEY".getEnv
  let secret = "TWITTER_CONSUMER_SECRET".getEnv

  var consumerToken = newConsumerToken(consumerKey, secret)

  var twitterAPI = newTwitterAPI(consumerToken, token.access_token, token.access_token_secret)

  reqParams["status"] = "testing123"
  reqParams["include_entities"] = "true"
  echo fmt"tweetStart = {tweetStart}"

  #var reqTarget = fmt"/2/tweets/search/recent?query=conversation_id:{tweetStart}&tweet.fields=in_reply_to_user_id,author_id,created_at,conversation_id"
  var url = "https://api.twitter.com/1.1/statuses/update.json"

  var currentPage : string

  echo fmt"url = {url}"

  # Simply get.
  var resp = twitterAPI.get("account/verify_credentials.json")
  echo resp.status

  # Using proc corresponding twitter REST APIs.
  resp = twitterAPI.statusesUpdate("testing 1 2 3")
  echo parseJson(resp.body)

  #while true:
    #if currentPage{"meta", "result_count"}.getInt == 0:
      #break
    #for tweet in currentPage{"data"}:
      #yield Tweet(
              #id: tweet{"id"}.getStr,
              #in_reply: tweet{"in_reply_to_user_id"}.getStr,
              #author_id: tweet{"author_id"}.getStr,
              #text: tweet{"text"}.getStr,
              #created_at: tweet{"created_at"}.getStr,
              #conversation_id: tweet{"conversation_id"}.getStr
            #)

    #let paginationToken = currentPage{"meta"}{"next_token"}

    #if paginationToken == nil:
      #break

    #echo "Getting next page"

    #reqTarget = fmt"/2/tweets/search/recent?query=conversation_id:{tweetStart}&tweet.fields=in_reply_to_user_id,author_id,created_at,conversation_id&next_token={paginationToken.getStr}"
    #url = fmt"https://api.twitter.com{reqTarget}"
    #currentPage = client.request(url, httpMethod = HttpGet).body.parseJson

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

proc renderThread*(tweetID : string, token : AccessToken) : Option[seq[string]] =
  let thread = toSeq(getThread(tweetID, token)).map(convertWords).map(capitalizeAscii)
  echo $thread
  if thread.len == 0:
    return none(seq[string])
  some(thread)
