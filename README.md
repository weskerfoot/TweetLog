### Twit2Blog

A simple tool to help make it easier to turn your tweet rants into real blog posts

### Building
`nimble build` is all you'll need at this point.

### Usage
Requires `TWITTER_CONSUMER_KEY` and `TWITTER_CONSUMER_SECRET`, both of which you can only get if you have a registered developer account and an application created for twitter.

```
Usage: twit2blog [opts]

Options:
  -u, --user   The screen name of the twitter user. E.g. If your twitter is https://twitter.com/foobar, then `foobar`.
  -t, --thread The ID of the last tweet in your thread. E.g. 12345.

For more information read the Github readme:
  https://github.com/weskerfoot/Twit2Blog#readme
```

Example: `twit2blog -t:1234 -u:alice | pandoc --from=markdown --to=html > thread.html`

You must provide the ID of the *last* tweet from the thread you want rendered. E.g. [https://twitter.com/weskerfoot/status/1199466868953759750](https://twitter.com/weskerfoot/status/1199466868953759750) is the last tweet in one of my threads. The reason for this is that the twitter API does not provide an easy way to search for replies to a given tweet.

You can see the output generated from it [here](https://wesk.tech/tweet_example.html)
