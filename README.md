### TweetLog

A simple tool to help make it easier to archive readable tweets you can browse. No external server or proprietary SaaS solution needed.

### Building
Running `nimble build` is all you'll need at this point.

### Usage
Requires `TWITTER_CONSUMER_KEY` and `TWITTER_CONSUMER_SECRET`, both of which you can only get if you have a registered developer account and an application created for twitter.


1. Compile the server with `nimble build` and then start the server like so.
```
./tweetlog
```

2. Install the bookmarklet. Copy the contents of the `bookmarklet.min.js` file, and then create a bookmark in your browser with it as the location. You may read the unoptimized source in `bookmarklet.js`.

3. Go to a twitter thread, click the bookmarklet, it will open up a new page where your thread will eventually be. Wait a bit and come back to your beautifully archived thread!
