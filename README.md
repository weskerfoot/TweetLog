### Twit2Blog

A simple tool to help make it easier to turn your tweet rants into real blog posts

### Building
`nimble build` is all you'll need at this point.

### Running
Requires `TWITTER_CONSUMER_KEY` and `TWITTER_CONSUMER_SECRET`, both of which you can only get if you have a registered developer account and an application created for twitter.

Example: `/twit2blog -t:1234 -u:alice | pandoc --from=markdown --to=html > thread.html`
