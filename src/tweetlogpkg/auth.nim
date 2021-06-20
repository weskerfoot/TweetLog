import httpClient, base64, uri, json, os, strformat, sequtils, strutils, options, sugar, times, types
import tables, algorithm, base64, math, options
import nimcrypto
import threadpool

proc realEncodeUrl*(s: string): string =
  ## Exclude A..Z a..z 0..9 - . _ ~
  ## See https://dev.twitter.com/oauth/overview/percent-encoding-parameters
  result = newStringOfCap(s.len + s.len shr 2) # assume 12% non-alnum-chars
  for i in 0..s.len-1:
    case s[i]
    of 'a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.', '~':
      add(result, s[i])
    else:
      add(result, '%')
      add(result, toHex(ord(s[i]), 2))

proc tweetClient*(token : string) : HttpClient =
  var client = newHttpClient()

  client.headers = newHttpHeaders(
    {
      "Authorization" : token
    }
  )
  client

# 3-legged OAuth stuff

proc parseQueryString(qstr : string) : Table[string, string] =
  toTable(
    map(qstr.split("&"),
        proc(pair : string) : tuple[a: string, b: string] =
          let split = pair.split("=")
          (split[0], split[1])))

proc generateNonce() : string {.gcsafe.} =
  let alphabet = map(toSeq(65..90).concat(
                     toSeq(97..122)).concat(
                     toSeq(49..57)), (c) {.gcsafe.} => char(c))

  var randBytes : array[50, uint8]
  discard randomBytes(randBytes)
  return map(randBytes, (c) => alphabet[(c.int %% alphabet.len)]).join

proc constructEncodedString(params : Params, sep : string, include_quotes : bool) : string =
  var encodedPairs : seq[string] = @[]
  var keyPairs : seq[tuple[key: string, value: string]] = toSeq(params.pairs)

  keyPairs.sort((a, b) => cmp(a.key.realEncodeUrl, b.key.realEncodeUrl))

  for pair in keyPairs:
    if include_quotes:
      encodedPairs &= pair[0] & "=" & "\"" & pair[1].realEncodeUrl & "\""
    else:
      encodedPairs &= pair[0] & "=" & pair[1].realEncodeUrl

  encodedPairs.join(sep)

proc constructParameterString(params : Params) : string =
  result = params.constructEncodedString("&", include_quotes=false)
  echo fmt"parameter string = {result}"

proc constructHeaderString(params : Params) : string =
  "OAuth " & params.constructEncodedString(", ", include_quotes=true)

proc sign(reqMethod : string,
          paramString : string,
          baseUrl : string) : string =

  let sigBaseString : string = reqMethod.toUpperAscii & "&" & baseUrl.realEncodeUrl & "&" & paramString.realEncodeUrl
  var signingKey : string

  signingKey = getEnv("TWITTER_CONSUMER_SECRET").realEncodeUrl & "&"

  result = sha1.hmac(signingKey, sigBaseString).data.encode

proc signRequest*(requestUrl : string,
                  requestMethod : string) : Params =
  # Return params along with signature that signs request for API request
  let oauth_consumer_key = getEnv("TWITTER_CONSUMER_KEY")
  let oauth_nonce = generateNonce()

  result["oauth_callback"] = getEnv("TWITTER_OAUTH_CALLBACK")

  # The twitter documentation uses SHA1, but this works and is future-proof
  let oauth_signature_method = "HMAC-SHA1".realEncodeUrl
  let oauth_timestamp : string = $trunc(epochTime()).uint64

  result["oauth_nonce"] = oauth_nonce
  result["oauth_signature_method"] = oauth_signature_method
  result["oauth_timestamp"] = oauth_timestamp
  result["oauth_consumer_key"] = oauth_consumer_key
  result["oauth_version"] = "1.0"

  let paramString = result.constructParameterString

  result["oauth_signature"] = sign(requestMethod, paramString, requestUrl)

proc getAuthRequestSigned(requestUrl : string) : Params =
  signRequest(requestUrl, "POST")

proc requestToken*(requestUrl : string) : Option[OAuthToken] =
  var headers = newHttpHeaders([])

  let params = getAuthRequestSigned(requestUrl)
  let client = tweetClient(params.constructHeaderString)
  let resp = client.request(requestUrl, httpMethod = HttpPost, headers = headers, body = "")

  if resp.status != "200 OK":
    echo resp.body
    return none(OAuthToken)

  let keyPairs = resp.body.parseQueryString

  if not (keyPairs.hasKey("oauth_token") and keyPairs.hasKey("oauth_token_secret")):
    return none(OAuthToken)

  some((oauth_token: keyPairs["oauth_token"], oauth_token_secret: keyPairs["oauth_token_secret"]))

proc getTokenRedirect*() : string =
  let req = "https://api.twitter.com/oauth/request_token".requestToken
  fmt"https://api.twitter.com/oauth/authenticate?oauth_token={req.get.oauth_token}"

proc getAccessToken*(oauth_token : string, oauth_verifier : string) : Option[AccessToken] =
  var params : Params
  let client = tweetClient(params.constructHeaderString)
  let requestUrl = fmt"https://api.twitter.com/oauth/access_token?oauth_token={oauth_token}&oauth_verifier={oauth_verifier}"
  let resp = client.request(requestUrl, httpMethod = HttpPost)

  if resp.status != "200 OK":
    return none(AccessToken)

  let keyPairs = resp.body.parseQueryString

  some((access_token: keyPairs["oauth_token"],
        access_token_secret: keyPairs["oauth_token_secret"],
        screen_name: keyPairs["screen_name"],
        user_id: keyPairs["user_id"]))

import jwt

proc generateJWT*(token : AccessToken) : string =
  # take an access token and return an encrypted JWT
  let secret = getEnv("JWT_SECRET")
  var encoded = toJWT(%*{
    "header" : {
      "alg" : "HS256",
      "typ" : "JWT"
    },
    "claims" : {
      "access_token" : token.access_token,
      "access_token_secret" : token.access_token_secret,
      "screen_name" : token.screen_name,
      "user_id" : token.user_id
    }
  })

  encoded.sign(secret)
  $encoded

proc verify*(token: string): bool =
  let secret = getEnv("JWT_SECRET")
  try:
    let jwtToken = token.toJWT()
    result = jwtToken.verify(secret, HS256)
  except InvalidToken:
    result = false

proc decode*(token: string): Option[AccessToken] =
  if not token.verify:
    return none(AccessToken)
  let claims = token.toJWT().claims
  some((access_token: claims["access_token"].node.str,
        access_token_secret: claims["access_token_secret"].node.str,
        screen_name: claims["screen_name"].node.str,
        user_id: claims["user_id"].node.str))
