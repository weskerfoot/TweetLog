import httpClient, base64, uri, json, os, strformat, sequtils, strutils, options, sugar, times, types
import tables, algorithm, base64, math, options
import nimcrypto

proc tweetClient*(token : string) : HttpClient =
  var client = newHttpClient()
  client.headers = newHttpHeaders(
    {
      "Authorization" : token
    }
  )
  client

# client credentials flow
proc buildAuthHeader() : string =
  let consumerKey = "TWITTER_CONSUMER_KEY".getEnv
  let secret = "TWITTER_CONSUMER_SECRET".getEnv
  "Basic " & (consumerKey.encodeUrl & ":"  & secret.encodeUrl).encode

proc getBearerToken*() : string =
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

# 3-legged OAuth stuff
type Params = Table[string, string]
type OAuthToken = tuple[token: string, token_secret: string]

proc generateNonce() : string =
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

  let client = tweetClient(params.constructHeaderString)

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

