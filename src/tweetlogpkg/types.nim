import tables

type Params* = Table[string, string]
type OAuthToken* = tuple[oauth_token: string, oauth_token_secret: string]

type AccessToken* = tuple[access_token : string,
                          access_token_secret: string,
                          screen_name: string,
                          user_id: string]

type
  Tweet* = ref object of RootObj
    id*: string
    in_reply*: string
    author_id*: string
    text*: string
    created_at*: string
    conversation_id*: string
