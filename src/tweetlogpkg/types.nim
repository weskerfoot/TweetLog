type
  Tweet* = ref object of RootObj
    id*: string
    in_reply*: string
    author_id*: string
    text*: string
    created_at*: string
    conversation_id*: string
