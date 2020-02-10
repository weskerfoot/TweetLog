(function() {
  function getLastXPath(xpexp) {
    var iterator = document.evaluate(xpexp, document, null, XPathResult.ORDERED_NODE_ITERATOR_TYPE, null);
    var result = iterator.iterateNext();
    var lastEl = result;

    while(result != null) {
      result = iterator.iterateNext();
      if (result == null) {
        break;
      }
      lastEl = result;
    }
    return lastEl;
  }

  function getLastTweet() {
    var author = window.location.pathname.split('/')[1];
    var xp = "//a[contains(@href, '"+author+"/status')]";
    return getLastXPath(xp).pathname;
  }

  function queueTweet() {
    /* TODO check the current URL */
    /* TODO check the last tweet URL is valid, skip likes/images */
    var lastTweet = getLastTweet();
    var url = "http://localhost:8080/thread"+lastTweet;
    window.open(url, "_blank");
  }

  queueTweet();

})()
