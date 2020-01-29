### Twit2Blog

A simple tool to help make it easier to generate readable tweets you can browse.

### Building
`nimble build` is all you'll need at this point.

### Usage
Requires `TWITTER_CONSUMER_KEY` and `TWITTER_CONSUMER_SECRET`, both of which you can only get if you have a registered developer account and an application created for twitter.

```
./twit2blog
```

You must provide the ID of the *last* tweet from the thread you want rendered. E.g. [https://twitter.com/weskerfoot/status/1199466868953759750](https://twitter.com/weskerfoot/status/1199466868953759750) is the last tweet in one of my threads. The reason for this is that the twitter API does not provide an easy way to search for replies to a given tweet.

Example: `http://localhost:8080/thread/weskerfoot/status/1221552400852451329`
