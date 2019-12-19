# This is just an example to get you started. Users of your hybrid library will
# import this file by writing ``import twit2blogpkg/submodule``. Feel free to rename or
# remove this file altogether. You may create additional modules alongside
# this file as required.

import httpClient, base64, uri, json, os, strformat

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


proc listTweets*(user : string) : JsonNode =
  var client = newHttpClient()
  let reqTarget = fmt"/1.1/statuses/user_timeline.json?count=100&screen_name={user}"
  let url = fmt"https://api.twitter.com{reqTarget}"
  client.headers = newHttpHeaders(
    {
      "Authorization" : getToken()
    }
  )

  client.request(url, httpMethod = HttpGet).body.parseJson
